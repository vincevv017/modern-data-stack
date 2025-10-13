-- Create suppliers table
CREATE TABLE suppliers (
    id INT PRIMARY KEY,
    supplier_name VARCHAR(100) NOT NULL,
    country VARCHAR(50) NOT NULL,
    region VARCHAR(50) NOT NULL,
    sustainability_score INT DEFAULT 50
);

-- Insert suppliers
INSERT INTO suppliers (id, supplier_name, country, region, sustainability_score) VALUES
(1, 'EcoTech Solutions', 'Germany', 'Europe', 85),
(2, 'GreenWare Co', 'USA', 'North America', 72),
(3, 'Sustainable Goods Ltd', 'UK', 'Europe', 90),
(4, 'NaturalPath Inc', 'Canada', 'North America', 78),
(5, 'EarthFirst Manufacturing', 'Netherlands', 'Europe', 88);

-- Create products table
CREATE TABLE products (
    id INT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    supplier_id INT,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
);

-- Insert products
INSERT INTO products (id, product_name, category, price, supplier_id) VALUES
(501, 'Bamboo Laptop Stand', 'Electronics', 299.99, 1),
(502, 'Recycled Paper Notebook', 'Office', 49.99, 2),
(503, 'Solar Power Bank', 'Electronics', 599.99, 3),
(504, 'Organic Cotton T-Shirt', 'Clothing', 149.99, 4),
(505, 'Reusable Water Bottle', 'Lifestyle', 89.99, 5),
(506, 'Biodegradable Phone Case', 'Electronics', 199.99, 1),
(507, 'Hemp Backpack', 'Accessories', 399.99, 2);

CREATE INDEX idx_products_supplier ON products(supplier_id);
