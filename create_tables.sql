/*Autores: 
    Nestor Gonzalez 16-10455
    Jesus Bandez 17-10046

Crear el esquema de la base
*/


DROP TABLE IF EXISTS item_in_box;
DROP TABLE IF EXISTS box;
DROP TABLE IF EXISTS item;
DROP TABLE IF EXISTS unit;
DROP TABLE IF EXISTS order_status;
DROP TABLE IF EXISTS status_catalog;
DROP TABLE IF EXISTS notes;
DROP TABLE IF EXISTS delivery;
DROP TABLE IF EXISTS employee;
DROP TABLE IF EXISTS placed_order;
DROP TABLE IF EXISTS customer;
DROP TABLE IF EXISTS city;
DROP TABLE IF EXISTS order_item;


-- yellow area

CREATE TABLE unit (
    id SERIAL PRIMARY KEY,
    unit_name VARCHAR(64) NOT NULL,
    unit_short VARCHAR(8)
);

CREATE TABLE item (
    id SERIAL PRIMARY KEY,
    item_name VARCHAR(255) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    item_photo TEXT, 
    description TEXT, 
    unit_id INT REFERENCES unit (id) NOT NULL
);

-- green area
CREATE TABLE city (
    id SERIAL PRIMARY KEY,
    city_name VARCHAR(128) NOT NULL, 
    postal_code VARCHAR(16) NOT NULL
);

CREATE TABLE customer (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(64) NOT NULL,
    last_name VARCHAR(64) NOT NULL,
    user_name VARCHAR(64) NOT NULL,
    password VARCHAR(64) NOT NULL,
    time_inserted TIMESTAMP NOT NULL,
    confirmation_code VARCHAR(128) NOT NULL,
    time_confirmed TIMESTAMP,
    contact_email VARCHAR(128) NOT NULL,
    contact_phone VARCHAR(128),
    city_id INT REFERENCES city (id),
    address VARCHAR(255),
    delivery_city_id INT REFERENCES city (id),
    delivery_address VARCHAR(255)
);

CREATE TABLE employee (
    id SERIAL PRIMARY KEY,
    employee_code VARCHAR(32) NOT NULL,
    first_name VARCHAR(64) NOT NULL,
    last_name VARCHAR(64) NOT NULL
);

-- RED AREA
CREATE TABLE status_catalog (
    id SERIAL PRIMARY KEY,
    status_name VARCHAR(128) NOT NULL
);

CREATE TABLE placed_order (
    id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customer (id) NOT NULL,
    time_placed TIMESTAMP NOT NULL,
    details TEXT,
    delivery_city_id INT REFERENCES city (id) NOT NULL,
    delivery_address VARCHAR(255) NOT NULL,
    grade_customer INT,
    grade_employee INT
);

CREATE TABLE order_item (
    id SERIAL PRIMARY KEY,
    placed_order_id INT REFERENCES placed_order (id) NOT NULL,
    item_id INT REFERENCES item (id) NOT NULL,
    quantity DECIMAL(10, 3) NOT NULL,
    price DECIMAL(10, 2) NOT NULL
);

CREATE TABLE order_status (
    id SERIAL PRIMARY KEY,
    placed_order_id INT REFERENCES placed_order (id) NOT NULL,
    status_catalog_id INT REFERENCES status_catalog (id) NOT NULL,
    status_time TIMESTAMP NOT NULL,
    details TEXT
);


CREATE TABLE notes (
    id SERIAL PRIMARY KEY,
    placed_order_id INT REFERENCES placed_order (id) NOT NULL,
    employee_id INT REFERENCES employee (id),
    customer_id INT REFERENCES customer (id),
    note_time TIMESTAMP  NOT NULL,
    note_text text NOT NULL
);

CREATE TABLE delivery (
    id SERIAL PRIMARY KEY,
    delivery_time_planned TIMESTAMP NOT NULL,
    delivery_time_actual TIMESTAMP,
    notes TEXT,
    placed_order_id INT REFERENCES placed_order (id) NOT NULL,
    employee_id INT REFERENCES employee (id)
);

CREATE TABLE box(
    id SERIAL PRIMARY KEY,
    box_code VARCHAR(32) NOT NULL,
    delivery_id INT REFERENCES delivery (id) NOT NULL,
    employee_id INT REFERENCES employee (id) NOT NULL
);


CREATE TABLE item_in_box(
    id SERIAL PRIMARY KEY,
    box_id INT REFERENCES box (id) NOT NULL,
    item_id INT REFERENCES item (id) NOT NULL,
    quantity DECIMAL(10, 3) NOT NULL,
    is_replacemen BOOLEAN NOT NULL
);


