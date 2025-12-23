let
    // ==============================================================================
    // STEP 0: DYNAMIC CONFIGURATION
    // Extracts date suffixes from the "Helper" table to build dynamic column names 
    // (e.g., "SOH1223"). This ensures the final report headers match the data source dates.
    // ==============================================================================
    SourceHelper = Excel.CurrentWorkbook(){[Name="Helper"]}[Content],
    DateList = SourceHelper[#"Date to analyse "],

    GetVolName = (rowNumber) => 
        let 
            val = Text.From(DateList{rowNumber}),
            suffix = Text.End(val, 4)
        in 
            "SOH" & suffix,

    TargetName_T1 = GetVolName(0),
    TargetName_T2 = GetVolName(1),
    TargetName_T3 = GetVolName(2),
    TargetName_T5 = GetVolName(3),

    // ==============================================================================
    // STEP 1-4: EXTRACT & TRANSFORM SNAPSHOTS
    // Loads four distinct Stock-On-Hand (SOH) snapshots.
    // Logic: Standardizes "Item Code" and "Wh" (Warehouse) to ensure clean joins.
    // ==============================================================================
    
    // Process Baseline (Table1)
    Source = Excel.CurrentWorkbook(){[Name="Table1"]}[Content],
    #"Selected T1 Columns" = Table.SelectColumns(Source, {"Supplier", "Buyer", "Wh", "Desc", "Item Code", "Stock On Hand"}),
    #"Renamed T1" = Table.RenameColumns(Table.TransformColumnTypes(#"Selected T1 Columns", {{"Item Code", type text}, {"Wh", Int64.Type}, {"Stock On Hand", type number}}), {{"Stock On Hand", "_SOH_Start"}}),

    // Process Intermediate Snapshots (Table2, Table3, Table5)
    Source2 = Excel.CurrentWorkbook(){[Name="Table2"]}[Content],
    #"Renamed T2" = Table.RenameColumns(Table.TransformColumnTypes(Table.SelectColumns(Source2, {"Item Code", "Wh", "Stock On Hand"}), {{"Item Code", type text}, {"Wh", Int64.Type}, {"Stock On Hand", type number}}), {{"Stock On Hand", "_SOH_Mid1"}}),

    Source3 = Excel.CurrentWorkbook(){[Name="Table3"]}[Content],
    #"Renamed T3" = Table.RenameColumns(Table.TransformColumnTypes(Table.SelectColumns(Source3, {"Item Code", "Wh", "Stock On Hand"}), {{"Item Code", type text}, {"Wh", Int64.Type}, {"Stock On Hand", type number}}), {{"Stock On Hand", "_SOH_Mid2"}}),

    Source5 = Excel.CurrentWorkbook(){[Name="Table5"]}[Content],
    #"Renamed T5" = Table.RenameColumns(Table.TransformColumnTypes(Table.SelectColumns(Source5, {"Item Code", "Wh", "Stock On Hand"}), {{"Item Code", type text}, {"Wh", Int64.Type}, {"Stock On Hand", type number}}), {{"Stock On Hand", "_SOH_End"}}),

    // ==============================================================================
    // STEP 5: MULTI-KEY RELATIONAL JOIN
    // Merges snapshots using a Composite Key {"Item Code", "Wh"}.
    // This prevents data duplication if an item exists in multiple warehouses.
    // ==============================================================================
    #"Merged T2" = Table.ExpandTableColumn(Table.NestedJoin(#"Renamed T1", {"Item Code", "Wh"}, #"Renamed T2", {"Item Code", "Wh"}, "T2", JoinKind.LeftOuter), "T2", {"_SOH_Mid1"}),
    #"Merged T3" = Table.ExpandTableColumn(Table.NestedJoin(#"Merged T2", {"Item Code", "Wh"}, #"Renamed T3", {"Item Code", "Wh"}, "T3", JoinKind.LeftOuter), "T3", {"_SOH_Mid2"}),
    #"Merged T5" = Table.ExpandTableColumn(Table.NestedJoin(#"Merged T3", {"Item Code", "Wh"}, #"Renamed T5", {"Item Code", "Wh"}, "T5", JoinKind.LeftOuter), "T5", {"_SOH_End"}),

    // ==============================================================================
    // STEP 6: TREND ANALYSIS CALCULATIONS
    // Calculates Absolute Decrease and Percentage Variance.
    // ==============================================================================
    #"Added Decrease" = Table.AddColumn(#"Merged T5", "Total SOH Decrease", each [_SOH_Start] - [_SOH_End], type number),
    #"Added Variance %" = Table.AddColumn(#"Added Decrease", "Total SOH Decrease %", each if [_SOH_Start] = null or [_SOH_Start] = 0 then 0 else Number.Abs([Total SOH Decrease] / [_SOH_Start]), type number),
    
    // Filtering for significant movements
    #"Filtered Significance" = Table.SelectRows(Table.TransformColumnTypes(#"Added Variance %",{{"Total SOH Decrease %", Percentage.Type}}), each [Total SOH Decrease] > 1),
    #"Sorted Results" = Table.Sort(#"Filtered Significance", {{"Total SOH Decrease", Order.Descending}}),

    // ==============================================================================
    // STEP 7: DYNAMIC HEADER APPLICATION
    // Final step: Replaces placeholder names with the dynamic "SOH+Date" strings.
    // ==============================================================================
    #"Applied Dynamic Names" = Table.RenameColumns(#"Sorted Results", {
        {"_SOH_Start", TargetName_T1}, {"_SOH_Mid1", TargetName_T2},
        {"_SOH_Mid2", TargetName_T3}, {"_SOH_End", TargetName_T5}
    })
in
    #"Applied Dynamic Names"
