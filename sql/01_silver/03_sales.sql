-- silver.sales: vendas limpas e tipadas
-- Depende de: silver.products, silver.countrys
CREATE TABLE IF NOT EXISTS silver.sales (
    segment        TEXT,
    country        TEXT,
    product        TEXT NOT NULL,
    discount_band  TEXT,
    units_sold     DOUBLE PRECISION,
    sale_price     BIGINT,
    gross_sales    DOUBLE PRECISION,
    discounts      DOUBLE PRECISION,
    perc_discount  NUMERIC(38,4),
    sales          DOUBLE PRECISION,
    profit         DOUBLE PRECISION,
    perc_profit    NUMERIC(38,4),
    profit_flag    TEXT,
    date           DATE,
    month_number   BIGINT,
    year           BIGINT,
    CONSTRAINT fk_sales_products FOREIGN KEY (product) REFERENCES silver.products (product),
    CONSTRAINT fk_sales_contry   FOREIGN KEY (country) REFERENCES silver.countrys (country)
);
