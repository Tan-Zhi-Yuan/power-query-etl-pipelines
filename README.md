# ⚡ Power Query (ETL) Pipelines

## Overview
A repository of advanced **Power Query (M Code)** scripts used for high-volume data transformation, supply chain logic enforcement, and data modeling. This collection demonstrates the "E" and "T" in ETL—Extracting raw data from disparate sources and Transforming it into clean, reliable datasets for analysis.

---

## 📂 Transformation Pipelines

<details>
<summary><b>1. Automated Supply Chain Exception Monitor (Click to Expand)</b></summary>
<br>

> **File:** [SupplyChain_Exceptions.pq](./SupplyChain_Exceptions.pq)
>
> **The Problem:**
> Purchasing Officers were manually reviewing thousands of open POs to check for delays. Critical issues (e.g., impossible transit times or late shipments) were being missed due to human error and data volume.
>
> **The Solution:**
> * **Complex Date Auditing:** Implemented a robust `if-then-else` logic engine that compares multiple date fields against SLA benchmarks (e.g., flagging if Transit Time is <10 days or >80 days).
> * **Data Integrity (Row Explosion Prevention):** Applied `Table.Distinct` on the mapping table prior to merging. This defensive coding prevents "One-to-Many" join errors that inflate financial totals.
> * **Normalization:** Standardized "Foreign Currency" vs "Local Currency" columns using conditional replacement logic to ensure financial totals were accurate across different regions (AU/NZ).

</details>

<details>
<summary><b>2. PO Range Normalization & TEU Logic (Click to Expand)</b></summary>
<br>

> **File:** [PO_Range_and_TEU_Normalizer.pq](./PO_Range_and_TEU_Normalizer.pq)
>
> **The Problem:**
> * **Shorthand Data:** Operations teams entered POs as text ranges (e.g., "10200-05"), which prevented joining against the ERP database.
> * **Aggregation Errors:** Merging header-level Freight Costs onto line-level items caused the "Sum of Sums" error (inflated costs).
>
> **The Solution:**
> * **Smart Text Expansion:** Developed a custom parsing algorithm that splits delimiters, interprets shorthand suffixes, and generates a dynamic list `{Start..End}` to create atomic rows for every PO.
> * **Index-Based Grouping:** Utilized `Table.Group` combined with `Table.Sort` to create a local index for each PO. Logic was applied to assign Container Volumes (TEU) and Financial Totals *only* to `Index=1`, ensuring 100% accuracy in downstream Pivot Tables.
> * **TEU Calculation:** Automated the conversion of container strings (e.g., "40ftHQ") into numerical values (2.25 TEU) for logistics capacity planning.

</details>

<details>
<summary><b>3. Transit Time Analyzer (Click to Expand)</b></summary>
<br>

> **File:** [Transit_Time_Analysis.pq](./Transit_Time_Analysis.pq)
>
> **The Problem:**
> Logistics data exported from SAP is "Line-Level" (one row per item), making it impossible to calculate average transit times without inflating the data (e.g., a PO with 50 items counts as 50 shipments). Additionally, Port codes were combined with Country codes (e.g., "CNShanghai").
>
> **The Solution:**
> * **Header-Level Deduplication:** Sorts by Line Number and performs a `Table.Distinct` on the PO Number. This collapses multi-line POs into a single "Shipment Event" to ensure accurate averages.
> * **String Parsing:** Extract the first 2 characters of the departure field to isolate the "Origin Country" and trims the remainder to find the "Origin Port."
> * **Dynamic Filtering:** Automatically filters for the "Last 6 Months" relative to the current system date, creating a rolling window for trend analysis.

</details>

<details>
<summary><b>4. Dynamic Date Dimension (Standard Template) (Click to Expand)</b></summary>
<br>

> **File:** *[Coming Soon]*
>
> **The Logic:**
> A reusable M Code function that generates a contiguous date table based on the Start/End dates of the transaction data, including custom flags for "Fiscal Year", "IsWorkDay", and "Quarter".

</details>

<details>
<summary><b>5. Procurement Valuation Report (Click to Expand)</b></summary>
<br>

> **File:** [Procurement_Valuation_Report.pq](./Procurement_Valuation_Report.pq)
>
> **The Problem:**
> Generating end-of-period inventory valuation reports requires complex merging of purchasing data with separate container-type records and filtering by exact Start/End of Year dates defined by finance.
>
> **The Solution:**
> * **Convenient Dynamic Date Range:** The query dynamically reads the **Start of Year (SOY)** and **End of Year (EOY)** dates from simple configuration tables in the workbook. This allows finance users to control the exact reporting window *without* editing M Code.
> * **Data De-Duplication:** Uses `Table.Distinct` on the combined `PO Number` and `LineNum` fields to ensure every unique line item is counted exactly once, crucial for accurate valuation totals.
> * **Relational Merge:** Performs a `Left Outer Join` to bring in container type data (`U_MCS_Container`) from a separate table for richer analysis.

</details>

<details>
<summary><b>6. Dynamic SOH Trend Analyzer (Click to Expand)</b></summary>
<br>

> **File:** [Dynamic_SOH_Trend_Analysis.pq](./Dynamic_SOH_Trend_Analysis.pq)
>
> **The Problem:**
> Stock-On-Hand (SOH) analysis requires comparing multiple point-in-time snapshots. Standard queries break when column headers change (e.g., "SOH Dec" vs "SOH Jan"). Furthermore, joining purely on "Item Code" causes errors when inventory is distributed across multiple warehouses.
>
> **The Solution:**
> * **Composite Key Joins:** Utilizes a multi-key joining strategy `{"Item Code", "Wh"}` to reconcile stock movements at the specific warehouse level, preventing data duplication.
> 
> * **Dynamic Metadata Injection:** Employs custom M functions to scrape date values from a "Helper" table and programmatically inject them into column headers at runtime (e.g., renaming placeholders to `SOH1223`).
> * **Variance Analytics:** Automatically calculates absolute SOH decrease and percentage variance, applying a significance filter (movements > 1 unit) to isolate actionable inventory depletion trends.

</details>

---

## 💡 Technical Highlights & M Code Concepts

* **Composite Key Logic:** Utilizing lists `{"Key1", "Key2"}` within join functions to ensure relational integrity in many-to-many scenarios.

* **Defensive Merging:** Handling duplicates in lookup tables before `Table.NestedJoin` to ensure cardinality.
* **Complex Text Parsing:** Using `Text.Split`, `Text.End`, and list generation syntax `{x..y}` to turn unstructured text strings into structured rows.
* **Advanced Grouping:** Using `Table.Group` to create localized indexes per transaction ID (`PO_Row_Index`). This technique is critical for handling "Header vs. Line Item" granularity issues within a flat table structure.

---

## ⚙️ Engineering Philosophy & AI-Augmented Workflow

This repository demonstrates a **Modern "Hybrid" Development Strategy**.
In an era where syntax is cheap but logic is expensive, my focus is on **Architectural Design** and **Business Value**. I utilize Large Language Models (LLMs) as a "force multiplier" to accelerate development.

### 🧠 The Division of Labor
* **Human Architect (Me):**
    * **Business Logic:** Defining the complex rules (e.g., SLA Date thresholds, Header/Line logic, TEU factors).
    * **System Architecture:** Designing the "Star Schema" data model.
    * **Validation:** Stress-testing transformations to ensure financial accuracy.
* **AI Assistant (Tooling):**
    * **Syntax Generation:** Rapidly translating logic into specific, case-sensitive **M Code**.
    * **Pattern Optimization:** Suggesting efficient steps (e.g., removing unused columns early) to optimize memory.
    * **Boilerplate:** Generating standard header comments and documentation.

### 🛠️ Tech Stack
* **VBA:** Event-Driven Automation and Object Model manipulation.
* **Power Automate:** OS-level orchestration and API integration.
* **Power Query (M Code):** ETL data transformation and cleaning.
