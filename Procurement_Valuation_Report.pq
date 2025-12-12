let
    // ==============================================================================
    // STEP 1: CONFIGURATION & DATE RANGE DEFINITION
    // Reads two helper tables (SOY, EOY) to define a dynamic date filter range.
    // ==============================================================================
    
    // Read Start of Year (SOY) date from config table
    Source_SOY = Excel.CurrentWorkbook(){[Name="SOY"]}[Content],
    SOY_Date = Date.From(Source_SOY{0}[Column1]),

    // Read End of Year (EOY) date from config table
    Source_EOY = Excel.CurrentWorkbook(){[Name="EOY"]}[Content],
    EOY_Date = Date.From(Source_EOY{0}[Column1]),

    // ==============================================================================
    // STEP 2: LOAD MAIN DATA AND PERFORM INITIAL CLEANUP
    // ==============================================================================
    Source = Excel.CurrentWorkbook(){[Name="Table1"]}[Content],
    
    // Select specific columns first to optimize memory (faster than removing later)
    #"Selected Required Columns" = Table.SelectColumns(Source, {
        "PO Number", "Supplier Inv Date", "Whse", "Supplier#", "Supplier Name", 
        "Line Id", "Item Code", "Item Description", "Ccy", "PO Qty", "PO Price", 
        "PO Amount", "PO LineNum", "Inv Price", "Inv Amount", "Supplier Inv No"
    }),

    #"Changed Type" = Table.TransformColumnTypes(#"Selected Required Columns",{
        {"PO Number", Int64.Type}, {"Supplier Inv Date", type date}, {"Whse", type text}, 
        {"Supplier#", type text}, {"Supplier Name", type text}, {"PO LineNum", Int64.Type}, 
        {"Item Code", type text}, {"Item Description", type text}, {"Ccy", type text}, 
        {"PO Qty", Int64.Type}, {"PO Price", type number}, {"PO Amount", type number}
    }),

    // ==============================================================================
    // STEP 3: RENAME AND APPLY DATE FILTER
    // ==============================================================================
    #"Renamed Columns" = Table.RenameColumns(#"Changed Type",{
        {"Supplier#", "Supplier Code"},
        {"Whse", "WhsCode"},
        {"PO LineNum", "LineNum"},
        {"Item Code", "ItemCode"},
        {"Item Description", "ITEMNAME"},
        {"Ccy", "Currency"},
        {"PO Qty", "Quantity"},
        {"PO Price", "Price"},
        {"PO Amount", "total"},
        {"Supplier Inv Date", "Invoice Date"} // Use a clean column name
    }),

    // Apply the dynamic filter using the SOY_Date and EOY_Date variables
    #"Filtered By Date Range" = Table.SelectRows(#"Renamed Columns", 
        each [Invoice Date] >= SOY_Date and [Invoice Date] <= EOY_Date
    ),

    // ==============================================================================
    // STEP 4: MERGE FCL TYPE (Container Type)
    // ==============================================================================
    
    Source_Container = Excel.CurrentWorkbook(){[Name="Table4"]}[Content],
    
    // Prepare the lookup table
    #"Container_Typed" = Table.TransformColumnTypes(Source_Container, {
        {"PO Number", Int64.Type}, 
        {"FCL Type", type text}
    }),
    
    // Merge FCL Type onto the main table using PO Number (Left Outer Join)
    #"Merged FCL Data" = Table.NestedJoin(#"Filtered By Date Range", {"PO Number"}, 
        #"Container_Typed", {"PO Number"}, "Container_Data", JoinKind.LeftOuter
    ),
    
    // Expand the container column
    #"Expanded FCL Type" = Table.ExpandTableColumn(#"Merged FCL Data", "Container_Data", 
        {"FCL Type"}, {"U_MCS_Container"}
    ),
    
    // ==============================================================================
    // STEP 5: FINAL CLEANUP AND DEDUPLICATION
    // ==============================================================================
    
    #"Reordered Final" = Table.ReorderColumns(#"Expanded FCL Type",{
        "PO Number", "LineNum", "Supplier Code", "Supplier Name", "Quantity", 
        "WhsCode", "ItemCode", "ITEMNAME", "Invoice Date", "U_MCS_Container", 
        "Currency", "Price", "total"
    }),
    
    // Remove duplicates based on the unique line item (PO Number + LineNum)
    // This step ensures only one record exists for each PO line item.
    #"Removed Duplicates" = Table.Distinct(#"Reordered Final", {"PO Number", "LineNum"})

in
    #"Removed Duplicates"
