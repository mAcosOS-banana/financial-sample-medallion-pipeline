-- bronze.manufacturing
CREATE TABLE IF NOT EXISTS bronze.manufacturing (
    segment              TEXT,
    units_sold           DOUBLE PRECISION,
    manufacturing_price  BIGINT,
    cogs                 DOUBLE PRECISION,
    date                 DATE,
    month_number         BIGINT,
    month_name           TEXT,
    year                 BIGINT,
    product_name         TEXT,
    country              TEXT,
    product              TEXT
);
