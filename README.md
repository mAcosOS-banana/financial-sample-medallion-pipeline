# 📊 Financial Sample — Pipeline Medalhão com Polars, PostgreSQL e Power BI

![Python](https://img.shields.io/badge/Python-3.13-3776AB?logo=python&logoColor=white)
![Polars](https://img.shields.io/badge/Polars-DataFrame-CD792C?logo=polars&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Render-4169E1?logo=postgresql&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-DAX-F2C811?logo=powerbi&logoColor=black)
![Status](https://img.shields.io/badge/status-em%20evolução-yellow)

> Projeto de engenharia e análise de dados que implementa um pipeline em **arquitetura medalhão** (Raw → Bronze → Silver → Gold), com modelagem dimensional em **esquema estrela** e consumo analítico no **Power BI**.

📄 [English version](README.en.md)

---

## 📑 Sumário

1. [Sobre o projeto](#-sobre-o-projeto)
2. [Status de implementação](#-status-de-implementação)
3. [Arquitetura](#-arquitetura)
4. [Stack tecnológica](#-stack-tecnológica)
5. [O dataset e suas particularidades](#-o-dataset-e-suas-particularidades)
6. [Estrutura do repositório](#-estrutura-do-repositório)
7. [Camadas do pipeline](#-camadas-do-pipeline)
8. [Modelo dimensional](#-modelo-dimensional)
9. [Camada de consumo — Power BI](#-camada-de-consumo--power-bi)
10. [Decisões técnicas](#-decisões-técnicas)
11. [Validações de qualidade](#-validações-de-qualidade)
12. [Como executar](#-como-executar)
13. [Limitações conhecidas](#-limitações-conhecidas)
14. [Próximos passos](#-próximos-passos)
15. [Aprendizados](#-aprendizados)
16. [Autor](#-autor)

---

## 🎯 Sobre o projeto

Desenvolvi este projeto para consolidar, em um único fluxo de ponta a ponta, as práticas que considero essenciais em engenharia de dados:

- ingestão resiliente de dados brutos;
- separação clara de responsabilidades entre camadas;
- limpeza e padronização com regras explícitas e auditáveis;
- modelagem dimensional voltada para consumo analítico;
- métricas de negócio corretas do ponto de vista matemático.

Mais do que o resultado visual, o foco do projeto está nas **decisões técnicas** e em seus **trade-offs**. Por isso, este README documenta não apenas *o que* foi feito, mas *por que* foi feito dessa forma.

---

## 🚦 Status de implementação

O projeto está em evolução. Hoje, o repositório contém a ingestão das planilhas de vendas e a estrutura (DDL) das tabelas de todas as camadas. As transformações entre as camadas estão descritas neste README, mas os scripts de carga ainda não estão versionados.

| Etapa | Situação | Onde |
|---|---|---|
| Criação dos schemas `raw`, `bronze`, `silver` e `gold` | ✅ Implementado | `sql/00_schemas.sql` |
| Estrutura das tabelas (DDL) de todas as camadas | ✅ Implementado | `sql/00_bronze/`, `sql/01_silver/`, `sql/02_gold/` |
| Ingestão das planilhas de vendas em `raw.sales_raw` | ✅ Implementado | `ingestion/load_bronze.py` |
| Ingestão das planilhas de manufatura em `raw.manufacturing_raw` | ⏳ Pendente | `ingestion/load_bronze.py` lista os arquivos, mas não os carrega |
| Carga Raw → Bronze | ⏳ Não versionado | — |
| Transformações da Silver (limpeza, correção de segmentos, colunas derivadas) | ⏳ Não versionado | — |
| Carga da Gold (dimensões, fatos e `resume_products`) | ⏳ Não versionado | — |
| Validações de qualidade | ✅ Consultas prontas, mas dependem das cargas acima | `sql/99_quality_checks.sql` |
| Relatório Power BI | ✅ Versionado | `powerbi/financial_sample.pbix` |

> Os trechos de SQL das seções [Silver](#silver--dado-limpo-tipado-e-confiável) e [Gold](#gold--dado-de-negócio) mostram a lógica das transformações. Eles ainda não estão em arquivos do repositório.

---

## 🏗 Arquitetura

```mermaid
flowchart LR
    A[Planilhas XLSX<br/>Sales e Manufacturing] -->|Polars| B[(Raw<br/>cópia das planilhas)]
    B -->|SQL| C[(Bronze<br/>tipos da fonte, sem tratamento)]
    C -->|SQL| D[(Silver<br/>limpo e tipado)]
    D -->|SQL| E[(Gold<br/>esquema estrela)]
    E -->|Import| F[Power BI<br/>DAX]

    subgraph Render [PostgreSQL gerenciado — Render]
        B
        C
        D
        E
    end
```

> No repositório, apenas a etapa **Planilhas → Raw** (vendas) está automatizada. Veja o [Status de implementação](#-status-de-implementação).

**Princípios que segui:**

- Cada camada lê **somente** da camada imediatamente anterior.
- O dado flui em uma única direção. Uma correção na Silver nunca altera a Bronze.
- O Power BI consome **exclusivamente** a camada Gold.
- Qualquer camada pode ser reconstruída a partir da anterior.

---

## 🧰 Stack tecnológica

| Componente | Tecnologia | Papel no projeto |
|---|---|---|
| Linguagem | Python | Ingestão e orquestração das cargas |
| Processamento | Polars | Leitura, padronização de colunas e gravação na Raw |
| Banco de dados | PostgreSQL | Armazenamento das camadas e transformações em SQL |
| Hospedagem | Render | PostgreSQL gerenciado em nuvem, com acesso via SSL |
| Conexão Python ↔ banco | SQLAlchemy + psycopg2 | Engine de escrita do `write_database` |
| Gerenciamento de pacotes | uv | Ambiente e dependências do projeto |
| Visualização | Power BI (Power Query + DAX) | Modelo semântico, medidas e relatórios |

---

## 📦 O dataset e suas particularidades

Utilizei o **Financial Sample**, um dataset **sintético** de vendas de uma empresa de manufatura, disponibilizado pela Microsoft.

Os dados chegaram em **quatro planilhas** (`data/raw/`): vendas (`Sales`) e manufatura (`Manufacturing`), cada uma dividida em dois períodos (2013–2014 e 2015–2016).

Antes de qualquer transformação, analisei a estrutura dos dados. Encontrei características que influenciaram diretamente a modelagem:

| Característica | Impacto na modelagem |
|---|---|
| Cada linha é um **resumo mensal** (segmento × país × produto × mês), e não uma venda individual | Define a granularidade da fato e impede o cálculo de ticket médio |
| Todas as datas estão no **dia 1 do mês** | A dimensão calendário precisa estender o último mês até o fim (`EOMONTH`) |
| O período vai de **set/2013 a dez/2016**, em duas bases (2013–2014 e 2015–2016) | 2013 é um ano parcial; comparações anuais exigem cuidado |
| A combinação segmento × país × produto × mês **não é única** (112 combinações se repetem, quase todas no segmento Government) | A fato não pode assumir essa combinação como chave; cada linha é identificada pelo `id` gerado |
| O `sale_price` varia por **segmento**, e não por produto | O mesmo produto apresenta preços muito diferentes na mesma data |
| **Não existe** identificador de pedido | Um `id` gerado identifica registros, mas não representa uma venda |
| Variações de grafia em textos (`segment`, `discount_band`) | Exige padronização explícita na Silver |

---

## 🗂 Estrutura do repositório

```
financial-sample-medallion-pipeline/
├── data/
│   └── raw/                               # 4 planilhas originais (Sales e Manufacturing, 2013–2014 e 2015–2016)
├── ingestion/
│   ├── load_bronze.py                     # Leitura com Polars e carga das vendas em raw.sales_raw
│   └── utils.py                           # normalizar_nome: padronização dos nomes de colunas
├── sql/
│   ├── 00_schemas.sql                     # Criação dos schemas raw, bronze, silver e gold
│   ├── 00_bronze/                         # DDL das tabelas Raw e Bronze (sales e manufacturing)
│   ├── 01_silver/                         # DDL de products, countrys, sales e manufacturing
│   ├── 02_gold/                           # DDL das dimensões, das fatos e da tabela agregada
│   └── 99_quality_checks.sql              # Validações de qualidade
├── powerbi/
│   └── financial_sample.pbix              # Relatório (modo Import)
├── docs/
│   ├── Data_Analyst_Pratical_Case.pdf     # Enunciado do case
│   ├── REQUISITOS.md                      # Requisitos derivados do case
│   └── images/                            # Prints do modelo e do relatório (a adicionar)
├── .env.example                           # Variáveis de ambiente (sem credenciais)
├── .python-version
├── pyproject.toml
├── uv.lock
├── README.md
└── README.en.md
```

> Os arquivos em `sql/00_bronze/`, `sql/01_silver/` e `sql/02_gold/` criam **apenas a estrutura** das tabelas (`CREATE TABLE IF NOT EXISTS`). Eles não carregam dados.

---

## 🥉🥈🥇 Camadas do pipeline

### Raw — cópia das planilhas no banco

**Objetivo:** levar o conteúdo das planilhas para o banco sem alterar valores. Esta camada não é consultada para análise. Ela funciona como cópia de segurança e permite reprocessar todo o pipeline do zero. Os arquivos originais ficam em `data/raw/` e nunca são modificados.

**O que o `ingestion/load_bronze.py` faz hoje:**

1. **Lê as planilhas de vendas** (`.xlsx`) com o Polars e o engine `calamine`.
2. **Padroniza os nomes das colunas** para `snake_case` (`Gross Sales` → `gross_sales`) com a função `normalizar_nome` (`ingestion/utils.py`), que também remove acentos e conectores.
3. **Separa a coluna combinada** `country,product` em `country` e `product`.
4. **Grava a tabela `raw.sales_raw`**, acrescentando (`append`) os arquivos de cada período.

```python
import polars as pl
from utils import normalizar_nome

for arquivo in sales_data:
    df = pl.read_excel(arquivo, engine="calamine")
    df = df.rename({col: normalizar_nome(col) for col in df.columns})

    df = (
        df.with_columns(
            pl.col("country,product")
            .str.split_exact(",", 1)
            .struct.rename_fields(["country", "product"])
            .alias("split")
        )
        .unnest("split")
        .drop("country,product")
    )

    df.write_database(
        table_name="raw.sales_raw",
        connection=engine.connect(),
        engine="sqlalchemy",
        if_table_exists="append",
    )
```

Os schemas são criados previamente (`sql/00_schemas.sql`), pois o Polars cria a tabela, mas não cria o schema:

```sql
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;
```

> **Pendências conhecidas no script:**
> - As planilhas de manufatura estão listadas em `manufacturing_data`, mas ainda não são carregadas. A tabela `raw.manufacturing_raw` é criada pelo DDL e fica vazia.
> - No código real, a separação de `country,product` está dentro de um `try/except` que apenas imprime `"ok"`. Um erro nessa etapa é silenciado.
> - Como a gravação usa `append`, executar o script duas vezes duplica as linhas.

---

### Bronze — dado bruto, padronizado

**Objetivo:** guardar o conteúdo da fonte em formato padronizado e consultável, sem alterar valores.

**Situação:** as tabelas `bronze.sales` e `bronze.manufacturing` estão definidas em `sql/00_bronze/`, com as mesmas colunas e tipos da Raw. O script que copia os dados da Raw para a Bronze ainda não está versionado.

**O que não faço nesta camada:** corrigir, remover, deduplicar ou recalcular qualquer valor.

---

### Silver — dado limpo, tipado e confiável

**Objetivo:** entregar dados corretos e consistentes, na granularidade original, sem regras de negócio complexas.

**Situação:** a estrutura das tabelas está em `sql/01_silver/`. As regras abaixo descrevem a lógica de transformação. O script de carga ainda não está versionado.

#### `silver.sales`

**1. Limpeza de texto**

- `TRIM` para remover espaços no início e no fim.
- `INITCAP` para padronizar a capitalização de `country` e `product`.

**2. Correção de segmentos**

Primeiro padronizo o texto. Depois aplico a correção com padrões `ILIKE`:

```sql
CASE
    WHEN segment_raw ILIKE 'enter%rise' THEN 'Enterprise'
    WHEN segment_raw ILIKE 'gover%'     THEN 'Government'
    WHEN segment_raw ILIKE 'smal%'      THEN 'Small Business'
    WHEN segment_raw ILIKE 'mid%'       THEN 'Midmarket'
    WHEN segment_raw ILIKE 'channel%'   THEN 'Channel Partners'
    ELSE segment_raw
END AS segment
```

**3. Faixa de desconto**

O valor `None` em `discount_band` foi substituído por `No Discount`. O termo original pode ser confundido com ausência de dado.

**4. Colunas derivadas (cálculo na mesma linha)**

| Coluna | Fórmula |
|---|---|
| `perc_discount` | `discounts / NULLIF(gross_sales, 0)` |
| `perc_profit` | `profit / NULLIF(sales, 0)` |
| `profit_flag` | `Profit` / `Loss` / `Break-Even`, a partir de `profit` |

**5. Tipagem**

- Valores monetários e quantidades → mantêm os tipos da Bronze (`DOUBLE PRECISION`; `sale_price` em `BIGINT`).
- Percentuais → `NUMERIC(38,4)`.
- Datas → `DATE`.
- Ano e mês → `BIGINT`.

A conversão dos valores monetários para `NUMERIC(38,4)` acontece na carga da Gold (`gold.fact_sales`).

#### Tabelas auxiliares

- **`silver.products`:** cadastro de produtos (`product` como chave primária).
- **`silver.countrys`:** cadastro de países (`country` como chave primária).
- **`silver.manufacturing`:** custo de fabricação (`manufacturing_price`) e `cogs`, na granularidade segmento × país × produto × mês.

A integridade dentro da camada é garantida por chaves estrangeiras. `silver.sales` e `silver.manufacturing` referenciam `silver.products` e `silver.countrys`. Em `silver.sales`, `product` também é `NOT NULL`:

```sql
CREATE TABLE IF NOT EXISTS silver.sales (
    -- ...
    product  TEXT NOT NULL,
    -- ...
    CONSTRAINT fk_sales_products FOREIGN KEY (product) REFERENCES silver.products (product),
    CONSTRAINT fk_sales_contry   FOREIGN KEY (country) REFERENCES silver.countrys (country)
);
```

---

### Gold — dado de negócio

**Objetivo:** organizar os dados em **esquema estrela**, prontos para consumo analítico.

**Situação:** a estrutura das tabelas está em `sql/02_gold/`. Os `INSERT` mostrados abaixo descrevem a carga, que ainda não está versionada.

#### Dimensões

| Tabela | Chave | Atributo |
|---|---|---|
| `gold.dim_products` | `id` (UUID) | `product` |
| `gold.dim_countrys` | `id` (UUID) | `country` |
| `gold.dim_segments` | `id` (UUID) | `segment` |

As dimensões recebem **carga incremental**, para manter os identificadores estáveis:

```sql
INSERT INTO gold.dim_products (product)
SELECT product FROM silver.products
ON CONFLICT (product) DO NOTHING;
```

#### Fato `gold.fact_sales`

**Granularidade:** uma linha por registro da Silver (segmento × país × produto × mês).

- `segment`, `country` e `product` são substituídos pelos `id` das dimensões.
- Apenas métricas **aditivas** permanecem na fato.
- Chaves estrangeiras com `NOT NULL`.

```sql
INSERT INTO gold.fact_sales (
    segment_id, country_id, product_id, discount_band, date,
    units_sold, sale_price, gross_sales, discounts, sales, profit, profit_flag
)
SELECT
    ds.id, dc.id, dp.id, s.discount_band, s.date,
    s.units_sold, s.sale_price, s.gross_sales, s.discounts, s.sales, s.profit, s.profit_flag
FROM silver.sales s
JOIN gold.dim_segments ds ON ds.segment = s.segment
JOIN gold.dim_countrys dc ON dc.country = s.country
JOIN gold.dim_products dp ON dp.product = s.product;
```

#### Fato `gold.fact_manufacturing`

**Granularidade:** uma linha por registro de `silver.manufacturing` (segmento × país × produto × mês).

- `segment`, `country` e `product` são substituídos pelos `id` das dimensões, com chaves estrangeiras `NOT NULL`.
- Métricas de custo: `manufacturing_price` e `cogs`, em `NUMERIC(38,2)`.
- Diferente da `fact_sales`, ainda mantém `month_number` e `year`.

#### Fato agregada `gold.resume_products`

**Granularidade:** uma linha por produto. Consolida métricas de venda (`silver.sales`) e de custo (`silver.manufacturing`): `total_units_sold`, `total_gross_sales`, `total_discounts`, `total_sales`, `total_profit`, `total_cogs`, `max_manufacturing_price`, `min_manufacturing_price`, `gross_profit` e `gross_margin`.

As duas fontes são **agregadas separadamente** e unidas com `FULL JOIN`:

```sql
WITH sales_resume AS (
    SELECT product, SUM(sales) AS total_sales, SUM(profit) AS total_profit, ...
    FROM silver.sales GROUP BY product
),
manufacturing_resume AS (
    SELECT product, SUM(cogs) AS total_cogs, ...
    FROM silver.manufacturing GROUP BY product
)
SELECT ...
FROM manufacturing_resume m
FULL JOIN sales_resume s ON s.product = m.product
LEFT JOIN gold.dim_products d ON d.product = COALESCE(m.product, s.product);
```

---

## ⭐ Modelo dimensional

```mermaid
erDiagram
    dim_products  ||--o{ fact_sales : "product_id"
    dim_countrys  ||--o{ fact_sales : "country_id"
    dim_segments  ||--o{ fact_sales : "segment_id"
    dim_calendar  ||--o{ fact_sales : "date"
    dim_products  ||--o{ fact_manufacturing : "product_id"
    dim_countrys  ||--o{ fact_manufacturing : "country_id"
    dim_segments  ||--o{ fact_manufacturing : "segment_id"
    dim_products  ||--|| resume_products : "product_id"

    fact_sales {
        uuid id PK
        uuid product_id FK
        uuid country_id FK
        uuid segment_id FK
        date date FK
        text discount_band
        numeric units_sold
        numeric sale_price
        numeric gross_sales
        numeric discounts
        numeric sales
        numeric profit
        text profit_flag
    }
    fact_manufacturing {
        uuid id PK
        uuid product_id FK
        uuid country_id FK
        uuid segment_id FK
        date date
        numeric manufacturing_price
        numeric cogs
        int month_number
        int year
    }
    dim_products {
        uuid id PK
        text product
    }
    dim_countrys {
        uuid id PK
        text country
    }
    dim_segments {
        uuid id PK
        text segment
    }
    dim_calendar {
        date Date PK
        int Year
        int Month_Number
        text Month_Name
    }
    resume_products {
        uuid product_id FK
        numeric total_units_sold
        numeric total_sales
        numeric total_profit
        numeric total_cogs
        numeric gross_profit
        numeric gross_margin
    }
```

> A `dim_calendar` é criada no Power BI (DAX), e não no banco.

---

## 📈 Camada de consumo — Power BI

### Conexão

- Banco PostgreSQL no **Render**, com conexão **SSL**.
- Dois parâmetros no Power Query: **servidor** (`pServer`) e **banco** (`pDatabase`).
- Credenciais armazenadas nas configurações da fonte de dados, **nunca** nos parâmetros.
- Todas as tabelas em **modo Import**.
- Colunas de navegação (`Record` / `Table`) geradas pelas foreign keys removidas no Power Query. As relações são definidas no modelo.

### Dimensão calendário

Criada em DAX, do primeiro ao último mês da fato:

```dax
dim_calendar =
VAR StartDate = MIN ( fact_sales[date] )
VAR EndDate   = EOMONTH ( MAX ( fact_sales[date] ), 0 )
RETURN
ADDCOLUMNS (
    CALENDAR ( StartDate, EndDate ),
    "Year",              YEAR ( [Date] ),
    "Quarter Name",      "Q" & QUARTER ( [Date] ),
    "Month Number",      MONTH ( [Date] ),
    "Month Name",        FORMAT ( [Date], "MMMM", "en-US" ),
    "Year Month Number", YEAR ( [Date] ) * 100 + MONTH ( [Date] ),
    "Months Ago",        DATEDIFF ( [Date], EndDate, MONTH )
    -- ... demais atributos
)
```

A tabela está marcada como tabela de datas. As colunas textuais são ordenadas pelas colunas numéricas correspondentes.

### Principais medidas

| Medida | Definição |
|---|---|
| `total_sales` | Soma da receita líquida |
| `profit_margin` | `(sales − cogs) / sales` |
| `markup` | `(sales − cogs) / cogs` |
| `cogs_ratio` | `cogs / sales` |
| `average_unit_price` | `sales / units_sold` |
| `sales_mom_%` | Variação contra o mês anterior |
| `sales_yoy_%` | Variação contra o mesmo período do ano anterior |
| `sales_period_var_%` | Variação contra o período anterior de mesmo tamanho |
| `sales_var_%_dynamic` | YoY no nível Ano e MoM no nível Mês |

**Variação dinâmica com drill-down:**

```dax
sales_previous_dynamic =
SWITCH (
    TRUE (),
    ISINSCOPE ( dim_calendar[Month Name] ),
        CALCULATE ( [total_sales], DATEADD ( dim_calendar[Date], -1, MONTH ) ),
    ISINSCOPE ( dim_calendar[Year] ),
        CALCULATE ( [total_sales], DATEADD ( dim_calendar[Date], -1, YEAR ) )
)

sales_var_%_dynamic =
VAR current_ = [total_sales]
VAR previous = [sales_previous_dynamic]
RETURN
IF ( NOT ISBLANK ( previous ), DIVIDE ( current_ - previous, previous ) )
```

**Variação para seleções com vários meses:**

```dax
sales_previous_period =
VAR StartDate = MIN ( dim_calendar[Date] )
VAR EndDate   = MAX ( dim_calendar[Date] )
VAR NMonths   = DATEDIFF ( StartDate, EndDate, MONTH ) + 1
RETURN
CALCULATE ( [total_sales], DATEADD ( dim_calendar[Date], -NMonths, MONTH ) )
```

---

## 🧠 Decisões técnicas

Esta seção registra as principais decisões do projeto. Para cada uma, descrevo o contexto, a escolha e o motivo.

### Ingestão, Raw e Bronze

#### 1. Polars para a ingestão
- **Decisão:** usar Polars em vez de pandas.
- **Motivo:** API expressiva, bom desempenho e gravação direta em schema qualificado com `write_database`.
- **Trade-off:** com o engine `sqlalchemy`, o Polars usa o `pandas.to_sql` internamente. Para volumes maiores, o engine `adbc` é mais eficiente.

#### 2. Tipos inferidos da planilha na Raw e na Bronze
- **Decisão:** manter os tipos que o Polars infere das células do Excel (`double precision`, `bigint`, `date` e `text`), sem casts manuais.
- **Motivo:** no `.xlsx`, as células já são tipadas. Datas e números chegam corretos à Raw e à Bronze, sem conversão de texto. Os ajustes de tipo e de domínio ficam na Silver.
- **Trade-off:** um valor inválido em uma coluna numérica pode virar nulo ou interromper a carga. Se o tipo de uma coluna mudar entre os arquivos, o `append` falha. Ler tudo como texto evitaria esses dois riscos, em troca de casts explícitos na Silver.

#### 3. Um schema por camada
- **Decisão:** `raw`, `bronze`, `silver` e `gold` como schemas separados no mesmo banco.
- **Motivo:** isolamento lógico, controle de permissões por camada e nomes autoexplicativos.

### Silver

#### 4. Padronizar o texto antes de corrigir
- **Decisão:** aplicar `TRIM` e `INITCAP` antes do `CASE` de correção dos segmentos.
- **Motivo:** espaços invisíveis e diferenças de capitalização faziam comparações exatas falharem. Padronizando primeiro, as regras de correção ficam menores e mais robustas.

#### 5. `profit_flag` calculada a partir de `profit`
- **Decisão:** classificar o resultado da venda pelo valor absoluto do lucro, e não pelo percentual.
- **Motivo:** o percentual é arredondado para quatro casas. Um lucro muito pequeno seria arredondado para zero e classificado como `Break-Even` de forma incorreta.

#### 6. `NUMERIC(38,4)` para percentuais
- **Decisão:** armazenar percentuais como fração com quatro casas decimais.
- **Motivo:** com duas casas, `0,0567` viraria `0,06`. A perda de precisão afetaria qualquer análise posterior.

#### 7. `NULLIF` em todas as divisões
- **Decisão:** proteger os denominadores com `NULLIF(coluna, 0)`.
- **Motivo:** evita erros de divisão por zero. O resultado `NULL` deixa claro que a razão não existe, ao contrário de um `0` artificial.

#### 8. Percentuais por linha mantidos na Silver
- **Decisão:** manter `perc_discount` e `perc_profit` na Silver.
- **Motivo:** são cálculos estáveis e feitos na mesma linha.
- **Ressalva:** são métricas **não aditivas**. Nunca as utilizo como base de agregação. No BI, sempre recalculo a partir das somas.

### Gold e modelagem

#### 9. Esquema estrela
- **Decisão:** separar fatos (métricas) e dimensões (atributos descritivos).
- **Motivo:** menos joins nas consultas, modelo mais simples no Power BI e melhor desempenho do motor VertiPaq.

#### 10. Tabelas em vez de views
- **Decisão:** materializar Silver e Gold como tabelas.
- **Motivo:** o resultado é processado uma vez por carga, e não a cada consulta. Além disso, se uma camada anterior falhar, a Gold continua exibindo a última carga válida.

#### 11. Chaves independentes entre camadas
- **Decisão:** a Gold possui chaves próprias. Nenhuma foreign key liga a Gold à Silver.
- **Motivo:** permite reprocessar a Silver (inclusive com `DROP TABLE`) sem bloqueios. A ligação entre camadas ocorre na carga, por meio da chave natural.

#### 12. Chaves substitutas em UUID
- **Decisão:** gerar os `id` das dimensões com `gen_random_uuid()`.
- **Trade-off reconhecido:** chaves inteiras (`IDENTITY`) ocupam 4 bytes contra 16 do UUID e deixam o modelo do Power BI mais leve. Para o volume deste projeto, o impacto é desprezível. Em um cenário de produção, eu avaliaria chaves inteiras.

#### 13. Carga incremental nas dimensões
- **Decisão:** inserir apenas registros novos (`ON CONFLICT DO NOTHING`).
- **Motivo:** o `gen_random_uuid()` gera um valor novo a cada execução. Recriar a dimensão quebraria a ligação com fatos, relatórios e filtros salvos.

#### 14. Fato apenas com métricas aditivas
- **Decisão:** remover percentuais e atributos de calendário (`month_number`, `month_name`, `year`) da `fact_sales`. A `profit_flag` foi mantida como atributo da linha (dimensão degenerada).
- **Motivo:** atributos de data pertencem à dimensão calendário. Métricas não aditivas devem ser calculadas no contexto do filtro, e não armazenadas. A `profit_flag` não é uma métrica: ela classifica cada registro e serve como filtro no relatório.

#### 15. Acumulados fora da fato
- **Decisão:** não armazenar lucro acumulado (MTD) na fato.
- **Motivo:** o acumulado não é aditivo, não respeita filtros aplicados no relatório e precisaria ser recalculado a cada nova carga. O cálculo correto é uma medida DAX.

#### 16. `FULL JOIN` na tabela de resumo
- **Decisão:** agregar vendas e custos separadamente e unir com `FULL JOIN`.
- **Motivo:** cada lado tem uma linha por produto, o que garante uma junção 1:1 sem truques de `MAX` no `GROUP BY`. O `FULL JOIN` também expõe produtos com venda sem custo (ou o contrário), o que serve como verificação de integridade.

### Power BI

#### 17. Razão das somas em todas as métricas percentuais
- **Decisão:** calcular razões como `SUM(a) / SUM(b)`.
- **Motivo:** a média de percentuais por linha dá o mesmo peso a vendas grandes e pequenas, o que distorce o resultado.

| Venda | sales | profit | margem |
|---|---|---|---|
| A | 1.000 | 100 | 10% |
| B | 10 | 5 | 50% |
| **Média das razões** | | | **30%** ❌ |
| **Razão das somas** | | | **10,4%** ✅ |

#### 18. Margem sobre a receita líquida
- **Decisão:** usar `sales` (após desconto) como base da margem, e não `gross_sales`.
- **Motivo:** o desconto reduz a receita efetiva. Usar a receita bruta infla a margem.
- **Complemento:** diferenciei explicitamente **margem** (`÷ sales`) e **markup** (`÷ cogs`), que respondem a perguntas diferentes.

#### 19. Preço médio unitário em vez de ticket médio
- **Decisão:** não publicar uma métrica de ticket médio.
- **Motivo:** o dataset não possui identificador de pedido. Um `id` gerado por linha apenas conta registros. A métrica disponível e honesta é o preço médio por unidade (`sales / units_sold`).

#### 20. `DIVIDE` sem valor alternativo
- **Decisão:** usar `DIVIDE(a, b)` sem o terceiro argumento.
- **Motivo:** retornar vazio em vez de zero evita que "sem dados" seja interpretado como "margem zero".

#### 21. Calendário em DAX estendido com `EOMONTH`
- **Decisão:** gerar a dimensão de datas no Power BI, do primeiro dia da base ao último dia do último mês.
- **Motivo:** como as datas da base estão no dia 1, terminar o calendário no `MAX` excluiria o restante do último mês e afetaria medidas de inteligência de tempo.

#### 22. Variação dinâmica com `ISINSCOPE`
- **Decisão:** uma única medida que compara ano contra ano no nível Ano e mês contra mês no nível Mês.
- **Motivo:** permite drill-down na hierarquia sem trocar de medida. O nível mais detalhado é testado primeiro, pois no nível Mês o Ano também está no escopo.

#### 23. Período anterior de mesmo tamanho com `DATEDIFF`
- **Decisão:** calcular a quantidade de meses selecionados e deslocar a comparação pelo mesmo tamanho.
- **Motivo:** quando o usuário seleciona vários meses, a comparação se ajusta automaticamente (3 meses contra os 3 anteriores, por exemplo).

#### 24. Modo Import
- **Decisão:** importar todas as tabelas.
- **Motivo:** o `.pbix` mantém uma cópia dos dados. O relatório continua funcionando para quem o abrir, mesmo sem acesso ao banco.

#### 25. Parâmetros de conexão sem credenciais
- **Decisão:** parametrizar apenas servidor e banco.
- **Motivo:** facilita a troca de ambiente sem expor senhas. Os parâmetros são passados diretamente ao conector, o que evita fontes dinâmicas que impedem a atualização no serviço do Power BI.

---

## ✅ Validações de qualidade

As consultas abaixo estão em `sql/99_quality_checks.sql`. Elas consultam a Silver e a Gold e, por isso, só retornam resultados úteis depois que essas camadas forem carregadas. Os resultados citados nos comentários se referem à base completa.

**Consistência das colunas monetárias:**

```sql
SELECT COUNT(*) AS inconsistencias
FROM silver.sales
WHERE ABS(gross_sales - units_sold * sale_price) > 0.01
   OR ABS(sales - (gross_sales - discounts))     > 0.01;
```

**Repetições na granularidade:**

```sql
SELECT segment, country, product, date, COUNT(*)
FROM silver.sales
GROUP BY 1, 2, 3, 4
HAVING COUNT(*) > 1;
-- Resultado atual: 112 combinações repetidas. É uma característica da fonte,
-- e não um erro de carga. A consulta serve para monitorar mudanças nesse número.
```

**Domínio dos segmentos após a correção:**

```sql
SELECT segment, COUNT(*)
FROM silver.sales
GROUP BY segment
ORDER BY segment;
-- Resultado esperado: exatamente 5 segmentos
```

**Integridade da carga da fato:**

```sql
SELECT
    (SELECT COUNT(*) FROM silver.sales)    AS linhas_silver,
    (SELECT COUNT(*) FROM gold.fact_sales) AS linhas_gold;
-- Os valores devem ser iguais
```

**Produtos sem correspondência na dimensão:**

```sql
SELECT DISTINCT s.product
FROM silver.sales s
LEFT JOIN gold.dim_products d ON d.product = s.product
WHERE d.id IS NULL;
-- Resultado esperado: nenhuma linha
```

---

## ▶️ Como executar

### Pré-requisitos

- Python 3.13+
- [uv](https://docs.astral.sh/uv/)
- Uma instância PostgreSQL 13+ (utilizei o [Render](https://render.com)). A versão 13 é a primeira com `gen_random_uuid()` nativo.
- Cliente `psql`
- Power BI Desktop (para abrir o relatório)

### 1. Clonar o repositório

```bash
git clone https://github.com/mAcosOS-banana/financial-sample-medallion-pipeline.git
cd financial-sample-medallion-pipeline
```

### 2. Instalar as dependências

```bash
uv sync
```

Dependências principais: `polars`, `fastexcel`, `python-calamine`, `sqlalchemy`, `psycopg2`, `pandas`, `pyarrow`, `python-dotenv`.

### 3. Configurar as variáveis de ambiente

Copie o arquivo de exemplo e preencha com os dados do seu banco:

```bash
cp .env.example .env
```

```env
POSTGRES_URL=postgresql+psycopg2://usuario:senha@host:5432/banco?sslmode=require
```

> ⚠️ O arquivo `.env` está no `.gitignore`. Nunca versione credenciais.

### 4. Criar os schemas e as tabelas

Execute `00_schemas.sql` e depois os scripts de DDL na ordem `00_bronze/` → `01_silver/` → `02_gold/`. Dentro de cada pasta, a numeração dos arquivos já coloca primeiro as tabelas referenciadas por chave estrangeira.

```bash
set -a; source .env; set +a
PG_URL="${POSTGRES_URL/+psycopg2/}"

psql "$PG_URL" -v ON_ERROR_STOP=1 -f sql/00_schemas.sql
for f in sql/00_bronze/*.sql sql/01_silver/*.sql sql/02_gold/*.sql; do
    psql "$PG_URL" -v ON_ERROR_STOP=1 -f "$f"
done
```

### 5. Carregar a Raw

```bash
uv run ingestion/load_bronze.py
```

O script carrega as planilhas de **vendas** em `raw.sales_raw`. As planilhas de manufatura ainda não são carregadas. Como a gravação usa `append`, não execute o script duas vezes sobre a mesma tabela.

### 6. Transformações entre as camadas

Os scripts de carga Raw → Bronze → Silver → Gold **ainda não estão no repositório**. A lógica de cada etapa está descrita em [Camadas do pipeline](#-camadas-do-pipeline).

### 7. Validações de qualidade

Depois das cargas, execute `sql/99_quality_checks.sql`:

```bash
psql "$PG_URL" -f sql/99_quality_checks.sql
```

### 8. Abrir o relatório

Abra `powerbi/financial_sample.pbix`. O relatório está em modo Import e funciona sem conexão. Para atualizar os dados, ajuste os parâmetros `pServer` e `pDatabase` e informe as credenciais do seu banco.

---

## ⚠️ Limitações conhecidas

- **Pipeline parcialmente versionado.** O repositório cobre a ingestão das vendas e a estrutura das tabelas. As cargas das camadas Bronze, Silver e Gold ainda não estão versionadas.
- **Dados sintéticos.** As diferenças de preço entre segmentos não refletem um cenário real.
- **Ticket médio indisponível.** O dataset não possui identificador de pedido.
- **Comparação anual parcial.** 2013 contém apenas quatro meses. A variação anual de 2014 contra 2013 compara 12 meses com 4. Para análises anuais, devem ser considerados apenas os meses presentes nos dois anos.
- **Granularidade mensal.** Não é possível realizar análises diárias ou semanais com significado real.
- **Hospedagem gratuita.** O banco no plano gratuito do Render possui prazo de expiração. O `.pbix` em modo Import preserva os dados da última atualização.

---

## 🚀 Próximos passos

- [ ] Carregar as planilhas de manufatura em `raw.manufacturing_raw`.
- [ ] Remover o `try/except` silencioso da ingestão e tornar a carga idempotente.
- [ ] Versionar os scripts de carga Raw → Bronze, Silver e Gold.
- [ ] Adicionar os prints do modelo e do relatório em `docs/images/`.
- [ ] Criar a dimensão `dim_discount_bands` e substituir o atributo textual da fato.
- [ ] Adicionar a coluna `cogs` à `gold.fact_sales`.
- [ ] Criar índices nas colunas de chave estrangeira das fatos (`segment_id`, `country_id`, `product_id`).
- [ ] Criar a fato mensal `gold.fact_sales_product_monthly`, com classificação **curva ABC** por mês.
- [ ] Adicionar membros "Desconhecido" (`-1`) às dimensões.
- [ ] Orquestrar o pipeline com **Apache Airflow**.
- [ ] Automatizar as validações de qualidade e registrar os resultados em uma tabela de auditoria.
- [ ] Adicionar colunas de metadados na Bronze (`_ingested_at`, `_source_file`).

---

## 📚 Aprendizados

Os pontos que mais agregaram ao meu entendimento durante o projeto foram:

- **A granularidade define tudo.** Entender que cada linha era um resumo mensal, e não uma venda, mudou a forma como modelei a fato e quais métricas eram possíveis.
- **Nem toda métrica pode ser armazenada.** Percentuais e acumulados parecem prontos para ir para a fato, mas quebram com filtros. O lugar certo é a medida.
- **Arredondamento tem consequências.** Uma classificação baseada em um valor arredondado gerou resultados incorretos.
- **Estabilidade de chaves é requisito, não detalhe.** Recriar uma dimensão com UUIDs aleatórios quebraria todo o modelo.
- **Documentar limitações é parte do trabalho.** Reconhecer o que o dataset não permite calcular evita conclusões erradas.

---

## 👤 Autor

**Marcos**
Analista de Dados · Estudante de Ciência da Computação (UNEMAT) e Engenharia de Dados (Infnet)

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/marcos-oliveira-601a18226)
[![GitHub](https://img.shields.io/badge/GitHub-181717?logo=github&logoColor=white)](https://github.com/mAcosOS-banana)