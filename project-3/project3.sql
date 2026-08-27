create warehouse enterprise_wh
warehouse_size='XSMALL'
auto_suspend=60
auto_resume=TRUE
initially_suspended=TRUE;

use warehouse enterprise_wh;

create database enterprise_db;

use enterprise_db;

create schema sales_schema;
use schema sales_schema;

create stage enterprise_stage;

create file format csv_format
type='csv'
field_delimiter=','
skip_header=1;

create table dim_customerS(
customer_id int primary key,
customer_name varchar(100),
city varchar(50),
membership varchar(50)
);
CREATE table dim_products(
product_id int primary key,
product_name varchar(100),
category varchar(50),
price number(10,2)
);
create table dim_branches(
branch_id int primary key,
branch_name varchar(100),
state varchar(100)

);
create table fact_sales(
sale_id int primary key,
customer_id int not null,
product_id int not null,
branch_id int not null,
quantity int,
sale_date date,
total_amount number(10,2),

foreign key(customer_id) references dim_customers(customer_id),
foreign key(product_id) references dim_products(product_id),
foreign key(branch_id) references dim_branches(branch_id)
);
create table fact_new_sales(
sale_id int primary key,
customer_id int not null,
product_id int not null,
branch_id int not null,
quantity int,
sale_date date,
total_amount number(10,2),

foreign key(customer_id) references dim_customers(customer_id),
foreign key(product_id) references dim_products(product_id),
foreign key(branch_id) references dim_branches(branch_id)
); 


copy into dim_customers
from @enterprise_stage
files=('customers.csv')
file_format=(format_name='csv_format');

copy into dim_products
from @enterprise_stage
files=('products.csv')
file_format=(format_name='csv_format');

copy into dim_branches
from @enterprise_stage
files=('branches.csv')
file_format=(format_name='csv_format');

copy into fact_sales
from @enterprise_stage
files=('sales.csv')
file_format=(format_name='csv_format');



-- 10.Create a Stream on the SALES table.
create stream sales_stream
on table fact_sales;

-- 11.Load new_sales.csv.
copy into fact_new_sales
from @enterprise_stage
files=('new_sales.csv')
file_format=(format_name='csv_format');

select*from fact_new_sales;

-- 12.Display only newly inserted records using the Stream.
-- 13.Merge newly arrived records into the SALES table
merge into fact_sales s
using fact_new_sales n
on s.sale_id=n.sale_id

when not matched then
insert(sale_id, customer_id, product_id, branch_id, quantity, sale_date, total_amount)
values(n.sale_id, n.customer_id, n.product_id, n.branch_id, n.quantity, n.sale_date, n.total_amount);

select*from sales_stream; 


-- 14.Identify duplicate Sale IDs.
select sale_id, count(*) as cnt from fact_sales
group by sale_id having
count(*)>1;

-- 15.Identify missing Customer IDs.
select s.* from fact_sales s
left join dim_customers c on 
s.customer_id=c.customer_id
where c.customer_id is NULL;

-- 16.Display invalid Product IDs.
select s.* from fact_sales s
left join dim_products p on 
s.product_id=p.product_id
where p.product_id is NULL;


-- 17.Count total newly inserted records.
select count(*) as cnt from fact_new_sales;



-- 18.Delete one sales record.
delete from fact_sales
where sale_id=3;
-- 19.Recover the deleted record using Time Travel.
insert into fact_sales 
select*from fact_sales at(offset=>-60*5) where sale_id=3;
-- 20.Verify recovery.
select*from fact_sales;


-- 21.Create a clone named: SALES_TEST
create table sales_test
clone fact_sales;

-- 22.Display cloned records.
select * from sales_test;
-- 23.Insert one new record into the clone.
insert into sales_test
values(16,1,101,1,2,'2026-07-05',12000);
-- 24.Verify that the original SALES table remains unchanged.
select*from fact_sales;


-- 25.Create a Task that automatically performs incremental loading every day.
create task auto_increment_load
warehouse=enterprise_wh
schedule="USING CRON 0 1 * * * UTC"
as
copy into fact_sales
from @enterprise_stage
files=('new_sales.csv')
file_format=(format_name='csv_format');
-- 26.Resume the Task.

alter task auto_increment_load
resume;
-- 27.Verify Task execution.
show tasks;


-- 28.Customer Revenue Report
select c.customer_id, c.customer_name, sum(s.total_amount) as revenue
from dim_customers c 
join fact_sales s on c.customer_id=s.customer_id
group by c.customer_id, c.customer_name
order by revenue desc;

-- 29.Branch Revenue Report
select b.branch_id, b.branch_name, sum(s.total_amount) as revenue
from dim_branches b 
join fact_sales s on b.branch_id=s.branch_id
group by b.branch_id, b.branch_name
order by revenue desc;


-- 30.Product Revenue Report
select p.product_id, p.product_name, sum(s.total_amount) as revenue
from dim_products p 
join fact_sales s on p.product_id=s.product_id
group by p.product_id, p.product_name
order by revenue desc;

-- 31.Monthly Revenue Report
select month(sale_date), sum(total_amount) as revenue
from fact_sales
group by month(sale_date)
order by revenue desc;

-- 32.Highest Revenue Customer
select customer_id, customer_name, sales from(select c.customer_id, c.customer_name, sum(s.total_amount) as sales,
rank() over(order by sales desc) as rnk
from dim_customers c 
join fact_sales s on c.customer_id=s.customer_id
group by c.customer_id, c.customer_name)t
where rnk=1;

-- 33.Highest Revenue Branch
select branch_id, branch_name, sales from (select b.branch_id, b.branch_name, sum(s.total_amount) as sales,
rank() over(order by sales desc) as rnk
from dim_branches b 
join fact_sales s on b.branch_id=s.branch_id
group by b.branch_id, b.branch_name)t where rnk=1;

-- 34.Top Five Products
select product_name, category,sales from (select p.product_name, p.category, sum(s.total_amount) as sales,
row_number() over(partition by p.category order by sales desc) as rnk
from dim_products p 
join fact_sales s on p.product_id=s.product_id
group by p.category,p.product_name)t where rnk<=5 order by sales desc;

-- 35.Customer Purchase Frequency
select c.customer_id, c.customer_name,
count(s.customer_id) as "purchase frequency"
from dim_customers c
join fact_sales s on c.customer_id=s.customer_id
group by c.customer_id, c.customer_name
order by "purchase frequency" desc, customer_id;

-- 36.Running Revenue
select sale_id, sale_date, total_amount,
sum(total_amount) over(order by sale_date,sale_id rows between unbounded preceding and current row) as running_total
from fact_sales
group by sale_id, sale_date,total_amount;

-- 37.Customer Ranking
select c.customer_id, c.customer_name, sum(s.total_amount) as sales,
rank() over(order by sales desc) as rnk
from dim_customers c 
join fact_sales s on c.customer_id=s.customer_id
group by c.customer_id, c.customer_name;


-- 38.Create View: CUSTOMER_REVENUE
create view customer_revenue as 
select c.customer_id, c.customer_name, sum(s.total_amount) as revenue
from dim_customers c 
join fact_sales s on c.customer_id=s.customer_id
group by c.customer_id, c.customer_name
order by revenue desc;

-- 39.Create Materialized View: BRANCH_REVENUE
create materialized view branch_revenue as
select branch_id, sum(total_amount) as revenue
from fact_sales 

group by branch_id;


-- 40.Display data from both Views.
select * from customer_revenue;

select * from branch_revenue;