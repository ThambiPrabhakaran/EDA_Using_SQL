-- Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region
select  distinct(market) from dim_customer
where customer = 'Atliq Exclusive' and region ='APAC'
order by market asc;

-- What is the percentage of unique product increase in 2021 vs. 2020? 
-- The final output contains these fields, unique_products_2020 unique_products_2021 percentage_chg

with cte_unique_products_2020 as
(
select count(distinct product_code) as unique_products_2020 from fact_sales_monthly
where fiscal_year = 2020
),
cte_unique_products_2021 as
(
select count(distinct product_code) as unique_products_2021 from fact_sales_monthly
where fiscal_year = 2021
)
select round((unique_products_2021 - unique_products_2020) / unique_products_2020, 2) * 100 as percentage_chg, unique_products_2020, unique_products_2021
from cte_unique_products_2020,cte_unique_products_2021;

-- Provide a report with all the unique product counts for each segment and sort them 
-- in descending order of product counts. The final output contains 2 fields, segment product_count
select segment, count(distinct product_code) as product_count 
from dim_product
group by segment
order by product_count desc;


-- Follow-up: Which segment had the most increase in unique products in 2021 vs 2020?
-- The final output contains these fields, segment product_count_2020 product_count_2021 difference

with cte_unique_product_2020 as
(
select segment, count(distinct fact_sales_monthly.product_code) as product_count_2020 from fact_sales_monthly
join dim_product
on dim_product.product_code = fact_sales_monthly.product_code
where fiscal_year = 2020
group by segment
),
cte_unique_product_2021 as
(
select segment, count(distinct fact_sales_monthly.product_code) as product_count_2021 from dim_product
join fact_sales_monthly
on dim_product.product_code = fact_sales_monthly.product_code
where fiscal_year = 2021
group by segment
)
select distinct(cte_unique_product_2020.segment), product_count_2020, product_count_2021, (product_count_2021-product_count_2020) as difference
from cte_unique_product_2020 
join cte_unique_product_2021 on cte_unique_product_2020.segment = cte_unique_product_2021.segment
order by difference desc;

-- Get the products that have the highest and lowest manufacturing costs.
-- The final output should contain these fields, product_code product manufacturing_cost

select distinct(dim_product.product_code), product, manufacturing_cost
from dim_product
join fact_manufacturing_cost on dim_product.product_code = fact_manufacturing_cost.product_code
where manufacturing_cost in (
(
select min(manufacturing_cost)
from fact_manufacturing_cost
)
,
(
select max(manufacturing_cost)
from fact_manufacturing_cost
)
)
order by manufacturing_cost desc;

-- Generate a report which contains the top 5 customers who received an
-- average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market.
-- The final output contains these fields, customer_code customer average_discount_percentage

select fact_pre_invoice_deductions.customer_code, dim_customer.customer, round(avg(fact_pre_invoice_deductions.pre_invoice_discount_pct) * 100, 2) as average_discount_percentage 
from fact_pre_invoice_deductions
join dim_customer on fact_pre_invoice_deductions.customer_code = dim_customer.customer_code
where market = 'India' and fiscal_year = 2021
group by fact_pre_invoice_deductions.customer_code
order by average_discount_percentage desc
limit 5;

-- Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month .
-- This analysis helps to get an idea of low and high-performing months and take strategic decisions.
-- The final report contains these columns: Month Year Gross sales Amount

select month(fact_sales_monthly.date) as Month, fact_sales_monthly.fiscal_year as Year, 
sum(round(fact_sales_monthly.sold_quantity * fact_gross_price.gross_price)) as Gross_sales_Amount
from fact_sales_monthly
join fact_gross_price on fact_sales_monthly.product_code = fact_gross_price.product_code
join dim_customer on fact_sales_monthly.customer_code = dim_customer.customer_code
where dim_customer.customer = "Atliq Exclusive" 
group by Month, fact_sales_monthly.fiscal_year
order by Gross_sales_Amount desc;

-- In which quarter of 2020, got the maximum total_sold_quantity?
-- The final output contains these fields sorted by the total_sold_quantity, Quarter total_sold_quantity

WITH quarterly_sales 
AS (
  SELECT
    CASE
      WHEN EXTRACT(MONTH FROM date) BETWEEN 9 AND 12 THEN 'Q1'
      WHEN EXTRACT(MONTH FROM date) BETWEEN 1 AND 3 THEN 'Q2'
      WHEN EXTRACT(MONTH FROM date) BETWEEN 4 AND 6 THEN 'Q3'
      WHEN EXTRACT(MONTH FROM date) BETWEEN 7 AND 9 THEN 'Q4'
    END AS quarter,
    SUM(sold_quantity) AS total_sold_quantity
  FROM
    fact_sales_monthly
  WHERE
    EXTRACT(YEAR FROM date) = 2020
  GROUP BY
    quarter
)
SELECT
  quarter,
  total_sold_quantity
FROM
  quarterly_sales
ORDER BY
  total_sold_quantity DESC;

-- Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution?
-- The final output contains these fields, channel gross_sales_mln percentage

WITH channel_gross_sales AS 
(
  SELECT
    d.channel,
    SUM(round(g.gross_price * f.sold_quantity)) AS gross_sales
  FROM
    fact_sales_monthly f
  JOIN
    fact_gross_price g ON f.product_code = g.product_code
  JOIN
    dim_customer d ON f.customer_code = d.customer_code
  WHERE
    EXTRACT(YEAR FROM f.date) = 2021
  GROUP BY
    d.channel
),
total_gross_sales AS (
  SELECT
    SUM(gross_sales) AS total_sales
  FROM
    channel_gross_sales
)
SELECT
  c.channel,
  (gross_sales/1000000) as gross_sales_mln,
  c.gross_sales / t.total_sales * 100 AS percentage
FROM
  channel_gross_sales c
CROSS JOIN
  total_gross_sales t
ORDER BY
  c.gross_sales DESC
LIMIT 1;


-- Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021?
-- The final output contains these fields, division product_code


WITH division_performance AS (
  SELECT
    dp.division,
    dp.product_code,
    SUM(fsm.sold_quantity) AS total_sold_quantity,
    RANK() OVER (PARTITION BY dp.division ORDER BY SUM(fsm.sold_quantity) DESC) AS product_rank
  FROM
    dim_product dp
  JOIN
    fact_sales_monthly fsm ON dp.product_code = fsm.product_code
  WHERE
    fsm.fiscal_year = 2021
  GROUP BY
    dp.division,
    dp.product_code
)
SELECT
 division,
  product_code
FROM
  division_performance
WHERE
  product_rank <= 3
ORDER BY
  division,
  product_rank;
