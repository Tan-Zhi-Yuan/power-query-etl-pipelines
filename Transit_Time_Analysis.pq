let
    // ==============================================================================
    // STEP 1: LOAD & SELECT COLUMNS
    // Imports raw PO data and keeps only logistics-related fields.
    // ==============================================================================
    Source = Excel.CurrentWorkbook(){[Name="Raw_PO_Data"]}[Content],
    
    // Select specific columns first to optimize memory usage
    #"Selected Columns" = Table.SelectColumns(Source, {
        "DocNum", "CardName", "ETDdate", "ETAdate", 
        "dep", "des", "WhsCode", "LineNum"
    }),

    #"Changed Type" = Table.TransformColumnTypes(#"Selected Columns",{
        {"DocNum", Int64.Type}, {"CardName", type text}, 
        {"ETDdate", type date}, {"ETAdate", type date}, 
        {"dep", type text}, {"des", type text}, 
        {"WhsCode", type text}, {"LineNum", Int64.Type}
    }),

    // ==============================================================================
    // STEP 2: FILTERING & NORMALIZATION
    // Removes local shipments and normalizes warehouse codes.
    // ==============================================================================
    
    // Filter out local deliveries (keep only International)
    #"Filtered International" = Table.SelectRows(#"Changed Type", each ([dep] <> "Local_Shipment_Code")),
    
    // Dynamic Date Filter: Keep only the last 6 months (Sliding Window)
    #"Filtered Last 6 Months" = Table.SelectRows(#"Filtered International", 
        each [ETDdate] >= Date.AddMonths(Date.From(DateTime.LocalNow()), -6)
    ),

    // Normalize Warehouse Codes (Map Legacy codes to Standard IDs)
    #"Normalized Warehouse" = Table.ReplaceValue(
        #"Filtered Last 6 Months", "01CO", "01", Replacer.ReplaceText, {"WhsCode"}
    ),
    #"Normalized Warehouse 2" = Table.ReplaceValue(
        #"Normalized Warehouse", "EXP", "02", Replacer.ReplaceText, {"WhsCode"}
    ),

    // ==============================================================================
    // STEP 3: DEDUPLICATION (HEADER LEVEL LOGIC)
    // ERP data is Line-Level. We need Header-Level (1 row per PO) to calculate averages.
    // ==============================================================================
    
    // Sort by Line Number to ensure we keep the first line (Line 0 or 1)
    #"Sorted by Line" = Table.Sort(#"Normalized Warehouse 2",{{"LineNum", Order.Ascending}}),
    
    // Remove duplicates based on PO Number to get unique shipments
    #"Unique POs" = Table.Distinct(#"Sorted by Line", {"DocNum"}),
    
    #"Removed LineNum" = Table.RemoveColumns(#"Unique POs",{"LineNum"}),

    // ==============================================================================
    // STEP 4: CALCULATIONS & TEXT PARSING
    // Calculates Transit Time and splits "CountryPort" strings.
    // ==============================================================================
    
    // Calculate Lead Time
    #"Added Transit Days" = Table.AddColumn(#"Removed LineNum", "Transit Days", 
        each Duration.Days([ETAdate] - [ETDdate]), Int64.Type
    ),

    // Rename Columns for Reporting
    #"Renamed Columns" = Table.RenameColumns(#"Added Transit Days",{
        {"des", "Destination Country"}, 
        {"dep", "Raw_Departure"}, 
        {"ETAdate", "ETA"}, 
        {"ETDdate", "ETD"}, 
        {"CardName", "Supplier"}, 
        {"DocNum", "PO"},
        {"WhsCode", "Destination Warehouse"}
    }),

    // Parse "CNShanghai" -> "CN" (Country) and "Shanghai" (Port)
    #"Parsed Origin Country" = Table.AddColumn(#"Renamed Columns", "Origin Country", 
        each Text.Start([Raw_Departure], 2), type text
    ),
    
    #"Parsed Origin Port" = Table.AddColumn(#"Parsed Origin Country", "Origin Port", 
        each Text.Trim(Text.Middle([Raw_Departure], 2)), type text
    ),
    
    #"Final Cleanup" = Table.RemoveColumns(#"Parsed Origin Port", {"Raw_Departure"}),
    
    #"Final Reorder" = Table.ReorderColumns(#"Final Cleanup",{
        "PO", "Supplier", "ETD", "ETA", "Origin Country", "Origin Port", 
        "Destination Country", "Destination Warehouse", "Transit Days"
    })
in
    #"Final Reorder"
