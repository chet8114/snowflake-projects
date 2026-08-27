create warehouse wh10
warehouse_size='XSMALL'
auto_suspend=60
auto_resume=true
initially_suspended=true;
use warehouse wh10;

create database db10;
use db10;

create schema sc10;

create stage stage10;

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
from @stage10
files=('customers_initial.csv')
file_format=(format_name='csv_format');

copy into customers_updates_table
from @stage10
files=('customer_updates.csv')
file_format=(format_name='csv_format');

select * from customers;
select * from customers_updates_table;




create table customer_dim_type3(
customer_key int autoincrement,
customer_id int,
customer_name varchar(50),
city varchar(50),
state varchar(50),
current_membership varchar(20),
previous_membership varchar(20),
segment varchar(20)
);

insert into customer_dim_type3(
customer_id,
customer_name,
city,
state,
current_membership,
previous_membership,
segment
)
select
customer_id,
customer_name,
city,
state,
membership,
null,
segment
from customers;

select
customer_id,
customer_name,
city,
current_membership,
previous_membership
from customer_dim_type3
order by customer_id;

update customer_dim_type3 t
set
previous_membership=t.current_membership,
current_membership=u.membership,
customer_name=u.customer_name,
city=u.city,
state=u.state,
segment=u.segment
from customers_updates_table u
where t.customer_id=u.customer_id;

select
customer_id,
customer_name,
city,
current_membership,
previous_membership
from customer_dim_type3
order by customer_id;

select
customer_id,
customer_name,
current_membership,
previous_membership
from customer_dim_type3
where customer_id=101;

create table customer_dim_type6(
customer_key int autoincrement,
customer_id int,
customer_name varchar(50),
city varchar(50),
state varchar(50),
current_membership varchar(20),
previous_membership varchar(20),
historical_membership varchar(20),
segment varchar(20),
effective_date date,
expiry_date date,
is_current boolean
);

insert into customer_dim_type6(
customer_id,
customer_name,
city,
state,
current_membership,
previous_membership,
historical_membership,
segment,
effective_date,
expiry_date,
is_current
)
select
customer_id,
customer_name,
city,
state,
membership,
null,
membership,
segment,
'2026-01-01',
'9999-12-31',
true
from customers;

update customer_dim_type6 t
set
expiry_date=dateadd(day,-1,u.effective_date),
is_current=false
from customers_updates_table u
where t.customer_id=u.customer_id
and t.is_current=true;

insert into customer_dim_type6(
customer_id,
customer_name,
city,
state,
current_membership,
previous_membership,
historical_membership,
segment,
effective_date,
expiry_date,
is_current
)
select
u.customer_id,
u.customer_name,
u.city,
u.state,
u.membership,
t.current_membership,
u.membership,
u.segment,
u.effective_date,
'9999-12-31',
true
from customers_updates_table u
join customer_dim_type6 t
on u.customer_id=t.customer_id
and t.is_current=false
and t.expiry_date=dateadd(day,-1,u.effective_date);

select
customer_id,
customer_name,
current_membership,
previous_membership,
effective_date,
expiry_date,
is_current
from customer_dim_type6
order by customer_id,effective_date;

select
customer_id,
customer_name,
city,
current_membership,
previous_membership
from customer_dim_type6
where is_current=true
order by customer_id;

select
customer_id,
customer_name,
current_membership,
effective_date,
expiry_date
from customer_dim_type6
where customer_id=101
and '2026-03-15' between effective_date and expiry_date;

select
'SCD TYPE 3' as scd_type,
'YES' as current_value,
'YES' as previous_value,
'NO' as historical_rows,
'NO' as effective_date,
'NO' as expiry_date,
'NO' as is_current
union all
select
'SCD TYPE 6',
'YES',
'YES',
'YES',
'YES',
'YES',
'YES';

select count(*) as scd_type_3_record_count
from customer_dim_type3;

select count(*) as scd_type_6_record_count
from customer_dim_type6;

select count(*) as scd_type_6_current_record_count
from customer_dim_type6
where is_current=true;

select count(*) as scd_type_6_historical_record_count
from customer_dim_type6
where is_current=false;