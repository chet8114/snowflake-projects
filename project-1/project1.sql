-- creating a warehouse with 4 key terms
create warehouse sales_wh1
warehouse_size='xsmall'
auto_suspend=60
auto_resume=true
initially_suspended=true;

-- using the warehouse
use warehouse sales_wh1;

-- creating a database
create database sales_db1;
use sales_db1;

create schema sales_schema1;
use schema sales_schema1;

create stage sales_stage1;

create file format csv_format
type='csv'
field_delimiter=','
skip_header=1;

create table dim_customers(
customer_id int primary key,
first_name varchar(50),
last_name varchar(50),
email varchar(50),
phone varchar(15),
address varchar(100)
);

create table dim_fooditems(
food_id int primary key,
name varchar(50),
price int,
category varchar(50),
availability varchar(50)
);

create table fact_orders(
order_id int primary key,
customer_id int not null,
food_id int not null,
quantity int,
order_date timestamp,
status varchar(50),
total_amount int,

foreign key(customer_id) references dim_customers(customer_id),
foreign key(food_id) references dim_fooditems(food_id)
)

copy into dim_customers
from @sales_stage1
files=('customers.csv')
file_format=(format_name='csv_format')

copy into dim_fooditems
from @sales_stage1
files=('fooditems.csv')
file_format=(format_name='csv_format')

copy into fact_orders
from @sales_stage1
files=('orders.csv')
file_format=(format_name='csv_format')

-- =========================================================================================================================
-- Task 11:Display all customer details.
select * from dim_customers;

-- Task 12:Display all food item details.
select * from dim_fooditems;

-- Task 13:Display all order details.
select * from fact_orders;

-- Task 14:Generate a Customer-wise Sales Report showing:
-- Customer ID
-- Customer Name
-- Total Amount Spent
select c.customer_id,concat(c.first_name,' ',c.last_name) as customer_name,sum(o.total_amount) as total_spents
from dim_customers c inner join fact_orders o 
on c.customer_id=o.customer_id
group by c.customer_id,customer_name;


-- Task 15:Find the Highest Spending Customer.
select c.customer_id,concat(c.first_name,' ',c.last_name) as customer_name,sum(o.total_amount) as total_spents
from dim_customers c inner join fact_orders o 
on c.customer_id=o.customer_id
group by c.customer_id,customer_name order by total_spents desc limit 1;

-- Task 16:Calculate the Total Business Revenue.
select sum(total_amount) as total_business_revenue from fact_orders;

-- Task 17:Generate a Category-wise Revenue Report.
-- The report should display:
-- Food Category
-- Total Revenue
select f.category,sum(o.total_amount) as total_revenue
from dim_fooditems f inner join fact_orders o 
on f.food_id=o.food_id
group by f.category;

-- Task 18:Generate an Order Status-wise Revenue Report.
-- The report should display:
-- Order Status
-- Total Revenue
select status,sum(total_amount) from fact_orders group by status;

-- Task 19:Display the Top Three Customers based on their total spending.
select c.customer_id,concat(c.first_name,' ',c.last_name) as customer_name,sum(o.total_amount) as total_spents
from dim_customers c inner join fact_orders o 
on c.customer_id=o.customer_id
group by c.customer_id,customer_name order by total_spents desc limit 3;

-- Task 20:Generate a Customer Purchase Frequency Report showing:
-- Customer ID
-- Customer Name
-- Number of Orders Placed
select c.customer_id,concat(c.first_name,' ',c.last_name) as customer_name,count(o.order_id) as no_of_orders
from dim_customers c inner join fact_orders o
on c.customer_id=o.customer_id
group by c.customer_id,customer_name;

-- Task 21:Display all Delivered Orders only.
select * from fact_orders where status='Delivered';

-- Task 22:Display all orders placed after 12 July 2026.
select * from fact_orders where order_date > '2026-07-12';

-- Phase 4: Views
-- ---------------
-- Task 23:Create a View named CUSTOMER_SALES_REPORT containing:
-- Customer ID
-- Customer Name
-- Total Amount Spent
create view CUSTOMER_SALES_REPORT as
select c.customer_id,concat(c.first_name,' ',c.last_name) as customer_name,sum(o.total_amount) as total_spents
from dim_customers c inner join fact_orders o 
on c.customer_id=o.customer_id
group by c.customer_id,customer_name;


-- Task 24:Retrieve all records from the created View.
select * from CUSTOMER_SALES_REPORT;

-- Task 25:Sort the View data in descending order of Total Amount Spent.
select * from CUSTOMER_SALES_REPORT order by total_spents desc;