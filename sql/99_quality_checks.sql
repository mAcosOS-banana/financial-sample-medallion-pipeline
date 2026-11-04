-- Validações de qualidade (ver seção "Validações de qualidade" do README)

-- 1. Consistência das colunas monetárias (esperado: 0)
SELECT COUNT(*) AS inconsistencias
FROM silver.sales
WHERE ABS(gross_sales - units_sold * sale_price) > 0.01
   OR ABS(sales - (gross_sales - discounts))     > 0.01;

-- 2. Repetições na granularidade (resultado atual: 112 combinações; característica da fonte)
SELECT segment, country, product, date, COUNT(*)
FROM silver.sales
GROUP BY 1, 2, 3, 4
HAVING COUNT(*) > 1;

-- 3. Domínio dos segmentos após a correção (esperado: exatamente 5 segmentos)
SELECT segment, COUNT(*)
FROM silver.sales
GROUP BY segment
ORDER BY segment;

-- 4. Integridade da carga da fato (os valores devem ser iguais)
SELECT
    (SELECT COUNT(*) FROM silver.sales)    AS linhas_silver,
    (SELECT COUNT(*) FROM gold.fact_sales) AS linhas_gold;

-- 5. Produtos sem correspondência na dimensão (esperado: nenhuma linha)
SELECT DISTINCT s.product
FROM silver.sales s
LEFT JOIN gold.dim_products d ON d.product = s.product
WHERE d.id IS NULL;
