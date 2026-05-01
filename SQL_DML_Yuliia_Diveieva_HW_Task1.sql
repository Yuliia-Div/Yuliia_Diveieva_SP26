--adding films
BEGIN;

INSERT INTO public.film (title, release_year, language_id, rental_duration, rental_rate)
SELECT new_films.title, new_films.release_year, l.language_id, new_films.rental_duration, new_films.rental_rate
FROM (VALUES 
    ('ASTEROID CITY', 2023, 7, 4.99),
    ('MAMMA MIA!', 2008, 14, 9.99),
    ('THE ADDAMS FAMILY', 1991, 21, 19.99)
) AS new_films(title, release_year, rental_duration, rental_rate)
CROSS JOIN public.language l
WHERE l.name = 'English'
  AND NOT EXISTS (
      SELECT 1 
      FROM public.film f 
      WHERE f.title = new_films.title
      	AND f.release_year = new_films.release_year
  )
RETURNING *;

COMMIT;
/*
Data uniqueness here is insured by adding a "not exists" block, which checks if such titles already exist in the table.
If the transaction fails nothing will happen
Before adding these films, I checked whether they already exist in the table using this query:
SELECT *
FROM film f
WHERE UPPER(f.title) LIKE 'ASTEROID CITY' 
	OR UPPER(f.title) LIKE 'MAMMA MIA!'
	OR UPPER(f.title) LIKE 'THE ADDAMS FAMILY';
*/
-----------------------------------------------------------

--connecting films with categories
BEGIN;

INSERT INTO public.film_category (film_id, category_id)
SELECT f.film_id, c.category_id
FROM (VALUES 
    ('ASTEROID CITY', 'Comedy'),
    ('MAMMA MIA!', 'Music'),
    ('THE ADDAMS FAMILY', 'Horror')
) AS mapping(film_title, cat_name)
JOIN public.film f ON f.title = mapping.film_title
JOIN public.category c ON c.name = mapping.cat_name
WHERE NOT EXISTS (
    SELECT 1 FROM public.film_category fc
    WHERE fc.film_id = f.film_id
      AND fc.category_id = c.category_id 
)
RETURNING *;

COMMIT;
/*
These queries create connections between created films and the category table by adding rows in the film-category table.
"Not exists" is also added here to ensure that such a connection doesn't exist yet. As such film din't exist till the 
previous query internal check is more than enough
 */
-----------------------------------------------------------

--adding actors
BEGIN;

INSERT INTO public.actor (first_name, last_name)
SELECT a.fn, a.ln
FROM (VALUES 
    ('JASON', 'SCHWARTZMAN'), ('SCARLETT', 'JOHANSSON'), 
    ('MERYL', 'STREEP'), ('AMANDA', 'SEYFRIED'), 
    ('ANJELICA', 'HUSTON'), ('RAUL', 'JULIA')
) AS a(fn, ln)
WHERE NOT EXISTS (
    SELECT 1 FROM public.actor a1
    WHERE a1.first_name = a.fn AND a1.last_name = a.ln
)
RETURNING *;

COMMIT;
/*
Before adding actors I checked if they already exist in the actor table.
SELECT *
FROM actor a
WHERE UPPER(a.first_name) = 'ANJELICA' AND UPPER(a.last_name) = 'HUSTON'
	OR UPPER(a.first_name) = 'RAUL' AND UPPER(a.last_name) = 'JULIA'
	OR UPPER(a.first_name) = 'JASON' AND UPPER(a.last_name) = 'SCHWARTZMAN'
	OR UPPER(a.first_name) = 'SCARLETT' AND UPPER(a.last_name) = 'JOHANSSON'
	OR UPPER(a.first_name) = 'MERYL' AND UPPER(a.last_name) = 'STREEP'
	OR UPPER(a.first_name) = 'AMANDA' AND UPPER(a.last_name) = 'SEYFRIED';

*/
----------------------------------------------------------------------------------------

--connecting actors fith films
BEGIN;

INSERT INTO public.film_actor (actor_id, film_id)
SELECT a.actor_id, f.film_id
FROM (VALUES 
    ('MERYL', 'STREEP', 'MAMMA MIA!'),
    ('AMANDA', 'SEYFRIED', 'MAMMA MIA!'),
    ('ANJELICA', 'HUSTON', 'THE ADDAMS FAMILY'),
    ('RAUL', 'JULIA', 'THE ADDAMS FAMILY'),
    ('JASON', 'SCHWARTZMAN', 'ASTEROID CITY'),
    ('SCARLETT', 'JOHANSSON', 'ASTEROID CITY')
) AS mapping(fname, lname, ftitle)
JOIN public.actor a ON a.first_name = mapping.fname AND a.last_name = mapping.lname
JOIN public.film f ON f.title = mapping.ftitle
WHERE NOT EXISTS (
    SELECT 1 FROM public.film_actor fa 
    WHERE fa.actor_id = a.actor_id 
    AND fa.film_id = f.film_id
)
RETURNING *;

COMMIT;
/*
This query establishes a connection between actors and their films
checking results:
  
SELECT f.title, a.first_name, a.last_name
FROM public.film f
JOIN public.film_actor fa ON f.film_id = fa.film_id
JOIN public.actor a ON a.actor_id = fa.actor_id
WHERE f.title = 'MAMMA MIA!';
*/
----------------------------------------------------------------------------------------

--adding films to the inventory of the first store
BEGIN;

INSERT INTO public.inventory (film_id, store_id)
SELECT f.film_id, (SELECT store_id FROM public.store ORDER BY random() LIMIT 1)
FROM public.film f
WHERE f.title IN ('MAMMA MIA!', 'ASTEROID CITY', 'THE ADDAMS FAMILY')
RETURNING *;

COMMIT;
/* "Not exist" may not be used here if we assume that some films may have several copies in one same store */
-------------------------------------------------------------------------
--altering existing customer

BEGIN;
UPDATE public.customer
SET store_id = 1, 
	first_name = 'YULIIA', 
	last_name = 'DIVEIEVA', 
	email = 'JULIIA.DIVIEVA@gmail.com', 
	address_id = (
		SELECT a.address_id
		FROM address a
		WHERE a.address = '613 Korolev Drive'), 
	last_update = CURRENT_DATE
WHERE customer_id = (
		SELECT r.customer_id
	    FROM public.rental r
	    JOIN public.payment p ON r.customer_id = p.customer_id
	    GROUP BY r.customer_id
	    HAVING COUNT(DISTINCT r.rental_id) >= 43 
	       AND COUNT(DISTINCT p.payment_id) >= 43
	    LIMIT 1
	    )
	AND NOT EXISTS (
    SELECT 1 FROM public.customer c
    WHERE c.email = 'JULIIA.DIVIEVA@gmail.com'
)
	    
RETURNING *;

COMMIT;
/*
Every table that we modified has a default value of "now()" so when we create new rows there is no need to manually insert it
but in the last query we edited a row that already existed, so we had to add the value as "CURRENT_DATE".
If one of the queries fails then it enters an aborted state in which all executions will be rejected until a Rollback or
closing the connection.
*/
---------------------------------------------------------------------------------------------
--removing related records (payment and rental)
BEGIN;

DELETE FROM public.payment
WHERE customer_id = (
    SELECT customer_id FROM public.customer 
    WHERE email = 'JULIIA.DIVIEVA@gmail.com'
)
RETURNING *;

DELETE FROM public.rental
WHERE customer_id = (
    SELECT customer_id FROM public.customer 
    WHERE email = 'JULIIA.DIVIEVA@gmail.com'
)
RETURNING *;

COMMIT;
/*The deletion is safe because there is a restriction based on the full name in the customer. These tables are child tables 
with history data so deleting info in them won't affect other tables or cause foreign key violations. We had to follow such
order of deleting to prevent mistakes, as if we start to delete from the rental table, I'll cause a violation with the 
payment table contains rental_id.
 */ 

---------------------------------------------------------------------------------------------------------------------
--renting movies
BEGIN;

INSERT INTO public.rental (rental_date, inventory_id, customer_id, return_date, staff_id)
SELECT 
    '2017-05-15 10:00:00'::timestamp, i.inventory_id, c.customer_id, '2017-05-20 10:00:00'::timestamp, (SELECT staff_id FROM public.staff WHERE store_id = i.store_id ORDER BY RANDOM() LIMIT 1)
FROM public.inventory i
JOIN public.film f ON i.film_id = f.film_id
JOIN public.customer c ON c.email = 'JULIIA.DIVIEVA@gmail.com'
WHERE f.title IN ('MAMMA MIA!', 'ASTEROID CITY', 'THE ADDAMS FAMILY')
  AND NOT EXISTS (
      SELECT 1 FROM public.rental r 
      WHERE r.inventory_id = i.inventory_id 
      AND r.rental_date = '2017-05-15 10:00:00'::timestamp
  )
RETURNING rental_id;

INSERT INTO public.payment (customer_id, staff_id, rental_id, amount, payment_date)
SELECT c.customer_id, (SELECT staff_id FROM public.staff WHERE store_id = i.store_id ORDER BY RANDOM() LIMIT 1), 
	r.rental_id, f.rental_rate, '2017-05-20 10:00:00'::timestamp
FROM public.rental r
JOIN public.inventory i ON r.inventory_id = i.inventory_id
JOIN public.film f ON i.film_id = f.film_id
JOIN public.customer c ON c.email = 'JULIIA.DIVIEVA@gmail.com'
WHERE f.title IN ('MAMMA MIA!', 'ASTEROID CITY', 'THE ADDAMS FAMILY')
  AND NOT EXISTS (
      SELECT 1 FROM public.payment p 
      WHERE p.customer_id = c.customer_id
      AND p.payment_date = '2017-05-20 10:00:00'::timestamp
  )
RETURNING payment_id;

COMMIT;
/*Here we ensured that that data won't be duplicated by checking if a row with such inventory_id and time exists in the
first case and whether a record with such time and customer exists in the second one. Connections are created correctly 
here because all the IDs were taken directly from their tables.
 */