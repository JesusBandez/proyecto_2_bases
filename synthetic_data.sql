-- extension usada para generar passsword aleatorias 
CREATE EXTENSION IF NOT EXISTS pgcrypto;


DROP TABLE IF EXISTS city_aux;
DROP TABLE IF EXISTS last_name;
DROP TABLE IF EXISTS first_name;
DROP TABLE IF EXISTS street_aux;
DROP TABLE IF EXISTS phone_number_aux;
DROP TABLE IF EXISTS item_aux;
DROP TABLE IF EXISTS brand_aux;
DROP TABLE IF EXISTS customer_personality;


-- Tabla donde se cargan los datos del .csv
-- population se usan para dar peso a las ciudades con mayor poblacion
CREATE TABLE city_aux (
    city VARCHAR(128) NOT NULL,
	population INT,
    zips VARCHAR(16) NOT NULL
);


-- Tabla para los nombres y apellidos que se usan para generar usuarios
CREATE TABLE last_name (
    name VARCHAR(50) NOT NULL,
    count INTEGER   
);

CREATE TABLE first_name (
	name VARCHAR(50) NOT NULL
);

-- Usada para crear los nombres de las calles
CREATE TABLE street_aux (
	name VARCHAR(50) NOT NULL
);

-- Tablas para generar los items
CREATE TABLE item_aux (
	name VARCHAR(255) NOT NULL,
	unit VARCHAR(255) NOT NULL,
	metric VARCHAR(255) NOT NULL
);

CREATE TABLE brand_aux (
	name VARCHAR(255) NOT NULL
);

-- Tabla de numeros telefonicos
CREATE TABLE phone_number_aux (
	number VARCHAR(50) NOT NULL
);

-- Asocia los customer con una 'personalidad'.
-- placed_orders_rate se usa para dar peso a  customers 
-- para que aparezcan en mas ordenes que otros
CREATE TABLE customer_personality (
	id INT,
	placed_orders_rate FLOAT
);

-- Insertar los datos de los .csv
\copy city_aux FROM './CSVs/filtered_data_cities.csv' WITH DELIMITER ',' CSV HEADER;
\copy last_name FROM './CSVs/last_names.csv' WITH DELIMITER ',' CSV HEADER;
\copy first_name FROM './CSVs/names.csv' WITH DELIMITER ',' CSV HEADER;
\copy street_aux FROM './CSVs/streets.csv' WITH DELIMITER ',' CSV HEADER;
\copy item_aux FROM './CSVs/items.csv' WITH DELIMITER ',' CSV HEADER;
\copy brand_aux FROM './CSVs/marcas.csv' WITH DELIMITER E'~' CSV HEADER;
\copy phone_number_aux FROM 'CSVs/phone_numbers.csv' WITH DELIMITER ',' CSV HEADER;

-- llenar tabla city
INSERT INTO city (city_name, postal_code)
	SELECT city, zips
	FROM city_aux;

-- insertar status de ordenes en el catalogo
INSERT INTO status_catalog (status_name)
	VALUES
		('order placed'),
		('order confirmed'),
		('in transit'),
		('delivered');

-- Procedimiento para crear los deliverys de una orden
CREATE OR REPLACE PROCEDURE createDelivery(order_id INT, transit_time TIMESTAMP, delivered_time TIMESTAMP DEFAULT NULL)
AS $$
DECLARE
	id_order_status INT;
	planned_time TIMESTAMP;
	id_employee INT;
BEGIN

	-- Calcular tiempo planeado de entrega
	planned_time := transit_time + RANDOM()* INTERVAL '1 DAYS' + INTERVAL '12 hours';	

	-- Elegir employee al azar
	SELECT id INTO id_employee
	FROM employee	
	ORDER BY random()
	LIMIT 1;

	-- Insertar el delivery
	INSERT INTO delivery (delivery_time_planned, delivery_time_actual, placed_order_id, employee_id)
	VALUES
		(planned_time, delivered_time, order_id, id_employee);
END
$$ LANGUAGE plpgsql;

--Prodecimiento para llenar el historial de status de una orden.
CREATE OR REPLACE PROCEDURE createOrderStatus(order_id INT, order_inserted_time TIMESTAMP) 
AS $$
DECLARE
	status_order_placed_id INT;
	status_in_transit_id INT;
	status_delivered_id INT;
	status_order_confirmed INT;
	order_in_transit_time TIMESTAMP;
	order_delivered_time TIMESTAMP;
	order_confirmed_time TIMESTAMP;
BEGIN
	SELECT id INTO status_order_placed_id
	FROM status_catalog
	WHERE status_name = 'order placed';

	SELECT id INTO status_order_confirmed
	FROM status_catalog
	WHERE status_name = 'order confirmed';

	SELECT id INTO status_in_transit_id
	FROM status_catalog
	WHERE status_name = 'in transit';

	SELECT id INTO status_delivered_id
	FROM status_catalog
	WHERE status_name = 'delivered';

	-- Status placed
	INSERT INTO order_status 
		(placed_order_id, status_catalog_id, status_time)
	VALUES
		(order_id, status_order_placed_id, order_inserted_time);

	-- Si la orden tiene menos de 1 hora creada, siempre es solo placed
	IF NOW() - INTERVAL '1 hours' < order_inserted_time THEN
		NULL;

	-- Si la orden tiene menos de 5 hora creada, esta en confirmed
	ELSIF NOW() - INTERVAL '5 hours' < order_inserted_time  THEN
		INSERT INTO order_status 
			(placed_order_id, status_catalog_id, status_time)
		VALUES
			(order_id, status_order_placed_id, order_inserted_time+RANDOM()* INTERVAL '4 HOURS');
	-- Si la orden tiene menos de 5 dias creada, tiene 0.8 de probabilidad
	-- de aun estar en 'in transit'
	ELSIF NOW() - INTERVAL '5 days' < order_inserted_time 
		AND RANDOM() < 0.8 THEN

		order_confirmed_time := order_inserted_time +RANDOM()* INTERVAL '4 HOURS';
		INSERT INTO order_status 
			(placed_order_id, status_catalog_id, status_time)
		VALUES
			(order_id, status_order_confirmed, order_confirmed_time);

		order_in_transit_time := order_confirmed_time + RANDOM()* INTERVAL '2 days';
		INSERT INTO order_status 
			(placed_order_id, status_catalog_id, status_time)
		VALUES
			(order_id, status_in_transit_id, order_in_transit_time);

		CALL createDelivery(order_id, order_in_transit_time);

	-- Toda orden con mayor tiempo de creacion se guarda como entregada
	ELSE 
		order_confirmed_time := order_inserted_time +RANDOM()* INTERVAL '4 HOURS';
		INSERT INTO order_status 
			(placed_order_id, status_catalog_id, status_time)
		VALUES
			(order_id, status_order_confirmed, order_confirmed_time);

		order_in_transit_time := order_confirmed_time + RANDOM()*INTERVAL '2 days';
		INSERT INTO order_status 
			(placed_order_id, status_catalog_id, status_time)
		VALUES
			(order_id, status_in_transit_id, order_in_transit_time);
		
		order_delivered_time := order_in_transit_time + RANDOM()*INTERVAL '3 days';
		INSERT INTO order_status 
			(placed_order_id, status_catalog_id, status_time)
		VALUES
			(order_id, status_delivered_id, order_delivered_time);

		CALL createDelivery(order_id, order_in_transit_time, order_delivered_time);
	END IF;
END
$$ LANGUAGE plpgsql;




-- procedimiento crear ordenes
CREATE OR REPLACE PROCEDURE createOrders(number_of_orders INT) 
AS $$
DECLARE
	customer_id INT;
	customer_inserted_time TIMESTAMP;
	city_destination_id INT;
	address VARCHAR;
	order_time_placed TIMESTAMP;
	order_id INT;
	
BEGIN	
	FOR i IN 1..number_of_orders LOOP
		-- Elegir usuario
		SELECT id, time_inserted 
		INTO customer_id, customer_inserted_time
		FROM customer
		NATURAL JOIN customer_personality
		ORDER BY random() * placed_orders_rate
		LIMIT 1;
		
		-- ID de ciudad y direccion
		SELECT delivery_city_id, delivery_address INTO city_destination_id, address
		FROM customer
		WHERE id = customer_id;

		-- Elegir una fecha aleatoria entre la insercion del usuario y hoy
		SELECT customer_inserted_time +
			RANDOM() * (NOW() - customer_inserted_time)
			INTO order_time_placed;
		
		INSERT INTO placed_order 
			(customer_id, time_placed, delivery_city_id, delivery_address)
			VALUES
			(customer_id, order_time_placed, city_destination_id, address)
			RETURNING id INTO order_id;
		
		-- Agregar el historial de status a la orden
		CALL createOrderStatus(order_id, order_time_placed);

	END LOOP;
END
$$ LANGUAGE plpgsql;


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
		-- Elegir un nombre de producto al azar
		SELECT name, unit INTO name_product, to_insert_unit_name
		FROM item_aux
		ORDER BY random()
		LIMIT 1;

		-- Elegir un nombre de alguna marca
		SELECT name INTO brand
		FROM brand_aux
		ORDER BY random()
		LIMIT 1;
		
		name_product := CONCAT(name_product, ' ',brand);		

		-- Asignar un precion aleatorio entre 0.1 y 100
		price := random()*(100-0.1)+0.1;
		
		-- Asignar la unidad del producto.
		SELECT id INTO unit_id
		FROM unit
		WHERE unit_name = to_insert_unit_name;
		
		-- Si la unidad no existe, insertarla
		IF unit_id IS NULL THEN
			INSERT INTO unit ( unit_name )
			VALUES ( to_insert_unit_name )
			RETURNING id INTO unit_id;
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
	phone_number VARCHAR;
	city_id INTEGER;
	calle VARCHAR;
	customer_id INT;

	-- Delta define la diferencia del menor al mayor numero posible para asignar
	-- a placed_orders_rate. No debe ser mayor a max_delta
	delta INT := 400;
	max_delta INT := 500;

BEGIN
	
	--insertar Customers
	FOR i IN 1..number_of_customers LOOP
		-- Primer nombre
		SELECT name INTO nombreCliente
		FROM first_name
		ORDER BY random()
		LIMIT 1;
		
		-- Apellido
		SELECT name INTO apellidoCliente
		FROM last_name
		ORDER BY random()
		LIMIT 1;
		
		-- Generar un username unico
		username := nombreCliente || apellidoCliente ||i;
		
		-- Generar contrasenia
		pw := substr(md5(random()::text), 1, 8); -- generar contraseña de 8 caracteres

        -- Asignar tiempo insertado en la bbdd
		time_inserted := NOW() - RANDOM() * INTERVAL '10 MONTHS';
		
		-- Tiempo de confimacion de mail
		time_confirmed := time_inserted + RANDOM()*INTERVAL '1 HOUR';
		
		-- codigo de confirmacion
		code := substr(md5(random()::text), 1, 4);
		
		-- generar email
		email := nombreCliente || apellidoCliente ||i*10 || '@gmail.com';
		
		-- elegir un numero de tlf
		SELECT number INTO phone_number
		FROM phone_number_aux
		ORDER BY random()
		LIMIT 1;
		
		-- Elegir una ciudad para el customer. Las ciudades con mayor poblacion
		-- tiene mas probabilidad de ser elegidas.
		SELECT id INTO city_id
		FROM city
		Where city_name = (
			Select city
			FROM city_aux
			ORDER BY population*random() DESC
			LIMIT 1
		);
		
		-- Generar direccion
		SELECT name INTO calle
		FROM street_aux
		ORDER BY random()
		LIMIT 1;
		
		calle := round(random() * 100) + 100 || ' ' || calle;
		
		INSERT INTO Customer (
			first_name, last_name, user_name, password, time_inserted, 
		 	confirmation_code, time_confirmed, contact_email, contact_phone, 
			city_id, address, delivery_city_id, delivery_address
		)
		VALUES (
			nombreCliente, apellidoCliente, username, pw, time_inserted, 
			code, time_confirmed, email, phone_number, city_id, calle, city_id, calle
		);
	END LOOP;

	FOR customer_id IN (SELECT id FROM Customer) LOOP
		INSERT INTO customer_personality (id, placed_orders_rate)
			VALUES
			(customer_id, RANDOM()*2*delta+max_delta-delta);
	END LOOP;

END
$$ LANGUAGE plpgsql;

-- Procedimiento para crear empleados
CREATE OR REPLACE PROCEDURE createEmployees(number_of_employees INT)
AS $$
DECLARE
	name_employee VARCHAR;
	last_name_employee VARCHAR;
	emp_code VARCHAR;

BEGIN
	FOR i IN 1..number_of_employees LOOP
		-- Elegir nombre
		SELECT name INTO name_employee
		FROM first_name
		ORDER BY random()
		LIMIT 1;
		
		-- Apellido
		SELECT name INTO last_name_employee
		FROM last_name
		ORDER BY random()
		LIMIT 1;

		emp_code := CONCAT('EMP_C', i);
		
		INSERT INTO employee (employee_code, first_name, last_name)
		VALUES
			(name_employee, last_name_employee, emp_code);

	END LOOP;
END
$$ LANGUAGE plpgsql;


-- Procedimiento asignar n items a una orden
CREATE OR REPLACE PROCEDURE assignItemsToOrder(total_number_items_to_add INT, order_id INT) 
AS $$
DECLARE
	item RECORD;
	items_added INT := 0;
	items_to_add INT;
BEGIN
	-- Numero de items a agregar
	WHILE items_added < total_number_items_to_add LOOP
		items_to_add := RANDOM()*((total_number_items_to_add-items_added)-1)+1;
		
		-- Se selecciona un item aleatorio para guardarlo 'items_to_add' veces.
		-- El precio del item influye en su probabilidad de ser elegido.
		SELECT * INTO item
		FROM item
		ORDER BY random()+(price/100)*0.3
		LIMIT 1;

		INSERT INTO order_item (placed_order_id, item_id, quantity, price) 
		VALUES (order_id, item.id, items_to_add, items_to_add*item.price);

		items_added := items_added + items_to_add;
	END LOOP;
END
$$ LANGUAGE plpgsql;
-- Procedimiento para asignar los items a las ordenes garantizando que se cumpla
-- el numero de items promedio por orden
CREATE OR REPLACE PROCEDURE createOrderItems(promedio INT, numeroDeOrdenes INT) 
AS $$
DECLARE
	placed_id INT;
	x INT;
	acc INT := 0;
	count INT := 1;
	y INT;

	item_price decimal(10, 2);
BEGIN
	x := numeroDeOrdenes % 2;
	FOR placed_id IN (SELECT id FROM placed_order) LOOP
		CASE
			WHEN x = 0 THEN
				y := floor(random() * promedio) + 1;

				CALL assignItemsToOrder(y, placed_id);

				acc = acc + y;
				count = count + 1;
				x := 1;
			ELSE
				y := count*promedio - acc;

				CALL assignItemsToOrder(y, placed_id);

				acc = acc + y;
				count = count + 1;
				x := 0;
		END CASE;
	END LOOP;
END
$$ LANGUAGE plpgsql;

-- procedimiento para crear Box's
CREATE OR REPLACE PROCEDURE createBox() 
AS $$
DECLARE
	box_id INTEGER;
	quantity_var DECIMAL;
	is_replacement_var BOOL;
	orden RECORD;
	deliv RECORD;
	item RECORD;
	box_code_var VARCHAR;
	deivery_id_var INTEGER;
	employee_id_var INTEGER;	
	count INTEGER := 0;

	-- Probabilidad de que el articulo sea un reemplazo
	is_replacement_prob FLOAT := 0.01;
BEGIN

	FOR orden IN (
		SELECT * From placed_order p 
		JOIN Order_status o on p.id = o.placed_order_id
		JOIN status_catalog s on o.status_catalog_id = s.id
		WHERE s.status_name = 'in transit'
		) LOOP
				 
		FOR deliv IN (
			SELECT d.id FROM delivery d
		 	WHERE d.placeD_order_id = orden.id
			) LOOP
			---- crear box y asociarla con delivery

			FOR item IN (
				SELECT oi.item_id, oi.quantity FROM order_item oi
				WHERE oi.placed_order_id = orden.id
			) LOOP

				
				-- choose box_code
				box_code_var := 'BX' || count;
				
				-- choose deivery_id
				deivery_id_var := deliv.id;
				
				-- choose employee_id
				SELECT id INTO employee_id_var
				FROM employee
				ORDER BY random()
				LIMIT 1;
				
				INSERT INTO Box (box_code, delivery_id, employee_id)
				VALUES (box_code_var, deivery_id_var, employee_id_var)
				RETURNING id INTO box_id;
				
				count := count + 1;
				
				---- crear item_in_box				
				--
				IF RANDOM() < (1 - is_replacement_prob) THEN
					is_replacement_var := FALSE;
				ELSE 
					is_replacement_var := TRUE;
				END IF;
				
				INSERT INTO item_in_box (box_id, item_id, quantity, is_replacement)
				VALUES (box_id, item.item_id, item.quantity, is_replacement_var);				
			END LOOP;
		END LOOP;				 
	END LOOP;
END
$$ LANGUAGE plpgsql;


-- Procedimiento almacenado
CREATE OR REPLACE PROCEDURE spCreateTestData(number_of_customers INT, number_of_orders INT, number_of_items INT, avg_items_per_order INT) 
AS $$
BEGIN
CALL createCustomers(number_of_customers);
CALL createItems(number_of_items);
CALL createOrders(number_of_orders);
CALL createEmployees(10);
CALL createOrderItems(avg_items_per_order, number_of_orders);
CALL createBox();
END
$$ LANGUAGE plpgsql;


	