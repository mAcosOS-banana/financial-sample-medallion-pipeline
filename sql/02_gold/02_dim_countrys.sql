-- gold.dim_countrys: dimensão com chave substituta UUID (carga incremental com ON CONFLICT DO NOTHING)
CREATE TABLE IF NOT EXISTS gold.dim_countrys (
    id       UUID NOT NULL DEFAULT gen_random_uuid(),
    country  TEXT NOT NULL,
    CONSTRAINT dim_countrys_pkey PRIMARY KEY (id),
    CONSTRAINT dim_countrys_country_key UNIQUE (country)
);
