--Case Study Questions
--Each of the following case study questions can be answered using a single SQL statement:

SELECT *
FROM members;

SELECT *
FROM menu;

SELECT *
FROM sales;

-- 1. What is the total amount each customer spent at the restaurant?
SELECT
	s.customer_id,
	SUM(m.price) AS total_amount
FROM
	sales s
	JOIN menu m ON s.product_id = m.product_id
GROUP BY
	s.customer_id;

-- 2. How many days has each customer visited the restaurant?
SELECT
	customer_id,
	COUNT(DISTINCT order_date) AS no_of_visits
FROM
	sales
GROUP BY
	customer_id;

-- 3. What was the first item from the menu purchased by each customer?
SELECT
	customer_id,
	product_name
FROM
	(
		SELECT
			customer_id,
			product_id,
			MIN(order_date) AS min_order,
			ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY MIN(order_date)) AS row_num
		FROM
			sales
		GROUP BY
			customer_id,
			product_id
	) first_item_purchased
	JOIN menu m ON m.product_id = first_item_purchased.product_id
WHERE
	row_num = 1;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT TOP 1
	m.product_name AS product_name,
	COUNT(s.product_id) AS product_count
FROM
	sales s
	JOIN menu m ON s.product_id = m.product_id
GROUP BY
	m.product_name
ORDER BY
	product_count DESC;
		
-- 5. Which item was the most popular for each customer?
SELECT
	customer_id,
	product_name
FROM
	(
		SELECT
			customer_id,
			product_id,
			COUNT(*) AS product_count,
			RANK() OVER (PARTITION BY customer_id ORDER BY COUNT(*) DESC) AS row_num
		FROM
			sales
		GROUP BY
			customer_id,
			product_id
	) product
	JOIN menu m ON m.product_id = product.product_id
WHERE
	row_num = 1;

-- 6. Which item was purchased first by the customer after they became a member?
SELECT
	customer_id,
	product_name
FROM
	(
		SELECT
			s.customer_id,
			order_date,
			product_id,
			ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY order_date) AS row_num
		FROM
			sales s
			JOIN members m ON m.customer_id = s.customer_id
		WHERE
			order_date >= join_date
	) item
	JOIN menu m ON m.product_id = item.product_id
WHERE
	row_num = 1;

-- 7. Which item was purchased just before the customer became a member?
SELECT
	customer_id,
	product_name
FROM
	(
		SELECT
			s.customer_id,
			order_date,
			product_id,
			ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY order_date DESC, product_id DESC) AS row_num
		FROM
			sales s
			JOIN members m ON m.customer_id = s.customer_id
		WHERE
			order_date < join_date
	) item
	JOIN menu m ON m.product_id = item.product_id
WHERE
	row_num = 1;

-- 8. What is the total items and amount spent for each member before they became a member?
SELECT
	customer_id,
	COUNT(*) AS total_items,
	SUM(m.price)
FROM
	(
		SELECT
			s.customer_id,
			order_date,
			product_id,
			ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY order_date DESC, product_id) AS row_num
		FROM
			sales s
			JOIN members m ON m.customer_id = s.customer_id
		WHERE
			order_date < join_date
	) item
	JOIN menu m ON m.product_id = item.product_id
GROUP BY
	customer_id;

-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
SELECT
	customer_id,
	SUM(price * multiplier) AS points
FROM
	(
		SELECT
			s.customer_id,
			m.price,
			CASE WHEN m.product_id = 1 THEN (2 * 10)
				 WHEN m.product_id = 2 THEN 10
				 WHEN m.product_id = 3 THEN 10
				 ELSE 0 END AS multiplier
		FROM
			sales s
			JOIN menu m ON m.product_id = s.product_id
	) multiply
GROUP BY
	customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items,
-- not just sushi - how many points do customer A and B have at the end of January?
SELECT
	customer_id,
	SUM(price * multiplier) AS points
FROM
	(
		SELECT 
			s.customer_id,
			m.price,
			CASE WHEN s.order_date BETWEEN m2.join_date AND DATEADD(WEEK, 1, m2.join_date) THEN (2 * 10)
				 ELSE 10 END AS multiplier
		FROM
			sales s
			JOIN menu m ON m.product_id = s.product_id
			JOIN members m2 ON m2.customer_id = s.customer_id
		WHERE
			MONTH(s.order_date) = 1
	) multiply
GROUP BY
	customer_id;


---------------		BONUS QUESTIONS		---------------
-- The following questions are related creating basic data tables that Danny and his team can use to quickly 
-- derive insights without needing to join the underlying tables using SQL
-- 1.
SELECT
	s.customer_id,
	s.order_date,
	mu.product_name,
	mu.price,
	CASE WHEN s.order_date >= m.join_date THEN 'Y'
		 ELSE 'N' END AS member
FROM
	sales s
	JOIN menu mu ON mu.product_id = s.product_id
	LEFT JOIN members m ON m.customer_id = s.customer_id;

-- 2.
WITH ranked AS (
	SELECT 
		s.customer_id,
		s.order_date,
		mu.product_name,
		mu.price,
		CASE WHEN order_date >= join_date THEN 'Y' ELSE 'N' END AS member,
		RANK() OVER (PARTITION BY s.customer_id, CASE WHEN order_date >= join_date THEN 'Y' ELSE 'N' END ORDER BY s.order_date) AS ranking
	FROM
		sales s
		JOIN menu mu ON mu.product_id = s.product_id
		LEFT JOIN members m ON m.customer_id = s.customer_id
)
SELECT
	customer_id,
	order_date,
	product_name,
	price,
	member,
	CASE WHEN member = 'N' THEN 'null' ELSE CAST(ranking AS VARCHAR) END AS ranking
FROM
	ranked;