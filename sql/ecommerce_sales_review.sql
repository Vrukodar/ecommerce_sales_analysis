CREATE DATABASE olist_ecommerce;
USE olist_ecommerce;

--  csv's were imported using Table Data import Wizard in MySQL workbench.
--  created a separate table for each csv file. 


-- Calculating no. of days delayed in each order delivery
SELECT 
	order_id, 
    order_status,
    order_purchase_timestamp,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    DATEDIFF(order_delivered_customer_date, order_estimated_delivery_date) AS delivery_delay_days
FROM olist_orders_dataset
WHERE order_status = 'delivered';
--  delivery_delay_days > 0 means late orders and delivery_delay_days <= 0 means ontime/early ordersolist_order_reviews_dataset


-- How does delay in delivery affect customer reviews?
SELECT 
	o.order_id,
    DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) AS delivery_delay_days,
    r.review_score
FROM olist_orders_dataset o
JOIN olist_order_reviews_dataset r ON o.order_id = r.order_id
WHERE o.order_status = "delivered";
-- more the delay less is the review



-- Get order value per order
SELECT 
    o.order_id,
    oi.order_id,
    SUM(oi.price + oi.freight_value) AS order_value
FROM olist_orders_dataset o
JOIN olist_order_items_dataset oi ON o.order_id = oi.order_id
GROUP BY o.order_id;



--  Now, to check how does customer review and no. of days delayed vary across 
-- location of seller and customer, it is required to remove duplicate order_ids from reviews table

-- get duplicate order_ids
WITH ranked_reviews AS (
	SELECT
		*, 
		ROW_NUMBER() OVER (
			PARTITION BY order_id
			ORDER BY review_creation_date DESC) AS rn
	FROM olist_order_reviews_dataset
)
SELECT * FROM ranked_reviews WHERE rn > 1;

-- remove older reviews for same order
DELETE 
FROM olist_order_reviews_dataset
WHERE review_id IN (
	WITH ranked_reviews AS (
		SELECT
			*, 
			ROW_NUMBER() OVER (
				PARTITION BY order_id
				ORDER BY review_creation_date DESC) AS rn
		FROM olist_order_reviews_dataset
	)
	SELECT review_id FROM ranked_reviews WHERE rn > 1
);

-- check how does customer review and no. of days delayed vary across 
-- location of seller and customer




-- Create a view to get all above in on place
-- customer, seller location, customer reviews, delay days and order value in one place
SELECT 
	o.order_id, 
    c.customer_state,
    s.seller_state, 
    DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) AS delivery_delay_days,
    r.review_score,
    SUM(oi.price + oi.freight_value) AS order_value 
FROM olist_orders_dataset o
JOIN olist_customers_dataset c ON o.customer_id = c.customer_id
JOIN olist_order_items_dataset oi ON o.order_id = oi.order_id
JOIN olist_sellers_dataset s ON oi.seller_id = s.seller_id
JOIN olist_order_reviews_dataset r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY o.order_id, c.customer_state, s.seller_state, delivery_delay_days, r.review_score;


CREATE VIEW vw_delivery_satisfaction AS
SELECT 
	o.order_id, 
    c.customer_state,
    s.seller_state, 
    DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) AS delivery_delay_days,
    r.review_score,
    SUM(oi.price + oi.freight_value) AS order_value 
FROM olist_orders_dataset o
JOIN olist_customers_dataset c ON o.customer_id = c.customer_id
JOIN olist_order_items_dataset oi ON o.order_id = oi.order_id
JOIN olist_sellers_dataset s ON oi.seller_id = s.seller_id
JOIN olist_order_reviews_dataset r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY o.order_id, c.customer_state, s.seller_state, delivery_delay_days, r.review_score;




-- aggregate review vs delay time 
SELECT 
	AVG(review_score), 
    CASE 
		WHEN delivery_delay_days <= 0 THEN 'On-time/early'
		WHEN delivery_delay_days BETWEEN 1 AND 3 THEN '1-3 days late'
		WHEN delivery_delay_days BETWEEN 4 AND 7 THEN '4-7 days late'
		WHEN delivery_delay_days >= 8 THEN '8+ days late'
    END AS delay_bucket
FROM vw_delivery_satisfaction 
GROUP BY delay_bucket;
-- avg review score shows decline with higher days of delay

