-----------------------------------------------------------------------------------------------
--DDL
CREATE DATABASE hotel_booking_real;

CREATE SCHEMA IF NOT EXISTS inventory;

--------------------------------------------------------------------------------------------------
--Hotel Infrastructure
CREATE TABLE IF NOT EXISTS inventory.hotel(
	hotel_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	hotel_name varchar(100) NOT NULL UNIQUE,
	address text NOT NULL UNIQUE, --if the business decides to expand the network and the DB to manage inventory, it will make sense to separate address into a few columns
	city varchar(50) NOT NULL,
	CONSTRAINT unique_hotel_city UNIQUE (hotel_name, city)
);

CREATE TABLE IF NOT EXISTS inventory.room_type(
	type_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	type_name VARCHAR(50) NOT NULL,
	capacity_adults INT CHECK (capacity_adults > 0) NOT NULL,
	capacity_children INT CHECK (capacity_children >= 0),
	CONSTRAINT unique_type UNIQUE (type_name, capacity_adults, capacity_children)
);

CREATE TABLE IF NOT EXISTS inventory.rooms(
	room_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	hotel_id INT NOT NULL REFERENCES inventory.hotel(hotel_id) ON DELETE RESTRICT,
	type_id INT NOT NULL REFERENCES inventory.room_type(type_id) ON DELETE RESTRICT,
	room_number INT NOT NULL,
	CONSTRAINT unique_room_in_hotel UNIQUE (hotel_id, room_number)
);

CREATE TABLE IF NOT EXISTS inventory.room_price_log(
	price_history_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	type_id INT NOT NULL REFERENCES inventory.room_type(type_id) ON DELETE RESTRICT,
	base_price DECIMAL(10,2) NOT NULL CHECK (base_price >= 0),
	valid_from DATE NOT NULL CHECK (valid_from > '2000-01-01'),
	valid_to DATE, 
	CHECK (valid_to > valid_from),
	CONSTRAINT unique_room_price_log UNIQUE (type_id, valid_from, valid_to)
);

-------------------------------------------------------------------------
--Booking

CREATE TABLE IF NOT EXISTS inventory.guest(
	guest_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	first_name VARCHAR(50) NOT NULL,
	last_name VARCHAR(50) NOT NULL, --separated full_name
	phone VARCHAR(15) NOT NULL UNIQUE CHECK (phone LIKE '+%'),
	email VARCHAR(255) UNIQUE CHECK (email LIKE '%@%'),
	birth_date DATE CHECK (birth_date > '2000-01-01'), -- "current date" is not allowed in a check but the guest who is booking should be an adult, so a trigger is needed
	discount int CHECK (discount >= 0)
);

CREATE OR REPLACE FUNCTION check_age() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.birth_date > (current_date - 18 * 365) THEN
        RAISE EXCEPTION 'The guest with ID % (% %) is underaged - %', NEW.guest_id, NEW.first_name, NEW.last_name, NEW.birth_date;
    END IF;
    RETURN NEW;
END;

$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_age_check
BEFORE INSERT OR UPDATE ON inventory.guest
FOR EACH ROW EXECUTE FUNCTION check_age();


CREATE TABLE IF NOT EXISTS inventory.booking(
	booking_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	guest_id INT NOT NULL REFERENCES inventory.guest(guest_id) ON DELETE RESTRICT,
	created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	check_in_date DATE NOT NULL CHECK (check_in_date > '2000-01-01'),
	check_out_date DATE NOT NULL,
	CONSTRAINT check_out_date CHECK (check_out_date > check_in_date)
);

CREATE TYPE payment_methods AS ENUM ('cash', 'card');

CREATE TABLE IF NOT EXISTS inventory.payment(
	payment_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	booking_id INT NOT NULL REFERENCES inventory.booking(booking_id) ON DELETE RESTRICT,
	amount DECIMAL(10,2) NOT NULL CHECK (amount >= 0),
	payment_method payment_methods NOT NULL,
	payment_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP CHECK (payment_date > '2000-01-01')
);

CREATE TYPE inventory.booking_status AS ENUM ('pending', 'confirmed', 'checked_in', 'checked_out', 'cancelled', 'no_show');

CREATE TABLE IF NOT EXISTS inventory.booking_status_logs(
	log_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	booking_id INT NOT NULL REFERENCES inventory.booking(booking_id) ON DELETE CASCADE,
	status inventory.booking_status NOT NULL,
	changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP CHECK (changed_at > '2000-01-01')
);

CREATE TABLE IF NOT EXISTS inventory.booking_rooms(
	booking_id INT NOT NULL REFERENCES inventory.booking(booking_id) ON DELETE CASCADE,
	room_id INT NOT NULL REFERENCES inventory.rooms(room_id) ON DELETE RESTRICT,	
	price_at_booking DECIMAL(10,2) NOT NULL,
	PRIMARY KEY (booking_id, room_id)
);

CREATE OR REPLACE FUNCTION inventory.check_room_availability() 
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
		SELECT 1 
        FROM inventory.booking b
        JOIN inventory.booking_rooms br ON b.booking_id = br.booking_id
        WHERE br.room_id = NEW.room_id
        AND b.check_in_date < (SELECT check_out_date FROM inventory.booking WHERE booking_id = NEW.booking_id)
        	AND b.check_out_date > (SELECT check_in_date FROM inventory.booking WHERE booking_id = NEW.booking_id)
        	AND b.booking_id != NEW.booking_id
    ) THEN
        RAISE EXCEPTION 'Room % is already booked for these dates', NEW.room_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_room_availability
BEFORE INSERT OR UPDATE ON inventory.booking_rooms
FOR EACH ROW EXECUTE FUNCTION inventory.check_room_availability();

-----------------------------------------------------------------------
--Service
CREATE TABLE IF NOT EXISTS inventory.services(
	service_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	service_name VARCHAR(100) NOT NULL UNIQUE,
	base_price DECIMAL(10,2) NOT NULL CHECK (base_price >= 0)
);

CREATE TABLE IF NOT EXISTS inventory.booking_services(
	booking_id INT NOT NULL REFERENCES inventory.booking(booking_id) ON DELETE CASCADE,
	service_id INT NOT NULL REFERENCES inventory.services(service_id) ON DELETE RESTRICT,	
	quantity INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
	price_at_booking DECIMAL(10,2) NOT NULL CHECK (price_at_booking >= 0), 
	PRIMARY KEY (booking_id, service_id)
);

CREATE TABLE IF NOT EXISTS inventory.service_price_history(
	service_history_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	service_id INT NOT NULL REFERENCES inventory.services(service_id) ON DELETE RESTRICT,	
	price DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    valid_from DATE NOT NULL CHECK (valid_from > '2000-01-01'),
    valid_to DATE NOT NULL DEFAULT '9999-01-01'::DATE, 
    CONSTRAINT check_service_price_dates CHECK (valid_to > valid_from),
    CONSTRAINT unique_service_price_period UNIQUE (service_id, valid_from, valid_to)
);

/*what if
Choosing the wrong type (like TEXT for money) causes rounding errors or prevents from doing math like "total revenue". It’s like trying to calculate a discount on a word instead of a number.
If FK is Missing, we get orphaned data, where a booking exists but isn't linked to any guest.
If we should create the Parent before the Child so the child has a valid ID to point to. If we do this out of order, the database stops with a Foreign Key Violation error.
Restricting date to be inserted January 1, 2000, prevents accidental typos like "1926" that would break booking calendar and reports (but it was mentioned to do that to all the DB, so all guests will be younger than 26).
Non-negative values restriction prevents impossible math, ensuring a room price or guest count can never be a negative number.
Specific data type prevents data chaos by forcing everyone to use the same standard terms instead of various abbreviations.
Unique prevents duplicate entries, ensuring that two different guests cannot register with the same email or phone number.
Not Null prevents missing information, making sure that vital fields like "Price" or "Name" are never left blank.
*/

-----------------------------------------------------------------------------------------------------------
--inserting data

--------------------------------------------------------------------------------------------------
--Hotel Infrastructure
BEGIN;

INSERT INTO inventory.hotel (hotel_name, address, city)
VALUES 
    ('Grand Lviv Plaza', '12 Liberty Ave', 'Lviv'),
    ('Riverside Resort', '45 Coastal Road', 'Odessa')
ON CONFLICT (hotel_name, city) DO NOTHING
RETURNING *;

INSERT INTO inventory.room_type (type_name, capacity_adults, capacity_children)
VALUES 
    ('Deluxe', 2, 0),
    ('Deluxe', 2, 2),
    ('Standart', 1, 0)
ON CONFLICT (type_name, capacity_adults, capacity_children) DO NOTHING
RETURNING *;

INSERT INTO inventory.rooms (hotel_id, type_id, room_number)
SELECT h.hotel_id, rt.type_id, x.room_number
FROM (VALUES 
    ('grand lviv plaza', 'Deluxe', 2, 2, 102),
    ('riverside resort', 'Deluxe', 2, 0, 305)
) AS x(hotel_name, type_name, adult_c, child_c, room_number)
JOIN inventory.hotel h ON LOWER(h.hotel_name) = LOWER(x.hotel_name)
JOIN inventory.room_type rt ON rt.type_name = x.type_name 
    AND rt.capacity_adults = x.adult_c 
    AND rt.capacity_children = x.child_c
ON CONFLICT (hotel_id, room_number) DO NOTHING
RETURNING *;

INSERT INTO inventory.room_price_log (type_id, base_price, valid_from, valid_to)
SELECT rt.type_id, x.base_price, x.valid_from, x.valid_to
FROM (VALUES 
    ('Deluxe', 2, 2, 650, '2015-05-16'::DATE, '2026-09-30'::DATE),
    ('Deluxe', 2, 0, 800, '2010-05-16'::DATE, NULL)
) AS x(type_name, adult_c, child_c, base_price, valid_from, valid_to)
JOIN inventory.room_type rt ON rt.type_name = x.type_name 
    AND rt.capacity_adults = x.adult_c 
    AND rt.capacity_children = x.child_c
ON CONFLICT (type_id, valid_from, valid_to) DO NOTHING
RETURNING *;
COMMIT;

------------------------------------------------------------------------------
--Booking
BEGIN;

INSERT INTO inventory.guest (first_name, last_name, phone, email, birth_date, discount)
SELECT x.first_name, x.last_name, x.phone, x.email, x.birth_date, x.discount
FROM (VALUES 
    ('Markiyan', 'Steiner', '+380671112233', 'm.steiner@email.com', '2004-04-12'::DATE, 10)
) AS x(first_name, last_name, phone, email, birth_date, discount)
WHERE NOT EXISTS (
    SELECT 1 FROM inventory.guest g 
    WHERE g.phone = x.phone
       OR g.email = x.email
)
RETURNING *;

WITH inserted_booking AS (
    INSERT INTO inventory.booking (guest_id, check_in_date, check_out_date)
    SELECT g.guest_id, '2026-06-01'::DATE, '2026-06-10'::DATE
    FROM inventory.guest g 
    WHERE g.phone = '+380671112233'
    RETURNING booking_id, check_in_date
),
inserted_rooms AS (
    INSERT INTO inventory.booking_rooms (booking_id, room_id, price_at_booking)
    SELECT 
        ib.booking_id, 
        r.room_id,
        (SELECT base_price 
         FROM inventory.room_price_log rpl 
         WHERE rpl.type_id = r.type_id 
         	AND ib.check_in_date BETWEEN rpl.valid_from AND COALESCE(rpl.valid_to, '9999-12-31')
         ORDER BY rpl.valid_from DESC 
         LIMIT 1)
    FROM inserted_booking ib
    CROSS JOIN inventory.rooms r
    WHERE r.room_number = 102 
    	AND r.hotel_id = (SELECT hotel_id FROM inventory.hotel WHERE LOWER(hotel_name) = LOWER('Grand Lviv Plaza'))
    RETURNING booking_id
)
INSERT INTO inventory.booking_status_logs (booking_id, status)
SELECT 
    ib.booking_id, 
    'pending'::inventory.booking_status 
FROM inserted_booking ib;

COMMIT;

BEGIN;

INSERT INTO inventory.guest (first_name, last_name, phone, email, birth_date)
SELECT x.first_name, x.last_name, x.phone, x.email, x.birth_date
FROM (VALUES 
	('Sophia', 'Gnatyuk', '+380934445566', 's.gna@email.com', '2001-11-30'::DATE)
) AS x(first_name, last_name, phone, email, birth_date)
WHERE NOT EXISTS (
    SELECT 1 FROM inventory.guest g 
    WHERE g.phone = x.phone
    	OR g.email = x.email
)
RETURNING *;

WITH inserted_booking AS (
    INSERT INTO inventory.booking (guest_id, check_in_date, check_out_date)
    SELECT g.guest_id, '2026-07-10'::DATE, '2026-07-15'::DATE
    FROM inventory.guest g 
    WHERE g.phone = '+380934445566'
    RETURNING booking_id, check_in_date
),
inserted_rooms AS (
    INSERT INTO inventory.booking_rooms (booking_id, room_id, price_at_booking)
    SELECT 
        ib.booking_id, 
        r.room_id,
        (SELECT rpl.base_price 
         FROM inventory.room_price_log rpl 
         WHERE rpl.type_id = r.type_id 
         	AND ib.check_in_date BETWEEN rpl.valid_from AND COALESCE(rpl.valid_to, '9999-12-31')
         ORDER BY rpl.valid_from DESC 
         LIMIT 1)
    FROM inserted_booking ib
    CROSS JOIN inventory.rooms r
    WHERE r.room_number = 102 
    	AND r.hotel_id = (SELECT hotel_id FROM inventory.hotel WHERE LOWER(hotel_name) = LOWER('Grand Lviv Plaza'))
    RETURNING booking_id
)
INSERT INTO inventory.booking_status_logs (booking_id, status)
SELECT 
    ib.booking_id, 
    'pending'::inventory.booking_status 
FROM inserted_booking ib;
COMMIT;

BEGIN;
INSERT INTO inventory.payment (booking_id, amount, payment_method)
SELECT 
    b.booking_id,
    (b.check_out_date - b.check_in_date) * br.price_at_booking,
    'card'
FROM inventory.booking b
JOIN inventory.booking_rooms br ON b.booking_id = br.booking_id
JOIN inventory.guest g ON b.guest_id = g.guest_id
WHERE g.phone = '+380671112233'
	AND EXISTS (
		SELECT 1 FROM inventory.booking_status_logs bsl 
		WHERE bsl.booking_id = b.booking_id 
		AND bsl.status = 'pending'
  )
	AND NOT EXISTS (
		SELECT 1 FROM inventory.booking_status_logs bsl 
		WHERE bsl.booking_id = b.booking_id 
			AND bsl.status IN ('confirmed', 'cancelled')
  )
ORDER BY b.booking_id DESC
LIMIT 1;
COMMIT;

BEGIN;
INSERT INTO inventory.payment (booking_id, amount, payment_method)
SELECT 
    b.booking_id,
    (b.check_out_date - b.check_in_date) * br.price_at_booking,
    'card'
FROM inventory.booking b
JOIN inventory.booking_rooms br ON b.booking_id = br.booking_id
JOIN inventory.guest g ON b.guest_id = g.guest_id
WHERE g.phone = '+380934445566'
  AND EXISTS (
      SELECT 1 FROM inventory.booking_status_logs bsl 
      WHERE bsl.booking_id = b.booking_id AND bsl.status = 'pending'
  )
  AND NOT EXISTS (
      SELECT 1 FROM inventory.booking_status_logs bsl 
      WHERE bsl.booking_id = b.booking_id AND bsl.status = 'confirmed'
  )
ORDER BY b.booking_id DESC
LIMIT 1;

COMMIT; 

---------------------------------------------------------------------------
--Service
BEGIN;
INSERT INTO inventory.services (service_name, base_price)
VALUES 
    ('SPA Treatment', 1200.00),
    ('Breakfast Buffet', 350.00)
ON CONFLICT (service_name) DO NOTHING
RETURNING *;

INSERT INTO inventory.service_price_history (service_id, price, valid_from)
SELECT s.service_id, x.price, x.valid_from::DATE
FROM (VALUES 
    ('Breakfast Buffet', 350.00, '2026-01-01'),
    ('SPA Treatment', 1200.00, '2026-01-01')
) AS x(service_name, price, valid_from)
JOIN inventory.services s ON s.service_name = x.service_name
ON CONFLICT (service_id, valid_from, valid_to) DO NOTHING
RETURNING *;

INSERT INTO inventory.booking_services (booking_id, service_id, quantity, price_at_booking)
SELECT 
    b.booking_id, 
    s.service_id, 
    x.qty,
    (SELECT sph.price 
     FROM inventory.service_price_history sph 
     WHERE sph.service_id = s.service_id 
       AND b.check_in_date BETWEEN sph.valid_from AND COALESCE(sph.valid_to, '9999-12-31')
     ORDER BY sph.valid_from DESC LIMIT 1)
FROM (VALUES 
    (102, '2026-07-10', 'Breakfast Buffet', 5),
    (102, '2026-07-10', 'SPA Treatment', 1)
) AS x(room_num, check_in, s_name, qty)
JOIN inventory.rooms r ON r.room_number = x.room_num
JOIN inventory.booking b ON b.check_in_date = x.check_in::DATE
JOIN inventory.booking_rooms br ON br.booking_id = b.booking_id AND br.room_id = r.room_id
JOIN inventory.services s ON s.service_name = x.s_name
ON CONFLICT (booking_id, service_id) DO NOTHING
RETURNING *;

COMMIT;
/*
To ensure the consistency of our data, we use the database as a strong gatekeeper through constraints. We build these rules directly into 
our tables to check every piece of info before it is saved.We keep our data connected using Foreign Keys, which act like a bridge between 
different tables.By setting these rules, we control exactly how the database handles these links, ensuring our history stays together and 
that no lost or orphaned records are ever left behind.
*/

-----------------------------------------------------------------------------------------
--Alter

BEGIN;

ALTER TABLE inventory.booking
	ADD COLUMN record_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE inventory.booking_rooms 
	ADD COLUMN record_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE inventory.booking_services 
	ADD COLUMN record_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE inventory.booking_status_logs 
	ADD COLUMN record_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE inventory.guest 
	ADD COLUMN record_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE inventory.hotel 
	ADD COLUMN record_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE inventory.payment 
	ADD COLUMN record_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE inventory.room_price_log 
	ADD COLUMN record_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE inventory.room_type 
	ADD COLUMN record_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE inventory.rooms
	ADD COLUMN record_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE inventory.service_price_history 
	ADD COLUMN record_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE inventory.services 
	ADD COLUMN record_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

COMMIT;