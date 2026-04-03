/*Part 1.1-Join 
Task: The marketing team needs a list of animation movies between 2017 and 2019
to promote family-friendly content in an upcoming season in stores. Show all animation movies 
released during this period with rate more than 1, sorted alphabetically
*/
SELECT f.title
FROM public.film f
INNER JOIN  public.film_category fc ON f.film_id = fc.film_id
INNER JOIN public.category c ON fc.category_id = c.category_id
WHERE LOWER(c.name) = 'animation'
AND f.release_year BETWEEN 2017 AND 2019
AND f.rating IN ('G', 'PG', 'PG-13')
AND f.rental_rate > 1
ORDER BY f.title;

/*Part 1.1 Subquery 
Task: The marketing team needs a list of animation movies between 2017 and 2019
to promote family-friendly content in an upcoming season in stores. Show all animation movies 
released during this period with rate more than 1, sorted alphabetically
*/
SELECT f.title
FROM public.film f 
WHERE f.film_id IN (
					SELECT fc.film_id 
					FROM public.film_category fc
					WHERE fc.category_id = 
											(SELECT c.category_id
											FROM public.category c
											WHERE LOWER(c.name) = 'animation')
					)
	AND f.release_year BETWEEN 2017 AND 2019
	AND f.rating IN ('G', 'PG', 'PG-13')
	AND f.rental_rate > 1
ORDER BY f.title;

/*Part 1.1 CTE
Task: The marketing team needs a list of animation movies between 2017 and 2019
to promote family-friendly content in an upcoming season in stores. Show all animation movies 
released during this period with rate more than 1, sorted alphabetically*/
WITH animation_films AS 
(SELECT fc.film_id 
FROM public.film_category fc
WHERE fc.category_id = 
						(SELECT c.category_id
						FROM public.category c
						WHERE LOWER(c.name) = 'animation'))
SELECT f.title
FROM public.film f 
INNER JOIN public.film_category fc ON f.film_id = fc.film_id 
WHERE f.film_id IN (
					SELECT af.film_id
					FROM animation_films af
					)
	AND f.release_year BETWEEN 2017 AND 2019
	AND f.rating IN ('G', 'PG', 'PG-13')
	AND f.rental_rate > 1
ORDER BY f.title;
/*Summary:
Task's logic: To filter family-friendly films, the ratings 'G', 'PG', 'PG-13' were chosen as was mentioned in the chat 
by Hanna Gorskoviene
Join type: I used INNER JOIN here because all films that we`re searching for should have category and there 
is no need in categories without films
Pros and cons: Subquery solution has the highest cost(129). It doesn`t bring unnecessary info like the join solution, but 
it`s definitely not the best solution because of the metrics.
	CTE solution has middle cost(81). Sctucture is prety complex and definitely harder to understand than join query. 
Actually, even the subquery logic looks easier.
	Join solution has the lowest cost(62). It has the easiest structure and is the most readable.
It was mentioned in the lesson that it is better to use CTE in cases where info from other tables is not needed in the 
result but the join has the best performance and by me an "animation movies" CTE is not often needed and is easy to 
recreate and it`s the structure is not too complex to use it here. So in this case I would choose join slution as the best*/


/*Part 1.2-Join 
Task: The finance department requires a report on store performance to assess profitability and plan resource allocation 
for stores after March 2017. Calculate the revenue earned by each rental store after March 2017 (since April) (include 
columns: address and address2 – as one column, revenue)
*/
SELECT a.address || ' ' ||  COALESCE(a.address2, '') AS store_address, SUM(p.amount) AS revenue
FROM public.address a
JOIN public.store s ON a.address_id = s.address_id 
JOIN public.staff sf ON s.store_id = sf.store_id
JOIN public.payment p ON sf.staff_id = p.staff_id
WHERE p.payment_date >= '2017-04-01'
GROUP BY store_address;

/*Part 1.2-Subquery 
Task: The finance department requires a report on store performance to assess profitability and plan resource allocation 
for stores after March 2017. Calculate the revenue earned by each rental store after March 2017 (since April) (include 
columns: address and address2 – as one column, revenue)
*/
SELECT a.address || ' ' || COALESCE(a.address2, '') AS store_address,
    (
	    SELECT SUM(p.amount)
	    FROM public.payment p
	    WHERE p.payment_date >= '2017-04-01'
		    AND p.staff_id IN (SELECT st.staff_id 
		          				FROM public.staff st 
		          				WHERE st.store_id = (SELECT s.store_id
		              								FROM public.store s 
		             								WHERE s.address_id = a.address_id)
		             			)
	) AS revenue
FROM public.address a
WHERE a.address_id IN (SELECT s.address_id FROM public.store s);

/*Part 1.2-CTE 
Task: The finance department requires a report on store performance to assess profitability and plan resource allocation 
for stores after March 2017. Calculate the revenue earned by each rental store after March 2017 (since April) (include 
columns: address and address2 – as one column, revenue)
*/
WITH revenue_summary AS (
    SELECT 
        s.address_id,
        (
        SELECT SUM(p.amount)
        FROM public.payment p
        WHERE p.payment_date >= '2017-04-01'
        AND p.staff_id IN (
	        SELECT st.staff_id 
	        FROM public.staff st 
	        WHERE st.store_id = s.store_id
			)
        ) AS total_revenue
    FROM public.store s
)
SELECT a.address || ' ' || COALESCE(a.address2, '') AS store_address, rs.total_revenue AS revenue
FROM public.address a
JOIN revenue_summary rs ON a.address_id = rs.address_id;
/*Summary:
Task's logic: To meet the requirement for "after March 2017," the filter >= 2017-04-01 was applied
Join type: I used INNER JOIN because it directly connects all the way from the stores to revenue
Pros and cons: Join solution has the highest cost(1120). It`s really inefficient as it forces system to lookup
for every single row in the address table
	CTE solution has low cost(1.3). It’s the fastest for the computer and the easiest to read. It just maps out the
connections between tables directly without overcomplicating and allows to reuse the revenue cte(it definitely will 
be reused by business) with siple changes of date.
	Subquery solution has good cost(1.3). It looks tidier than every other query and works efficiently but CTE is more 
useful
*/


/*Part 1.3-Join 
Task: The marketing department in our stores aims to identify the most successful actors since 2015 to boost customer 
interest in their films. Show top-5 actors by number of movies (released since 2015) they took part in (columns: 
first_name, last_name, number_of_movies, sorted by number_of_movies in descending order)
*/
SELECT a.first_name, a.last_name, count(fa.film_id) AS number_of_movies
FROM public.actor a
JOIN public.film_actor fa ON a.actor_id = fa.actor_id
JOIN public.film f ON fa.film_id = f.film_id 
WHERE f.release_year >= 2015
GROUP BY a.first_name, a.last_name
ORDER BY number_of_movies DESC
FETCH FIRST 5 ROWS WITH TIES;

-- That's the only way for the query to stay only "join" focused. The result may not be ordered the same as in the next 
-- queries because WITH TIES doesn't allow adding an actor name as a second filter

/*Part 1.3-Subquery 
Task: The marketing department in our stores aims to identify the most successful actors since 2015 to boost customer 
interest in their films. Show top-5 actors by number of movies (released since 2015) they took part in (columns: 
first_name, last_name, number_of_movies, sorted by number_of_movies in descending order)
*/
SELECT a.first_name, a.last_name, COUNT(fa.film_id) AS number_of_movies
FROM public.actor a
JOIN public.film_actor fa ON a.actor_id = fa.actor_id
WHERE fa.film_id IN (
    SELECT f.film_id 
    FROM public.film f 
    WHERE f.release_year >= 2015
)
GROUP BY a.first_name, a.last_name
HAVING COUNT(fa.film_id) >= COALESCE((
		SELECT count(fa2.film_id)
	    FROM public.film_actor fa2
	    JOIN public.film f2 ON fa2.film_id = f2.film_id
	    WHERE f2.release_year >= 2015
	    GROUP BY fa2.actor_id
	    ORDER BY 1 DESC
	    LIMIT 1 OFFSET 4 
	), 0)
ORDER BY number_of_movies DESC, a.first_name, a.last_name;


/*Part 1.3-CTE 
Task: The marketing department in our stores aims to identify the most successful actors since 2015 to boost customer 
interest in their films. Show top-5 actors by number of movies (released since 2015) they took part in (columns: 
first_name, last_name, number_of_movies, sorted by number_of_movies in descending order)
*/
WITH actor_movie_counts_since_2015 AS (
    SELECT fa.actor_id, COUNT(fa.film_id) AS number_of_movies
    FROM public.film_actor fa
    JOIN public.film f ON fa.film_id = f.film_id
    WHERE f.release_year >= 2015
    GROUP BY fa.actor_id
)
SELECT 
    a.first_name, 
    a.last_name, 
    amc.number_of_movies
FROM public.actor a
JOIN actor_movie_counts_since_2015 amc ON a.actor_id = amc.actor_id
WHERE amc.number_of_movies >= COALESCE((
		SELECT count(fa2.film_id)
	    FROM public.film_actor fa2
	    JOIN public.film f2 ON fa2.film_id = f2.film_id
	    WHERE f2.release_year >= 2015
	    GROUP BY fa2.actor_id
	    ORDER BY 1 DESC
	    LIMIT 1 OFFSET 4 
	), 0)
ORDER BY amc.number_of_movies DESC, a.first_name, a.last_name;


/*Summary:
Task's logic: There is a restriction for release_year(since 2015) in the requirement. So in queries the filter 
>= 2015 was applied(according to Evgeny Bochlarev comment). Now I added WITH TIES in the first query (that ensures that
all actors with the same number of films will be included but it doesn't order the result the same way as the other 
queries). To others I added a filter for a result that relies on the number of films of the fifth actor in the list.
Join type: I used INNER JOIN because it directly connects all the way from actors to films
Pros and cons: Cost is almost the same 221 for CTE and 222 for join and subquery, so it`s not a factor. Redaibily for 
join and subquery is the same, only logic may be a bit easier for join. CTE is clearly more complex but it allows us 
to reuse it. So for current task Join is a bit better but in more complex queries block from CTE can be used to compre 
actors or filter according to marketing or generally business purposes
*/


/*Part 1.4-Join 
Task: The marketing team needs to track the production trends of Drama, Travel, and Documentary films to inform 
genre-specific marketing strategies. Show number of Drama, Travel, Documentary per year (include columns: release_year, 
number_of_drama_movies, number_of_travel_movies, number_of_documentary_movies), sorted by release year in descending order. 
Dealing with NULL values is encouraged)
*/
SELECT f.release_year, 
	COUNT(CASE WHEN LOWER(c.name)  = 'drama' THEN 1 ELSE NULL END) AS number_of_drama_movies,
	COUNT(CASE WHEN LOWER(c.name)  = 'travel' THEN 1 ELSE NULL END) AS number_of_travel_movies,
	COUNT(CASE WHEN LOWER(c.name)  = 'documentary' THEN 1 ELSE NULL END) AS number_of_documentary_movies
FROM public.film f
JOIN public.film_category fc ON f.film_id = fc.film_id 
JOIN public.category c ON fc.category_id = c.category_id 
WHERE LOWER(c.name) IN ('drama', 'travel', 'documentary')
GROUP BY f.release_year 
ORDER BY f.release_year DESC;

/*Part 1.4-Subquery 
Task: The marketing team needs to track the production trends of Drama, Travel, and Documentary films to inform 
genre-specific marketing strategies. Show number of Drama, Travel, Documentary per year (include columns: release_year, 
number_of_drama_movies, number_of_travel_movies, number_of_documentary_movies), sorted by release year in descending order. 
Dealing with NULL values is encouraged)
*/
SELECT 
    f.release_year,
    (SELECT COUNT(*) 
     FROM public.film_category fc 
     JOIN public.category c ON fc.category_id = c.category_id 
     WHERE fc.film_id IN (SELECT film_id FROM film f2 WHERE f2.release_year = f.release_year)
     	AND LOWER(c.name) = 'drama') AS number_of_drama_movies,
    (SELECT COUNT(*) 
     FROM public.film_category fc 
     JOIN public.category c ON fc.category_id = c.category_id 
     WHERE fc.film_id IN (SELECT film_id FROM film f2 WHERE f2.release_year = f.release_year)
     	AND LOWER(c.name) = 'travel') AS number_of_travel_movies,
    (SELECT COUNT(*) 
     FROM public.film_category fc 
     JOIN public.category c ON fc.category_id = c.category_id 
     WHERE fc.film_id IN (SELECT film_id FROM film f2 WHERE f2.release_year = f.release_year)
     	AND LOWER(c.name) = 'documentary') AS number_of_documentary_movies
FROM public.film f
WHERE f.film_id IN (
	SELECT fc.film_id 
	FROM public.film_category fc
	JOIN public.category c ON fc.category_id = c.category_id
	WHERE LOWER(c.name) IN ('drama', 'travel', 'documentary')
	)
GROUP BY f.release_year
ORDER BY f.release_year DESC;

/*Part 1.4-CTE 
Task: The marketing team needs to track the production trends of Drama, Travel, and Documentary films to inform 
genre-specific marketing strategies. Show number of Drama, Travel, Documentary per year (include columns: release_year, 
number_of_drama_movies, number_of_travel_movies, number_of_documentary_movies), sorted by release year in descending order. 
Dealing with NULL values is encouraged)
*/
WITH genre_counter AS (
	SELECT f.release_year, c.name AS genre_name, COUNT(f.film_id) AS movie_count
	FROM public.film f
	JOIN public.film_category fc ON f.film_id = fc.film_id
	JOIN public.category c ON fc.category_id = c.category_id
	WHERE LOWER(c.name) IN ('drama', 'travel', 'documentary')
	GROUP BY f.release_year, c.name
)
SELECT release_year,
	MAX(CASE WHEN LOWER(genre_name) = 'drama' THEN movie_count ELSE 0 END) AS number_of_drama_movies,
	MAX(CASE WHEN LOWER(genre_name) = 'travel' THEN movie_count ELSE 0 END) AS number_of_travel_movies,
	MAX(CASE WHEN LOWER(genre_name) = 'documentary' THEN movie_count ELSE 0 END) AS number_of_documentary_movies
FROM genre_counter
GROUP BY release_year
ORDER BY release_year DESC;

/*Summary:
Task's logic: I had to check if film had only 1 category so i created separate query to check, result of it was nothing 
so i could create query without overcomplicating it
SELECT film_id, COUNT(category_id ) AS cat
FROM film_category
GROUP BY film_id
HAVING COUNT(category_id ) > 1
Join type: I used INNER JOIN because it directly connects all the way through the tables
Pros and cons: Join solution has the lowest cost(130). It look the most understandable and the logic i really siple, so 
I`ll chose it.
	Subquery solution has the highest cost(147). As i saw in previous queries just creating subquery in filter
with such tasks doesn`t make a lot of sence, so I tried different logic with subqueries inside of select. The resul has 
higher cost but it`s like a reusable block for selecting category rate.
	CTE solution has similar to join cost(131). It is only a bit more complicated than join but for me it looks like can 
be reused only in the same way as it is (not as filters or something like that). So it	s easier to change categories in
the join solution.
*/

/*Part 2.1 Subquery
The HR department aims to reward top-performing employees in 2017 with bonuses to recognize their contribution to stores 
revenue. Show which three employees generated the most revenue in 2017? 

Assumptions: 
staff could work in several stores in a year, please indicate which store the staff worked in (the last one);
if staff processed the payment then he works in the same store; 
take into account only payment_date
*/
SELECT 
    sf.first_name, 
    sf.last_name,
    SUM(p.amount) AS revenue,
    (SELECT i.store_id 
     FROM public.payment p2
     JOIN public.rental r ON p2.rental_id = r.rental_id
     JOIN public.inventory i ON r.inventory_id = i.inventory_id
     WHERE p2.staff_id = sf.staff_id 
       AND p2.payment_date BETWEEN '2017-01-01' AND '2017-12-31'
     ORDER BY p2.payment_date DESC, p2.payment_id DESC
     LIMIT 1
    ) AS last_store
FROM public.staff sf
JOIN public.payment p ON sf.staff_id = p.staff_id 
WHERE p.payment_date BETWEEN '2017-01-01' AND '2017-12-31'
GROUP BY sf.staff_id
HAVING SUM(p.amount) >= COALESCE((
	SELECT SUM(amount)
	FROM public.payment
	WHERE payment_date BETWEEN '2017-01-01' AND '2017-12-31'
	GROUP BY staff_id
	ORDER BY SUM(amount) DESC
	OFFSET 2
	LIMIT 1
), 0)
ORDER BY revenue DESC;

/*Part 2.1 CTE
The HR department aims to reward top-performing employees in 2017 with bonuses to recognize their contribution to stores revenue. Show which three employees generated the most revenue in 2017? 

Assumptions: 
staff could work in several stores in a year, please indicate which store the staff worked in (the last one);
if staff processed the payment then he works in the same store; 
take into account only payment_date
*/
WITH staff_revenue AS (
    SELECT 
        p.staff_id, 
        SUM(p.amount) AS total_revenue
    FROM public.payment p
    WHERE p.payment_date BETWEEN '2017-01-01' AND '2017-12-31'
    GROUP BY p.staff_id
    ORDER BY SUM(p.amount) DESC
),
last_store_worked AS (
    SELECT DISTINCT ON (p.staff_id)
        p.staff_id,
        i.store_id AS last_store
    FROM public.payment p
    JOIN public.rental r ON p.rental_id = r.rental_id
    JOIN public.inventory i ON r.inventory_id = i.inventory_id
    WHERE p.payment_date BETWEEN '2017-01-01' AND '2017-12-31'
    ORDER BY p.staff_id, p.payment_date DESC, p.payment_id DESC
)
SELECT 
    sf.first_name, 
    sf.last_name, 
    sr.total_revenue AS revenue,
    lsw.last_store
FROM public.staff sf
JOIN staff_revenue sr ON sf.staff_id = sr.staff_id
JOIN last_store_worked lsw ON sf.staff_id = lsw.staff_id
WHERE sr.total_revenue >= COALESCE((
	SELECT sr.total_revenue
	FROM staff_revenue sr
	OFFSET 2
	LIMIT 1
), 0)
ORDER BY revenue DESC;


/*Summary:
	Task's logic: As we had to find top-performing employees it is more logical to count a consultant as such an employee
(not a casier). So the payment amount was counted through the connection with rental table (not directly). The last store that 
the employee worked in 2017 was taken from the inventory table as in the staff table there is only the last one.
	Pros and cons: Subquery solution has the highest cost(3749).CTE solution has middle cost(5816). Having the task in 
mind choosing the subquery option looks better as it is more efficient and has a clearer structure. But CTE option has 
a good block which shows the anual employee revenue which is really useful for a business
	I couldn`t find a clear join solution as the table should contain the last stores where staff worked so it makes 
improsible grouping by payment amount impossible*/


/*Part 2.2 Join
Task: The management team wants to identify the most popular movies and their target audience age groups to optimize 
marketing efforts. Show which 5 movies were rented more than others (number of rentals), and what's the expected age 
of the audience for these movies? To determine expected age please use 'Motion Picture Association film rating system'
*/
SELECT f.title,
	f.rating,
	CASE 
		WHEN rating = 'G' THEN 'All ages admitted. Nothing that would offend parents for viewing by children.' 
		WHEN rating = 'PG' THEN 'Some material may not be suitable for children. Parents urged to give "parental guidance". May contain some material parents might not like for their young children.'
		WHEN rating = 'PG-13' THEN 'Some material may be inappropriate for children under 13. Parents are urged to be cautious. Some material may be inappropriate for pre-teenagers.' 		
		WHEN rating = 'R' THEN 'Under 17 requires accompanying parent or adult guardian. Contains some adult material. Parents are urged to learn more about the film before taking their young children with them.'
		WHEN rating = 'NC-17' THEN 'No one 17 and under admitted. Clearly adult. Children are not admitted.'
		ELSE '' 
		END AS expected_age,
	COUNT(r.rental_id ) AS num_of_rentals
FROM public.film f
JOIN public.inventory i ON f.film_id = i.film_id 
JOIN public.rental r ON i.inventory_id = r.inventory_id 
GROUP BY f.title,f.rating, expected_age
ORDER BY num_of_rentals DESC
FETCH FIRST 5 ROWS WITH TIES;
-- The same thing here as in the 1.3 query. All needded results are included but the order may be a bit messed up.

/*Part 2.2 Subquery
Task: The management team wants to identify the most popular movies and their target audience age groups to optimize 
marketing efforts. Show which 5 movies were rented more than others (number of rentals), and what's the expected age 
of the audience for these movies? To determine expected age please use 'Motion Picture Association film rating system'
*/
SELECT 
    f.title,
    f.rating,
    CASE 
        WHEN f.rating = 'G' THEN 'All ages admitted. Nothing that would offend parents for viewing by children.' 
        WHEN f.rating = 'PG' THEN 'Some material may not be suitable for children. Parents urged to give "parental guidance".'
        WHEN f.rating = 'PG-13' THEN 'Some material may be inappropriate for children under 13.' 		
        WHEN f.rating = 'R' THEN 'Under 17 requires accompanying parent or adult guardian.'
        WHEN f.rating = 'NC-17' THEN 'No one 17 and under admitted. Clearly adult.'
        ELSE '' 
    	END AS expected_age,
    COUNT(r.rental_id) AS num_of_rentals
FROM public.film f
JOIN public.inventory i ON f.film_id = i.film_id
JOIN public.rental r ON i.inventory_id = r.inventory_id
GROUP BY f.film_id
HAVING COUNT(r.rental_id) >= COALESCE((
	SELECT COUNT(r.rental_id)
	FROM public.rental r
	JOIN public.inventory i ON r.inventory_id = i.inventory_id
	GROUP BY i.film_id
	ORDER BY COUNT(r.rental_id) DESC
	OFFSET 4
	LIMIT 1
), 0)
ORDER BY num_of_rentals DESC, f.film_id;

/*Part 2.1 CTE
Task: The management team wants to identify the most popular movies and their target audience age groups to optimize 
marketing efforts. Show which 5 movies were rented more than others (number of rentals), and what's the expected age 
of the audience for these movies? To determine expected age please use 'Motion Picture Association film rating system'
*/
WITH movie_rentals AS (
    SELECT i.film_id, COUNT(r.rental_id) AS num_of_rentals
    FROM public.inventory i
    JOIN public.rental r ON i.inventory_id = r.inventory_id
    GROUP BY i.film_id
)
SELECT 
    f.title,
    f.rating,
    CASE 
        WHEN f.rating = 'G' THEN 'All ages admitted. Nothing that would offend parents for viewing by children.' 
        WHEN f.rating = 'PG' THEN 'Some material may not be suitable for children. Parents urged to give "parental guidance".'
        WHEN f.rating = 'PG-13' THEN 'Some material may be inappropriate for children under 13.' 		
        WHEN f.rating = 'R' THEN 'Under 17 requires accompanying parent or adult guardian.'
        WHEN f.rating = 'NC-17' THEN 'No one 17 and under admitted. Clearly adult.'
        ELSE '' 
    END AS expected_age,
    mr.num_of_rentals
FROM public.film f
JOIN movie_rentals mr ON f.film_id = mr.film_id
WHERE mr.num_of_rentals >= COALESCE((
	SELECT mr.num_of_rentals
	FROM movie_rentals mr
    ORDER BY num_of_rentals DESC
	OFFSET 4
	LIMIT 1
), 0)
ORDER BY mr.num_of_rentals DESC, f.film_id;

/*Summary:
	Task's logic: As was written in the task to determine expected age please use 'Motion Picture Association film rating 
system' from https://en.wikipedia.org/wiki/Motion_Picture_Association_film_rating_system
	Join type: I used an INNER JOIN because it directly connects all the way through the tables
	Pros and cons: The subquery solution has a giant cost(172929). And as it doesn`t really have advantages in comparison 
with the other queries we`ll move on to them
	The join option cost is 1789, which is way better than the previous one. The structure is logical and readable but CTE 
is the same(cost even better - 1153) and additionally has a movie rentals counter that is really useful for business*/


/*Part 3.1 Join
Task: The stores’ marketing team wants to analyze actors' inactivity periods to select those with notable career breaks 
for targeted promotional campaigns, highlighting their comebacks or consistent appearances to engage customers with 
nostalgic or reliable film stars
V1: gap between the latest release_year and current year per each actor;
*/
SELECT a.first_name, a.last_name, (EXTRACT(YEAR FROM CURRENT_DATE) - MAX(f.release_year)) AS inactivity_gap
FROM public.actor a
JOIN public.film_actor fa ON a.actor_id = fa.actor_id 
JOIN public.film f ON fa.film_id = f.film_id 
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY a.actor_id;

/*Part 3.1 Subquery
Task: The stores’ marketing team wants to analyze actors' inactivity periods to select those with notable career breaks 
for targeted promotional campaigns, highlighting their comebacks or consistent appearances to engage customers with 
nostalgic or reliable film stars
V1: gap between the latest release_year and current year per each actor;
*/
SELECT a.first_name, a.last_name, (EXTRACT(YEAR FROM CURRENT_DATE) - sub.latest_year) AS inactivity_gap
FROM public.actor a
JOIN (
    SELECT fa.actor_id, MAX(f.release_year) AS latest_year
    FROM public.film_actor fa
    JOIN public.film f ON fa.film_id = f.film_id
    GROUP BY fa.actor_id
) sub ON a.actor_id = sub.actor_id
ORDER BY a.actor_id ;

/*Part 3.1 CTE
Task: The stores’ marketing team wants to analyze actors' inactivity periods to select those with notable career breaks 
for targeted promotional campaigns, highlighting their comebacks or consistent appearances to engage customers with 
nostalgic or reliable film stars
*/
WITH actor_max_year AS (
    SELECT 
        fa.actor_id, 
        MAX(f.release_year) AS latest_year
    FROM public.film_actor fa
    JOIN public.film f ON fa.film_id = f.film_id
    GROUP BY fa.actor_id
)
SELECT 
    a.first_name, 
    a.last_name, 
    (EXTRACT(YEAR FROM CURRENT_DATE) - amy.latest_year) AS inactivity_gap
FROM public.actor a
JOIN actor_max_year amy ON a.actor_id = amy.actor_id
ORDER BY a.actor_id ;



/*Summary:
	Task's logic: gap between the latest release_year and current year per each actor
	Join type: I used an INNER JOIN because it directly connects all the way through the tables
	Pros and cons: The subquery solution has a bigger cost that others but the difference is smaller(270 vs 240). 
The query is pretty simple so there is in no sence in creating structures like CTE or Subquery*/


/*Part 3.2 Join
Task: The stores’ marketing team wants to analyze actors' inactivity periods to select those with notable career breaks 
for targeted promotional campaigns, highlighting their comebacks or consistent appearances to engage customers with 
nostalgic or reliable film stars
*/
SELECT 
    a.first_name, 
    a.last_name,
    (EXTRACT(YEAR FROM CURRENT_DATE) - MIN(f.release_year)) - COUNT(DISTINCT f.release_year) AS total_inactivity_years
FROM public.actor a
JOIN public.film_actor fa ON a.actor_id = fa.actor_id
JOIN public.film f ON fa.film_id = f.film_id
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY total_inactivity_years DESC;


/*Part 3.2 Subquery
Task: The stores’ marketing team wants to analyze actors' inactivity periods to select those with notable career breaks 
for targeted promotional campaigns, highlighting their comebacks or consistent appearances to engage customers with 
nostalgic or reliable film stars
*/
SELECT 
    a.first_name, 
    a.last_name,
    (
        SELECT (EXTRACT(YEAR FROM CURRENT_DATE) - MIN(f.release_year)) - COUNT(DISTINCT f.release_year)
        FROM public.film_actor fa
        JOIN public.film f ON fa.film_id = f.film_id
        WHERE fa.actor_id = a.actor_id
    ) AS total_inactivity_years
FROM public.actor a
ORDER BY total_inactivity_years DESC;

/*Part 3.2 CTE
Task: The stores’ marketing team wants to analyze actors' inactivity periods to select those with notable career breaks 
for targeted promotional campaigns, highlighting their comebacks or consistent appearances to engage customers with 
nostalgic or reliable film stars
*/
WITH actor_career_stats AS (
    SELECT 
        a.actor_id,
        a.first_name, 
        a.last_name,
        (EXTRACT(YEAR FROM CURRENT_DATE) - MIN(f.release_year)) AS career_span,
        COUNT(DISTINCT f.release_year) AS active_years
    FROM public.actor a
    JOIN public.film_actor fa ON a.actor_id = fa.actor_id
    JOIN public.film f ON fa.film_id = f.film_id
    GROUP BY a.actor_id, a.first_name, a.last_name
)
SELECT first_name, last_name, (career_span - active_years) AS total_inactivity_years
FROM actor_career_stats
ORDER BY total_inactivity_years DESC;

/*Summary: gaps between sequential films per each actor
	Task's logic: As the aim is to calculate gaps between sequential films per each actor, we can create a formula 
that will simplify query. So if we have to count the years of inactivity we can do it this way: 
current_year - first_film_release_year - count(distinct_release_years)
	Join type: I used an INNER JOIN because it directly connects all the way through the tables
	Pros and cons: The cost difference between the CTE and join query VS subquery is huge (630 against 21330). So subquery 
is not the best choice. If we compare the join and the CTE, the join`s logical complexity is simpler but the CTE logic is 
easier to understand. Also it can be reused for general actor metrics, so in my oppinion it is better for production*/