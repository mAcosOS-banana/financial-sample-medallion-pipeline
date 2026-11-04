-- gold.fact_sales: uma linha por segmento × país × produto × mês
-- Depende de: gold.dim_segments, gold.dim_countrys, gold.dim_products
CREATE TABLE IF NOT EXISTS gold.fact_sales (
    id             UUID NOT NULL DEFAULT gen_random_uuid(),
    segment_id     UUID NOT NULL,
    country_id     UUID NOT NULL,
    product_id     UUID NOT NULL,
    discount_band  TEXT NOT NULL,
    date           DATE NOT NULL,
    units_sold     NUMERIC(38,4),
    sale_price     NUMERIC(38,4),
    gross_sales    NUMERIC(38,4),
    discounts      NUMERIC(38,4),
    sales          NUMERIC(38,4),
    profit         NUMERIC(38,4),
    profit_flag    TEXT,
    CONSTRAINT fact_sales_pkey       PRIMARY KEY (id),
    CONSTRAINT fk_fact_sales_segment FOREIGN KEY (segment_id) REFERENCES gold.dim_segments (id),
    CONSTRAINT fk_fact_sales_country FOREIGN KEY (country_id) REFERENCES gold.dim_countrys (id),
    CONSTRAINT fk_fact_sales_product FOREIGN KEY (product_id) REFERENCES gold.dim_products (id)
);
