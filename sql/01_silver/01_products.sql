-- silver.products: cadastro de produtos
CREATE TABLE IF NOT EXISTS silver.products (
    product  TEXT NOT NULL,
    CONSTRAINT products_pkey PRIMARY KEY (product)
);
