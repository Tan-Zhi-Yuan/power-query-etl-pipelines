let
    // ==============================================================================
    // STEP 1: LOAD & EXPAND PO RANGES
    // Imports shorthand ranges (e.g., "10200-05") and expands them into individual rows.
    // ==============================================================================
    Source_Ranges = Excel.CurrentWorkbook(){[Name="Range_Source_Table"]}[Content],
    
    #"Ranges: Changed Type" = Table.TransformColumnTypes(Source_Ranges,{
        {"PO range", type any}, {"No of POs", Int64.Type}
    }),
    
    // Filter out empty rows to prevent errors
    #"Ranges: Filtered Nulls" = Table.SelectRows(#"Ranges: Changed Type", each ([PO range] <> null)),
    
    // Custom Function: Split string delimiters and generate lists {Start..End}
    #"Ranges: Expand Logic" = Table.AddColumn(#"Ranges: Filtered Nulls", "Custom", each let
        inputText = Text.From([PO range]),
        parts = Text.Split(inputText, "-"),
        start_num_text = Text.Trim(parts{0}),
        // Check if a suffix exists (e.g., the "05" in "10200-05")
        end_suffix = if List.Count(parts) > 1 and parts{1} <> "" and parts{1} <> null then Text.Trim(parts{1}) else null,
        start_val = try Number.From(start_num_text) otherwise null
    in
        // If single number, return list of one. If range, generate full list.
        if end_suffix = null or start_val = null then
            if start_val = null then null else {start_val}
        else
            let
                suffix_len = Text.Length(end_suffix),
                prefix_text = Text.Start(start_num_text, Text.Length(start_num_text) - suffix_len),
                end_val_candidate = try Number.From(prefix_text & end_suffix) otherwise null,
                end_val = if end_val_candidate = null then null 
                          else if end_val_candidate >= start_val then end_val_candidate 
                          else null
            in
                if end_val = null then {start_val} else {start_val..end_val}
    ),
    
    RangeTable = Table.ExpandListColumn(#"Ranges: Expand Logic", "Custom"),

    // ==============================================================================
    // STEP 2: LOAD FINANCIAL STATUS
    // Imports the financial totals from the system report.
    // ==============================================================================
    Source_Status = Excel.CurrentWorkbook(){[Name="Financial_Source_Table"]}[Content],
    StatusTable = Table.SelectColumns(Source_Status, {"PO Number", "Total", "Cur"}),

    // ==============================================================================
    // STEP 3: MAIN TRANSFORMATION
    // Merges data, calculates TEU (Volume), and normalizes financial totals.
    // ==============================================================================
    Source_Main = Excel.CurrentWorkbook(){[Name="Main_Data_Table"]}[Content],
    
    // Join with Expanded Ranges to filter for relevant POs only
    #"Merged With Ranges" = Table.NestedJoin(Source_Main, {"PO Number"}, RangeTable, {"Custom"}, "RangeData", JoinKind.Inner),
    #"Removed RangeData" = Table.RemoveColumns(#"Merged With Ranges",{"RangeData"}),
    
    // GROUPING ALGORITHM:
    // We group by PO Number to apply logic to the "First Line" only.
    // This prevents "Double Counting" of financial totals when multiple lines exist.
    #"Grouped for Indexing" = Table.Group(#"Removed RangeData", {"PO Number"}, {
        {"WithIndex", each Table.AddIndexColumn(Table.Sort(_, {{"linenum", Order.Ascending}}), "PO_Row_Index", 1, 1), type table}
    }),
    
    // Expand the grouped table back out
    ColumnsToExpand = List.Combine({List.RemoveItems(Table.ColumnNames(#"Removed RangeData"), {"PO Number"}), {"PO_Row_Index"}}),
    #"Expanded Indexed Table" = Table.ExpandTableColumn(#"Grouped for Indexing", "WithIndex", ColumnsToExpand, ColumnsToExpand),
    
    // CALCULATE TEU (Twenty-foot Equivalent Unit)
    // Logic: Only apply TEU value to the first line (Index=1) to avoid duplication.
    #"Added TEU" = Table.AddColumn(#"Expanded Indexed Table", "TEU", 
        each if [PO_Row_Index] = 1 
            then (if [Container Type] = "20ft" or [Container Type] = "SpecialCargo" then 1 
                  else if [Container Type] = "40ft" then 2 
                  else if [Container Type] = "40ftHQ" then 2.25 
                  else null)
            else 0,
        type number),

    // MAP FINANCIALS
    #"Merged OM Status" = Table.NestedJoin(#"Added TEU", {"PO Number"}, StatusTable, {"PO Number"}, "OM_Status", JoinKind.LeftOuter),
    #"Expanded OM Status" = Table.ExpandTableColumn(#"Merged OM Status", "OM_Status", {"Total", "Cur"}, {"Total_Source", "Currency_Source"}),
    
    // Final Logic: If TEU is 0 (meaning it's a secondary line), set Total Cost to 0 to prevent sum-of-sums errors.
    #"Calculated Final Total" = Table.AddColumn(#"Expanded OM Status", "Total", 
        each if [TEU] = 0 then 0 else [Total_Source], 
        type number),
    
    #"Final Cleanup" = Table.RemoveColumns(#"Calculated Final Total",{"Total_Source", "PO_Row_Index", "Currency_Source"}),
    
    // Add Standard Currency Column
    #"Added Currency" = Table.AddColumn(#"Final Cleanup", "Currency", each "EUR", type text)
in
    #"Added Currency"
        "quantity", "linenum", "Destination", "Ship By Date", "Departure Date", 
        "Expected Arrival Date", "Supplier Confirmed Arrival", "Vessel Arrival", 
        "warehouse", "TEU", "Total", "Currency [EUR]"
    })
in
    #"Final Reorder"
