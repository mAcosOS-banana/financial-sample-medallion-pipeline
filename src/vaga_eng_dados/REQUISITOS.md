# Requisitos do Projeto: Relatório Mensal de Vendas

Fonte: [Data_Analyst_Pratical_Case.pdf](src/Data_Analyst_Pratical_Case.pdf) (1 página, marcada como "Ilustrativo").

## Contexto

O profissional foi alocado em um projeto de um cliente: uma empresa nacional cujo principal produto é a venda de bicicletas em diversos países. A empresa possui uma base de dados consistente, com muitas informações sobre vendas.

## Usuário

**Sales Specialist** (especialista de vendas).

## Demandas do cliente

| Eu quero... | Para... |
| --- | --- |
| Avaliar a performance das vendas mensais e anuais | Definir as prioridades e a estratégia comercial do próximo mês |
| Comparar as vendas de diferentes clientes e setores | Traçar ações e estratégias específicas para alavancar os meus resultados |

## Frequência de reporte

| Frequência | Público | Finalidade |
| --- | --- | --- |
| Semanal | Time de vendas | Montar estratégias durante a semana |
| Mensal | C-Level | Reunião mensal |

## Requisitos derivados

O PDF não lista requisitos técnicos. Os itens abaixo são uma interpretação das demandas acima.

### Funcionais

- **RF1:** apresentar as vendas agregadas por mês e por ano.
- **RF2:** permitir comparar a performance entre períodos, para apoiar a definição das prioridades do mês seguinte.
- **RF3:** apresentar e comparar as vendas por cliente.
- **RF4:** apresentar e comparar as vendas por setor.
- **RF5:** evidenciar os principais destaques de cada visão, para embasar ações comerciais específicas.

### Não funcionais

- **RNF1:** os dados devem poder ser atualizados ao menos semanalmente.
- **RNF2:** oferecer uma visão de nível executivo para a reunião mensal com o C-Level, além da visão operacional do time de vendas.

## Pontos em aberto

O PDF não define:

- o formato da entrega (dashboard, relatório ou apresentação) nem as ferramentas a usar;
- as métricas de performance (por exemplo, receita, volume ou margem);
- o que significa "setor" nos dados;
- o papel das bases de `Manufacturing` em `src/vaga_eng_dados/files/`, já que as demandas tratam apenas de vendas.
