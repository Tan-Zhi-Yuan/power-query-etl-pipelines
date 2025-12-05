/* ==============================================================================
   PROJECT: Automated Supply Chain Exception Monitor
   DESCRIPTION: Consolidates AU/NZ Purchasing Data, maps Purchaser ownership, 
                and flags shipments that violate lead-time SLAs.
   ============================================================================== */

// --- SECTION 1: DATA INGESTION & CLEANING (AU & NZ) ---

// Query: Raw_Data_AU
let
    Source = Excel.CurrentWorkbook(){[Name="Table5"]}[Content],
    #"Changed Type" = Table.TransformColumnTypes(Source,{{"PO Number", Int64.Type}, {"DocDate", type date}, {"Supplier Name", type text}, {"Total", type number}, {"TotalFC", type number}}),
    // Logic: If Foreign Currency Total is 0, fallback to Local Currency Total
    #"Filled Zero TotalFC" = Table.ReplaceValue(#"Changed Type", each [TotalFC], each if [TotalFC] = 0 then [Total] else [TotalFC], Replacer.ReplaceValue, {"TotalFC"}),
    #"Removed Columns" = Table.RemoveColumns(#"Filled Zero TotalFC",{"Depart", "Vendor Ref No", "APRI Number", "Total"})
in
    #"Removed Columns"

// Query: Raw_Data_NZ
let
    Source = Excel.CurrentWorkbook(){[Name="Table4"]}[Content],
    #"Changed Type" = Table.TransformColumnTypes(Source,{{"PO Number", Int64.Type}, {"DocDate", type date}, {"Supplier Name", type text}, {"Total", type number}, {"TotalFC", type number}}),
    #"Filled Zero TotalFC" = Table.ReplaceValue(#"Changed Type", each [TotalFC], each if [TotalFC] = 0 then [Total] else [TotalFC], Replacer.ReplaceValue, {"TotalFC"}),
    #"Removed Columns" = Table.RemoveColumns(#"Filled Zero TotalFC",{"Vendor Ref No", "APRI Number", "Total", "gross weight"})
in
    #"Removed Columns"

// --- SECTION 2: MERGING & ENRICHMENT ---

// Query: Combined_PO_Data
let
    // 1. Stack the tables
    Source = Table.Combine({Raw_Data_AU, Raw_Data_NZ}),
    
    // 2. Load and Deduplicate Purchaser Mapping Table
    // CRITICAL STEP: Deduplicating ensures we don't accidentally create duplicate PO rows during the join.
    InclusionListTable_Raw = Excel.CurrentWorkbook(){[Name="Inclusion"]}[Content],
    InclusionListTable = Table.Distinct(InclusionListTable_Raw, {"Supplier Name"}),
    
    // 3. Left Outer Join to map Suppliers to Purchasers
    #"Merged Queries" = Table.NestedJoin(Source, {"Supplier Name"}, InclusionListTable, {"Supplier Name"}, "Purchaser Data", JoinKind.LeftOuter),
    #"Expanded Purchaser" = Table.ExpandTableColumn(#"Merged Queries", "Purchaser Data", {"Purchaser"}, {"Purchaser"})
in
    #"Expanded Purchaser"

// --- SECTION 3: BUSINESS LOGIC & AUDITING ---

// Query: Audit_Exceptions
let
    Source = Combined_PO_Data,
    
    // 1. Ensure Dates are strictly typed for calculation
    #"Changed Type" = Table.TransformColumnTypes(Source,{
        {"DocDate", type date}, 
        {"Ship By Date", type date}, 
        {"Supplier Confirmed Arrival", type date}, 
        {"Confirmed Departure Date", type date}
    }),
    
    // 2. Filter out Non-Standard Destinations
    #"Filtered Destination" = Table.SelectRows(#"Changed Type", each ([Destination] <> "AU Adelaide" and [Destination] <> "NZ Lyttelton")),
    
    // 3. Apply Exception Logic (SLA Violations)
    #"Added Custom" = Table.AddColumn(#"Filtered Destination", "Audit_Status", each 
        // Rule A: Order Placed but older than 3 days
        if [Status] = "1 - Order Placed" and Duration.Days(DateTime.Date(DateTime.LocalNow()) - [DocDate]) > 3 then "Fail"
        
        // Rule B: PI Confirmed but less than 14 days to Ship Date
        else if [Status] = "2 - PI Confirmed" and [Ship By Date] <> null and Duration.Days([Ship By Date] - DateTime.Date(DateTime.LocalNow())) < 14 then "Fail"
        
        // Rule C: Confirmed Departure but sitting for >3 days
        else if [Status] = "3 - Shipment Confirmed" and [Confirmed Departure Date] <> null and Duration.Days(DateTime.Date(DateTime.LocalNow()) - [Confirmed Departure Date]) > 3 then "Fail"
        
        // Rule D: Logic Error (Departure is after Arrival)
        else if [Confirmed Departure Date] <> null and [Supplier Confirmed Arrival] <> null and [Confirmed Departure Date] > [Supplier Confirmed Arrival] then "Fail"
        
        // Rule E: Transit Time is illogical (<10 days or >80 days)
        else if [Confirmed Departure Date] <> null and [Supplier Confirmed Arrival] <> null and (Duration.Days([Supplier Confirmed Arrival] - [Confirmed Departure Date]) < 10 or Duration.Days([Supplier Confirmed Arrival] - [Confirmed Departure Date]) > 80) then "Fail"
        else "OK"
    ),
    
    // 4. Return only the Failures
    #"Filtered Failures" = Table.SelectRows(#"Added Custom", each ([Audit_Status] = "Fail") and ([Purchaser] <> null)),
    #"Final Cleanup" = Table.RemoveColumns(#"Filtered Failures",{"TotalFC", "Cur", "Remarks"})
in
    #"Final Cleanup"
