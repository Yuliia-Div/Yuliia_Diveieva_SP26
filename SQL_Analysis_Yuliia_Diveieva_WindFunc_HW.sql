--Task 1
/*Create a query to produce a sales report highlighting the top customers with the highest sales across different sales 
channels. This report should list the top 5 customers for each channel. Additionally, calculate a key performance 
indicator (KPI) called 'sales_percentage,' which represents the percentage of a customer's sales relative to the total 
sales within their respective channel.

Please format the columns as follows:
Display the total sales amount with two decimal places
Display the sales percentage with four decimal places and include the percent sign (%) at the end
Display the result for each channel in descending order of sales
*/

WITH t_sales AS (
SELECT DISTINCT s.cust_id, ch.channel_desc,
SUM(amount_sold) OVER (PARTITION BY s.cust_id, ch.channel_desc) AS cust_amount,
ROUND(SUM(amount_sold) OVER (PARTITION BY ch.channel_desc),2) AS chanel_sales
FROM sh.sales s
JOIN sh.channels ch using(channel_id)
),
ranked_cust as (
SELECT *,
RANK() OVER (PARTITION BY channel_desc ORDER BY cust_amount desc) AS rk
FROM t_sales
)
SELECT r.channel_desc, c.cust_first_name, c.cust_last_name, r.cust_amount, r.chanel_sales , CAST(r.cust_amount * 100/ r.chanel_sales AS Decimal(8,4))||' %' AS sales_percentage
FROM ranked_cust r
JOIN customers c using(cust_id)
WHERE r.rk <= 5
ORDER BY r.chanel_sales DESC, r.cust_amount DESC;

/*CTE 't_sales' employs SUM() OVER window functions to calculate customer-level and channel-level totals
CTE 'ranked_cust'applies the RANK() function with PARTITION BY channel_desc to isolate rankings for each unique sales medium*/

--Task 2
/*Create a query to retrieve data for a report that displays the total sales for all products in the Photo category in 
the Asian region for the year 2000. Calculate the overall report total and name it 'YEAR_SUM'

Display the sales amount with two decimal places
Display the result in descending order of 'YEAR_SUM'
For this report, consider exploring the use of the crosstab function.
*/
CREATE EXTENSION IF NOT EXISTS tablefunc;
SELECT prod_name, 
    ROUND(YEAR_SUM, 2) AS YEAR_SUM, 
    ROUND("2000-01", 2) AS "2000-01", 
    ROUND("2000-02", 2) AS "2000-02", 
    ROUND("2000-03", 2) AS "2000-03", 
    ROUND("2000-04", 2) AS "2000-04"
FROM CROSSTAB('
	SELECT p.prod_name, 
		SUM(SUM(s.amount_sold)) OVER (PARTITION BY p.prod_name) as year_sum,
        t.calendar_quarter_desc,
		SUM(s.amount_sold) as quarter_amount
	FROM sh.sales s
	JOIN (SELECT time_id, calendar_quarter_desc, calendar_year FROM sh.times WHERE calendar_year = 2000) t ON s.time_id = t.time_id
	JOIN (SELECT prod_id, prod_name FROM sh.products WHERE LOWER(prod_category) = ''photo'') p ON s.prod_id = p.prod_id
	WHERE s.cust_id IN (SELECT c.cust_id FROM sh.customers c WHERE c.country_id IN (
							SELECT country_id FROM sh.countries WHERE LOWER(country_region) = ''asia''))
	GROUP BY p.prod_name, t.calendar_quarter_desc',
    'SELECT DISTINCT calendar_quarter_desc FROM sh.times WHERE calendar_year = 2000 ORDER BY 1')
AS pivot (prod_name text, YEAR_SUM NUMERIC, "2000-01" NUMERIC, "2000-02" NUMERIC, "2000-03" NUMERIC, "2000-04" NUMERIC)
ORDER BY YEAR_SUM DESC;
/*CROSSTAB is used to transform row-level quarterly data into a pivot table format
Double SUM: The inner SUM(s.amount_sold) calculates totals per quarter, while the outer SUM(...) OVER (PARTITION BY...) window function calculates the total 
annual sales across all quarters for each product row
The second argument of CROSSTAB ensures that all four quarters are represented as columns, even if sales data for a specific quarter is missing for certain products
*/


--Task 3
/*Create a query to generate a sales report for customers ranked in the top 300 based on total sales in the years 1998, 
1999, and 2001. The report should be categorized based on sales channels, and separate calculations should be performed 
for each channel.
Retrieve customers who ranked among the top 300 in sales for the years 1998, 1999, and 2001
Categorize the customers based on their sales channels
Perform separate calculations for each sales channel
Include in the report only purchases made on the channel specified
Format the column so that total sales are displayed with two decimal places*/
WITH sum_chan AS (
	SELECT cust_id, channel_id, SUM(amount_sold) AS total_amount
	FROM sh.sales
	WHERE EXTRACT(YEAR FROM time_id) IN (1998, 1999, 2001) 
	GROUP BY channel_id, cust_id),
ranked_cust AS (
SELECT channel_id, cust_id, total_amount,
	RANK() OVER (PARTITION BY channel_id ORDER BY total_amount DESC) AS rk
FROM sum_chan)
SELECT c.channel_desc, r.cust_id, c2.cust_last_name, c2.cust_first_name, ROUND(r.total_amount, 2) 
FROM ranked_cust r
JOIN sh.channels c ON r.channel_id = c.channel_id 
JOIN sh.customers c2 ON r.cust_id = c2.cust_id 
WHERE rk<=300
ORDER BY channel_desc, rk ASC;
/*THe furst CTE aggregates sales data from into customer/channel totals
The second one applies the RANK() window function with PARTITION BY to reset rankings for every channel
*/

--Task 4
/*Create a query to generate a sales report for January 2000, February 2000, and March 2000 specifically for the Europe 
and Americas regions.
Display the result by months and by product category in alphabetical order.*/

SELECT DISTINCT t.calendar_month_desc, p.prod_category, 
	SUM(s.amount_sold) FILTER (WHERE c.country_region = 'Europe') OVER (PARTITION BY t.calendar_month_desc, p.prod_category) AS europe_sales,
	SUM(s.amount_sold) FILTER (WHERE c.country_region = 'Americas') OVER (PARTITION BY t.calendar_month_desc, p.prod_category) AS americas_sales
FROM sh.sales s
JOIN sh.products p ON s.prod_id = p.prod_id
JOIN sh.times t ON s.time_id = t.time_id
JOIN (SELECT cu.cust_id, co.country_region
		FROM sh.customers cu
		JOIN sh.countries co ON cu.country_id = co.country_id
		WHERE co.country_region IN ('Europe', 'Americas')) c
	ON s.cust_id = c.cust_id
WHERE t.calendar_month_desc IN ('2000-01', '2000-02', '2000-03')
ORDER BY t.calendar_month_desc, p.prod_category
/* Filter in the window functions is used to pivot regional totals within a single result set
DISTINCT is used to handle row granularity when applying OVER() without a standard GROUP BY clause*/