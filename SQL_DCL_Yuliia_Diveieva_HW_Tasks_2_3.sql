--Task 2. Implement role-based authentication model for dvd_rental database
--2.1 Create a new user with the username "rentaluser" and the password "rentalpassword". Give the user the ability to connect to the database but no other permissions.
CREATE ROLE rentaluser WITH LOGIN PASSWORD 'rentalpassword';
GRANT USAGE ON SCHEMA public TO rentaluser;

--2.2 Grant "rentaluser" permission allows reading data from the "customer" table. Сheck to make sure this permission works correctly: write a SQL query to select all customers.
GRANT SELECT ON TABLE public.customer TO rentaluser;

SET ROLE rentaluser;
SELECT * FROM public.customer; -- successful 
SELECT * FROM public.staff; -- denied 
DELETE FROM public.customer WHERE customer_id = 1;-- denied 
RESET ROLE;

--2.3 Create a new user group called "rental" and add "rentaluser" to the group. 
CREATE ROLE rental;
GRANT rental TO rentaluser;

--2.4 Grant the "rental" group INSERT and UPDATE permissions for the "rental" table. Insert a new row and update one existing row in the "rental" table under that role. 
GRANT INSERT, UPDATE ON TABLE public.rental TO rental;

SET ROLE rentaluser;
INSERT INTO public.rental (rental_id, rental_date, inventory_id, customer_id, staff_id)
VALUES (1000000, '2004-03-28'::timestamp, 1, 1, 1); -- successful 
UPDATE public.rental
SET rental_date = '2004-03-25'::timestamp
WHERE rental_id = 1000000; -- denied as the user doesn't have select permission 
-- GRANT SELECT ON TABLE public.rental TO rental; --Will make the previous query work
INSERT INTO public.customer (store_id, address_id)
VALUES (1, 1); -- denied
SELECT * FROM public.rental; -- denied
RESET ROLE;

SELECT has_table_privilege('rentaluser', 'public.rental', 'UPDATE'); -- shows that the user has Update permission

--2.5 Revoke the "rental" group's INSERT permission for the "rental" table. Try to insert new rows into the "rental" table make sure this action is denied.
REVOKE INSERT ON TABLE public.rental FROM rental;

SET ROLE rentaluser;
INSERT INTO public.rental (rental_id, rental_date, inventory_id, customer_id, staff_id)
VALUES (2000000, '2004-08-28'::timestamp, 1, 1, 1); -- denied 
RESET ROLE;

--2.6 Create a personalized role for any customer already existing in the dvd_rental database. 

CREATE ROLE client_mary_smith;

--Task 3. Implement row-level security
--Write a query to make sure this user sees only their own data and one to show zero rows or error
ALTER TABLE public.rental ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment ENABLE ROW LEVEL SECURITY;

CREATE POLICY rental_personal_access ON public.rental
    FOR SELECT
    TO client_mary_smith
    USING (customer_id = 1);
CREATE POLICY payment_personal_access ON public.payment
    FOR SELECT
    TO client_mary_smith
    USING (customer_id = 1);

GRANT USAGE ON SCHEMA public TO client_mary_smith;
GRANT SELECT ON TABLE public.rental TO client_mary_smith;
GRANT SELECT ON TABLE public.payment TO client_mary_smith;

SET ROLE client_mary_smith;
SELECT * FROM public.rental; -- allowed access
SELECT * FROM public.payment; -- allowed access
SELECT * FROM public.rental WHERE customer_id = 2; -- denied access, doesn't show the data
SELECT * FROM public.payment WHERE customer_id = 2; -- denied access, doesn't show the data
RESET ROLE;