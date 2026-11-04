-- gold.resume_products: fato agregada, uma linha por produto (vendas + custos)
-- Depende de: gold.dim_products
CREATE TABLE IF NOT EXISTS gold.resume_products (
    product_id               UUID NOT NULL,
    max_manufacturing_price  NUMERIC(38,4),
    min_manufacturing_price  NUMERIC(38,4),
    total_cogs               NUMERIC(38,4),
    total_units_sold         NUMERIC(38,4),
    total_gross_sales        NUMERIC(38,4),
    total_discounts          NUMERIC(38,4),
    total_sales              NUMERIC(38,4),
    total_profit             NUMERIC(38,4),
    gross_profit             NUMERIC(38,4),
    gross_margin             NUMERIC(38,4),
    CONSTRAINT resume_products_product_id_fkey FOREIGN KEY (product_id) REFERENCES gold.dim_products (id)
);
