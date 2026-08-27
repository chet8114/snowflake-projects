create warehouse sales_wh2
warehouse_size='xsmall'
auto_suspend=60
auto_resume=true
initially_suspended=true;

use warehouse sales_wh2;

create database sales_db2;

use sales_db2;

create schema sales_schema2;
use schema sales_schema2;

create stage sales_stage1;

create file format csv_format
type='csv'
field_delimiter=','
skip_header=1;

create table dim_customers(
customer_id int primary key ,
customer_name varchar(50),
city varchar(50),
membership varchar(50)
);

create table dim_products(
product_id int primary key,
product_name varchar(50),
category varchar(50),
price int
);

create table dim_branches(
branch_id int primary key,
branch_name varchar(50),
city varchar(50)
);

create table fact_sales(
sale_id int primary key,
customer_id int not null,
product_id int not null,
branch_id int not null,
quantity int,
sale_date date,
total_amount int,

foreign key(customer_id) references dim_customers(customer_id),
foreign key(product_id) references dim_products(product_id),
foreign key(branch_id) references dim_branches(branch_id)
);

copy into dim_customers
from @sales_stage1
files=('customers.csv')
file_format=(format_name='csv_format')

copy into dim_branches
from @sales_stage1
files=('branches.csv')
file_format=(format_name='csv_format')

copy into dim_products
from @sales_stage1
files=('products.csv')
file_format=(format_name='csv_format')

copy into fact_sales
from @sales_stage1
files=('sales.csv')
file_format=(format_name='csv_format')

-- =========================================================================================================================================
-- Display all customers.
select * from dim_customers;

-- Display all products.
select * from dim_products;

-- Display all branches.
select * from dim_branches;

-- Display all sales transactions.
select * from fact_sales;

-- Calculate total business revenue.
select sum(total_amount) as total_business_rev from fact_sales;

-- Generate customer-wise sales.
select c.customer_name,sum(s.total_amount) 
from dim_customers c inner join fact_sales s
on c.customer_id=s.customer_id
group by c.customer_name;

-- Generate branch-wise sales.
select b.branch_name,sum(s.total_amount) 
from dim_branches b inner join fact_sales s
on b.branch_id=s.branch_id
group by b.branch_name;

-- Generate product-wise sales.
select p.product_name,sum(s.total_amount)
from dim_products p inner join fact_sales s
on p.product_id=s.product_id
group by p.product_name;

-- Generate category-wise sales.
select p.category,sum(s.total_amount) as category_rev
from dim_products p inner join fact_sales s
on p.product_id=s.product_id
group by p.category;

-- Display the highest revenue branch.
select b.branch_name,sum(s.total_amount) as high_rev
from dim_branches b inner join fact_sales s
on b.branch_id=s.branch_id
group by b.branch_name order by high_rev desc limit 1;

-- Display the highest spending customer.
select c.customer_name,sum(s.total_amount) as cus_rev
from dim_customers c inner join fact_sales s
on c.customer_id=s.customer_id
group by c.customer_name order by cus_rev desc limit 1;

-- Display the top three products by revenue.
select p.product_name,sum(s.total_amount) as pro_rev
from dim_products p inner join fact_sales s
on p.product_id=s.product_id
group by p.product_name order by pro_rev desc limit 3;

-- Display the top three customers by spending.
select c.customer_name,sum(s.total_amount) as cus_rev
from dim_customers c inner join fact_sales s
on c.customer_id=s.customer_id
group by c.customer_name order by cus_rev desc limit 3;

-- Phase-4: Window Functions
-- ---------------------------
-- Rank customers based on total spending.
SELECT
    customer_name,
    total_spending,
    RANK() OVER (ORDER BY total_spending DESC) AS customer_rank
FROM
(
    SELECT
        c.customer_name,
        SUM(s.total_amount) AS total_spending
    FROM dim_customers c
    INNER JOIN fact_sales s
        ON c.customer_id = s.customer_id
    GROUP BY c.customer_name
) AS t;

-- Rank branches based on total sales.

-- Display the top-selling product in each category using ROW_NUMBER().
-- Calculate cumulative sales using SUM() OVER().
-- Calculate the average sale amount using AVG() OVER().


-- Phase-5: CTE
-- --------------
-- Generate customer-wise revenue using a Common Table Expression (CTE).
WITH CustomerSpending AS
(
    SELECT
        c.customer_name,
        SUM(s.total_amount) AS total_spending
    FROM dim_customers c
    INNER JOIN fact_sales s
        ON c.customer_id = s.customer_id
    GROUP BY c.customer_name
)
SELECT
    customer_name,
    total_spending,
    RANK() OVER (ORDER BY total_spending DESC) AS customer_rank
FROM CustomerSpending;
-- Display customers whose spending is greater than the average spending.


-- Phase-6: Views
-- -----------------
-- Create a View named SALES_REPORT.
create view SALES_REPORT as select * from fact_sales;
-- Create a Materialized View named TOP_CUSTOMERS.
create materialized view top_customers as select customer_id,sum(total_amount) as sales from fact_sales group by customer_id;
-- Query both views.
select * from sales_report;
select t.customer_id,t.sales,c.customer_name from top_customers t join dim_customers c on t.customer_id=c.customer_id order by t.sales desc;