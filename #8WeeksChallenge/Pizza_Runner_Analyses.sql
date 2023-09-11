--------------------		DATA CLEANING		--------------------

SELECT *
FROM customer_orders;

-- Customer Orders
UPDATE customer_orders
SET exclusions = CASE WHEN exclusions = 'null' THEN '0'
					  WHEN exclusions IS NULL THEN '0'
					  WHEN exclusions = '' THEN '0'
					  ELSE exclusions END;

UPDATE customer_orders
SET extras = CASE WHEN extras = 'null' THEN '0'
				  WHEN extras IS NULL THEN '0'
				  WHEN extras = '' THEN '0'
				  ELSE extras END;

ALTER TABLE customer_orders
ADD hourly INTEGER;

UPDATE customer_orders
SET hourly = DATEPART(HOUR, order_time);

ALTER TABLE customer_orders
ADD daily INTEGER;

UPDATE customer_orders
SET daily = DATEPART(WEEKDAY, order_time);

-- Runner Orders
SELECT *
FROM runner_orders;

ALTER TABLE runner_orders
ADD pick_up_time DATETIME;

UPDATE runner_orders
SET pick_up_time = TRY_CAST(pickup_time AS DATETIME)
WHERE TRY_CAST(pickup_time AS DATETIME) IS NOT NULL;

ALTER TABLE runner_orders
DROP COLUMN pickup_time;

ALTER TABLE runner_orders
ADD pickup_time DATETIME;

UPDATE runner_orders
SET pickup_time = pick_up_time;

ALTER TABLE runner_orders
DROP COLUMN pick_up_time;

UPDATE runner_orders
SET pickup_time = COALESCE(pickup_time, '1900-01-01 00:00:00')
WHERE pickup_time IS NULL;
-- '1900-01-01 00:00:' is used to describe pickup times that had no delivery, if no delivery, then no pickup
-- Hence the need to define it that way.

UPDATE runner_orders		
SET distance = CASE WHEN distance = 'null' THEN '0'
					WHEN distance IS NULL THEN '0'
					WHEN distance LIKE '%km' THEN TRIM(LEFT(distance, CHARINDEX('k', distance) - 1))
					ELSE distance END;

UPDATE runner_orders		
SET duration = CASE WHEN duration = 'null' THEN '0'
					WHEN duration IS NULL THEN '0'
					WHEN duration LIKE '%m%' THEN TRIM(LEFT(duration, CHARINDEX('m', duration) - 1))
					ELSE duration END;

UPDATE runner_orders		
SET cancellation = CASE WHEN cancellation = 'null' THEN 'Delivered'
						WHEN cancellation IS NULL THEN 'Delivered'
						WHEN cancellation LIKE '' THEN 'Delivered'
						ELSE cancellation END;

-- Remove Duplicates, if any:
WITH duplicate AS (
	SELECT *,
		ROW_NUMBER() OVER 
			(PARTITION BY order_id,
						  customer_id,
						  pizza_id,
						  exclusions,
						  extras,
						  order_time
						  ORDER BY order_time
			) AS row_num
	FROM
		customer_orders
)

DELETE
FROM duplicate
WHERE row_num > 1;

-- Runners
SELECT *
FROM runners;


--------------------		ANALYSES		--------------------

SELECT *
FROM customer_orders;
SELECT *
FROM pizza_names;
SELECT *
FROM pizza_recipes;
SELECT *
FROM pizza_toppings;
SELECT *
FROM runner_orders;
SELECT *
FROM runners;


--------------------		ANALYSES A - Pizza Metrics		--------------------

-- 1. How many pizzas were ordered?
SELECT 
	COUNT(*) AS ordered_pizzas
FROM
	customer_orders;


-- 2. How many unique customer orders were made?
SELECT
	COUNT(DISTINCT customer_id) AS unique_customer_order
FROM
	customer_orders;


-- 3. How many successful orders were delivered by each runner?
SELECT
	runner_id,
	COUNT(*) AS delivered
FROM 
	runner_orders
WHERE
	cancellation = 'Delivered'
GROUP BY
	runner_id;


-- 4. How many of each type of pizza was delivered?
SELECT
	CAST(p.pizza_name AS VARCHAR(MAX)) AS pizza_name,
	COUNT(*) AS delivered
FROM
	customer_orders c
	JOIN runner_orders r ON c.order_id = r.order_id
	JOIN pizza_names p ON p.pizza_id = c.pizza_id
WHERE 
	cancellation = 'Delivered'
GROUP BY
	c.pizza_id,
	CAST(p.pizza_name AS VARCHAR(MAX));


-- 5. How many Vegetarian and Meatlovers were ordered by each customer?

-- Getting the data types of columns in tables:
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'pizza_names';

-- Using CAST
SELECT 
	c.customer_id,
	CAST(p.pizza_name AS VARCHAR(MAX)) AS pizza_name,
	COUNT(*) AS pizza_count
FROM
	customer_orders c
	JOIN pizza_names p 
		ON p.pizza_id = c.pizza_id
GROUP BY
	c.customer_id,
	CAST(p.pizza_name AS VARCHAR(MAX));

-- USING CONVERT
SELECT 
	c.customer_id,
	CONVERT(VARCHAR(MAX), p.pizza_name) AS pizza_name,
	COUNT(*) AS pizza_count
FROM
	customer_orders c
	JOIN pizza_names p 
		ON p.pizza_id = c.pizza_id
GROUP BY
	c.customer_id,
	CONVERT(VARCHAR(MAX), p.pizza_name);


-- 6. What was the maximum number of pizzas delivered in a single order?
SELECT
	MAX(delivered) AS max_delivered
FROM
	(
		SELECT
			c.order_id,
			SUM(CASE WHEN cancellation = 'Delivered' THEN 1 ELSE 0 END) AS delivered
		FROM
			customer_orders c
			JOIN runner_orders r ON r.order_id = c.order_id
		GROUP BY
			c.order_id
	) delivered_orders

-------------------------------------------------------------------
-- This only works when one column has data that need to be split
WITH to_pivot AS (
	SELECT
		order_id,
		customer_id,
		pizza_id,
		exclusions,
		order_time,
		VALUE,
		ROW_NUMBER() OVER (PARTITION BY order_id, pizza_id, exclusions ORDER BY order_time) AS RowNum
	FROM	
		customer_orders
	CROSS APPLY string_split(exclusions, ',')
)
SELECT 
	order_id,
	customer_id,
	pizza_id,
	order_time,
	[1] AS exclsuions_1,
	CASE WHEN [2] IS NULL THEN 0 ELSE [2] END AS exclusions_2
FROM to_pivot
PIVOT (MAX(VALUE) FOR RowNum IN ([1], [2])) AS PVT;
-------------------------------------------------------------

-- Use this temp_table for exclusions and extras queries
CREATE TABLE #change (
order_id VARCHAR(50),
customer_id VARCHAR(50),
pizza_id VARCHAR(50),
exclusions_1 VARCHAR(50),
exclusions_2 VARCHAR(50),
extras_1 VARCHAR(50),
extras_2 VARCHAR(50),
order_time DATETIME
);

INSERT INTO #change
SELECT
	order_id,
	customer_id,
	pizza_id,
	LEFT(exclusions, 1),
	CASE WHEN exclusions NOT LIKE '%,%' THEN 0 ELSE TRIM(RIGHT(exclusions, LEN(exclusions) - CHARINDEX(',', exclusions))) END,
	LEFT(extras, 1),
	CASE WHEN extras NOT LIKE '%,%' THEN 0 ELSE TRIM(RIGHT(extras, LEN(extras) - CHARINDEX(',', extras))) END,
	order_time
FROM
	customer_orders;

SELECT * FROM #change;


-- 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
-- Split exclusions and extras values, separated by commas, into separate rows (FROM CHATGPT)
SELECT *
FROM customer_orders;
--
-- CHANGE:
SELECT
	customer_id,
	SUM(one_change) AS changed,
	SUM(no_change) AS no_change
FROM
	(
		SELECT
			ch.customer_id,
			exclusions_1,
			exclusions_2,
			extras_1,
			extras_2,
			CASE WHEN exclusions_1 != 0 OR exclusions_2 != 0 OR extras_1 != 0 OR extras_2 != 0 THEN 1 ELSE 0 END AS one_change,
			CASE WHEN exclusions_1 = 0 AND exclusions_2 = 0 AND extras_1 = 0 AND extras_2 = 0 THEN 1 ELSE 0 END AS no_change
		FROM
			#change ch
			JOIN runner_orders r ON r.order_id = ch.order_id
		WHERE
			cancellation = 'Delivered'
	) changed_and_delivered
GROUP BY
	customer_id;


-- 8. How many pizzas were delivered that had both exclusions and extras?
SELECT
	COUNT(*) AS delivered 
FROM
	(
		SELECT
			ch.order_id,
			exclusions_1,
			exclusions_2,
			extras_1,
			extras_2
		FROM
			#change ch
			JOIN runner_orders r ON r.order_id = ch.order_id
		WHERE
			(exclusions_1 != 0 OR exclusions_2 != 0) AND (extras_1 != 0 OR extras_2 != 0)
		AND cancellation = 'Delivered'
	) delivered_changes


-- 9. What was the total volume of pizzas ordered for each hour of the day?
SELECT
	hourly,
	COUNT(*) AS order_by_hour
FROM
	customer_orders
GROUP BY
	hourly;


-- 10. What was the volume of orders for each day of the week?
SELECT
	DATENAME(DW, order_time) AS daily,
	COUNT(*) AS order_by_day
FROM
	customer_orders
GROUP BY
	DATENAME(DW, order_time);


--------------------		ANALYSES B - Runner and Customer Experience		--------------------

-- 1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
SELECT 
	weekly_reg,
	COUNT(*) AS no_of_signups
FROM
	(
		SELECT
			CASE WHEN registration_date BETWEEN '2021-01-01' AND '2021-01-07' THEN 'week 1'
				 WHEN registration_date BETWEEN '2021-01-08' AND '2021-01-14' THEN 'week 2'
				 WHEN registration_date BETWEEN '2021-01-15' AND '2021-01-21' THEN 'week 3'
				 ELSE NULL END AS weekly_reg
		FROM 
			runners
	) registration
GROUP BY
	weekly_reg;

-- I STILL NEED TO WORK ON THIS AND FIGURE OUT HOW TO AUTOMATE THE PROCESS:
--SELECT
--	start_week,
--	CASE WHEN registration_date BETWEEN start_week AND end_week THEN 1 ELSE 0 END
--FROM
--	(
--SELECT
--	CAST(DATEADD(WEEK, DATEDIFF(WEEK, '2021-01-01', registration_date), '2021-01-01') AS DATE) AS start_week,
--	LEAD(CAST(DATEADD(WEEK, DATEDIFF(WEEK, '2021-01-01', registration_date), '2021-01-01') AS DATE)) OVER (ORDER BY registration_date) AS end_week
--FROM
--	runners
--) sub
--JOIN runners r ON r.registration_date = sub.start_week
--WHERE
--(start_week IS NOT NULL OR end_week IS NOT NULL) AND start_week != end_week;


-- 2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
-- '1900-01-01 00:00:00' represents pickup times that have no time ************
-- SOLVING MANUALLY:
SELECT
	runner_id,
	ROUND(SUM(CAST(diff AS FLOAT)) / COUNT(*), 2) AS [avg_time (mins)]
FROM
	(
		SELECT DISTINCT
			runner_id,
			order_time,
			pickup_time,
			DATEDIFF(MINUTE, order_time, pickup_time) AS diff
		FROM
			runner_orders r
			JOIN customer_orders c ON r.order_id = c.order_id
		WHERE
			pickup_time != '1900-01-01 00:00:00'
	) time_diff
GROUP BY
	runner_id;

-- USING AVG:
SELECT
	runner_id,
	ROUND(AVG(CAST(diff AS FLOAT)), 2) AS [avg_time (mins)]
FROM
	(
		SELECT DISTINCT
			runner_id,
			order_time,
			pickup_time,
			DATEDIFF(MINUTE, order_time, pickup_time) AS diff
		FROM
			runner_orders r
			JOIN customer_orders c ON r.order_id = c.order_id
		WHERE
			pickup_time != '1900-01-01 00:00:00'
	) time_diff
GROUP BY
	runner_id;

-- Previous Solution:
--WITH difF AS (
--	SELECT
--		runner_id,
--		pickup_time,
--		LAG(pickup_time) OVER (ORDER BY order_id) AS prev_pickup_time
--	FROM
--		runner_orders
--	WHERE
--		pickup_time != '1900-01-01 00:00:00'
--)
--SELECT
--	runner_id,
--	AVG(CASE
--		WHEN prev_pickup_time IS NULL OR pickup_time IS NULL THEN 0
--		ELSE DATEDIFF(MINUTE, prev_pickup_time, pickup_time) END) AS [avg_time_diff (mins)]
--FROM
--	difF
--GROUP BY
--	runner_id


---- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
/* The only relationship between the number of pizzas and how long it takes to prepare can be evaluated in the periods 
between the order date and the pickup date (when the pizza was ready), because the runners delivered the pizzas fresh (which is hot from the oven).*/
SELECT
	c.order_id,
	p.pizza_name,
	order_time,
	pickup_time,
	DATEDIFF(MINUTE, order_time, pickup_time) AS diff
FROM
	customer_orders c
	JOIN runner_orders r ON r.order_id = c.order_id
	JOIN pizza_names p ON p.pizza_id = c.pizza_id
WHERE
	pickup_time != '1900-01-01 00:00:00'
-- There is no relationship between the number of pizzas and how long the order takes to prepare, let me break it down briefly:
/* Judging by the difference between the order time and the pickup time for orders 1 and 2, it took approximately 10 minutes for each of them to get ready as from the time it was ordered,
but comparing it with two orders with order id 3, it took 21 minutes for both of them to get ready, which is 2 times to time it takes to handle one order. Comaparing single orders made, like that of order 8, 
we see that it took 21 minutes also to get ready. Again, comparing it to the other ids like 4 and 10, they have a difference of 30 and 16 minutes respectively. 
With these insights, it's hard to come to the conclusion that more more pizzas take more time to prepare and less takes less time.*/

/* I also included the types of pizza to see if there is any correlation, there isn't. We can further conclude that there is no relationship between the number of pizzas and how long the order takes to prepare.*/

SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH,IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'runner_orders'


-- 4. What was the average distance travelled for each customer?
SELECT
	customer_id,
	ROUND(AVG(CAST(distance AS FLOAT)), 2) AS avg_distance
FROM
	customer_orders c
	JOIN runner_orders r ON r.order_id = c.order_id
WHERE
	cancellation = 'Delivered' --For a distance to have been covered, there had to have been a delivery made
GROUP BY
	customer_id;


-- 5. What was the difference between the longest and shortest delivery times for all orders?
SELECT
	MAX(CAST(duration AS INT)) - MIN(CAST(duration AS INT)) AS [delivery_difference (mins)]
FROM
	runner_orders
WHERE
	cancellation = 'Delivered';


-- 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
SELECT
	runner_id,
	order_id,
	ROUND(AVG(CAST(distance AS FLOAT) / (CAST(duration AS FLOAT) / 60)), 2) AS [avg_speed (km/hr)]
FROM
	runner_orders
WHERE 
	cancellation = 'Delivered'
GROUP BY
	order_id,
	runner_id;
-- The Average speed of each runner increased with each order delivered, only runner_id 1 has a decrease on the 3rd delivery but increased greatly on his 4th delivery.


-- 7. What is the successful delivery percentage for each runner?
SELECT
	runner_id,
	(delivered_count * 100) / total_count AS delivery_percentage
FROM
	(
		SELECT
			runner_id,
			SUM(CASE WHEN cancellation = 'Delivered' THEN 1 ELSE 0 END) delivered_count,
			COUNT(*) AS total_count
		FROM
			runner_orders
		GROUP BY
			runner_id
	) agg;

