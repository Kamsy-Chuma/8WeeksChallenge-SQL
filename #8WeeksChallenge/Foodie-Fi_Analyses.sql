SELECT * FROM plans;
SELECT * FROM subscriptions;

---------------------	CASE A		--------------------
-- Based off the 8 sample customers provided in the sample from the subscriptions table, 
-- write a brief description about each customer’s onboarding journey.

SELECT customer_id, plan_name, start_date
FROM subscriptions s
JOIN plans p ON p.plan_id = s.plan_id
WHERE customer_id IN (1, 2, 11, 13, 15, 16, 18, 19);

-- Each customer always starts with the free trial but end up getting a different plan, based on preference:
-- Customer 1 bought the basic monthly package 
-- Customer 2 bought the pro annual package
-- Customer 11 cancelled his package immediately after his free trial but still paid for the following month because he didn't cancel during his trial period
-- Customer 13 bought the basic monthly package and upgraded to pro monthly after 3 months
-- Customer 15 bought the pro monthly package and cancelled his package after the pro package rolled offer.
-- Customer 16 bought the basic monthly and upgraded to pro annual about 4 months after his first sub
-- Customer 18 bought the pro monthly package
-- Customer 19 bought the pro monthly package and upgraded to pro annual exactly 2 months after.


-------------------		CASE B		-------------------

-- 1. How many customers has Foodie-Fi ever had?
SELECT
	COUNT(DISTINCT customer_id) AS customers
FROM
	subscriptions;


-- 2. What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value
SELECT
	DATETRUNC(Month, start_date) AS month_start,
	COUNT(*) AS trial_distribution
FROM
	subscriptions
WHERE
	plan_id = 0
GROUP BY
	DATETRUNC(Month, start_date)
ORDER BY 
	month_start;


-- 3. What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name
SELECT
	plan_name,
	COUNT(*) AS plan_distribution
FROM
	plans p
	JOIN subscriptions s ON s.plan_id = p.plan_id
WHERE
	YEAR(start_date) > 2020
GROUP BY
	plan_name
ORDER BY
	plan_distribution;


-- 4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
SELECT
	churn AS churn_count,
	ROUND(CAST((churn * 100) AS FLOAT)/no_churn, 1) AS churn_rate
FROM
	(
		SELECT
			SUM(CASE WHEN plan_name = 'churn' THEN 1 ELSE 0 END) AS churn,
			SUM(CASE WHEN plan_name = 'trial' THEN 1 ELSE 0 END) AS no_churn
		FROM
			plans p
			JOIN subscriptions s ON s.plan_id = p.plan_id
	) churned;


-- 5. How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?
WITH churn AS (
	SELECT
		MAX(CASE WHEN rownum = 2 THEN plan_id ELSE NULL END) AS two,
		total_count
	FROM (
		SELECT
			customer_id,
			plan_id,
			ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY start_date) AS RowNum,
			COUNT(CASE WHEN plan_id = 0 THEN customer_id ELSE NULL END) OVER () total_count
		FROM
			subscriptions
	) ranked
	GROUP BY
		customer_id,
		total_count
	HAVING
		MAX(CASE WHEN rownum = 2 THEN plan_id ELSE NULL END) = 4
)
SELECT
	COUNT(*) AS churn_count,
	ROUND(CAST(COUNT(*) * 100 AS FLOAT) / total_count, 0) AS churn_rate
FROM
	churn
GROUP BY
	total_count;


-- 6. What is the number and percentage of customer plans after their initial free trial?
SELECT
	SUM(CASE WHEN plan_id != 0 THEN 1 ELSE 0 END) AS subscribed,
	ROUND(CAST(SUM(CASE WHEN plan_id != 0 THEN 1 ELSE 0 END) * 100 AS FLOAT) / COUNT(*), 2) AS sub_rate
FROM
	subscriptions;

-- If the above looks complex, you can break it down like so:
WITH subscription AS (
	SELECT
		SUM(CASE WHEN plan_id != 0 THEN 1 ELSE 0 END) AS subscribed,
		COUNT(*) AS total
	FROM
		subscriptions
)
SELECT
	subscribed,
	ROUND(CAST(subscribed * 100 AS FLOAT) / total, 2) AS sub_rate
FROM
	subscription;


-- 7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
WITH subscription AS (
	SELECT 
		plan_name,
		CAST(COUNT(*) AS FLOAT) AS no_of_customer_sub
	FROM
		subscriptions s
		JOIN plans p ON p.plan_id = s.plan_id
	WHERE
		start_date <= '2020-12-31'
	GROUP BY
		plan_name
)
SELECT
	plan_name,
	no_of_customer_sub,
	ROUND((no_of_customer_sub * 100)/ SUM(no_of_customer_sub) OVER (), 1) AS percentage_breakdown
FROM
	subscription;


-- 8. How many customers have upgraded to an annual plan in 2020?
SELECT
	COUNT(*) AS pro_annual_count
FROM
	(
		SELECT
			customer_id,
			plan_id,
			start_date
		FROM
			subscriptions
		WHERE
			plan_id = 3
		AND YEAR(start_date) = '2020'
	) annual_plan;


-- 9. How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
WITH zero AS (
	SELECT *
	FROM subscriptions
	WHERE plan_id = 0
),
three AS (
	SELECT *
	FROM subscriptions
	WHERE plan_id = 3
)
SELECT
	AVG(diff) AS avg_days_to_upgrade
FROM
	(
		SELECT DISTINCT
			s.customer_id,
			DATEDIFF(DAY, z.start_date, t.start_date) AS diff
		FROM
			zero z
			JOIN three t ON t.customer_id = z.customer_id 
			JOIN subscriptions s ON s.customer_id = z.customer_id
	) sub;


-- 10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)


-- 11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
WITH plans AS (
	SELECT
		customer_id,
		MAX(CASE WHEN RowNum = 2 THEN plan_id ELSE NULL END) AS plan_one,
		MAX(CASE WHEN RowNum = 3 THEN plan_id ELSE NULL END) AS plan_two,
		MAX(CASE WHEN RowNum = 4 THEN plan_id ELSE NULL END) AS plan_three
	FROM 
		(
			SELECT
				*,
				ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY customer_id) AS RowNum
			FROM
				subscriptions
		) sub 
	WHERE RowNum != 1 AND YEAR(start_date) = '2020'
	GROUP BY customer_id
)
SELECT
	COUNT(customer_id) pro_to_basic
FROM
	plans 
WHERE
	(plan_one = 2 AND plan_two = 1) 
OR	(plan_two = 2 AND plan_three = 1);


--------------------		C. Challenge Payment Question		--------------------

--The Foodie-Fi team wants you to create a new payments table for the year 2020 that includes amounts paid by each customer in the subscriptions table with the following requirements:

--monthly payments always occur on the same day of month as the original start_date of any monthly paid plan
--upgrades from basic to monthly or pro plans are reduced by the current paid amount in that month and start immediately
--upgrades from pro monthly to pro annual are paid at the end of the current billing period and also starts at the end of the month period
--once a customer churns they will no longer make payments

SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'plans'

----------------------------------------------------------------------------------------------------
-- Start and end dates of package (with 2 packages only)

-- Create Temp table for for subscribers with two packages:
CREATE TABLE #two_packages (customer_id INT, start_date DATE, end_date DATE)
INSERT INTO #two_packages
SELECT customer_id, MAX(CASE WHEN rownum = 2 THEN start_date ELSE NULL END) AS start_date, MAX(CASE WHEN rownum = 3 THEN start_date ELSE NULL END) AS end_date
FROM
	(
		SELECT customer_id, s.plan_id, start_date, plan_name, price, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY start_date) AS rownum
		FROM subscriptions s JOIN plans p ON p.plan_id = s.plan_id
		WHERE YEAR(start_date) = '2020'
	) sub
GROUP BY customer_id;


-- Create a Temp Table for subscription and plan:
CREATE TABLE #process (customer_id INT, plan_id INT, start_date DATE, plan_name VARCHAR(13), price DECIMAL(6, 2), rownum INT)
INSERT INTO #process
SELECT customer_id, s.plan_id, start_date, plan_name, price, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY start_date) AS rownum
FROM
	subscriptions s
	JOIN plans p ON p.plan_id = s.plan_id
WHERE
	YEAR(start_date) = '2020';														


-- Create Temp Table for Post-Upgraded subscribers:
CREATE TABLE #post_upgrade_stop_date (customer_id INT, start_date DATE, end_date DATE)
INSERT INTO #post_upgrade_stop_date
SELECT customer_id, MAX(start_date_2) AS start_date, MAX(start_date_3) AS end_date 
FROM (
	SELECT customer_id, CASE WHEN rownum = 3 AND plan_id != 3 THEN start_date ELSE NULL END AS start_date_2, CASE WHEN rownum = 4 AND plan_id != 3 THEN start_date ELSE NULL END AS start_date_3, plan_id, plan_name, price, rownum
	FROM #process
	) sub2
GROUP BY customer_id
ORDER BY customer_id, start_date;
----------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------
-- This is the query to create the table:
CREATE TABLE #payments (customer_id INT, plan_id INT, plan_name VARCHAR(13), payment_date DATE, amount DECIMAL(6, 2));
WITH upgraded_package_process AS (
	SELECT customer_id, start_date_2 AS start_date, start_date_3 AS end_date, plan_id, plan_name, price 
	FROM (
		SELECT customer_id, CASE WHEN rownum = 3 AND plan_id != 3 THEN start_date ELSE NULL END AS start_date_2, CASE WHEN rownum = 4 AND plan_id != 3 THEN start_date ELSE NULL END AS start_date_3, plan_id, plan_name, price
		FROM #process
	) sub2
	WHERE plan_id != 4
	UNION ALL
	SELECT u.customer_id, DATEADD(MONTH, 1, u.start_date), u.end_date, plan_id, plan_name, price
	FROM upgraded_package_process u
	JOIN #post_upgrade_stop_date p ON p.customer_id = u.customer_id
	WHERE DATEADD(MONTH, 1, u.start_date) <= (CASE WHEN p.end_date IS NULL THEN '2020-12-31' ELSE p.end_date END)
),
monthly_trial_record AS (
	SELECT customer_id, start_date, plan_id, plan_name, price
	FROM
		(
			SELECT customer_id, s.plan_id, start_date, plan_name, price, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY start_date) AS rownum
			FROM subscriptions s JOIN plans p ON p.plan_id = s.plan_id
			WHERE YEAR(start_date) = '2020'
		) sub
	WHERE
		rownum = 2
	AND plan_id != 4
	UNION ALL
	SELECT
		m.customer_id, DATEADD(MONTH, 1, m.start_date), plan_id, plan_name, price
	FROM
		monthly_trial_record m
		JOIN #two_packages t ON t.customer_id = m.customer_id
	WHERE
		DATEADD(MONTH, 1, m.start_date) < (CASE WHEN end_date  IS NULL THEN '2020-12-31' ELSE end_date END)
	AND plan_name != 'pro annual'
)

INSERT INTO #payments (customer_id, plan_id, plan_name, payment_date, amount)
SELECT customer_id, plan_id, plan_name, start_date AS payment_date, price AS amount
FROM monthly_trial_record
UNION ALL
-- upgraded package
SELECT active.customer_id,  upgrade.plan_id, upgrade.plan_name, upgrade.start_date, (upgrade.price - active.price) AS upgrade_price
FROM (
	SELECT customer_id, start_date, plan_id, plan_name, price, rownum
	FROM #process
	WHERE
		rownum = 2
	AND plan_id != 4
) active
	JOIN (
		SELECT customer_id, start_date, plan_id, plan_name, price, rownum
		FROM #process
		WHERE
			rownum IN (3, 4)
		AND plan_id != 4
	) upgrade
		ON upgrade.customer_id = active.customer_id
UNION ALL
SELECT customer_id, plan_id, plan_name, start_date, price
FROM (
    SELECT customer_id, u.plan_id, u.plan_name, start_date, p.price, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY start_date) AS rownum_2
    FROM upgraded_package_process u
    JOIN plans p ON p.plan_id = u.plan_id
    WHERE start_date IS NOT NULL
) AS subquery
WHERE rownum_2 > 1
ORDER BY customer_id, start_date;


CREATE TABLE payments (customer_id INT, plan_id INT, plan_name VARCHAR(13), payment_date DATE, amount DECIMAL(6, 2), payment_order INT)
INSERT INTO payments (customer_id, plan_id, plan_name, payment_date, amount, payment_order)
SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY payment_date) FROM #payments

SELECT * FROM payments;


--------------------		D. Outside The Box Questions		--------------------
-- The following are open ended questions which might be asked during a technical interview for this case study 
-- there are no right or wrong answers, but answers that make sense from both a technical and a business perspective make an amazing impression!


-- 1. How would you calculate the rate of growth for Foodie-Fi?
-- We can evaluate the growth rate by analysing sales for the year, 2020. We can do this using the payment table to show the  distribution of the sales in 2020
-- Total Sales Generated in 2020 based on subscriptions:
SELECT SUM(amount) AS total_sum 
FROM payments;
-- $100,695.20 was generated for the company in the year 2020.

-- Now let's break it down further:
SELECT
	MONTH(payment_date) AS month_num,
	DATENAME(MONTH, payment_date) AS payment_month,
	SUM(amount) AS amount
FROM
	payments
GROUP BY
	DATENAME(MONTH, payment_date), MONTH(payment_date)
ORDER BY
	month_num;
-- There's a consistent increase in the revenue generated from January till October and then there was a decrease in sales in November, from October, and an increase rom November to December also.
-- October generated the highest revenue in 2020 with a sum of $14,179.80

-- Now to get the rate of increase from January to December in 2020:
WITH rate AS (
	SELECT MAX(CASE WHEN payment_month = 'January' THEN CAST(amount AS FLOAT) ELSE '' END) AS start_year, MAX(CASE WHEN payment_month = 'December' THEN CAST(amount AS FLOAT) ELSE '' END) AS end_year
	FROM (
		SELECT
			MONTH(payment_date) AS month_num,
			DATENAME(MONTH, payment_date) AS payment_month,
			SUM(amount) AS amount
		FROM
			payments
		GROUP BY
			DATENAME(MONTH, payment_date), MONTH(payment_date)
	) twenty_twenty
)
SELECT ROUND(((end_year - start_year) * 100) / start_year, 2) AS [growth_rate (%)]
FROM rate;
-- There was a 915.23% increase in the sales from january till December, which is more than ten times the amount generated in January, This indicates that Foddie-Fi is doing really well.

-- We can also find the increase in customers (the growth rate of customers) to understand the customer retention over the years:
SELECT
	COUNT(DISTINCT CASE WHEN YEAR(start_date) = '2020' AND plan_id = 0 THEN customer_id ELSE NULL END) AS trial_period,
	COUNT(DISTINCT CASE WHEN YEAR(start_date) = '2020' AND rownum > 1 AND plan_id != 4 THEN customer_id ELSE NULL END) AS twenty_twenty,
	COUNT(DISTINCT CASE WHEN YEAR(start_date) = '2021' AND rownum > 1 AND plan_id != 4 THEN customer_id ELSE NULL END) AS twenty_one
FROM (
	SELECT
		customer_id,
		plan_id,
		start_date,
		ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY start_date) AS rownum
	FROM
		subscriptions
) sub;
-- Out of 1000 customers that utilised the free trial, 891 bought a plan immediately after the free trial in 2020, only 126 purchased extra packages in 2021.
-- That is way less than the amount of people who subscribed in 2020.


-- 2. What key metrics would you recommend Foodie-Fi management to track over time to assess performance of their overall business?
-- i. Churn rate of customers.
	-- If churn rate is high, What factors negatively affect the customer experience?
-- ii. Retention rate of customers immediately after subscription.
-- iii. Based on the limited dataset, there are limited key metrics to gather from this, but without it, analysing the type of content that customers resonate with will go a long way.
-- iv. Increase in sales over the years
	-- Which year drove more sales
-- v. Customers that generated the most revenue for the business


-- 3. What are some key customer journeys or experiences that you would analyse further to improve customer retention?
-- i. The number of custommers that made multiple packages or rahter upgraded their packages as against the number of customers that made just one package.
-- To rephrase, how many packages did each customer purchase?
	-- The time period or difference between when the first package was made and their upgrades.
-- ii. What package was the most purchased.
-- iii. For customers that churned, how long were they subscribed before churning?
	-- Was there any particular reason why they churned?
	-- What factors affected customer experieince?


-- 4. If the Foodie-Fi team were to create an exit survey shown to customers who wish to cancel their subscription, what questions would you include in the survey?
-- i. What factors negatively impacted your experience?
-- ii. Was your subscription worth it?
-- iii. How would you rate your experience on Foodie-Fi app out of 10?
-- iv. What aspects of the app would you recommend Foodie-Fi to improve on?
-- v. Why did you join Foodie-Fi initially and what were your expectations?


-- 5. What business levers could the Foodie-Fi team use to reduce the customer churn rate? How would you validate the effectiveness of your ideas?
-- We could look further into the user experience and improve upon it.
	-- i. Continuously improve the user interface, app speed, and overall user experience to keep customers engaged and satisfied.
	-- Validation: Collect user feedback and track metrics like app session duration, bounce rate, and user satisfaction scores (e.g., through surveys). A positive trend in these metrics can indicate improved user experience.
	-- i. We could Offer discounts or incentives for users who commit to annual subscriptions instead of monthly ones.
	-- Validation: We compare the churn rate between monthly and annual subscribers. If annual subscribers have a significantly lower churn rate, it indicates that this strategy is effective.