create warehouse wh9
warehouse_size='XSMALL'
auto_suspend=60
auto_resume=true
initially_suspended=true;

use warehouse wh9;

create database db9;
use db9;

create schema sc9;
use schema sc9;

create stage stage9;

create file format csv_format
type='csv'
field_delimiter=','
skip_header=1;

create table customers(
customer_id int primary key,
customer_name varchar(50),
city varchar(20),
state varchar(20),
membership varchar(20),
segment varchar(20)
);


create table customers_updates_table(
customer_id int primary key,
customer_name varchar(50),
city varchar(20),
state varchar(20),
membership varchar(20),
segment varchar(20),
effective_date date
);

copy into customers
from @stage9
files=('customers_initial.csv')
file_format=(format_name='csv_format');

copy into customers_updates_table
from @stage9
files=('customer_updates.csv')
file_format=(format_name='csv_format');

select * from customers;
select * from customers_updates_table;

create table dim_customers_1(
customer_key int primary key autoincrement,
customer_id int not null,
customer_name varchar(50),
city varchar(20),
state varchar(20),
membership varchar(20),
segment varchar(20)
);

create table dim_customers_2(
customer_key int primary key autoincrement,
customer_id int not null,
customer_name varchar(50),
city varchar(20),
state varchar(20),
membership varchar(20),
segment varchar(20),
effective_date date,
expiry_date date,
is_current boolean default TRUE
);

insert into dim_customers_1(customer_id, customer_name, city, state, membership, segment)
select customer_id, customer_name, city, state, membership, segment from customers;

merge into dim_customers_1 d 
using customers_updates_table c on
d.customer_id=c.customer_id

when matched then update set
d.city=c.city,
d.state=c.state,
d.membership=c.membership,
d.segment=c.segment;

select*from dim_customers_1 order by customer_id;

insert into dim_customers_2(customer_id, customer_name, city, state, membership, segment, effective_date, expiry_date)
select customer_id, customer_name, city, state, membership, segment, '2026-01-01', '9999-12-31' from customers;

merge into dim_customers_2 d
using customers_updates_table c on
d.customer_id=c.customer_id

when matched then update set 
d.expiry_date=c.effective_date-1,
d.is_current=FALSE;

insert into dim_customers_2(customer_id, customer_name, city, state, membership, segment, effective_date, expiry_date)
select c.customer_id, c.customer_name, c.city, c.state, c.membership, c.segment, c.effective_date, '9999-12-31' from customers_updates_table c;

select*from dim_customers_2 order by customer_id;

-- Display Current Customer Records
select customer_id,customer_name,city,state,membership,segment from dim_customers_2 where is_current=TRUE order by customer_id;


--  Historical Customer Analysis: What was Customer 101's membership on March 15, 2026?
select customer_id, membership from dim_customers_2
where '2026-03-15' between effective_date and expiry_date
and customer_id=101;
 