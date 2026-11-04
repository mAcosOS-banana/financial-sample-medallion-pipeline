-- Criação dos schemas (um por camada).
-- O Polars cria as tabelas no write_database, mas não cria o schema.
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;
