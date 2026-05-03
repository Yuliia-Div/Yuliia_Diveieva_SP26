
CREATE DATABASE museum;

CREATE SCHEMA IF NOT EXISTS collection_management;
----------------------------------------------------------------------------------------------------
-- Independent parent tables
CREATE TABLE IF NOT EXISTS collection_management.locations (
    location_id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(50) NOT NULL,
    address TEXT
);

CREATE TABLE IF NOT EXISTS collection_management.external_partners (
    partner_id BIGSERIAL PRIMARY KEY,
    org_name VARCHAR(255) NOT NULL,
    contact_person VARCHAR(255),
    contract_details TEXT
);

CREATE TABLE IF NOT EXISTS collection_management.employees (
    employee_id BIGSERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    tax_id VARCHAR(50) NOT NULL UNIQUE,
    birth_date DATE NOT NULL CHECK (birth_date < CURRENT_DATE - '18 years'::INTERVAL),
    address TEXT
);

CREATE TABLE IF NOT EXISTS collection_management.visitors (
    visitor_id BIGSERIAL PRIMARY KEY,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(15) UNIQUE,
    category VARCHAR(50) NOT NULL DEFAULT 'General',
    registration_date DATE NOT NULL DEFAULT CURRENT_DATE
);

--Primary entities
CREATE TABLE IF NOT EXISTS collection_management.artifacts (
    artifact_id BIGSERIAL PRIMARY KEY,
    inventory_number VARCHAR(50) NOT NULL UNIQUE,
    title VARCHAR(255) NOT NULL,
    acquisition_date DATE NOT NULL CHECK (acquisition_date <= CURRENT_DATE), 
    created_by VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS collection_management.exhibitions (
    exhibition_id BIGSERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    is_online BOOLEAN NOT NULL DEFAULT FALSE,
    responsible_employee_id BIGINT NOT NULL REFERENCES collection_management.employees(employee_id),
    CONSTRAINT check_exh_dates CHECK (end_date > start_date)
);

--Entities that depend from primary entities
CREATE TABLE IF NOT EXISTS collection_management.price_list (
    price_id BIGSERIAL PRIMARY KEY,
    exhibition_id BIGINT REFERENCES collection_management.exhibitions(exhibition_id),
    location_id BIGINT REFERENCES collection_management.locations(location_id),
    visitor_category VARCHAR(50) NOT NULL,
    price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    start_date DATE NOT NULL,
    end_date DATE,
    CONSTRAINT check_price_target CHECK (exhibition_id IS NOT NULL OR location_id IS NOT NULL),
    CONSTRAINT check_price_dates CHECK (end_date >= start_date)
);

CREATE TABLE IF NOT EXISTS collection_management.employee_log (
    log_id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL REFERENCES collection_management.employees(employee_id) ON DELETE SET NULL,
    location_id BIGINT NOT NULL REFERENCES collection_management.locations(location_id),
    position VARCHAR(100) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    CONSTRAINT check_emp_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

--Logs
CREATE TABLE IF NOT EXISTS collection_management.artifact_movement_log (
    movement_id BIGSERIAL PRIMARY KEY,
    artifact_id BIGINT NOT NULL REFERENCES collection_management.artifacts(artifact_id) ON DELETE RESTRICT,
    location_id BIGINT REFERENCES collection_management.locations(location_id),
    exhibition_id BIGINT REFERENCES collection_management.exhibitions(exhibition_id),
    external_partner_id BIGINT REFERENCES collection_management.external_partners(partner_id),
    status VARCHAR(50) NOT NULL,
    start_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_date TIMESTAMP,
    CONSTRAINT check_mov_dates CHECK (end_date IS NULL OR end_date >= start_date),
    CONSTRAINT check_mov_presence CHECK (location_id IS NOT NULL OR exhibition_id IS NOT NULL OR external_partner_id IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS collection_management.visit_logs (
    visit_id BIGSERIAL PRIMARY KEY,
    visitor_id BIGINT NOT NULL REFERENCES collection_management.visitors(visitor_id),
    price_id BIGINT NOT NULL REFERENCES collection_management.price_list(price_id),
    visit_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actual_price DECIMAL(10, 2) NOT NULL CHECK (actual_price >= 0)
);

---------------------------------------------------------------------------------
--Checks

ALTER TABLE collection_management.artifact_movement_log DROP CONSTRAINT IF EXISTS chk_movement_status_enum;
ALTER TABLE collection_management.artifact_movement_log 
ADD CONSTRAINT chk_movement_status_enum 
CHECK (status IN ('Stored', 'On Display', 'On Loan', 'Restoration', 'Transit'));

ALTER TABLE collection_management.locations DROP CONSTRAINT IF EXISTS chk_location_type_list;
ALTER TABLE collection_management.locations 
ADD CONSTRAINT chk_location_type_list 
CHECK (type IN ('Gallery', 'Storage', 'Office', 'Restoration', 'Transit'));

ALTER TABLE collection_management.visitors DROP CONSTRAINT IF EXISTS chk_visitor_category_list;
ALTER TABLE collection_management.visitors 
ADD CONSTRAINT chk_visitor_category_list 
CHECK (category IN ('General', 'Student', 'Child', 'VIP', 'Senior', 'Corporate'));

ALTER TABLE collection_management.price_list DROP CONSTRAINT IF EXISTS chk_price_category_sync;
ALTER TABLE collection_management.price_list 
ADD CONSTRAINT chk_price_category_sync 
CHECK (visitor_category IN ('General', 'Student', 'Child', 'VIP', 'Senior', 'Corporate'));

ALTER TABLE collection_management.visitors DROP CONSTRAINT IF EXISTS chk_visitor_reg_after_launch;
ALTER TABLE collection_management.visitors 
ADD CONSTRAINT chk_visitor_reg_after_launch 
CHECK (registration_date >= '2026-01-01');

ALTER TABLE collection_management.employees DROP CONSTRAINT IF EXISTS chk_tax_id_length;
ALTER TABLE collection_management.employees 
ADD CONSTRAINT chk_tax_id_length 
CHECK (LENGTH(tax_id) = 10);
-- Dropping checks before creating them ensures rerunability of the code and allows to easily reuse it if we need to change conditions of the checks
-----------------------------------------------------------------------------------
--Inserting data

-- 1. CORE INFRASTRUCTURE (The Foundation)
-- Tables: locations, employee, external_partners (They are independent and required for all subsequent steps.

BEGIN;
INSERT INTO collection_management.locations (name, type, address)
SELECT * FROM (VALUES 
    ('Main Gallery', 'Gallery', '12 Museum St, Lviv'),
    ('North Storage', 'Storage', '14 Museum St, Lviv'),
    ('Restoration Lab', 'Restoration', '12 Museum St, Lviv'),
    ('Admin Office', 'Office', '14 Museum St, Lviv'),
    ('Scythian Hall', 'Gallery', '12 Museum St, Lviv'),
    ('Archive Room', 'Storage', '14 Museum St, Lviv')
) AS data(name, type, address)
WHERE NOT EXISTS (SELECT 1 FROM collection_management.locations l WHERE l.name = data.name);

INSERT INTO collection_management.employees (first_name, last_name, tax_id, birth_date, address)
VALUES 
    ('Olena', 'Petrenko', '2901234567', '1985-05-12', '12 Liberty Ave, Lviv'),
    ('Andriy', 'Koval', '2804567890', '1990-11-22', '45 Coastal Rd, Odessa'),
    ('Serhiy', 'Sydorov', '3007891234', '1982-02-01', '8 Market Sq, Lviv'),
    ('Maryna', 'Bondar', '2705432109', '1995-08-15', '3 High St, Kyiv'),
    ('Ivan', 'Melnyk', '3109876543', '1988-12-30', '21 Park Ln, Lviv'),
    ('Tetiana', 'Boyko', '2603210987', '1993-04-20', '10 Hill Blvd, Dnipro')
ON CONFLICT (tax_id) DO NOTHING;

INSERT INTO collection_management.external_partners (org_name, contact_person, contract_details)
SELECT * FROM (VALUES 
    ('National Art Museum', 'Dr. Smith', 'Exchange program #2026-A'),
    ('Historical Society', 'Jane Doe', 'Research partnership'),
    ('Global Heritage Trust', 'M. Vance', 'Security audit contract'),
    ('Louvre Museum', 'J. Picard', 'International loan 2026'),
    ('British Museum', 'S. Jenkins', 'Ancient artifacts swap'),
    ('Kyiv History Museum', 'O. Melnyk', 'Regional cooperation')
) AS data(org_name, contact_person, contract_details)
WHERE NOT EXISTS (SELECT 1 FROM collection_management.external_partners p WHERE p.org_name = data.org_name);
COMMIT;

-- 2. The Content
-- Tables: artifacts, visitors (register items and the mandatory 'Guest' profile)

BEGIN;
INSERT INTO collection_management.artifacts (inventory_number, title, acquisition_date, created_by)
VALUES 
    ('M-2026-001', 'Scythian Gold Comb', '2026-01-15', 'Olena Petrenko'),
    ('M-2026-002', 'Mammoth Tusk Fragment', '2026-02-10', 'Andriy Koval'),
    ('M-2026-003', 'Oil Painting: Lviv Morning', '2026-03-05', 'Olena Petrenko'),
    ('M-2026-004', 'Roman Silver Denarius', '2026-03-20', 'Serhiy Sydorov'),
    ('M-2026-005', 'Medieval Sword Hilt', '2026-04-01', 'Andriy Koval'),
    ('M-2026-006', 'Baroque Ceramic Vase', '2026-04-12', 'Serhiy Sydorov')
ON CONFLICT (inventory_number) DO NOTHING;

INSERT INTO collection_management.visitors (visitor_id, first_name, last_name, phone, category, registration_date)
VALUES (1, 'Guest', 'Museum', NULL, 'General', '2026-01-01')
ON CONFLICT (visitor_id) DO NOTHING;

INSERT INTO collection_management.visitors (first_name, last_name, phone, category, registration_date)
VALUES 
    ('Ivan', 'Bondar', '380445550192', 'General', '2026-02-15'),
    ('Olena', 'Shevchenko', '380679876543', 'Student', '2026-03-10'),
    ('Mark', 'Taylor', '14155552671', 'VIP', '2026-03-20'),
    ('Dmytro', 'Kuzmenko', '380631112233', 'General', '2026-04-05'),
    ('Anna', 'Franko', '380990001122', 'Child', '2026-04-18'),
    ('Marta', 'Kvitka', '380954445566', 'Senior', '2026-04-22')
ON CONFLICT (phone) DO NOTHING;
COMMIT;

-- 3. Organisation
-- Tables: exhibitions, employee_log (connects employees to specific events and career roles)

BEGIN;
INSERT INTO collection_management.exhibitions (title, start_date, end_date, is_online, responsible_employee_id)
SELECT * FROM (VALUES 
    ('Golden Age', '2026-02-01'::DATE, '2026-05-01'::DATE, FALSE, (SELECT employee_id FROM collection_management.employees WHERE tax_id = '2901234567')),
    ('Digital History', '2026-01-15'::DATE, NULL, TRUE, (SELECT employee_id FROM collection_management.employees WHERE tax_id = '3007891234')),
    ('Lviv Art Renaissance', '2026-03-15'::DATE, '2026-06-15'::DATE, FALSE, (SELECT employee_id FROM collection_management.employees WHERE tax_id = '2901234567')),
    ('Roman Footprints', '2026-04-01'::DATE, '2026-07-01'::DATE, FALSE, (SELECT employee_id FROM collection_management.employees WHERE tax_id = '2804567890')),
    ('Baroque Wonders', '2026-04-15'::DATE, '2026-10-15'::DATE, FALSE, (SELECT employee_id FROM collection_management.employees WHERE tax_id = '2705432109')),
    ('Medieval Steel', '2026-05-01'::DATE, '2026-08-01'::DATE, FALSE, (SELECT employee_id FROM collection_management.employees WHERE tax_id = '2603210987'))
) AS data(title, start_date, end_date, is_online, resp_id)
WHERE NOT EXISTS (SELECT 1 FROM collection_management.exhibitions e WHERE e.title = data.title);

INSERT INTO collection_management.employee_log (employee_id, location_id, position, start_date)
SELECT * FROM (VALUES 
    ((SELECT employee_id FROM collection_management.employees WHERE tax_id = '2901234567'), (SELECT location_id FROM collection_management.locations WHERE name = 'Scythian Hall'), 'Senior Curator', '2026-01-01'::DATE),
    ((SELECT employee_id FROM collection_management.employees WHERE tax_id = '2804567890'), (SELECT location_id FROM collection_management.locations WHERE name = 'Restoration Lab'), 'Head Restorer', '2026-02-01'::DATE),
    ((SELECT employee_id FROM collection_management.employees WHERE tax_id = '3007891234'), (SELECT location_id FROM collection_management.locations WHERE name = 'Admin Office'), 'IT Manager', '2026-01-15'::DATE),
    ((SELECT employee_id FROM collection_management.employees WHERE tax_id = '2705432109'), (SELECT location_id FROM collection_management.locations WHERE name = 'Main Gallery'), 'Tour Guide', '2026-03-01'::DATE),
    ((SELECT employee_id FROM collection_management.employees WHERE tax_id = '3109876543'), (SELECT location_id FROM collection_management.locations WHERE name = 'North Storage'), 'Security Lead', '2026-01-01'::DATE),
    ((SELECT employee_id FROM collection_management.employees WHERE tax_id = '2603210987'), (SELECT location_id FROM collection_management.locations WHERE name = 'Archive Room'), 'Archivist', '2026-04-01'::DATE)
) AS data(emp_id, loc_id, pos, s_date)
WHERE NOT EXISTS (SELECT 1 FROM collection_management.employee_log el WHERE el.employee_id = data.emp_id AND el.start_date = data.s_date);
COMMIT;

-- 4. Operations
-- Tables: price_list, artifact_movement_log (establishes costs and historical locations for artifacts)

BEGIN;
INSERT INTO collection_management.price_list (exhibition_id, location_id, visitor_category, price, start_date)
SELECT 
    data.exh_id::bigint, data.loc_id::bigint, data.cat, data.pr::decimal, data.s_date::DATE
FROM (VALUES 
    ((SELECT exhibition_id FROM collection_management.exhibitions WHERE title = 'Golden Age'), NULL::bigint, 'General', 200.00, '2026-02-01'),
    ((SELECT exhibition_id FROM collection_management.exhibitions WHERE title = 'Golden Age'), NULL::bigint, 'Student', 100.00, '2026-02-01'),
    (NULL::bigint, (SELECT location_id FROM collection_management.locations WHERE name = 'Main Gallery'), 'General', 150.00, '2026-01-01'),
    (NULL::bigint, (SELECT location_id FROM collection_management.locations WHERE name = 'Main Gallery'), 'Child', 0.00, '2026-01-01'),
    ((SELECT exhibition_id FROM collection_management.exhibitions WHERE title = 'Roman Footprints'), NULL::bigint, 'VIP', 500.00, '2026-04-01'),
    ((SELECT exhibition_id FROM collection_management.exhibitions WHERE title = 'Lviv Art Renaissance'), NULL::bigint, 'General', 180.00, '2026-03-15')
) AS data(exh_id, loc_id, cat, pr, s_date)
WHERE NOT EXISTS (SELECT 1 FROM collection_management.price_list pl WHERE pl.visitor_category = data.cat AND (pl.exhibition_id = data.exh_id OR pl.location_id = data.loc_id));

INSERT INTO collection_management.artifact_movement_log (artifact_id, location_id, exhibition_id, status, start_date)
SELECT 
    data.art_id::bigint, data.loc_id::bigint, data.exh_id::bigint, data.stat, data.s_date::TIMESTAMP
FROM (VALUES 
    ((SELECT artifact_id FROM collection_management.artifacts WHERE inventory_number = 'M-2026-001'), (SELECT location_id FROM collection_management.locations WHERE name = 'Scythian Hall'), NULL::bigint, 'On Display', '2026-03-01 09:00:00'),
    ((SELECT artifact_id FROM collection_management.artifacts WHERE inventory_number = 'M-2026-002'), (SELECT location_id FROM collection_management.locations WHERE name = 'North Storage'), NULL::bigint, 'Stored', '2026-02-10 10:00:00'),
    ((SELECT artifact_id FROM collection_management.artifacts WHERE inventory_number = 'M-2026-003'), NULL::bigint, (SELECT exhibition_id FROM collection_management.exhibitions WHERE title = 'Lviv Art Renaissance'), 'On Display', '2026-03-15 09:00:00'),
    ((SELECT artifact_id FROM collection_management.artifacts WHERE inventory_number = 'M-2026-004'), NULL::bigint, (SELECT exhibition_id FROM collection_management.exhibitions WHERE title = 'Roman Footprints'), 'On Display', '2026-04-01 10:00:00'),
    ((SELECT artifact_id FROM collection_management.artifacts WHERE inventory_number = 'M-2026-005'), (SELECT location_id FROM collection_management.locations WHERE name = 'Restoration Lab'), NULL::bigint, 'Restoration', '2026-04-05 11:00:00'),
    ((SELECT artifact_id FROM collection_management.artifacts WHERE inventory_number = 'M-2026-006'), (SELECT location_id FROM collection_management.locations WHERE name = 'Main Gallery'), NULL::bigint, 'On Display', '2026-04-12 09:00:00')
) AS data(art_id, loc_id, exh_id, stat, s_date)
WHERE NOT EXISTS (SELECT 1 FROM collection_management.artifact_movement_log aml WHERE aml.artifact_id = data.art_id AND aml.start_date = data.s_date::TIMESTAMP);

COMMIT;

-- 5. Transactions
-- Tables: visit_logs (depends on all previous layers)

BEGIN;
INSERT INTO collection_management.visit_logs (visitor_id, price_id, visit_timestamp, actual_price)
SELECT 
    data.v_id::bigint, data.p_id::bigint, data.v_time::TIMESTAMP, data.a_price::decimal
FROM (VALUES 
    ((SELECT visitor_id FROM collection_management.visitors WHERE phone = '380445550192'), (SELECT price_id FROM collection_management.price_list WHERE price = 150.00 LIMIT 1), '2026-04-20 10:00:00', 150.00),
    (1, (SELECT price_id FROM collection_management.price_list WHERE price = 150.00 LIMIT 1), '2026-04-21 14:20:00', 150.00),
    ((SELECT visitor_id FROM collection_management.visitors WHERE phone = '380679876543'), (SELECT price_id FROM collection_management.price_list WHERE price = 100.00 LIMIT 1), '2026-03-22 11:30:00', 100.00),
    ((SELECT visitor_id FROM collection_management.visitors WHERE phone = '14155552671'), (SELECT price_id FROM collection_management.price_list WHERE price = 500.00 LIMIT 1), '2026-04-05 09:15:00', 500.00),
    ((SELECT visitor_id FROM collection_management.visitors WHERE phone = '380631112233'), (SELECT price_id FROM collection_management.price_list WHERE price = 150.00 LIMIT 1), '2026-04-15 16:45:00', 150.00),
    ((SELECT visitor_id FROM collection_management.visitors WHERE phone = '380990001122'), (SELECT price_id FROM collection_management.price_list WHERE price = 0.00 LIMIT 1), '2026-04-18 12:00:00', 0.00)
) AS data(v_id, p_id, v_time, a_price)
WHERE NOT EXISTS (SELECT 1 FROM collection_management.visit_logs vl WHERE vl.visitor_id = data.v_id AND vl.visit_timestamp = data.v_time::TIMESTAMP);
COMMIT;

------------------------------------------------------------------------
--Functions

-- 1. Function that updates the responsible employee for the chosen exhibition
CREATE OR REPLACE FUNCTION collection_management.update_exhibition_responsible_staff(
    p_exhibition_id bigint,
    p_exhibition_title VARCHAR,
    p_emp_first_name VARCHAR,
    p_emp_last_name VARCHAR
)
RETURNS TEXT AS $$
DECLARE
    v_new_employee_id BIGINT;
BEGIN
    -- Find`s employee id based on their name
    SELECT employee_id INTO v_new_employee_id
    FROM collection_management.employees
    WHERE first_name = p_emp_first_name 
    	AND last_name = p_emp_last_name;

    IF v_new_employee_id IS NULL THEN
        RAISE EXCEPTION 'Employee % % not found.', p_emp_first_name, p_emp_last_name;
    END IF;

	UPDATE collection_management.exhibitions
    SET responsible_employee_id = v_new_employee_id
    WHERE exhibition_id = p_exhibition_id 
    	AND title = p_exhibition_title;

    -- 4. Check if the exhibition was found and updated
    IF NOT FOUND THEN
        RAISE EXCEPTION  'Update failed: Exhibition ID % with title "%" not found.', p_exhibition_id, p_exhibition_title;
    END IF;

    RETURN 'Success: Exhibition ' ||p_exhibition_title|| ' updated with new curator.';
END;
$$ LANGUAGE plpgsql;

--Test
SELECT collection_management.update_exhibition_responsible_staff(1, 'Medieval Steel', 'Andriy', 'Koval');

-- 2. Function that adds visitors 

CREATE OR REPLACE FUNCTION collection_management.add_new_visit_transaction(
    p_visitor_phone VARCHAR,
    p_exhibition_title VARCHAR,
    p_visit_time TIMESTAMP
)
RETURNS TEXT AS $$
DECLARE
    v_visitor_id BIGINT;
    v_visitor_category VARCHAR;
    v_price_id BIGINT;
    v_actual_price DECIMAL;
BEGIN
    -- Check if the phone belongs to a registered visitor
    SELECT visitor_id, category INTO v_visitor_id, v_visitor_category
    FROM collection_management.visitors
    WHERE phone = p_visitor_phone;

    -- If phone is not found or is NULL, treat as the default "Guest" (id 1)
    IF v_visitor_id IS NULL THEN
        v_visitor_id := 1;
        v_visitor_category := 'General';
        p_visitor_phone := 'Guest (Anonymous)';
    END IF;

    -- Resolve price id and amount based on resolved category and exhibition
    SELECT price_id, price INTO v_price_id, v_actual_price
    FROM collection_management.price_list
    WHERE visitor_category = v_visitor_category
      AND exhibition_id = (
          SELECT exhibition_id 
          FROM collection_management.exhibitions 
          WHERE title = p_exhibition_title
      )
    LIMIT 1;

    --Validate price existence
    IF v_price_id IS NULL THEN
        RAISE EXCEPTION 'Pricing rule missing for Category: % on Exhibition: %', 
                        v_visitor_category, p_exhibition_title;
    END IF;

    -- Insert the transaction into logs
    INSERT INTO collection_management.visit_logs (visitor_id, price_id, visit_timestamp, actual_price)
    VALUES (v_visitor_id, v_price_id, p_visit_time, v_actual_price);

    RETURN format('Success! Visitor: %s | Category: %s | Exhibition: %s | Paid: %s', 
                  p_visitor_phone, v_visitor_category, p_exhibition_title, v_actual_price);
END;
$$ LANGUAGE plpgsql;

--Test
SELECT collection_management.add_new_visit_transaction(
    '380679876543'::VARCHAR, 
    'Golden Age'::VARCHAR, 
    '2026-04-24 14:00:00'::TIMESTAMP
); -- visitor exists

SELECT collection_management.add_new_visit_transaction(
    NULL::VARCHAR, 
    'Golden Age'::VARCHAR, 
    CURRENT_TIMESTAMP::TIMESTAMP
); --Guest

------------------------------------------------------------------------
--View

CREATE OR REPLACE VIEW collection_management.monthly_performance_within_quarter AS
WITH current_quarter AS (
    -- Dynamically identify the most recent quarter based on the latest visit
    SELECT date_trunc('quarter', MAX(visit_timestamp)) as last_q
    FROM collection_management.visit_logs
)
SELECT 
    TO_CHAR(vl.visit_timestamp, 'Month') AS visit_month,
    e.title AS exhibition_name,
    v.category AS visitor_segment,
    COUNT(vl.visit_id) AS tickets_sold,
    SUM(vl.actual_price) AS revenue,
    ROUND((SUM(vl.actual_price) / SUM(SUM(vl.actual_price)) OVER (PARTITION BY e.title)) * 100, 2) AS pct_of_quarterly_total,
    TO_CHAR(vl.visit_timestamp, 'YYYY-"Q"Q') AS calendar_quarter
FROM collection_management.visit_logs vl
JOIN collection_management.visitors v ON vl.visitor_id = v.visitor_id
JOIN collection_management.price_list pl ON vl.price_id = pl.price_id
LEFT JOIN collection_management.exhibitions e ON pl.exhibition_id = e.exhibition_id
CROSS JOIN current_quarter cq
WHERE date_trunc('quarter', vl.visit_timestamp) = cq.last_q
GROUP BY 
    TO_CHAR(vl.visit_timestamp, 'Month'), 
    EXTRACT(MONTH FROM vl.visit_timestamp),
    e.title, 
    v.category, 
    TO_CHAR(vl.visit_timestamp, 'YYYY-"Q"Q')
ORDER BY EXTRACT(MONTH FROM vl.visit_timestamp) ASC, revenue DESC;

/*The view merges ticket sales, visitor types, and exhibition names into a single list. By looking at this table, 
management can identify which exhibitions attract the most people and which visitor groups, like students or VIPs, bring 
in the most money each month. It highlights busy or slow periods and shows exactly how much each month contributes to the 
total quarterly budget.
*/

---------------------------------------------------------------------------------
--Role

CREATE ROLE museum_manager WITH LOGIN PASSWORD 'very_secure_password';
GRANT USAGE ON SCHEMA collection_management TO museum_manager;
GRANT SELECT ON ALL TABLES IN SCHEMA collection_management TO museum_manager;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA collection_management TO museum_manager;
ALTER DEFAULT PRIVILEGES IN SCHEMA collection_management 
GRANT SELECT ON TABLES TO museum_manager; -- will automatically grant select permission to the manager 

SELECT grantee, table_schema, table_name, privilege_type 
FROM information_schema.role_table_grants 
WHERE grantee = 'museum_manager';