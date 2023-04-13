-- extension usada para generar passsword aleatorias 
CREATE EXTENSION IF NOT EXISTS pgcrypto;


-- ####################################################################
-- ########## PROBABLEMENTE TENDREMOS QUE ELIMINAR ESTO DESPUES #######
\i create_tables.sql
DROP TABLE IF EXISTS city_aux;
DROP TABLE IF EXISTS last_name;
DROP TABLE IF EXISTS first_name;
DROP TABLE IF EXISTS street_aux;
DROP TABLE IF EXISTS item_aux;
DROP TABLE IF EXISTS brand_aux;
-- ####################################################################
-- ####################################################################


CREATE TABLE city_aux (
    city VARCHAR(128) NOT NULL,
	pupulation INT,
    zips VARCHAR(16) NOT NULL
);

CREATE TABLE last_name (
    name VARCHAR(50) NOT NULL,
    count INTEGER   
);

CREATE TABLE first_name (
	name VARCHAR(50) NOT NULL
);

CREATE TABLE street_aux (
	name VARCHAR(50) NOT NULL
);

CREATE TABLE item_aux (
	name VARCHAR(255) NOT NULL,
	unit VARCHAR(255) NOT NULL,
	metric VARCHAR(255) NOT NULL
);

CREATE TABLE brand_aux (
	name VARCHAR(255) NOT NULL
);

\copy city_aux FROM 'filtered_data_cities.csv' WITH DELIMITER ',' CSV HEADER;
\copy last_name FROM 'filtered_data_names.csv' WITH DELIMITER ',' CSV HEADER;
\copy first_name FROM 'names.csv' WITH DELIMITER ',' CSV HEADER;
\copy street_aux FROM 'streets.csv' WITH DELIMITER ',' CSV HEADER;
\copy item_aux FROM './CSVs/items.csv' WITH DELIMITER ',' CSV HEADER;
\copy brand_aux FROM './CSVs/marcas.csv' WITH DELIMITER E'~' CSV HEADER;

-- llenar tabla city
INSERT INTO city (city_name, postal_code)
	SELECT city, zips
	FROM city_aux;


-- procedimiento crear productos
CREATE OR REPLACE PROCEDURE createItems(number_of_items INT) 
AS $$
DECLARE
	name_product VARCHAR;
	brand VARCHAR;
	price DECIMAL(10, 2);
	unit_id INT;
	to_insert_unit_name VARCHAR;

BEGIN	
	FOR i IN 1..number_of_items LOOP
		-- Choose product name
		SELECT name, unit INTO name_product, to_insert_unit_name
		FROM item_aux
		ORDER BY random()
		LIMIT 1;

		-- Choose brand name
		SELECT name INTO brand
		FROM brand_aux
		ORDER BY random()
		LIMIT 1;

		-- Create product name
		name_product := CONCAT(name_product, ' ',brand);		

		-- Assign a random price
		price := random()*100;
		
		-- Assign unit
		SELECT id INTO unit_id
		FROM unit
		WHERE unit_name = to_insert_unit_name;
		
		IF unit_id IS NULL THEN
			INSERT INTO unit ( unit_name )
			VALUES ( to_insert_unit_name );
			SELECT id INTO unit_id
			FROM unit
			WHERE unit_name = to_insert_unit_name;
		END IF;

		INSERT INTO item (
			item_name, price, unit_id
		) VALUES (
			name_product, price, unit_id
		);

	END LOOP;



END
$$ LANGUAGE plpgsql;


-- procedimiento crear customers
CREATE OR REPLACE PROCEDURE createCustomers(number_of_customers INT) 
AS $$
DECLARE
	nombreCliente VARCHAR;
	apellidoCliente VARCHAR;
	username VARCHAR;
	pw VARCHAR;
	timestamp_value CONSTANT timestamp :=TO_TIMESTAMP('2022-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS');
	days_offset INTEGER;
	hours_offset INTEGER;
	minutes_offset INTEGER;
	time_inserted timestamp;
	time_confirmed timestamp;
	code VARCHAR;
	email VARCHAR;
BEGIN
	
	--insertar Customers
	FOR i IN 1..number_of_customers LOOP
		-- choose first_name
		SELECT name INTO nombreCliente
		FROM first_name
		ORDER BY random()
		LIMIT 1;
		
		-- choose last_name
		SELECT name INTO apellidoCliente
		FROM last_name
		ORDER BY random()
		LIMIT 1;
		
		-- choose username
		username := nombreCliente || apellidoCliente ||i;
		
		-- choose password 
		pw := substr(md5(random()::text), 1, 8); -- generar contraseña de 8 caracteres

        -- choose time_inserted
		days_offset := floor(random() * 365);
		hours_offset := floor(random() * 24);
		minutes_offset := floor(random() * 60);
		time_inserted := date_trunc(
			'minute', 
			timestamp_value + days_offset * INTERVAL '1 DAY' + hours_offset * INTERVAL '1 HOUR' + minutes_offset * INTERVAL '1 MINUTE'
		);
		
		-- choose time_confirmed
		time_confirmed := time_inserted + INTERVAL '1 HOUR';
		
		-- choose confirmation_code
		code := substr(md5(random()::text), 1, 4);
		
		-- choose email
		email := nombreCliente || apellidoCliente ||i*10 || '@gmail.com';
		
		INSERT INTO Customer (
			first_name, last_name, user_name, password, time_inserted, 
		 	confirmation_code, time_confirmed, contact_email, contact_phone, 
			city_id, address, delivery_city_id, delivery_address
		)
		VALUES (
			nombreCliente, apellidoCliente, username, pw, time_inserted, 
			code, time_confirmed, email, 'hola', 37, 'hola', 37, 'hola'
		);
	END LOOP;


END
$$ LANGUAGE plpgsql;



-- Procedimiento almacenado
CREATE OR REPLACE PROCEDURE spCreateTestData(number_of_customers INT, number_of_orders INT, number_of_items INT, avg_items_per_order INT) 
AS $$
BEGIN
CALL createCustomers(number_of_customers);
CALL createItems(number_of_items);
END
$$ LANGUAGE plpgsql;



	