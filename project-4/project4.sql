create warehouse sales_wh4
warehouse_size='xsmall'
auto_suspend=60
auto_resume=true
initially_suspended=true;

use warehouse sales_wh4;

create database sales_db4;

use sales_db4;

create schema sales_schema4;
use schema sales_schema4;

create stage sales_stage4;

create file format csv_format
type='csv'
field_delimiter=','
skip_header=1;

create table dim_customers(
customer_id int primary key ,
customer_name varchar(50),
city varchar(50),
state varchar(50),
membership varchar(50)
);

create table dim_products(
product_id int primary key,
product_name varchar(50),
category varchar(50),
brand varchar(50),
price int
);

create table dim_branches(
branch_id int primary key,
branch_name varchar(50),
city varchar(50),
state varchar(50),
region varchar(50),
manager_name varchar(50)
);

create table dim_calendar(
date_id int primary key,
date date,
day varchar(50),
day_name varchar(50),
week_no int,
month varchar(50),
quarter varchar(20),
year int,
is_weekend boolean
);

create table fact_sales(
sale_id int primary key,
customer_id int not null,
product_id int not null,
branch_id int not null,
date_id int not null,
quantity int,
total_amount int,
foreign key(customer_id) references dim_customers(customer_id),
foreign key(product_id) references dim_products(product_id),
foreign key(date_id) references dim_calendar(date_id),
foreign key(branch_id) references dim_branches(branch_id)
);
copy into dim_customers
from @sales_stage4
files=('customers.csv')
file_format=(format_name='csv_format');

copy into dim_branches
from @sales_stage4
files=('branches.csv')
file_format=(format_name='csv_format');

copy into dim_products
from @sales_stage4
files=('products.csv')
file_format=(format_name='csv_format');

copy into dim_calendar
from @sales_stage4
files=('calendar.csv')
file_format=(format_name='csv_format');

copy into fact_sales
from @sales_stage4
files=('sales.csv')
file_format=(format_name='csv_format');

-- Customer-wise Sales Report
select c.customer_id,sum(s.total_amount) as tot_am
from dim_customers c 
inner join fact_sales s 
on c.customer_id=s.customer_id 
group by c.customer_id
order by tot_am desc;
-- Product-wise Revenue Report
select p.product_name ,sum(s.total_amount) as pro_amount 
from dim_products p
inner join fact_sales s
on p.product_id=s.product_id
group by p.product_id,p.product_name
order by pro_amount desc;
-- Branch-wise Sales Report
select b.branch_name,sum(s.total_amount) as branch_rev
from dim_branches b
inner join fact_sales s
on b.branch_id=s.branch_id
group by b.branch_id,b.branch_name
order by branch_rev desc;
-- Monthly Revenue Report
select c.month,sum(s.total_amount) as month_rev
from dim_calendar c 
inner join 
fact_sales s on 
c.date_id=s.date_id
group by c.month
order by month_rev desc;

-- State-wise Revenue Report
select b.state,sum(s.total_amount) as state_rev
from dim_branches b
inner join fact_sales s
on b.branch_id=s.branch_id
group by b.branch_id,b.state
order by state_rev desc;

-- Category-wise Revenue Report
select p.category ,sum(s.total_amount) as cat_rev 
from dim_products p
inner join fact_sales s
on p.product_id=s.product_id
group by p.category
order by cat_rev desc;
-- Top 10 Customers based on Total Sales
select c.customer_name,sum(s.total_amount) as tot_am
from dim_customers c 
inner join fact_sales s 
on c.customer_id=s.customer_id 
group by c.customer_id,customer_name
order by tot_am desc limit 10;

-- Top 10 Products based on Revenue
select p.product_name ,sum(s.total_amount) as pro_amount 
from dim_products p
inner join fact_sales s
on p.product_id=s.product_id
group by p.product_id,p.product_name
order by pro_amount desc limit 10;

-- Top 10 Performing Branches
select b.branch_name,sum(s.total_amount) as branch_rev
from dim_branches b
inner join fact_sales s
on b.branch_id=s.branch_id
group by b.branch_id,b.branch_name
order by branch_rev desc limit 10;

