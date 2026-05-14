--Task 1
/*Create a query for analyzing the annual sales data for the years 1999 to 2001, focusing on 
different sales channels and regions: 'Americas,' 'Asia,' and 'Europe.'
   The resulting report should contain the following columns:
   AMOUNT_SOLD: This column should show the total sales amount for each sales channel
   % BY CHANNELS: In this column, we should display the percentage of total sales for each 
channel (e.g. 100% - total sales for Americas in 1999, 63.64% - percentage of sales for the 
channel “Direct Sales”)
   % PREVIOUS PERIOD: This column should display the same percentage values as in the '% BY 
CHANNELS' column but for the previous year
   % DIFF: This column should show the difference between the '% BY CHANNELS' and '% PREVIOUS 
PERIOD' columns, indicating the change in sales percentage from the previous year.
   The final result should be sorted in ascending order based on three criteria: first by 
'country_region,' then by 'calendar_year,' and finally by 'channel_desc'
*/

WITH chan_percents AS (SELECT cou.country_region, EXTRACT('year' FROM s.time_id) AS "year", ch.channel_desc,
	SUM(SUM(s.amount_sold)) OVER (PARTITION BY channel_desc)  AS amount_sold,
	ROUND(SUM(SUM(s.amount_sold)) OVER (PARTITION BY cou.country_region, channel_desc, EXTRACT('year' FROM s.time_id)) * 100 / SUM(SUM(s.amount_sold)) OVER (PARTITION BY cou.country_region, EXTRACT('year' FROM s.time_id)), 2) AS "%_by_channels"
FROM sh.sales s 
JOIN sh.customers cus using(cust_id)
JOIN sh.countries cou using(country_id)
JOIN sh.channels ch using(channel_id)
WHERE s.time_id BETWEEN '1998-01-01'::DATE AND '2001-12-31'::DATE
	AND LOWER(cou.country_region) IN ('americas', 'asia', 'europe')
GROUP BY cou.country_region, EXTRACT('year' FROM s.time_id), ch.channel_desc
),
prepared_q AS (
	SELECT country_region, "year", channel_desc, amount_sold,  "%_by_channels" || ' %' AS "%_by_channels",
		LAG("%_by_channels") OVER (PARTITION BY country_region, channel_desc ORDER BY "year") || ' %' AS "%_previous_period",
	    ("%_by_channels" - LAG("%_by_channels") OVER (PARTITION BY country_region, channel_desc ORDER BY "year")) || ' %' AS "%_diff"
	FROM chan_percents
	ORDER BY country_region, "year", channel_desc
)
SELECT *
FROM prepared_q
WHERE "year" = 2001 
	OR "year" = 2000
	OR "year" = 1999;
--I had to add the prepared_q CTE and filter years separately, as in another way there appeared NULL values in the 
--"%_previous_period" and "%_diff" columns

--Task 2
/*You need to create a query that meets the following requirements:
Generate a sales report for the 49th, 50th, and 51st weeks of 1999.
Include a column named CUM_SUM to display the amounts accumulated during each week.
Include a column named CENTERED_3_DAY_AVG to show the average sales for the previous, current, and following days using 
a centered moving average.
For Monday, calculate the average sales based on the weekend sales (Saturday and Sunday) as well as Monday and Tuesday.
For Friday, calculate the average sales on Thursday, Friday, and the weekend.
*/
SELECT t.calendar_week_number, t.time_id::DATE, t.day_name,
	sum(s.amount_sold),
	sum(sum(s.amount_sold)) OVER (PARTITION BY t.calendar_week_number ORDER BY t.time_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cum_sum,
	CASE 
		WHEN LOWER(t.day_name) = 'monday'
			THEN ROUND(AVG(sum(s.amount_sold)) OVER (ORDER BY t.time_id::DATE ROWS BETWEEN 2 PRECEDING AND 1 FOLLOWING), 2)
		WHEN LOWER(t.day_name) = 'friday'
			THEN ROUND(AVG(sum(s.amount_sold)) OVER (ORDER BY t.time_id::DATE ROWS BETWEEN 1 PRECEDING AND 2 FOLLOWING), 2)
		ELSE ROUND(AVG(sum(s.amount_sold)) OVER (ORDER BY t.time_id::DATE ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING), 2)
	END AS centered_3_day_avg
FROM sh.sales s 
JOIN sh.times t USING(time_id)
WHERE t.calendar_week_number > 48 AND t.calendar_week_number < 52
	AND calendar_year = 1999
GROUP BY t.calendar_week_number, t.time_id::date
ORDER BY t.calendar_week_number, t.time_id::date;

--Task 3
/*Please provide 3 instances of utilizing window functions that include a frame clause, using RANGE, ROWS, and GROUPS 
modes. 
Additionally, explain the reason for choosing a specific frame type for each example. 
This can be presented as a single query or as three distinct queries.
*/
WITH chosen_sales AS (
	SELECT p.prod_name, p.prod_subcategory, t.time_id::DATE AS sale_date, s.quantity_sold, s.amount_sold, t.calendar_month_desc AS sale_month
    FROM sh.sales s
    JOIN sh.products p USING(prod_id)
    JOIN sh.times t USING(time_id)
    WHERE t.calendar_year = 1999
)
SELECT prod_subcategory, prod_name, sale_date, SUM(amount_sold),
    ROUND(AVG(SUM(amount_sold)) OVER (PARTITION BY prod_subcategory ORDER BY sale_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS rows_weekly_avg,
    ROUND(AVG(SUM(quantity_sold)) OVER (PARTITION BY prod_subcategory ORDER BY SUM(amount_sold) RANGE BETWEEN 100 PRECEDING AND 100 FOLLOWING)) AS range_price_vicinity_avg,
    ROUND(AVG(SUM(amount_sold)) OVER (PARTITION BY prod_subcategory ORDER BY sale_month GROUPS BETWEEN 1 PRECEDING AND CURRENT ROW), 2) AS groups_monthly_block_avg
FROM chosen_sales
GROUP BY prod_subcategory, prod_name, sale_date, sale_month
ORDER BY prod_subcategory, sale_date;

/*I used ROWS BETWEEN 6 PRECEDING AND CURRENT ROW because this mode focuses on the physical number of records in the 
result set. It is the most reliable way to create a smooth moving average that consistently takes the last 7 observations 
(current + 6 previous), regardless of the actual values or dates. This is essential for technical smoothing where the 
goal is to stabilize the data trend.
RANGE BETWEEN 100 PRECEDING AND 250 FOLLOWING is used to aggregate data for all products whose sales amount falls within
a +-100 range of the current product's amount. It is the best choice for clustering products that perform similarly, 
helping to identify demand patterns across price segments.
To treat all rows sharing the same value (the same sale_month) as a single logical unit I have chosen GROUPS. Since a 
single month contains many individual sales records, GROUPS ensures that we include the entire current month block and 
the entire previous month block as whole units. Unlike ROWS, it never "splits" a group, making it the perfect tool for 
comparing discrete time buckets or categories.*/