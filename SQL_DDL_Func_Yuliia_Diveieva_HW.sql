--------------------------------------------------------------------------------------------------------------------------------------
--Task 1. Create a view
/*Create a view called 'sales_revenue_by_category_qtr' that shows the film category and total sales revenue 
for the current quarter and year. The view should only display categories with at least one sale in the 
current quarter. */

CREATE OR REPLACE VIEW public.sales_revenue_by_category_qtr AS 
	WITH category_revenue AS(
		SELECT c.name, p.amount, p.payment_date 
		FROM public.payment p
		JOIN public.rental r ON p.rental_id = r.rental_id
		JOIN public.inventory i ON r.inventory_id = i.inventory_id
		JOIN public.film f ON i.film_id = f.film_id
		JOIN public.film_category fc ON f.film_id = fc.film_id 
		JOIN public.category c ON fc.category_id = c.category_id
		)
	SELECT cr.name,
		SUM(CASE 
	        WHEN EXTRACT(QUARTER FROM payment_date) = EXTRACT(QUARTER FROM CURRENT_DATE)  
	        	AND EXTRACT(YEAR FROM payment_date) = EXTRACT(YEAR FROM CURRENT_DATE)
	        THEN amount END) AS current_qtr_revenue,
	    SUM(CASE 
	        WHEN EXTRACT(YEAR FROM payment_date) = EXTRACT(YEAR FROM CURRENT_DATE) 
	        THEN amount 
	    	END) AS current_year_revenue
	FROM category_revenue cr
	GROUP BY cr.name
	HAVING SUM(CASE WHEN EXTRACT(YEAR FROM payment_date) = EXTRACT(YEAR FROM CURRENT_DATE) THEN amount END) IS NOT NULL;

--TEST QUERY
WITH test_category_revenue AS (
    SELECT 'Action' as name, 10.00 as amount, CAST('2026-04-07' AS DATE) as payment_date --current date (correct)
    UNION ALL
    SELECT 'Action', 20.00, CAST('2026-03-31' AS DATE) -- last day of q1 2026 (should only be counted in the year column)
    UNION ALL
    SELECT 'Sci-Fi', 50.00, CAST('2027-01-01' AS DATE) -- future date
    UNION ALL
    SELECT 'Sci-Fi', 99.00, NULL -- Null date
)
SELECT tcr.name,
		SUM(CASE 
	        WHEN EXTRACT(QUARTER FROM payment_date) = EXTRACT(QUARTER FROM CURRENT_DATE)  
	        	AND EXTRACT(YEAR FROM payment_date) = EXTRACT(YEAR FROM CURRENT_DATE)
	        THEN amount END) AS current_qtr_revenue,
	    SUM(CASE 
	        WHEN EXTRACT(YEAR FROM payment_date) = EXTRACT(YEAR FROM CURRENT_DATE) 
	        THEN amount 
	    	END) AS current_year_revenue
	FROM test_category_revenue tcr
	GROUP BY tcr.name
	HAVING SUM(CASE WHEN EXTRACT(YEAR FROM payment_date) = EXTRACT(YEAR FROM CURRENT_DATE) THEN amount END) IS NOT NULL;

/*
The query connects payments with categories, sums cases results and groups them by category name. 
The current year is calculated by extracting the year from the payment date and the current date. The current quarter is calculated by adding 
the quarter extraction to the year extraction (as without a year check it'll show results for the quarters from all years)
By using an "having current_year_revenue NOT NULL"  we ensure that only categories with sales will appear.
As the database coontain the date from the first and second quarters of 2017, I replaced "current date" in the query with '2017-01-25'::DATE.
Then I compared the result with the query:
SELECT EXTRACT(YEAR FROM payment_date) AS year_num, EXTRACT(QUARTER FROM payment_date) AS quarter_num, sum(amount)
FROM payment
GROUP BY year_num, quarter_num
*/

--------------------------------------------------------------------------------------------------------------------------------------
--Task 2. Create a query language functions
/*Create a query language function called 'get_sales_revenue_by_category_qtr' that accepts one parameter 
representing the current quarter and year and returns the same result as the 'sales_revenue_by_category_qtr' 
view.*/
CREATE OR REPLACE FUNCTION public.get_sales_revenue_by_category_qtr (qua_year VARCHAR)
RETURNS TABLE (category_name TEXT, quarter_num NUMERIC, year_num NUMERIC)
LANGUAGE plpgsql
AS $$
BEGIN
	RETURN QUERY
	WITH category_revenue AS(
		SELECT c.name, p.amount, p.payment_date 
		FROM public.payment p
		JOIN public.rental r ON p.rental_id = r.rental_id
		JOIN public.inventory i ON r.inventory_id = i.inventory_id
		JOIN public.film f ON i.film_id = f.film_id
		JOIN public.film_category fc ON f.film_id = fc.film_id 
		JOIN public.category c ON fc.category_id = c.category_id
		)
	SELECT cr.name,
		SUM(CASE 
	        WHEN EXTRACT(QUARTER FROM payment_date) = LEFT(qua_year, 1)::INT
	        	AND EXTRACT(YEAR FROM payment_date) = RIGHT(qua_year, 4)::INT
	        THEN amount END) AS current_qtr_revenue,
	    SUM(CASE 
	        WHEN EXTRACT(YEAR FROM payment_date) = RIGHT(qua_year, 4)::INT
	        THEN amount 
	    	END) AS current_year_revenue
	FROM category_revenue cr
	GROUP BY cr.name
	HAVING SUM(CASE WHEN EXTRACT(YEAR FROM payment_date) = RIGHT(qua_year, 4)::INT THEN amount END) IS NOT NULL;
END;
$$

--Test queries
SELECT *
FROM public.get_sales_revenue_by_category_qtr('2-2017'); --correct input

SELECT *
FROM public.get_sales_revenue_by_category_qtr('5-2017'); --uncorrect quarter

SELECT *
FROM public.get_sales_revenue_by_category_qtr(2-2017); --uncorrect format

SELECT *
FROM public.get_sales_revenue_by_category_qtr('1-2018'); --no data

/*The parameter here is needed for passing information about the chosen period to the function.
If the invalid quarter is passed then the function gives null values in the quarter column.
If no data exists for the chosen period then the function will return an empty table*/

-----------------------------------------------------------------------------------------------------------------------------------
--Task 3. Create procedure language functions
/*Create a function that takes a country as an input parameter and returns the most popular film in that 
specific country.*/

CREATE OR REPLACE FUNCTION public.most_popular_films_by_countries(countries VARCHAR[])
RETURNS TABLE (
    country_name text, 
    film_name text, 
    rating public."mpaa_rating", 
    f_language bpchar(20), 
    f_length int2, 
    release_year public."year"
)
AS $$
BEGIN
    RETURN QUERY
    WITH film_popularity AS (
        SELECT 
            co.country,
            f.title,
            f.rating,
            l.name AS language_name,
            f.length,
            f.release_year,
            COUNT(r.rental_id) as rental_count,
            DENSE_RANK() OVER (PARTITION BY co.country ORDER BY COUNT(r.rental_id) DESC) as rank
        FROM public.film f
        JOIN public.inventory i ON f.film_id = i.film_id
        JOIN public.rental r ON i.inventory_id = r.inventory_id
        JOIN public.store s ON i.store_id = s.store_id
        JOIN public.address a ON s.address_id = a.address_id
        JOIN public.city ci ON a.city_id = ci.city_id
        JOIN public.country co ON ci.country_id = co.country_id
        JOIN public.language l ON f.language_id = l.language_id
        WHERE LOWER(co.country) = ANY (SELECT LOWER(u) FROM unnest(countries) AS u)
        GROUP BY co.country, f.film_id, f.title, f.rating, l.name, f.length, f.release_year
    )
    SELECT fp.country, fp.title, fp.rating, fp.language_name, fp.length, fp.release_year
    FROM film_popularity fp
    WHERE fp.rank = 1;
END;
$$ LANGUAGE plpgsql;

--Test queries
SELECT *
FROM public.most_popular_films_by_countries(ARRAY['Canada', 'australia']);--correct

SELECT *
FROM public.most_popular_films_by_countries(ARRAY['Japan']);--incorrect country

/*The most popular film is defined by the number of rentals in the store.
The DB has only 2 stores located in Canada and Australia, so entering any other country will show no results, as we see in the second test query
To allow showing all films with the highest count of rents, I added DENSE_RANK() that gives the same rank to such films. 
The current query returns a table with only 1 film per country, so to test the function I ran the "inner part of with" and added "order by rank". 
The selected films are the only ones with such number of rentals.*/

--Task 4. Create procedure language functions
/*Create a function that generates a list of movies available in stock based on a partial title match (e.g., movies containing the word 'love' in their title). */

CREATE OR REPLACE FUNCTION public.films_in_stock_by_title(word VARCHAR)
RETURNS TABLE (
    Row_num bigint, 
    film_name text,
    f_language bpchar(20), 
    customer_name text, 
    rental_date timestamp with time zone
)
AS $$
DECLARE
    found_any int := 0;
BEGIN
    RETURN QUERY
    WITH latest_rentals AS (
		SELECT DISTINCT ON (f.title)
		    f.title, 
		    l.name as f_language,
		    c.first_name || ' ' || c.last_name AS full_name,
		    MAX(r.return_date) AS return_date
		FROM film f 
		JOIN "language" l ON f.language_id = l.language_id
		JOIN inventory i ON f.film_id = i.film_id
		JOIN rental r ON i.inventory_id = r.inventory_id
		JOIN customer c ON r.customer_id = c.customer_id 
		WHERE LOWER(f.title) LIKE ('%' || LOWER(word) || '%')
		GROUP BY f.film_id, f.title, l.name, full_name
		HAVING MAX(r.return_date) < CURRENT_DATE
		ORDER BY f.title
	)
	SELECT 
        ROW_NUMBER() OVER (ORDER BY lr.return_date DESC)::bigint,
        lr.title, 
        lr.f_language,
        lr.full_name,
        lr.return_date
    FROM latest_rentals lr
    ORDER BY lr.return_date DESC;

	GET DIAGNOSTICS found_any = ROW_COUNT;

	IF found_any = 0 THEN
        RETURN QUERY SELECT 
            NULL::bigint, 
            'Movie with specified title was not found'::text, 
            NULL::bpchar(20), 
            NULL::text, 
            NULL::timestamp with time zone;
    END IF;
END;
$$ LANGUAGE plpgsql;

--Test queries
SELECT *
FROM public.films_in_stock_by_title('love');--correct

SELECT *
FROM public.films_in_stock_by_title('something else');--abcent data

/*"LIKE ('%' || LOWER(word) || '%')" allows finding films. Such structure is used here to ensure case 
insensitivity as well as "lower" function with film titles.
If there are multiple matches the function will return a table with distinct film titles and the last customer 
who rented it.
If there are two matches then it`ll return 1 row where instead of film_name a message will be returned 
To reduce unnecessary data processing "WITH" and "DISTINCT ON" are used here. 
"WITH" helps to add row numbers only to the filtered data. "DISTINCT ON" helps with easier sort*/

-- Task 5. Create procedure language functions
/*Create a procedure language function called 'new_movie' that takes a movie title as a parameter and inserts
a new movie with the given title in the film table. The function should generate a new unique film ID, set 
the rental rate to 4.99, the rental duration to three days, the replacement cost to 19.99. The release year 
and language are optional and by default should be current year and Klingon respectively. */

CREATE OR REPLACE FUNCTION public.new_movie(
    x_title VARCHAR, 
    x_release_year public."year" DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::public."year", 
    x_language_name VARCHAR DEFAULT 'Klingon'
)
RETURNS public.film AS $$
DECLARE
    d_language_id int;
    d_exists int;
	d_result public.film;
BEGIN
    SELECT COUNT(*) INTO d_exists 
    FROM public.film 
    WHERE LOWER(title) = LOWER(x_title);
    IF d_exists > 0 THEN
        RAISE EXCEPTION 'A movie with the name "%" already exists in the database!', x_title;
    END IF;

    SELECT language_id INTO d_language_id 
    FROM public.language 
    WHERE LOWER(name) = LOWER(x_language_name);

    IF d_language_id IS NULL THEN
        INSERT INTO public.language (name) 
        VALUES (x_language_name) 
        RETURNING language_id INTO d_language_id;
        RAISE NOTICE 'Language "%" was not found, it was automatically added with ID %', x_language_name, d_language_id;
    END IF;

    INSERT INTO public.film (
        title, 
        release_year, 
        language_id, 
        rental_duration, 
        rental_rate, 
        replacement_cost
    ) 
    VALUES (UPPER(x_title), x_release_year, d_language_id, 3, 4.99, 19.99)
	RETURNING * INTO d_result;

    RETURN d_result;
END;
$$ LANGUAGE plpgsql;

SELECT public.new_movie('Interstellar Journey');--using default

SELECT public.new_movie('The Matrix Resurrections', 2021, 'English');--inserting a year and a language

SELECT public.new_movie('The Matrix Resurrections', 2021, 'English');--inserting a duplicate

/*IDs are established by adding rows in tables where ID column establishes it automatically and then returns it into a variable.
The function can't add a second film with the same title because the query checks whether it already exists in the table before inserting.
So if the film is already there the exception will be raised.
The function not only checks if the language exists, it also adds one to the table if it doesn't.
In "plpgsql" functions are complete inside transactions, so if it fails it'll rollback automatically.
To ensure that consistency is preserved, we don't use IDs directly. Instead we look for the name in the tables*/

/*If input parameters are incorrect, then a function will return the error "invalid input syntax for type" and won't launch.
If an input value is too long, then the "value too long for type character varying" error will appear.
If required data is missing, usually queries will return NULL results as a default, but these queries return message, errors and empty tables as a result
*/
 
