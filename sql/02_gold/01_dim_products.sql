-- gold.dim_products: dimensão com chave substituta UUID (carga incremental com ON CONFLICT DO NOTHING)
CREATE TABLE IF NOT EXISTS gold.dim_products (
    id       UUID NOT NULL DEFAULT gen_random_uuid(),
    product  TEXT NOT NULL,
    CONSTRAINT dim_products_pkey PRIMARY KEY (id),
    CONSTRAINT dim_products_product_key UNIQUE (product)
);
