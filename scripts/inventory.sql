-- Modified version of: https://github.com/debezium/container-images/blob/main/examples/postgres/2.6/inventory.sql

-- Create the schema that we'll use to populate data and watch the effect in the WAL
CREATE SCHEMA inventory;
SET search_path TO inventory;

-- Create products table
CREATE TABLE products (
  id SERIAL NOT NULL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description VARCHAR(512),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  modified_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
ALTER SEQUENCE products_id_seq RESTART WITH 101;
ALTER TABLE products REPLICA IDENTITY FULL;

-- Insert data into the products table
INSERT INTO products
VALUES (DEFAULT, 'scooter', 'Small 2-wheel scooter', DEFAULT, DEFAULT),
       (DEFAULT, 'car battery', '12V car battery', DEFAULT, DEFAULT),
       (DEFAULT, '12-pack drill bits', '12-pack of drill bits with sizes ranging from #40 to #3', DEFAULT, DEFAULT),
       (DEFAULT, 'hammer', '12oz carpenter''s hammer', DEFAULT, DEFAULT),
       (DEFAULT, 'spare tire', '24 inch spare tire', DEFAULT, DEFAULT);

-- Create stock table
CREATE TABLE stock (
  product_id INTEGER NOT NULL PRIMARY KEY,
  quantity INTEGER NOT NULL,
  created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  modified_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (product_id) REFERENCES products(id)
);
ALTER TABLE stock REPLICA IDENTITY FULL;

-- Insert data into the stock table
INSERT INTO stock
VALUES (101, 13, DEFAULT, DEFAULT),
       (102, 18, DEFAULT, DEFAULT),
       (103, 18, DEFAULT, DEFAULT),
       (104, 14, DEFAULT, DEFAULT),
       (105, 15, DEFAULT, DEFAULT);

-- Create customers table
CREATE TABLE customers (
  id SERIAL NOT NULL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  modified_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
ALTER SEQUENCE customers_id_seq RESTART WITH 1001;
ALTER TABLE customers REPLICA IDENTITY FULL;

-- Insert data into the customers table
INSERT INTO customers
VALUES (DEFAULT, 'Sally Thomas', 'sally.thomas@acme.com', DEFAULT, DEFAULT),
       (DEFAULT, 'George Bailey', 'gbailey@foobar.com', DEFAULT, DEFAULT),
       (DEFAULT, 'Edward Walker', 'ed@walker.com', DEFAULT, DEFAULT),
       (DEFAULT, 'Jane Caldwell', 'jane@caldwell.com', DEFAULT, DEFAULT),
       (DEFAULT, 'Anne Kretchmar', 'annek@noanswer.org', DEFAULT, DEFAULT);

-- Create orders table
CREATE TABLE orders (
  id SERIAL NOT NULL PRIMARY KEY,
  quantity INTEGER NOT NULL,
  customer_id INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  modified_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (customer_id) REFERENCES customers(id),
  FOREIGN KEY (product_id) REFERENCES products(id)
);
ALTER SEQUENCE orders_id_seq RESTART WITH 10001;
ALTER TABLE orders REPLICA IDENTITY FULL;

-- Insert data into the orders table
INSERT INTO orders
VALUES (DEFAULT, 1, 1001, 101, DEFAULT, DEFAULT),
       (DEFAULT, 1, 1002, 102, DEFAULT, DEFAULT),
       (DEFAULT, 1, 1003, 103, DEFAULT, DEFAULT),
       (DEFAULT, 1, 1004, 104, DEFAULT, DEFAULT),
       (DEFAULT, 1, 1005, 105, DEFAULT, DEFAULT);

-- Create trigger function to update modified_at column
CREATE OR REPLACE FUNCTION update_modified_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.modified_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add the trigger to the products table
CREATE TRIGGER trigger_update_products
BEFORE UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION update_modified_at();

-- Add the trigger to the stock table
CREATE TRIGGER trigger_update_stock
BEFORE UPDATE ON stock
FOR EACH ROW
EXECUTE FUNCTION update_modified_at();

-- Add the trigger to the customers table
CREATE TRIGGER trigger_update_customers
BEFORE UPDATE ON customers
FOR EACH ROW
EXECUTE FUNCTION update_modified_at();

-- Add the trigger to the orders table
CREATE TRIGGER trigger_update_orders
BEFORE UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION update_modified_at();
