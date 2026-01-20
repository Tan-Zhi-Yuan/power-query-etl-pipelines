let
    // ==============================================================================
    // STEP 0: DYNAMIC CONFIGURATION
    // ------------------------------------------------------------------------------
    // Extracts date values from the "Helper" table to build dynamic column headers.
    // Logic: Takes the last 4 characters of the date (e.g., "1223") to suffix "SOH".
    // ==============================================================================
    SourceHelper = Excel.CurrentWorkbook(){[Name="Helper"]}[Content],
    DateList = SourceHelper[#"Date to analyse"],

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
    // STEP 1: EXTRACT & STANDARDIZE SNAPSHOTS
    // ------------------------------------------------------------------------------
    // Loads 4 distinct snapshots (Start, Mid1, Mid2, End).
    // Renames the value column to a safe internal name (e.g., "_SOH_Start") to 
    // prevent collision during merges.
    // ==============================================================================
    
    // Snapshot 1 (Baseline)
    Source = Excel.CurrentWorkbook(){[Name="Table1"]}[Content],
    #"Selected T1 Columns" = Table.SelectColumns(Source, {"Supplier", "Buyer", "Desc", "Item Code", "Stock On Hand"}),
    #"Renamed T1" = Table.RenameColumns(Table.TransformColumnTypes(#"Selected T1 Columns", {{"Item Code", type text}, {"Stock On Hand", type number}}), {{"Stock On Hand", "_SOH_Start"}}),

    // Snapshot 2
    Source2 = Excel.CurrentWorkbook(){[Name="Table2"]}[Content],
    #"Renamed T2" = Table.RenameColumns(Table.TransformColumnTypes(Table.SelectColumns(Source2, {"Item Code", "Stock On Hand"}), {{"Item Code", type text}, {"Stock On Hand", type number}}), {{"Stock On Hand", "_SOH_Mid1"}}),

    // Snapshot 3
    Source3 = Excel.CurrentWorkbook(){[Name="Table3"]}[Content],
    #"Renamed T3" = Table.RenameColumns(Table.TransformColumnTypes(Table.SelectColumns(Source3, {"Item Code", "Stock On Hand"}), {{"Item Code", type text}, {"Stock On Hand", type number}}), {{"Stock On Hand", "_SOH_Mid2"}}),

    // Snapshot 4 (Current/End)
    Source5 = Excel.CurrentWorkbook(){[Name="Table5"]}[Content],
    #"Renamed T5" = Table.RenameColumns(Table.TransformColumnTypes(Table.SelectColumns(Source5, {"Item Code", "Stock On Hand"}), {{"Item Code", type text}, {"Stock On Hand", type number}}), {{"Stock On Hand", "_SOH_End"}}),

    // ==============================================================================
    // STEP 2: RELATIONAL MERGE (LEFT OUTER JOIN)
    // ------------------------------------------------------------------------------
    // Merges all snapshots onto the Baseline (Table 1) using "Item Code".
    // ==============================================================================
    #"Merged T2" = Table.ExpandTableColumn(Table.NestedJoin(#"Renamed T1", {"Item Code"}, #"Renamed T2", {"Item Code"}, "T2", JoinKind.LeftOuter), "T2", {"_SOH_Mid1"}),
    #"Merged T3" = Table.ExpandTableColumn(Table.NestedJoin(#"Merged T2", {"Item Code"}, #"Renamed T3", {"Item Code"}, "T3", JoinKind.LeftOuter), "T3", {"_SOH_Mid2"}),
    #"Merged T5" = Table.ExpandTableColumn(Table.NestedJoin(#"Merged T3", {"Item Code"}, #"Renamed T5", {"Item Code"}, "T5", JoinKind.LeftOuter), "T5", {"_SOH_End"}),

    // ==============================================================================
    // STEP 3: VARIANCE CALCULATIONS
    // ------------------------------------------------------------------------------
    // Calculates the Absolute Decrease (Start - End) and the % Variance.
    // ==============================================================================
    #"Selected Columns" = Table.SelectColumns(#"Merged T5", {"Supplier", "Buyer", "Desc", "Item Code", "_SOH_Start", "_SOH_Mid1", "_SOH_Mid2", "_SOH_End"}),
    
    #"Added Decrease" = Table.AddColumn(#"Selected Columns", "Total SOH Decrease", each [_SOH_Start] - [_SOH_End], type number),
    
    #"Added Variance %" = Table.AddColumn(#"Added Decrease", "Total SOH Decrease %", 
        each if [_SOH_Start] = null or [_SOH_Start] = 0 then 0 else Number.Abs([Total SOH Decrease] / [_SOH_Start]), type number
    ),
    
    // Filter: Remove 0 variance and ensure Decrease is not null
    #"Filtered Noise" = Table.SelectRows(Table.TransformColumnTypes(#"Added Variance %",{{"Total SOH Decrease %", Percentage.Type}}), each [Total SOH Decrease] <> 0 and [Total SOH Decrease] <> null),
    
    #"Sorted" = Table.Sort(#"Filtered Noise", {{"Total SOH Decrease", Order.Descending}}),

    // ==============================================================================
    // STEP 4: FINAL RENAMING & CLEANUP
    // ------------------------------------------------------------------------------
    // 1. Applies dynamic headers from Step 0.
    // 2. Filters out insignificant moves (<1) and "Temporary Supplier".
    // ==============================================================================
    #"Applied Dynamic Names" = Table.RenameColumns(#"Sorted", {
        {"_SOH_Start", TargetName_T5}, 
        {"_SOH_Mid1",  TargetName_T3},
        {"_SOH_Mid2",  TargetName_T2},
        {"_SOH_End",   TargetName_T1}
    }),
    
    #"Filtered Significance" = Table.SelectRows(#"Applied Dynamic Names", each [Total SOH Decrease] > 1),
    #"Removed Temp Suppliers" = Table.SelectRows(#"Filtered Significance", each ([Supplier] <> "Temporary Supplier"))

in
    #"Removed Temp Suppliers"
