-- Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

SELECT DISTINCT
    market, region
FROM
    dim_customer
WHERE
    customer = 'Atliq Exclusive'
        AND region = 'APAC';

/*What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields
unique_products_2020 , unique_products_2021 , percentage_chg */

WITH unique_product_count AS
(
	SELECT 
		COUNT(DISTINCT CASE WHEN fiscal_year = 2020 THEN product_code END) AS unique_products_2020,
		COUNT(DISTINCT CASE WHEN fiscal_year = 2021 THEN product_code END) AS unique_products_2021
	FROM 
		fact_sales_monthly 
)
SELECT 
	unique_products_2020,
	unique_products_2021,
	CONCAT(ROUND(((unique_products_2021 - unique_products_2020) * 100.0 / NULLIF(unique_products_2020, 0)), 2), '%') AS percentage_chg
FROM 
	unique_product_count;

/* Provide a report with all the unique product counts for each segment and sort them in descending order of product counts.
The final output contains 2 fields:
                                   segment, product_count   */
                                   
SELECT 
    segment, COUNT(DISTINCT product_code) AS product_count
FROM
    dim_product
GROUP BY segment
ORDER BY product_count;

/*
Follow-up: Which segment had the most increase in unique products in 2021 vs 2020?
The final output contains these fields:
segment, product_count_2020, product_count_2021, difference
*/

WITH unique_product AS
(
 SELECT
      p.segment AS segment,
      COUNT(DISTINCT
          (CASE 
              WHEN fiscal_year = 2020 THEN s.product_code END)) AS product_count_2020,
       COUNT(DISTINCT
          (CASE 
              WHEN fiscal_year = 2021 THEN s.product_code END)) AS product_count_2021        
 FROM fact_sales_monthly AS s
 INNER JOIN dim_product AS p
 ON s.product_code = p.product_code
 GROUP BY p.segment
)
SELECT segment, product_count_2020, product_count_2021, (product_count_2021-product_count_2020) AS difference
FROM unique_product
ORDER BY difference DESC;

/*
Get the products that have the highest and lowest manufacturing costs. 
The final output should contain these fields: product_code, product, manufacturing_cost
*/    

WITH highest_cost AS (
    SELECT 
        fmc.product_code, 
        dp.product, 
        fmc.manufacturing_cost
    FROM 
        fact_manufacturing_cost fmc
    JOIN 
        dim_product dp ON fmc.product_code = dp.product_code
    ORDER BY 
        fmc.manufacturing_cost DESC
    LIMIT 1
),
lowest_cost AS (
    SELECT 
        fmc.product_code, 
        dp.product, 
        fmc.manufacturing_cost
    FROM 
        fact_manufacturing_cost fmc
    JOIN 
        dim_product dp ON fmc.product_code = dp.product_code
    ORDER BY 
        fmc.manufacturing_cost ASC
    LIMIT 1
)

SELECT * FROM highest_cost
UNION ALL
SELECT * FROM lowest_cost;

-- without cte

-- Subquery for the product with the highest manufacturing cost
SELECT 
    fmc.product_code, 
    dp.product, 
    fmc.manufacturing_cost
FROM 
    fact_manufacturing_cost fmc
JOIN 
    dim_product dp ON fmc.product_code = dp.product_code
WHERE 
    fmc.manufacturing_cost = (SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost)

UNION ALL

-- Subquery for the product with the lowest manufacturing cost
SELECT 
    fmc.product_code, 
    dp.product, 
    fmc.manufacturing_cost
FROM 
    fact_manufacturing_cost fmc
JOIN 
    dim_product dp ON fmc.product_code = dp.product_code
WHERE 
    fmc.manufacturing_cost = (SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost);

/* 
Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct 
for the fiscal year 2021 and in the Indian market. The final output contains these fields,
customer_code, customer, average_discount_percentage
*/
SELECT 
    dc.customer_code,
    dc.customer,
    ROUND(AVG(fpid.pre_invoice_discount_pct)*100, 2) AS average_discount_percentage
FROM 
    fact_pre_invoice_deductions fpid
JOIN 
    dim_customer dc ON fpid.customer_code = dc.customer_code
WHERE 
    fpid.fiscal_year = 2021
    AND dc.market = 'India'
GROUP BY 
    dc.customer_code, 
    dc.customer
ORDER BY 
    average_discount_percentage DESC
LIMIT 5;

/*
Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month .
This analysis helps to get an idea of low and high-performing months and take strategic decisions. 
The final report contains these columns: Month, Year, Gross sales Amount
*/

SELECT 
    YEAR(fs.date) AS Year,
    MONTHNAME(fs.date) AS Month,
    ROUND(SUM(fs.sold_quantity * fp.gross_price)/1000000, 2) AS Gross_sales_amount_mln
FROM 
    fact_sales_monthly fs
INNER JOIN 
    fact_gross_price fp ON fs.product_code = fp.product_code AND fs.fiscal_year = fp.fiscal_year
INNER JOIN 
    dim_customer dc ON fs.customer_code = dc.customer_code
WHERE 
    dc.customer = 'Atliq Exclusive'
GROUP BY 
    MONTHNAME(fs.date), YEAR(fs.date)
ORDER BY 
    Year;

/*
In which quarter of 2020, got the maximum total_sold_quantity? The final output contains these fields sorted by the 
total_sold_quantity, Quarter total_sold_quantity
*/

SELECT 
    CASE
        WHEN MONTH(date) IN (9 , 10, 11) THEN 'Q1'
        WHEN MONTH(date) IN (12 , 1, 2) THEN 'Q2'
        WHEN MONTH(date) IN (3 , 4, 5) THEN 'Q3'
        ELSE 'Q4'
    END AS quarters,
    SUM(sold_quantity) AS total_quantity_sold
FROM
    fact_sales_monthly
WHERE
    fiscal_year = 2020
GROUP BY quarters
ORDER BY total_quantity_sold DESC;

/*
Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? 
The final output contains these fields: channel, gross_sales_mln, percentage
*/


WITH gross_sales AS
( 
 SELECT c.channel AS channel_,
        ROUND(SUM(b.gross_price*a.sold_quantity)/1000000,2) 
 AS gross_sales_million
 FROM fact_sales_monthly AS a
 LEFT JOIN fact_gross_price AS b
 ON a.product_code = b.product_code
 AND a.fiscal_year = b.fiscal_year
LEFT JOIN dim_customer AS c
 ON 
 a.customer_code = c.customer_code
 WHERE a.fiscal_year = 2021
 GROUP BY c.channel
)

SELECT channel_,
       CONCAT('$',gross_sales_million) AS gross_sales_million,
	CONCAT(ROUND(gross_sales_million/ SUM(gross_sales_million) OVER()*100,2),'%') AS percentage
FROM gross_sales
ORDER BY percentage DESC;

/* Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 
The final output contains these fields: division, product_code
*/

WITH top_sold_per_division AS (
    SELECT 
        b.division,
        b.product_code,
        b.product,
        SUM(a.sold_quantity) AS total_sold_quantity,
        ROW_NUMBER() OVER(PARTITION BY b.division ORDER BY SUM(a.sold_quantity) DESC) AS rank_order
    FROM 
        fact_sales_monthly a
    INNER JOIN 
        dim_product b ON a.product_code = b.product_code
    WHERE 
        a.fiscal_year = 2021
    GROUP BY  
        b.division, b.product_code, b.product
)
SELECT 
    division,
    product_code,
    product,
    total_sold_quantity
FROM 
    top_sold_per_division
WHERE 
    rank_order <= 3;


