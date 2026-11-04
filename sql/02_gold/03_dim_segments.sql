-- gold.dim_segments: dimensão com chave substituta UUID (carga incremental com ON CONFLICT DO NOTHING)
CREATE TABLE IF NOT EXISTS gold.dim_segments (
    id       UUID NOT NULL DEFAULT gen_random_uuid(),
    segment  TEXT NOT NULL,
    CONSTRAINT dim_segments_pkey PRIMARY KEY (id),
    CONSTRAINT dim_segments_segment_key UNIQUE (segment)
);
