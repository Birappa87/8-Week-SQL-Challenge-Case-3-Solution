select *
from plans

select *
from subscriptions
--What plan start_date values occur after the year 2020 for our dataset? 
--Show the breakdown by count of events for each plan_name
select
	s.plan_id,
	p.plan_name,
	count(s.plan_id) as no_events
from plans p inner join subscriptions s
	on p.plan_id = s.plan_id
where s.start_date > '2000-01-01'
group by s.plan_id, p.plan_name
order by s.plan_id;


--What is the monthly distribution of trial plan start_date values for our dataset 
--- use the start of the month as the group by value
select 
	datepart(month,start_date) as month,
	datename(month,start_date) as month_name,
	count(distinct customer_id) as no_of_customers
from subscriptions
where plan_id = 0
group by datename(month,start_date),
		datepart(month,start_date)
order by month;

----What is the customer count and percentage of customers who have churned rounded to 1 decimal place?

--Total number of distinct customer count 
-- total no of churned customers 
-- no_of_churned customers / total * 100

with cte as(
	select
		count(distinct s.customer_id) as count_of_customer_churned,
		(select count(distinct customer_id) from subscriptions) as total_customers
	from plans p inner join subscriptions s
		on p.plan_id = s.plan_id
	where p.plan_id = 4
)

select *,
	CONCAT(ROUND((cast(count_of_customer_churned as float)/total_customers)*100,1),'%') as perc_of_churned_customer
from cte

--How many customers have churned straight after their initial free trial - 
--what percentage is this rounded to the nearest whole number?

--customers with plan_id = 0 
with cte1 as (
	select *,
		DATEADD(day,7,start_date) as churned_date
	from subscriptions
	where plan_id = 0
), 
--customers with plan_id = 4
cte2 as(
	select *
	from subscriptions
	where plan_id = 4
)

--select s.customer_id,
--	s.plan_id,
--	s.start_date,
--	c1.churned_date
--from subscriptions s 
--	inner join cte1 c1 on s.customer_id = c1.customer_id
--	inner join cte2 c2 on s.customer_id = c2.customer_id
--where s.start_date = c1.churned_date and s.plan_id in (0,4)

select count(*) as total_customers
from subscriptions s 
	inner join cte1 c1 on s.customer_id = c1.customer_id
	inner join cte2 c2 on s.customer_id = c2.customer_id
where s.start_date = c1.churned_date and s.plan_id in (0,4)



--What is the number and percentage of customer plans after their initial free trial?
select count(distinct s.customer_id) as count_of_customers
	,concat((
		cast(count(distinct s.customer_id) as float)/(select count(distinct customer_id) from subscriptions)
		)*100,'%') as perc_after_free_trial
from plans p
inner join subscriptions s
on p.plan_id = s.plan_id
where s.plan_id != 0 and s.plan_id !=4

--for plan_id = 1
select p.plan_name
	,count(distinct s.customer_id) as count_of_customers
	,concat((
		cast(count(distinct s.customer_id) as float)/(select count(distinct customer_id) from subscriptions)
		)*100,'%') as perc_monthly_subscribers
from plans p
inner join subscriptions s
on p.plan_id = s.plan_id
where s.plan_id != 0 and s.plan_id !=4 and s.plan_id = 1
group by p.plan_name

--for plan_id = 2
select p.plan_name
	,count(distinct s.customer_id) as count_of_customers
	,concat((
		cast(count(distinct s.customer_id) as float)/(select count(distinct customer_id) from subscriptions)
		)*100,'%') as perc_pro_monthly_subscribers
from plans p
inner join subscriptions s
on p.plan_id = s.plan_id
where s.plan_id != 0 and s.plan_id !=4 and s.plan_id = 2
group by p.plan_name

-- plan_id = 3
select p.plan_name
	,count(distinct s.customer_id) as count_of_customers
	,concat((
		cast(count(distinct s.customer_id) as float)/(select count(distinct customer_id) from subscriptions)
		)*100,'%') as perc_pro_annual_subscribers
from plans p
	inner join subscriptions s
	on p.plan_id = s.plan_id
where s.plan_id != 0 and s.plan_id !=4 and s.plan_id = 3
group by p.plan_name;

--ALL in One using LEAD()
WITH next_plan_cte AS (
	SELECT 
	  customer_id, 
	  plan_id, 
	  LEAD(plan_id, 1) OVER(PARTITION BY customer_id 
		ORDER BY plan_id) as next_plan
	FROM subscriptions
)

SELECT 
  next_plan, 
  COUNT(*) AS conversions,
  ROUND(100 * CAST(COUNT(*) AS float)/ (
    SELECT COUNT(DISTINCT customer_id) 
    FROM subscriptions),
	1) AS conversion_percentage
FROM next_plan_cte
WHERE next_plan IS NOT NULL 
  AND plan_id = 0
GROUP BY next_plan
ORDER BY next_plan;

--What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?

-- Retrieve next plan's start date located in the next row based on current row
WITH next_plan AS(
	SELECT 
	  customer_id, 
	  plan_id, 
	  start_date,
	  LEAD(start_date, 1) OVER(PARTITION BY customer_id ORDER BY start_date) as next_date
	FROM subscriptions
	WHERE start_date <= '2020-12-31'
),
-- Find customer breakdown with existing plans on or after 31 Dec 2020
customer_breakdown AS (
	  SELECT 
		plan_id, 
		COUNT(DISTINCT customer_id) AS customers
	  FROM next_plan
	  WHERE 
			next_date IS NOT NULL AND (start_date < '2020-12-31' 
			  AND next_date > '2020-12-31')
			OR 
			(next_date IS NULL AND start_date < '2020-12-31')
	  GROUP BY plan_id
	  )

SELECT plan_id,
	customers, 
	ROUND(100 * cast(customers as float) / (
		SELECT COUNT(DISTINCT customer_id) 
		FROM subscriptions),
	1) AS percentage
FROM customer_breakdown
GROUP BY plan_id, customers
ORDER BY plan_id;

-- How many customers have upgraded to an annual plan in 2020?
select
	--customer_id,
	--plan_id
	count(distinct customer_id) as count_of_customers
from subscriptions
where start_date like '2020%' and plan_id = 3;

--ANS - > 195 customers have upgraded to an annual plan in 2020

--How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?

--retrive data for next plan
WITH trial_plan AS 
  (
  SELECT 
    customer_id, 
    start_date AS trial_date
  FROM subscriptions
  WHERE plan_id = 0
),
-- Filter results to customers at pro annual plan = 3
annual_plan AS
  (SELECT 
    customer_id, 
    start_date AS annual_date
  FROM subscriptions
  WHERE plan_id = 3
)

SELECT 
  abs(ROUND(AVG(DATEDIFF(day,annual_date,trial_date)),0)) AS avg_days_to_upgrade
FROM trial_plan tp
JOIN annual_plan ap
  ON tp.customer_id = ap.customer_id;


--Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)

WITH trial_plan AS 
  (
  SELECT 
    customer_id, 
    start_date AS trial_date
  FROM subscriptions
  WHERE plan_id = 0
),
-- Filter results to customers at pro annual plan = 3
annual_plan AS
  (SELECT 
    customer_id, 
    start_date AS annual_date
  FROM subscriptions
  WHERE plan_id = 3
),
time_lapse_tb as (
	SELECT 
	  tp.customer_id,
	  tp.trial_date,
	  ap.annual_date,
	  datediff(day,tp.trial_date,ap.annual_date) as time_lapse
	FROM trial_plan tp
	JOIN annual_plan ap
	  ON tp.customer_id = ap.customer_id
),
final_tb  as (
 select *,
	CASE
		when time_lapse <=30 then '0-30'
		when time_lapse > 30 and time_lapse <=60 then '30-60'
		when time_lapse > 60 and time_lapse <=90 then '60-90'
		when time_lapse > 90 and time_lapse <=120 then '90-120'
		when time_lapse > 120 and time_lapse <=180 then '120-180'
		when time_lapse > 180 and time_lapse <=210 then '180-210'
		when time_lapse > 210 and time_lapse <=240 then '210-240'
		when time_lapse > 240 and time_lapse <=270 then '240-270'
		when time_lapse > 270 and time_lapse <=300 then '270-300'
		when time_lapse > 300 and time_lapse <=330 then '300-330'
		when time_lapse > 330 and time_lapse <=365 then '330-365'
		else 'More than 1 year'
	end as time_bucket
 from time_lapse_tb
 )

 select 
	time_bucket,
	count(customer_id) AS Total_customers	
 from final_tb
 group by time_bucket;

 --How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
 -- Retrieve next plan's start date located in the next row based on current row
WITH next_plan_cte AS (
  SELECT 
    customer_id, 
    plan_id, 
    start_date,
    LEAD(plan_id, 1) OVER(
      PARTITION BY customer_id 
      ORDER BY plan_id) as next_plan
  FROM subscriptions)

SELECT 
  COUNT(*) AS downgraded
FROM next_plan_cte
WHERE start_date <= '2020-12-31'
  AND plan_id = 2 
  AND next_plan = 1;
