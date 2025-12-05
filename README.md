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
<summary><b>2. Dynamic Date Dimension (Standard Template)</b></summary>
<br>

> **File:** *[Coming Soon]*
>
> **The Logic:**
> A reusable M Code function that generates a contiguous date table based on the Start/End dates of the transaction data, including custom flags for "Fiscal Year", "IsWorkDay", and "Quarter".

</details>

---

## 💡 Technical Highlights & M Code Concepts

* **Defensive Merging:** Specifically handling duplicates in lookup tables before performing `Table.NestedJoin` to ensure data cardinality is preserved.
* **Duration Logic:** Utilizing `Duration.Days` for precise date math rather than simple subtraction, ensuring robustness across different Excel locale settings.
* **Functional Logic:** Using `Table.AddColumn` with nested conditional logic to create "computed columns" that act as audit flags.

---

## ⚙️ Engineering Philosophy & AI-Augmented Workflow

This repository demonstrates a **Modern "Hybrid" Development Strategy**.
In an era where syntax is cheap but logic is expensive, my focus is on **Architectural Design** and **Business Value**. I utilize Large Language Models (LLMs) as a "force multiplier" to accelerate development across my tech stack.

### 🧠 The Division of Labor
* **Human Architect (Me):**
    * **Business Logic:** Defining the complex rules (e.g., SLA Date thresholds, Currency Normalization rules).
    * **System Architecture:** Designing the "Star Schema" data model and determining how tables relate (Fact vs. Dimension).
    * **Validation:** Reviewing, debugging, and stress-testing all transformations to ensure financial accuracy.
* **AI Assistant (Tooling):**
    * **Syntax Generation:** Rapidly translating logic into specific, case-sensitive **M Code**.
    * **Pattern Optimization:** Suggesting more efficient transformation steps (e.g., `Table.Buffer`) for large datasets.
    * **Boilerplate:** Generating standard header comments and step documentation.

### 🛠️ Tech Stack & Methodology
This workflow allows me to maintain high standards of code quality across multiple domains:
* **VBA:** used for Event-Driven Automation and Object Model manipulation.
* **Power Automate (RPA):** used for OS-level orchestration and "Low-Code" integration.
* **Power Query (M Code):** used for robust ETL data transformation and cleaning steps.
