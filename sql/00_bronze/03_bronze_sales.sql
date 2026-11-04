-- bronze.sales
CREATE TABLE IF NOT EXISTS bronze.sales (
    segment        TEXT,
    discount_band  TEXT,
    units_sold     DOUBLE PRECISION,
    sale_price     BIGINT,
    gross_sales    DOUBLE PRECISION,
    discounts      DOUBLE PRECISION,
    sales          DOUBLE PRECISION,
    profit         DOUBLE PRECISION,
    date           DATE,
    month_number   BIGINT,
    month_name     TEXT,
    year           BIGINT,
    product_name   TEXT,
    country        TEXT,
    product        TEXT
);
