/* Transformation function for rental_month */
CREATE OR REPLACE FUNCTION month_rented(rental_date TIMESTAMP)
RETURNS int
LANGUAGE plpgsql
AS
$$
DECLARE rental_month int;
BEGIN
SELECT EXTRACT(MONTH FROM rental_date) INTO rental_month;
RETURN rental_month;
END;
$$;

/* Test rental_month function, should return 5 */
SELECT month_rented('2003-05-20');

/* Create Detailed table */
CREATE TABLE detailed_rentals (
	rental_month INTEGER NOT NULL,
	store_id INTEGER NOT NULL,
	inventory_id INTEGER NOT NULL,
	film_title VARCHAR(255), 
    category_name VARCHAR(255) NOT NULL,
    rental_rate NUMERIC(10,2),
    rental_count INTEGER,
    PRIMARY KEY (rental_month, store_id, inventory_id)
);

/* Create Summary table */
CREATE TABLE summary_rentals (
	rental_month INTEGER NOT NULL,
	category_name VARCHAR(255) NOT NULL,
	store_id INTEGER NOT NULL,
	total_rentals INTEGER,
	total_rental_rate NUMERIC(10,2),
	PRIMARY KEY (rental_month, category_name, store_id)
);

/* Test Detailed and Summary tables. Haven't inserted data so it will create empty tables */
SELECT * FROM detailed_rentals;
SELECT * FROM summary_rentals;

/* Create function for trigger on detailed table to update summary table */
CREATE OR REPLACE FUNCTION insert_summary_update()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
BEGIN
DELETE FROM summary_rentals;
INSERT INTO summary_rentals (rental_month, category_name, store_id, total_rentals, total_rental_rate)
SELECT rental_month, category_name, store_id, SUM(rental_count) AS total_rentals, SUM(rental_count * rental_rate) AS total_rental_rate
FROM detailed_rentals
GROUP BY rental_month, category_name, store_id
ORDER BY rental_month, category_name, store_id;
RETURN NEW;
END;
$$;

/* Create trigger */
CREATE TRIGGER new_rental
AFTER INSERT
ON detailed_rentals
FOR EACH STATEMENT
EXECUTE PROCEDURE insert_summary_update();

/* Insert data into detailed table from the source database */
INSERT INTO detailed_rentals (rental_month, store_id, inventory_id, film_title, category_name, rental_rate, rental_count)
SELECT month_rented(r.rental_date) AS rental_month, i.store_id, i.inventory_id, f.title AS film_title, c.name AS category_name, f.rental_rate, COUNT(r.rental_id) AS rental_count
FROM rental AS r
JOIN inventory AS i ON r.inventory_id = i.inventory_id
JOIN film AS f ON i.film_id = f.film_id
JOIN film_category AS fc ON f.film_id = fc.film_id
JOIN category AS c ON fc.category_id = c.category_id
GROUP BY rental_month, i.store_id, i.inventory_id, film_title, category_name, f.rental_rate
ORDER BY rental_month, i.store_id, i.inventory_id, category_name;

/* Test both tables, should populate with data */
SELECT * FROM detailed_rentals;
SELECT * FROM summary_rentals;

/* Create stored procedure to refresh data in both tables */
CREATE OR REPLACE PROCEDURE refresh_rentals_data()
LANGUAGE plpgsql
AS
$$
BEGIN
DELETE FROM detailed_rentals;
DELETE FROM summary_rentals;
INSERT INTO detailed_rentals (rental_month, store_id, inventory_id, film_title, category_name, rental_rate, rental_count)
SELECT month_rented(r.rental_date) AS rental_month, i.store_id, i.inventory_id, f.title AS film_title, c.name AS category_name, f.rental_rate, COUNT(r.rental_id) AS rental_count
FROM rental AS r
JOIN inventory AS i ON r.inventory_id = i.inventory_id
JOIN film AS f ON i.film_id = f.film_id
JOIN film_category AS fc ON f.film_id = fc.film_id
JOIN category AS c ON fc.category_id = c.category_id
GROUP BY month_rented(r.rental_date), i.store_id, i.inventory_id, film_title, c.name, f.rental_rate;
ORDER BY rental_month, i.store_id, i.inventory_id, category_name;
RETURN;
END;
$$;

/* Insert new table before testing stored procedure */
INSERT INTO detailed_rentals
VALUES ('2', '1', '79', 'Test Film', 'Test Cat', '1.99', '3');

/* detailed table had 12328 rows, will have 12329 after insert */
SELECT * FROM detailed_rentals;

/* summary table had 160 rows, will have 161 after insert */
SELECT * FROM summary_rentals;

/* Test stored procedure */
CALL refresh_rentals_data();

/* Test both table to make sure # of rows is 12328 and 160 */
SELECT * FROM detailed_rentals;
SELECT * FROM summary_rentals;




/* 
*
*
code used to test 
*
*
*/

select * from detailed_rentals;

select * from summary_rentals;

SELECT *
FROM detailed_rentals
WHERE category_name = 'Children'
AND store_id = 1;

delete from detailed_rentals;

drop table summary_rentals;

drop trigger if exists new_rental ON detailed_rentals;
drop function if exists ;insert_summary_update();

Select tgname from pg_trigger where tgrelid = 'detailed_rentals'::regclass;
