create warehouse wh_hospital1
warehouse_size='XSMALL'
auto_suspend=60
auto_resume=TRUE
initially_suspended=TRUE;

use warehouse wh_hospital1;

create database db_hospital;
use db_hospital;

create schema hospital_schema;
use schema hospital_schema;


create stage hospital_stage;


create file format csv_format
type='csv'
field_delimiter=','
skip_header=1;


create table patients(
patient_id varchar primary key,
patient_name varchar,
gender varchar,
city varchar,
state varchar
);

create table doctors(
doctor_id varchar primary key,
doctor_name varchar,
specialization varchar
);

create table hospitals(
hospital_id varchar primary key,
hospital_name varchar,
city varchar,
state varchar,
region varchar
);

create table departments(
department_id varchar primary key,
department_name varchar
);

create table treatments(
treatment_id varchar primary key,
treatment_name varchar,
treatment_category varchar
);

create table admissions(
admission_id varchar primary key,
patient_id varchar not null,
doctor_id varchar not null,
hospital_id varchar not null,
department_id varchar not null,
admission_date date,
discharge_date date,

foreign key(patient_id) references patients(patient_id),
foreign key(doctor_id) references doctors(doctor_id),
foreign key(hospital_id) references hospitals(hospital_id),
foreign key(department_id) references departments(department_id)
);

create table billings(
admission_id varchar not null,
patient_id varchar not null,
doctor_id varchar not null,
hospital_id varchar not null,
department_id varchar not null,
treatment_id varchar not null,
admission_date date,
discharge_date date,
quantity int,
treatment_amount int,
discount int,


foreign key(patient_id) references patients(patient_id),
foreign key(doctor_id) references doctors(doctor_id),
foreign key(hospital_id) references hospitals(hospital_id),
foreign key(department_id) references departments(department_id),
foreign key(treatment_id) references treatments(treatment_id)
);

copy into patients
from @hospital_stage
files=('patients.csv')
file_format=(format_name='csv_format');

copy into doctors
from @hospital_stage
files=('doctors.csv')
file_format=(format_name='csv_format');

copy into hospitals 
from @hospital_stage
files=('hospitals.csv')
file_format=(format_name='csv_format');

copy into departments
from @hospital_stage
files=('departments.csv')
file_format=(format_name='csv_format');

copy into treatments
from @hospital_stage
files=('treatments.csv')
file_format=(format_name='csv_format');

copy into admissions
from @hospital_stage
files=('admissions.csv')
file_format=(format_name='csv_format');

copy into billings
from @hospital_stage
files=('billings2.csv')
file_format=(format_name='csv_format');

create table dim_patients(
patient_key int primary key autoincrement,
patient_id varchar(10) not null,
patient_name varchar(50),
gender varchar(20),
city varchar(20),
state varchar(20)
);


create table dim_doctors(
doctor_key int primary key autoincrement,
doctor_id varchar(10) not null,
doctor_name varchar(50),
specialization varchar(20)
);

create table dim_hospitals(
hospital_key int primary key autoincrement,
hospital_id varchar(10) not null,
hospital_name varchar(100),
city varchar(20),
state varchar(20),
region varchar(20)
);

create table dim_departments(
department_key int primary key autoincrement,
department_id varchar(10) not null,
department_name varchar(50)
);

create table dim_treatments(
treatment_key int primary key autoincrement,
treatment_id varchar(10) not null,
treatment_name varchar(50),
treatment_category varchar(50)
);

create table dim_date(
date_key varchar primary key,
full_date date,
day int,
day_name varchar(20),
week_no int,
month int,
month_name varchar(20),
quarter varchar(5),
year int
);

create table fact_admissions(
admission_key int primary key autoincrement,
patient_key int not null,
doctor_key int not null,
hospital_key int not null,
department_key int not null,
date_key varchar not null,
admission_count int,
length_of_stay int, 


foreign key(patient_key) references dim_patients(patient_key),
foreign key(doctor_key) references dim_doctors(doctor_key),
foreign key(hospital_key) references dim_hospitals(hospital_key),
foreign key(department_key) references dim_departments(department_key),
foreign key(date_key) references dim_date(date_key)
);

create table fact_billings(
billing_key int primary key autoincrement,
patient_key int not null,
doctor_key int not null,
hospital_key int not null,
department_key int not null,
treatment_key int not null,
date_key varchar not null,
quantity int,
treatment_amount int,
discount int,
net_amount int,

foreign key(patient_key) references dim_patients(patient_key),
foreign key(doctor_key) references dim_doctors(doctor_key),
foreign key(hospital_key) references dim_hospitals(hospital_key),
foreign key(department_key) references dim_departments(department_key),
foreign key(treatment_key) references dim_treatments(treatment_key),
foreign key(date_key) references dim_date(date_key)

);

insert into dim_patients(patient_id, patient_name, gender, city, state)
select patient_id, patient_name, gender, city, state from patients;

insert into dim_doctors(doctor_id, doctor_name, specialization)
select doctor_id, doctor_name, specialization from doctors;

insert into dim_hospitals(hospital_id, hospital_name, city, state, region)
select hospital_id, hospital_name, city, state, region from hospitals;

insert into dim_departments(department_id, department_name)
select department_id, department_name from departments;

insert into dim_treatments(treatment_id, treatment_name, treatment_category)
select treatment_id, treatment_name, treatment_category from treatments;

insert into dim_date(date_key, full_date, day, day_name, week_no, month, month_name, quarter, year)
select to_varchar(full_date, 'YYYYMMDD') as date_key,
full_date, day(full_date) as day, dayname(full_date) as day_name, week(full_date) as week_no, month(full_date) as month,
monthname(full_date) as month_name, 'Q' || quarter(full_date) as quarter, year(full_date) as year from (
select dateadd(day, seq4(), '2026-01-01') as full_date
from table(generator(rowcount=>90))
)t; 

insert into fact_admissions(patient_key, doctor_key, hospital_key, department_key, date_key, admission_count, length_of_stay)
select p.patient_key, d.doctor_key, h.hospital_key, dp.department_key, dt.date_key, 1 as admission_count, (a.discharge_date-a.admission_date)
as length_of_stay
from admissions a 
join dim_patients p on a.patient_id=p.patient_id
join dim_doctors d on a.doctor_id=d.doctor_id
join dim_hospitals h on a.hospital_id=h.hospital_id
join dim_departments dp on a.department_id=dp.department_id
join dim_date dt on a.admission_date=dt.full_date;

select*from fact_admissions;

insert into fact_billings(patient_key, doctor_key, hospital_key, department_key, treatment_key, date_key, quantity, treatment_amount, discount, net_amount)
select p.patient_key, d.doctor_key, h.hospital_key, dp.department_key, t.treatment_key, dt.date_key, 1 as quantity, b.treatment_amount,
b.discount, (b.treatment_amount-b.discount) as net_amount
from billings b 
join dim_patients p on b.patient_id=p.patient_id
join dim_doctors d on b.doctor_id=d.doctor_id
join dim_hospitals h on b.hospital_id=h.hospital_id
join dim_departments dp on b.department_id=dp.department_id
join dim_treatments t on b.treatment_id=t.treatment_id
join dim_date dt on b.admission_date=dt.full_date;


select*from fact_billings;

-- hospital wise total admissions
select h.hospital_name, sum(a.admission_count) as total_admissions
from fact_admissions a 
join dim_hospitals h on a.hospital_key=h.hospital_key
group by h.hospital_name
order by total_admissions desc;

-- Hospital Revenue Analytics
select h.hospital_name, sum(b.net_amount) as total_revenue
from fact_billings b 
join dim_hospitals h on b.hospital_key=h.hospital_key
group by h.hospital_name
order by total_revenue desc;

-- monthly hospitals revenue
select to_varchar(dt.full_date, 'YYYY-MM') as month, sum(b.net_amount)
as total_revenue 
from fact_billings b
join dim_date dt on b.date_key=dt.date_key
group by to_varchar(dt.full_date, 'YYYY-MM')
order by total_revenue desc;

-- Doctor-wise Revenue
select d.doctor_name, sum(b.net_amount) as total_revenue
from fact_billings b 
join dim_doctors d on b.doctor_key=d.doctor_key
group by d.doctor_name;

-- compare:Total Admissions and Total Revenue by Hospital
with adm_summary as(
select h.hospital_key, sum(a.admission_count) as total_admissions
from dim_hospitals h 
join fact_admissions a on h.hospital_key=a.hospital_key
group by h.hospital_key
order by total_admissions desc
),

bill_summary as(
select h.hospital_key, sum(b.net_amount) as total_revenue
from dim_hospitals h 
join fact_billings b on h.hospital_key=b.hospital_key
group by h.hospital_key
order by total_revenue desc
)

select h.hospital_name, a.total_admissions, b.total_revenue
from dim_hospitals h 
join adm_summary a on h.hospital_key=a.hospital_key
join bill_summary b on h.hospital_key=b.hospital_key
order by a.total_admissions desc;