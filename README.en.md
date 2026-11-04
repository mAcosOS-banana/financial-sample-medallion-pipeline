# 📊 Financial Sample — Medallion Pipeline with Polars, PostgreSQL and Power BI

![Python](https://img.shields.io/badge/Python-3.13-3776AB?logo=python&logoColor=white)
![Polars](https://img.shields.io/badge/Polars-DataFrame-CD792C?logo=polars&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Render-4169E1?logo=postgresql&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-DAX-F2C811?logo=powerbi&logoColor=black)
![Status](https://img.shields.io/badge/status-in%20progress-yellow)

> A data engineering and analytics project that implements a **medallion architecture** pipeline (Raw → Bronze → Silver → Gold), with **star schema** dimensional modeling and analytical consumption in **Power BI**.

📄 [Versão em português](README.md)

---

## 📑 Table of contents

1. [About the project](#-about-the-project)
2. [Architecture](#-architecture)
3. [Tech stack](#-tech-stack)
4. [The dataset and its quirks](#-the-dataset-and-its-quirks)
5. [Repository structure](#-repository-structure)
6. [Pipeline layers](#-pipeline-layers)
7. [Dimensional model](#-dimensional-model)
8. [Consumption layer — Power BI](#-consumption-layer--power-bi)
9. [Technical decisions](#-technical-decisions)
10. [Quality checks](#-quality-checks)
11. [How to run](#-how-to-run)
12. [Known limitations](#-known-limitations)
13. [Next steps](#-next-steps)
14. [Lessons learned](#-lessons-learned)
15. [Author](#-author)

---

## 🎯 About the project

I built this project to bring together, in a single end-to-end flow, the practices I consider essential in data engineering:

- resilient ingestion of raw data;
- clear separation of responsibilities between layers;
- cleaning and standardization with explicit, auditable rules;
- dimensional modeling designed for analytical consumption;
- business metrics that are mathematically correct.

More than the visual result, the project focuses on **technical decisions** and their **trade-offs**. That is why this README documents not only *what* was done, but *why* it was done this way.

---

## 🏗 Architecture

```mermaid
flowchart LR
    A[Financial Sample<br/>CSV / XLSX] --> B[Raw<br/>original file]
    B -->|Polars| C[(Bronze<br/>source types, untreated)]
    C -->|SQL| D[(Silver<br/>clean and typed)]
    D -->|SQL| E[(Gold<br/>star schema)]
    E -->|Import| F[Power BI<br/>DAX]

    subgraph Render [Managed PostgreSQL — Render]
        C
        D
        E
    end
```

**Principles I followed:**

- Each layer reads **only** from the layer immediately before it.
- Data flows in a single direction. A fix in Silver never changes Bronze.
- Power BI consumes **only** the Gold layer.
- Any layer can be rebuilt from the previous one.

---

## 🧰 Tech stack

| Component | Technology | Role in the project |
|---|---|---|
| Language | Python | Ingestion and load orchestration |
| Processing | Polars | Reading, column standardization and writing to Bronze |
| Database | PostgreSQL | Layer storage and SQL transformations |
| Hosting | Render | Managed cloud PostgreSQL, accessed over SSL |
| Python ↔ database connection | SQLAlchemy + psycopg2 | Write engine for `write_database` |
| Package management | uv | Project environment and dependencies |
| Visualization | Power BI (Power Query + DAX) | Semantic model, measures and reports |

---

## 📦 The dataset and its quirks

I used the **Financial Sample**, a **synthetic** sales dataset of a manufacturing company, published by Microsoft.

Before any transformation, I analyzed the data structure. I found characteristics that directly shaped the modeling:

| Characteristic | Impact on modeling |
|---|---|
| Each row is a **monthly summary** (segment × country × product × month), not an individual sale | Defines the fact table grain and rules out an average ticket metric |
| All dates fall on the **1st of the month** | The calendar dimension must extend the last month to its end (`EOMONTH`) |
| The period runs from **Sep/2013 to Dec/2016**, in two files (2013–2014 and 2015–2016) | 2013 is a partial year; yearly comparisons require care |
| The segment × country × product × month combination is **not unique** (112 combinations repeat, almost all in the Government segment) | The fact table cannot use this combination as a key; each row is identified by the generated `id` |
| `sale_price` varies by **segment**, not by product | The same product shows very different prices on the same date |
| There is **no** order identifier | A generated `id` identifies records, but does not represent a sale |
| Spelling variations in text fields (`segment`, `discount_band`) | Requires explicit standardization in Silver |

---

## 🗂 Repository structure

```
financial-sample-medallion-pipeline/
├── data/
│   └── raw/                    # Original files (Financial Sample)
├── ingestion/
│   └── load_bronze.py          # Reading with Polars and loading into Bronze
├── sql/
│   ├── 00_schemas.sql          # Schema creation
│   ├── 00_bronze/              # Raw and Bronze layer tables
│   ├── 01_silver/              # Silver layer tables
│   ├── 02_gold/                # Dimensions, facts and aggregate tables
│   └── 99_quality_checks.sql   # Quality checks
├── powerbi/
│   └── financial_sample.pbix   # Report (Import mode)
├── docs/
│   └── images/                 # Screenshots of the model and the report
├── .env.example                # Environment variables (no credentials)
├── pyproject.toml
├── README.md
└── README.en.md
```

---

## 🥉🥈🥇 Pipeline layers

### Raw

Stores the file **exactly as it was received**. This layer is not queried for analysis. It works as a backup and allows the whole pipeline to be reprocessed from scratch.

---

### Bronze — raw data, standardized

**Goal:** keep the source content in a standardized, queryable format, without changing values.

**What I do in this layer:**

1. **Read the Excel spreadsheets** (`.xlsx`) with Polars and the `calamine` engine.
2. **Standardize column names** to `snake_case` (`Gross Sales` → `gross_sales`) with the `normalizar_nome` function, which also removes accents and connector words.
3. **Split the combined column** `country,product` into `country` and `product`.
4. **Write the table to a dedicated schema**, appending the files for each period.

```python
import polars as pl
from utils import normalizar_nome

for arquivo in sales_data:
    df = pl.read_excel(arquivo, engine="calamine")
    df = df.rename({col: normalizar_nome(col) for col in df.columns})

    df = (
        df.with_columns(
            pl.col("country,product")
            .str.split_exact(",", 1)
            .struct.rename_fields(["country", "product"])
            .alias("split")
        )
        .unnest("split")
        .drop("country,product")
    )

    df.write_database(
        table_name="raw.sales_raw",
        connection=engine.connect(),
        engine="sqlalchemy",
        if_table_exists="append",
    )
```

The schema is created beforehand, because Polars creates the table but not the schema:

```sql
CREATE SCHEMA IF NOT EXISTS bronze;
```

**What I don't do in this layer:** fix, remove, deduplicate or recalculate any value.

---

### Silver — clean, typed and reliable data

**Goal:** deliver correct and consistent data, at the original grain, without complex business rules.

#### `silver.sales`

**1. Text cleaning**

- `TRIM` to remove leading and trailing spaces.
- `INITCAP` to standardize the capitalization of `country` and `product`.

**2. Segment fixes**

First I standardize the text. Then I apply the fix with `ILIKE` patterns:

```sql
CASE
    WHEN segment_raw ILIKE 'enter%rise' THEN 'Enterprise'
    WHEN segment_raw ILIKE 'gover%'     THEN 'Government'
    WHEN segment_raw ILIKE 'smal%'      THEN 'Small Business'
    WHEN segment_raw ILIKE 'mid%'       THEN 'Midmarket'
    WHEN segment_raw ILIKE 'channel%'   THEN 'Channel Partners'
    ELSE segment_raw
END AS segment
```

**3. Discount band**

The value `None` in `discount_band` was replaced with `No Discount`. The original term can be mistaken for missing data.

**4. Derived columns (row-level calculation)**

| Column | Formula |
|---|---|
| `perc_discount` | `discounts / NULLIF(gross_sales, 0)` |
| `perc_profit` | `profit / NULLIF(sales, 0)` |
| `profit_flag` | `Profit` / `Loss` / `Break-Even`, based on `profit` |

**5. Typing**

- Monetary values and quantities → keep the Bronze types (`DOUBLE PRECISION`; `sale_price` as `BIGINT`).
- Percentages → `NUMERIC(38,4)`.
- Dates → `DATE`.
- Year and month → `BIGINT`.

Monetary values are converted to `NUMERIC(38,4)` when Gold is loaded (`gold.fact_sales`).

#### Auxiliary tables

- **`silver.products`:** product register (`product` as primary key).
- **`silver.manufacturing`:** manufacturing cost (`manufacturing_price`) and `cogs` per product.

Integrity within the layer is enforced by a foreign key:

```sql
ALTER TABLE silver.sales
    ALTER COLUMN product SET NOT NULL,
    ADD CONSTRAINT fk_sales_products
        FOREIGN KEY (product)
        REFERENCES silver.products (product);
```

---

### Gold — business data

**Goal:** organize the data in a **star schema**, ready for analytical consumption.

#### Dimensions

| Table | Key | Attribute |
|---|---|---|
| `gold.dim_products` | `id` (UUID) | `product` |
| `gold.dim_countrys` | `id` (UUID) | `country` |
| `gold.dim_segments` | `id` (UUID) | `segment` |

Dimensions are loaded **incrementally**, to keep identifiers stable:

```sql
INSERT INTO gold.dim_products (product)
SELECT product FROM silver.products
ON CONFLICT (product) DO NOTHING;
```

#### Fact `gold.fact_sales`

**Grain:** one row per Silver record (segment × country × product × month).

- `segment`, `country` and `product` are replaced by the dimension `id`s.
- Only **additive** metrics remain in the fact table.
- Foreign keys with `NOT NULL`.

```sql
INSERT INTO gold.fact_sales (
    segment_id, country_id, product_id, discount_band, date,
    units_sold, sale_price, gross_sales, discounts, sales, profit
)
SELECT
    ds.id, dc.id, dp.id, s.discount_band, s.date,
    s.units_sold, s.sale_price, s.gross_sales, s.discounts, s.sales, s.profit
FROM silver.sales s
JOIN gold.dim_segments ds ON ds.segment = s.segment
JOIN gold.dim_countrys dc ON dc.country = s.country
JOIN gold.dim_products dp ON dp.product = s.product;
```

#### Aggregate fact `gold.resume_products`

**Grain:** one row per product. Combines sales metrics (`silver.sales`) and cost metrics (`silver.manufacturing`).

The two sources are **aggregated separately** and combined with a `FULL JOIN`:

```sql
WITH sales_resume AS (
    SELECT product, SUM(sales) AS total_sales, SUM(profit) AS total_profit, ...
    FROM silver.sales GROUP BY product
),
manufacturing_resume AS (
    SELECT product, SUM(cogs) AS total_cogs, ...
    FROM silver.manufacturing GROUP BY product
)
SELECT ...
FROM manufacturing_resume m
FULL JOIN sales_resume s ON s.product = m.product
LEFT JOIN gold.dim_products d ON d.product = COALESCE(m.product, s.product);
```

---

## ⭐ Dimensional model

```mermaid
erDiagram
    dim_products  ||--o{ fact_sales : "product_id"
    dim_countrys  ||--o{ fact_sales : "country_id"
    dim_segments  ||--o{ fact_sales : "segment_id"
    dim_calendar  ||--o{ fact_sales : "date"
    dim_products  ||--|| resume_products : "product_id"

    fact_sales {
        uuid id PK
        uuid product_id FK
        uuid country_id FK
        uuid segment_id FK
        date date FK
        text discount_band
        numeric units_sold
        numeric sale_price
        numeric gross_sales
        numeric discounts
        numeric sales
        numeric profit
        text profit_flag
    }
    dim_products {
        uuid id PK
        text product
    }
    dim_countrys {
        uuid id PK
        text country
    }
    dim_segments {
        uuid id PK
        text segment
    }
    dim_calendar {
        date Date PK
        int Year
        int Month_Number
        text Month_Name
    }
    resume_products {
        uuid product_id FK
        numeric total_sales
        numeric total_cogs
        numeric gross_profit
        numeric gross_margin
    }
```

> `dim_calendar` is created in Power BI (DAX), not in the database.

---

## 📈 Consumption layer — Power BI

### Connection

- PostgreSQL database on **Render**, with an **SSL** connection.
- Two Power Query parameters: **server** (`pServer`) and **database** (`pDatabase`).
- Credentials are stored in the data source settings, **never** in the parameters.
- All tables in **Import mode**.
- Navigation columns (`Record` / `Table`) generated by the foreign keys are removed in Power Query. Relationships are defined in the model.

### Calendar dimension

Created in DAX, from the first to the last month of the fact table:

```dax
dim_calendar =
VAR StartDate = MIN ( fact_sales[date] )
VAR EndDate   = EOMONTH ( MAX ( fact_sales[date] ), 0 )
RETURN
ADDCOLUMNS (
    CALENDAR ( StartDate, EndDate ),
    "Year",              YEAR ( [Date] ),
    "Quarter Name",      "Q" & QUARTER ( [Date] ),
    "Month Number",      MONTH ( [Date] ),
    "Month Name",        FORMAT ( [Date], "MMMM", "en-US" ),
    "Year Month Number", YEAR ( [Date] ) * 100 + MONTH ( [Date] ),
    "Months Ago",        DATEDIFF ( [Date], EndDate, MONTH )
    -- ... other attributes
)
```

The table is marked as a date table. Text columns are sorted by their corresponding numeric columns.

### Main measures

| Measure | Definition |
|---|---|
| `total_sales` | Sum of net revenue |
| `profit_margin` | `(sales − cogs) / sales` |
| `markup` | `(sales − cogs) / cogs` |
| `cogs_ratio` | `cogs / sales` |
| `average_unit_price` | `sales / units_sold` |
| `sales_mom_%` | Change versus the previous month |
| `sales_yoy_%` | Change versus the same period of the previous year |
| `sales_period_var_%` | Change versus the previous period of the same length |
| `sales_var_%_dynamic` | YoY at the Year level and MoM at the Month level |

**Dynamic change with drill-down:**

```dax
sales_previous_dynamic =
SWITCH (
    TRUE (),
    ISINSCOPE ( dim_calendar[Month Name] ),
        CALCULATE ( [total_sales], DATEADD ( dim_calendar[Date], -1, MONTH ) ),
    ISINSCOPE ( dim_calendar[Year] ),
        CALCULATE ( [total_sales], DATEADD ( dim_calendar[Date], -1, YEAR ) )
)

sales_var_%_dynamic =
VAR current_ = [total_sales]
VAR previous = [sales_previous_dynamic]
RETURN
IF ( NOT ISBLANK ( previous ), DIVIDE ( current_ - previous, previous ) )
```

**Change for multi-month selections:**

```dax
sales_previous_period =
VAR StartDate = MIN ( dim_calendar[Date] )
VAR EndDate   = MAX ( dim_calendar[Date] )
VAR NMonths   = DATEDIFF ( StartDate, EndDate, MONTH ) + 1
RETURN
CALCULATE ( [total_sales], DATEADD ( dim_calendar[Date], -NMonths, MONTH ) )
```

---

## 🧠 Technical decisions

This section records the main decisions of the project. For each one, I describe the context, the choice and the reason.

### Ingestion and Bronze

#### 1. Polars for ingestion
- **Decision:** use Polars instead of pandas.
- **Reason:** expressive API, good performance and direct writes to a qualified schema with `write_database`.
- **Trade-off:** with the `sqlalchemy` engine, Polars uses `pandas.to_sql` internally. For larger volumes, the `adbc` engine is more efficient.

#### 2. Types inferred from the spreadsheet in Bronze
- **Decision:** keep the types Polars infers from the Excel cells (`double precision`, `bigint`, `date` and `text`), without manual casts.
- **Reason:** in an `.xlsx`, cells are already typed. Dates and numbers arrive in Bronze correctly, with no text conversion. Type and domain adjustments stay in Silver.
- **Trade-off:** an invalid value in a numeric column may become null or break the load. If a column's type changes between files, the `append` fails. Reading everything as text would avoid both risks, at the cost of explicit casts in Silver.

#### 3. One schema per layer
- **Decision:** `bronze`, `silver` and `gold` as separate schemas in the same database.
- **Reason:** logical isolation, per-layer permission control and self-explanatory names.

### Silver

#### 4. Standardize text before fixing it
- **Decision:** apply `TRIM` and `INITCAP` before the `CASE` that fixes segments.
- **Reason:** invisible spaces and capitalization differences made exact comparisons fail. Standardizing first keeps the fix rules smaller and more robust.

#### 5. `profit_flag` computed from `profit`
- **Decision:** classify the sale result by the absolute profit value, not by the percentage.
- **Reason:** the percentage is rounded to four decimal places. A very small profit would be rounded to zero and incorrectly classified as `Break-Even`.

#### 6. `NUMERIC(38,4)` for percentages
- **Decision:** store percentages as fractions with four decimal places.
- **Reason:** with two decimal places, `0.0567` would become `0.06`. The precision loss would affect any later analysis.

#### 7. `NULLIF` in every division
- **Decision:** protect denominators with `NULLIF(column, 0)`.
- **Reason:** prevents division-by-zero errors. A `NULL` result makes it clear that the ratio does not exist, unlike an artificial `0`.

#### 8. Row-level percentages kept in Silver
- **Decision:** keep `perc_discount` and `perc_profit` in Silver.
- **Reason:** they are stable, row-level calculations.
- **Caveat:** they are **non-additive** metrics. I never use them as a basis for aggregation. In BI, I always recalculate them from the sums.

### Gold and modeling

#### 9. Star schema
- **Decision:** separate facts (metrics) from dimensions (descriptive attributes).
- **Reason:** fewer joins in queries, a simpler model in Power BI and better performance from the VertiPaq engine.

#### 10. Tables instead of views
- **Decision:** materialize Silver and Gold as tables.
- **Reason:** the result is processed once per load, not on every query. In addition, if an earlier layer fails, Gold keeps showing the last valid load.

#### 11. Independent keys between layers
- **Decision:** Gold has its own keys. No foreign key links Gold to Silver.
- **Reason:** allows Silver to be reprocessed (including with `DROP TABLE`) without blocking. The link between layers happens during the load, through the natural key.

#### 12. UUID surrogate keys
- **Decision:** generate dimension `id`s with `gen_random_uuid()`.
- **Acknowledged trade-off:** integer keys (`IDENTITY`) take 4 bytes versus 16 for a UUID and make the Power BI model lighter. For this project's volume, the impact is negligible. In a production scenario, I would consider integer keys.

#### 13. Incremental load for dimensions
- **Decision:** insert only new records (`ON CONFLICT DO NOTHING`).
- **Reason:** `gen_random_uuid()` generates a new value on every run. Recreating the dimension would break the link with facts, reports and saved filters.

#### 14. Fact table with additive metrics only
- **Decision:** remove percentages and calendar attributes (`month_number`, `month_name`, `year`) from `fact_sales`. `profit_flag` was kept as a row attribute (degenerate dimension).
- **Reason:** date attributes belong to the calendar dimension. Non-additive metrics must be calculated in the filter context, not stored. `profit_flag` is not a metric: it classifies each record and works as a report filter.

#### 15. Running totals outside the fact table
- **Decision:** do not store month-to-date (MTD) profit in the fact table.
- **Reason:** a running total is not additive, does not respect report filters and would need to be recalculated on every new load. The correct calculation is a DAX measure.

#### 16. `FULL JOIN` in the summary table
- **Decision:** aggregate sales and costs separately and combine them with a `FULL JOIN`.
- **Reason:** each side has one row per product, which guarantees a 1:1 join without `MAX` tricks in the `GROUP BY`. The `FULL JOIN` also exposes products with sales but no cost (or the reverse), which serves as an integrity check.

### Power BI

#### 17. Ratio of sums for every percentage metric
- **Decision:** calculate ratios as `SUM(a) / SUM(b)`.
- **Reason:** averaging row-level percentages gives the same weight to large and small sales, which distorts the result.

| Sale | sales | profit | margin |
|---|---|---|---|
| A | 1,000 | 100 | 10% |
| B | 10 | 5 | 50% |
| **Average of ratios** | | | **30%** ❌ |
| **Ratio of sums** | | | **10.4%** ✅ |

#### 18. Margin over net revenue
- **Decision:** use `sales` (after discount) as the margin base, not `gross_sales`.
- **Reason:** the discount reduces effective revenue. Using gross revenue inflates the margin.
- **Complement:** I explicitly distinguished **margin** (`÷ sales`) from **markup** (`÷ cogs`), which answer different questions.

#### 19. Average unit price instead of average ticket
- **Decision:** do not publish an average ticket metric.
- **Reason:** the dataset has no order identifier. A row-level generated `id` only counts records. The available and honest metric is the average price per unit (`sales / units_sold`).

#### 20. `DIVIDE` without an alternate result
- **Decision:** use `DIVIDE(a, b)` without the third argument.
- **Reason:** returning blank instead of zero prevents "no data" from being read as "zero margin".

#### 21. DAX calendar extended with `EOMONTH`
- **Decision:** generate the date dimension in Power BI, from the first day of the data to the last day of the last month.
- **Reason:** since the dates in the data fall on the 1st, ending the calendar at `MAX` would exclude the rest of the last month and affect time intelligence measures.

#### 22. Dynamic change with `ISINSCOPE`
- **Decision:** a single measure that compares year over year at the Year level and month over month at the Month level.
- **Reason:** allows drill-down through the hierarchy without switching measures. The most detailed level is tested first, because at the Month level the Year is also in scope.

#### 23. Previous period of the same length with `DATEDIFF`
- **Decision:** calculate the number of selected months and shift the comparison by the same length.
- **Reason:** when the user selects several months, the comparison adjusts automatically (3 months versus the previous 3, for example).

#### 24. Import mode
- **Decision:** import all tables.
- **Reason:** the `.pbix` keeps a copy of the data. The report keeps working for anyone who opens it, even without database access.

#### 25. Connection parameters without credentials
- **Decision:** parameterize only the server and the database.
- **Reason:** makes switching environments easy without exposing passwords. The parameters are passed directly to the connector, which avoids dynamic sources that prevent refresh in the Power BI service.

---

## ✅ Quality checks

**Consistency of monetary columns:**

```sql
SELECT COUNT(*) AS inconsistencias
FROM silver.sales
WHERE ABS(gross_sales - units_sold * sale_price) > 0.01
   OR ABS(sales - (gross_sales - discounts))     > 0.01;
```

**Repetitions at the grain:**

```sql
SELECT segment, country, product, date, COUNT(*)
FROM silver.sales
GROUP BY 1, 2, 3, 4
HAVING COUNT(*) > 1;
-- Current result: 112 repeated combinations. This is a characteristic of the source,
-- not a load error. The query is used to monitor changes in this number.
```

**Segment domain after the fix:**

```sql
SELECT segment, COUNT(*)
FROM silver.sales
GROUP BY segment
ORDER BY segment;
-- Expected result: exactly 5 segments
```

**Fact load integrity:**

```sql
SELECT
    (SELECT COUNT(*) FROM silver.sales)    AS linhas_silver,
    (SELECT COUNT(*) FROM gold.fact_sales) AS linhas_gold;
-- The values must be equal
```

**Products with no match in the dimension:**

```sql
SELECT DISTINCT s.product
FROM silver.sales s
LEFT JOIN gold.dim_products d ON d.product = s.product
WHERE d.id IS NULL;
-- Expected result: no rows
```

---

## ▶️ How to run

### Prerequisites

- Python 3.13+
- [uv](https://docs.astral.sh/uv/)
- A PostgreSQL instance (I used [Render](https://render.com))
- Power BI Desktop (to open the report)

### 1. Clone the repository

```bash
git clone https://github.com/mAcosOS-banana/financial-sample-medallion-pipeline.git
cd financial-sample-medallion-pipeline
```

### 2. Install the dependencies

```bash
uv sync
```

Main dependencies: `polars`, `fastexcel`, `python-calamine`, `sqlalchemy`, `psycopg2`, `pandas`, `pyarrow`, `python-dotenv`.

### 3. Configure the environment variables

Copy the example file and fill it in with your database details:

```bash
cp .env.example .env
```

```env
POSTGRES_URL=postgresql+psycopg2://user:password@host:5432/database?sslmode=require
```

> ⚠️ The `.env` file is in `.gitignore`. Never commit credentials.

### 4. Create the schemas

```bash
set -a; source .env; set +a
psql "${POSTGRES_URL/+psycopg2/}" -f sql/00_schemas.sql
```

### 5. Load Bronze

```bash
uv run ingestion/load_bronze.py
```

### 6. Run the transformations

Run the SQL scripts in this order: `00_bronze/` → `01_silver/` → `02_gold/` → `99_quality_checks.sql`. Within each folder, follow the file numbering (tables referenced by foreign keys come first).

### 7. Open the report

Open `powerbi/financial_sample.pbix`. The report is in Import mode and works offline. To refresh the data, set the `pServer` and `pDatabase` parameters and enter your database credentials.

---

## ⚠️ Known limitations

- **Synthetic data.** Price differences between segments do not reflect a real scenario.
- **No average ticket.** The dataset has no order identifier.
- **Partial yearly comparison.** 2013 contains only four months. The 2014 versus 2013 yearly change compares 12 months with 4. For yearly analyses, only the months present in both years should be considered.
- **Monthly grain.** Daily or weekly analyses with real meaning are not possible.
- **Free hosting.** The database on Render's free plan has an expiration date. The `.pbix` in Import mode keeps the data from the last refresh.

---

## 🚀 Next steps

- [ ] Create the `dim_discount_bands` dimension and replace the text attribute in the fact table.
- [ ] Add the `cogs` column to `gold.fact_sales`.
- [ ] Create indexes on the fact tables' foreign key columns (`segment_id`, `country_id`, `product_id`).
- [ ] Create the monthly fact `gold.fact_sales_product_monthly`, with a monthly **ABC curve** classification.
- [ ] Add "Unknown" members (`-1`) to the dimensions.
- [ ] Orchestrate the pipeline with **Apache Airflow**.
- [ ] Automate the quality checks and record the results in an audit table.
- [ ] Add metadata columns to Bronze (`_ingested_at`, `_source_file`).

---

## 📚 Lessons learned

The points that added the most to my understanding during the project were:

- **The grain defines everything.** Understanding that each row was a monthly summary, not a sale, changed how I modeled the fact table and which metrics were possible.
- **Not every metric can be stored.** Percentages and running totals look ready to go into the fact table, but they break under filters. The right place is a measure.
- **Rounding has consequences.** A classification based on a rounded value produced incorrect results.
- **Key stability is a requirement, not a detail.** Recreating a dimension with random UUIDs would break the whole model.
- **Documenting limitations is part of the job.** Acknowledging what the dataset cannot calculate prevents wrong conclusions.

---

## 👤 Author

**Marcos**
Data Analyst · Computer Science student (UNEMAT) and Data Engineering student (Infnet)

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/marcos-oliveira-601a18226)
[![GitHub](https://img.shields.io/badge/GitHub-181717?logo=github&logoColor=white)](https://github.com/mAcosOS-banana)
