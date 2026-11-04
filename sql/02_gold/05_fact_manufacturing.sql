-- gold.fact_manufacturing: custos de fabricação por segmento × país × produto × mês
-- Depende de: gold.dim_segments, gold.dim_countrys, gold.dim_products
-- Obs.: os nomes das FKs (fk_fact_sales_*_id) são os que existem hoje no banco.
CREATE TABLE IF NOT EXISTS gold.fact_manufacturing (
    id                   UUID NOT NULL DEFAULT gen_random_uuid(),
    segment_id           UUID NOT NULL,
    country_id           UUID NOT NULL,
    product_id           UUID NOT NULL,
    manufacturing_price  NUMERIC(38,2),
    cogs                 NUMERIC(38,2),
    date                 DATE,
    month_number         INTEGER,
    year                 INTEGER,
    CONSTRAINT fact_manufacturing_pkey  PRIMARY KEY (id),
    CONSTRAINT fk_fact_sales_segment_id FOREIGN KEY (segment_id) REFERENCES gold.dim_segments (id),
    CONSTRAINT fk_fact_sales_country_id FOREIGN KEY (country_id) REFERENCES gold.dim_countrys (id),
    CONSTRAINT fk_fact_sales_product_id FOREIGN KEY (product_id) REFERENCES gold.dim_products (id)
);
