<details>
<summary><b>3. Automated Supply Chain Exception Monitor</b></summary>
<br>

> **File:** [SupplyChain_Exceptions.pq](./SupplyChain_Exceptions.pq)
>
> **The Problem:**
> Purchasing Officers were manually reviewing thousands of open POs to check for delays. Critical issues (e.g., impossible transit times or late shipments) were being missed due to human error.
>
> **The Solution:**
> * **Complex Date Auditing:** Implemented a robust `if-then-else` logic engine that compares multiple date fields against SLA benchmarks (e.g., flagging if Transit Time is <10 days or >80 days).
> * **Data Protection:** Applied `Table.Distinct` on the mapping table prior to merging to preventing "Row Explosion" (1-to-many join errors).
> * **Normalization:** Standardized "Foreign Currency" vs "Local Currency" columns using conditional replacement logic to ensure financial totals were accurate.

</details>
