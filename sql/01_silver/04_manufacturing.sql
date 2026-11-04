-- silver.manufacturing: custos de fabricação limpos e tipados
-- Depende de: silver.products, silver.countrys
CREATE TABLE IF NOT EXISTS silver.manufacturing (
    segment              TEXT,
    country              TEXT,
    product              TEXT,
    manufacturing_price  BIGINT,
    cogs                 DOUBLE PRECISION,
    date                 DATE,
    month_number         BIGINT,
    year                 BIGINT,
    CONSTRAINT fk_sales_product FOREIGN KEY (product) REFERENCES silver.products (product),
    CONSTRAINT fk_sales_contry  FOREIGN KEY (country) REFERENCES silver.countrys (country)
);
