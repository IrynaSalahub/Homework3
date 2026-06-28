CREATE DATABASE stores;

create table customers (
    customer_id serial primary key,
    full_name varchar(100) not null,
    email varchar(100) unique not null,
    balance numeric(10,2) default 0
);

create table products (
    product_id serial primary key,
    product_name varchar(100) not null,
    price numeric(10,2) not null,
    stock_quantity int not null
);

create table orders (
    order_id serial primary key,
    customer_id int references customers(customer_id),
    order_date timestamp default current_timestamp,
    total_amount numeric(10,2) default 0
);

create table order_items (
    order_item_id serial primary key,
    order_id int references orders(order_id),
    product_id int references products(product_id),
    quantity int not null,
    price numeric(10,2) not null
);

create table order_log (
    log_id serial primary key,
    order_id int,
    customer_id int,
    action varchar(50),
    log_date timestamp default current_timestamp
);

CREATE FUNCTION calculate_order_total(p_order_id int)
RETURNS numeric(10,2) AS $$
DECLARE
    v_total numeric(10,2);
BEGIN
    SELECT COALESCE(SUM(quantity * price), 0)
    INTO v_total
    FROM order_items
    WHERE order_id = p_order_id;
    RETURN v_total;
END;
$$ LANGUAGE plpgsql;


CREATE  PROCEDURE create_order(p_customer_id int)
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS
        (SELECT 1
         FROM customers
         WHERE customer_id = p_customer_id)
        THEN RAISE EXCEPTION 'Customer with ID % does not exist.', p_customer_id;
    END IF;
    INSERT INTO orders (customer_id, order_date, total_amount)
    VALUES (p_customer_id, CURRENT_TIMESTAMP, 0);
END;
$$;


CREATE PROCEDURE add_product_to_order(
    p_order_id int,
    p_product_id int,
    p_quantity int
)
LANGUAGE plpgsql AS $$
DECLARE
    v_price numeric(10,2);
    v_stock int;
BEGIN
    IF (p_quantity <= 0)
        THEN RAISE EXCEPTION 'Quantity must be greater than zero.';
    END IF;
    SELECT price, stock_quantity
    INTO v_price, v_stock
    FROM products
    WHERE product_id = p_product_id;
    IF (v_stock IS NULL)
        THEN RAISE EXCEPTION 'Product with ID % does not exist.', p_product_id;
    END IF;
    IF (v_stock < p_quantity)
        THEN RAISE EXCEPTION 'Not enough stock. Available: %', v_stock;
    END IF;
    INSERT INTO order_items (order_id, product_id, quantity, price)
    VALUES (p_order_id, p_product_id, p_quantity, v_price);
    UPDATE products
    SET stock_quantity = stock_quantity - p_quantity
    WHERE product_id = p_product_id;
END;
$$;