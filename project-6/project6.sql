create warehouse rev_wh
warehouse_size='XSMALL'
auto_suspend=60
auto_resume=TRUE
initially_suspended=True;

use warehouse rev_wh;

create database rev_db;

use rev_db;

create schema rev_schema;

use schema rev_schema;

create stage rev_stage;

create file format csv_format
type='csv'
field_delimiter=','
skip_header=1;

create table customers(
customer_id int primary key,
customer_name varchar(100),
city varchar(50),
state varchar(50),
membership varchar(50)
);

create table products(
product_id int primary key,
product_name varchar(100),
category varchar(50),
brand varchar(50),
price number(10,2)
);

create table t_branches(
branch_id int primary key,
branch_name varchar(100),
city varchar(50),
state varchar(50),
region  varchar(50),
manager_name varchar(50)
);

create table t_date(
date_id int primary key,
date date,
day int,
day_name varchar(50),
week_no int,
month varchar(20),
quarter varchar(5),
year int,
is_weekend boolean

);

create table sales(
sale_id int primary key,
customer_id int not null,
product_id int not null,
branch_id int not null,
date_id int not null,
quantity int,
total_amount number(10,2),

foreign key(customer_id) references customers(customer_id),
foreign key(product_id) references products(product_id),
foreign key(branch_id) references t_branches(branch_id),
foreign key(date_id) references t_date(date_id)

);
copy into customers
from @rev_stage
files=('customers.csv')
file_format=(format_name='csv_format');

copy into products
from @rev_stage
files=('products.csv')
file_format=(format_name='csv_format');

copy into t_branches
from @rev_stage
files=('branches.csv')
file_format=(format_name='csv_format');

copy into t_date
from @rev_stage
files=('calendar.csv')
file_format=(format_name='csv_format');

copy into sales
from @rev_stage
files=('sales.csv')
file_format=(format_name='csv_format');

-- create dimensions and look ups

create table dim_state(
state_id int primary key autoincrement,
state_name varchar(50)
);

create table dim_city(
city_id int primary key autoincrement,
city_name varchar(50),
state_id int not null,

foreign key(state_id) references dim_state(state_id)
);



create table dim_customers(
customer_id int primary key,
customer_name varchar(100),
membership varchar(50),
city_id int not null,

foreign key(city_id) references dim_city(city_id)
);

create table dim_category(
category_id int primary key autoincrement,
category_name varchar(50)
);

create table dim_brand(
brand_id int primary key autoincrement,
brand_name varchar(50)

);

create table dim_products(
product_id int primary key,
product_name varchar(100),
price number(10,2),
brand_id int not null,
category_id int not null,

foreign key(brand_id) references dim_brand(brand_id),
foreign key(category_id) references dim_category(category_id)
);

create table dim_region(
region_id int primary key autoincrement,
region_name varchar(50)
);

alter table dim_state
add region_id int not null;
alter table dim_state
add foreign key(region_id) references dim_region(region_id);


create table dim_branches(
branch_id int primary key,
branch_name varchar(100),
manager_name varchar(50),
city_id int not null,

foreign key(city_id) references dim_city(city_id)
);


create table dim_year(
year_id int primary key autoincrement,
year int
); 

create table dim_quarter(
quarter_id int primary key autoincrement,
quarter varchar(5),
year_id int not null,

constraint uk_quarter unique(quarter, year_id),

foreign key(year_id) references dim_year(year_id)
);

create table dim_month(
month_id int primary key autoincrement,
month_name varchar(20),
quarter_id int not null,

constraint uk_month unique(month_name, quarter_id),

foreign key(quarter_id) references dim_quarter(quarter_id)
);

create table dim_date(
date_id int primary key,
date date,
day int,
day_name varchar(50),
week_no int,
is_weekend boolean,
month_id int not null,

foreign key(month_id) references dim_month(month_id)
);

alter table sales
rename to fact_sales;

insert into dim_region(region_name)
select distinct region from t_branches;

select*from dim_region;

insert into dim_state(state_name, region_id)
select distinct b.state, r.region_id
from t_branches b
join dim_region r on b.region=r.region_name;

select*from dim_state;

insert into dim_city(city_name,state_id)
select distinct b.city, s.state_id
from t_branches b
join dim_state s on b.state=s.state_name;

select * from dim_city;

insert into dim_branches(branch_id, branch_name, manager_name, city_id)
select t.branch_id, t.branch_name, t.manager_name, c.city_id
from t_branches t
join dim_state s on t.state=s.state_name
join dim_city c on t.city=c.city_name
and c.state_id=s.state_id;

select*from dim_branches;

insert into dim_category(category_name)
select distinct category from products;

select*from dim_category;

insert into dim_brand(brand_name)
select distinct p.brand from products p;


select*from dim_brand;

insert into dim_products(product_id, product_name, price, brand_id, category_id)
select p.product_id, p.product_name, p.price, b.brand_id, c.category_id
from products p 
join dim_category c on p.category=c.category_name
join dim_brand b on p.brand=b.brand_name;

select*from dim_products;

insert into dim_customers(customer_id, customer_name, membership, city_id)
select c.customer_id, c.customer_name, c.membership, d.city_id
from customers c 
join dim_state s on c.state=s.state_name
join dim_city d on c.city=d.city_name
and s.state_id=d.state_id;

select*from dim_customers;

insert into dim_year(year)
select distinct year from t_date;

select*from dim_year;

insert into dim_quarter(quarter, year_id)
select distinct d.quarter, y.year_id
from t_date d
join dim_year y on d.year=y.year;

select*from dim_quarter;

insert into dim_month(month_name, quarter_id)
select distinct d.month, q.quarter_id from 
t_date d
join dim_year y on d.year=y.year
join dim_quarter q on d.quarter=q.quarter
and q.year_id=y.year_id;

select*from dim_month;

insert into dim_date(date_id, date, day, day_name, week_no, is_weekend, month_id)
select d.date_id, d.date, d.day, d.day_name, d.week_no, d.is_weekend, m.month_id
from t_date d
join dim_year y on d.year=y.year
join dim_quarter q on d.quarter=q.quarter
and q.year_id=y.year_id
join dim_month m on d.month=m.month_name
and m.quarter_id=q.quarter_id;

select*from dim_date;


-- =================================================================================================


-- Customer-wise Sales Report
select c.customer_id, c.customer_name, sum(s.total_amount) as sales
from dim_customers c
join fact_sales s on c.customer_id=s.customer_id
group by c.customer_id, c.customer_name
order by sales desc;

-- Product-wise Revenue Report
select p.product_id, p.product_name, sum(s.total_amount) as revenue
from dim_products p
join fact_sales s on p.product_id=s.product_id
group by p.product_id, p.product_name
order by revenue desc;

-- Brand-wise Revenue Report
select b.brand_id, b.brand_name, sum(s.total_amount) as revenue
from dim_brand b
join dim_products p on b.brand_id=p.brand_id
join fact_sales s on p.product_id=s.product_id
group by b.brand_id, b.brand_name
order by revenue desc;

-- Category-wise Revenue Report
select c.category_id, c.category_name, sum(s.total_amount) as revenue
from dim_category c
join dim_products p on c.category_id=p.category_id
join fact_sales s on p.product_id=s.product_id
group by c.category_id, c.category_name
order by revenue desc;

-- City-wise Sales Report
select c.city_id, c.city_name, sum(s.total_amount) as sales
from dim_city c
join dim_customers cu on c.city_id=cu.city_id
join fact_sales s on cu.customer_id=s.customer_id
group by c.city_id, c.city_name
order by sales desc;

-- State-wise Revenue Report
select st.state_id, st.state_name, sum(s.total_amount) as revenue
from dim_state st
join dim_city ci on st.state_id=ci.state_id
join dim_customers c on ci.city_id=c.city_id
join fact_sales s on c.customer_id=s.customer_id
group by st.state_id, st.state_name
order by revenue desc;

-- Region-wise Revenue Report
select r.region_id, r.region_name, sum(s.total_amount) as revenue
from dim_region r
join dim_state st on r.region_id=st.region_id
join dim_city ci on st.state_id=ci.state_id
join dim_branches b on ci.city_id=b.city_id
join fact_sales s on b.branch_id=s.branch_id
group by r.region_id, r.region_name
order by revenue desc;

-- Monthly Revenue Report
select m.month_id, m.month_name, sum(s.total_amount) as revenue
from dim_month m 
join dim_date d on m.month_id=d.month_id
join fact_sales s on d.date_id=s.date_id
group by m.month_id, m.month_name
order by revenue desc;

-- Quarterly Revenue Report
select q.quarter_id, q.quarter, sum(s.total_amount) as revenue
from dim_quarter q 
join dim_month m on q.quarter_id=m.quarter_id
join dim_date d on m.month_id=d.month_id
join fact_sales s on d.date_id=s.date_id
group by q.quarter_id, q.quarter
order by revenue desc;

-- Top 10 Customers
select customer_id, customer_name, sales from (select c.customer_id, c.customer_name, sum(s.total_amount) as sales,
dense_rank() over(order by sales desc) as rnk
from dim_customers c
join fact_sales s on c.customer_id=s.customer_id
group by c.customer_id, c.customer_name)t where rnk<=10;

-- Top 10 Products
select product_id, product_name, revenue from (select p.product_id, p.product_name, sum(s.total_amount) as revenue,
dense_rank() over(order by revenue desc) as rnk
from dim_products p
join fact_sales s on p.product_id=s.product_id
group by p.product_id, p.product_name)t where rnk<=10;

-- Top 10 Branches
select branch_id, branch_name, revenue from (select b.branch_id, b.branch_name, sum(s.total_amount) as revenue,
dense_rank() over(order by revenue desc) as rnk
from dim_branches b 
join fact_sales s on b.branch_id=s.branch_id
group by b.branch_id, b.branch_name)t where rnk<=10;