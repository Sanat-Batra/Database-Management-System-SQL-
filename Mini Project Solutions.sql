CREATE DATABASE mp2;
USE mp2;

-- 1.	Join all the tables and create a new table called combined_table.
-- (market_fact, cust_dimen, orders_dimen, prod_dimen, shipping_dimen)

SHOW tables;
SELECT * FROM cust_dimen;
SELECT * FROM market_fact;


CREATE TABLE combined_table AS 
SELECT m.ord_id, m.prod_id, m.ship_id, m.cust_id, m.sales, m.discount, m.order_quantity, m.profit, m.shipping_cost,m.product_base_margin,
cd.customer_name, cd.province,cd.region, cd.customer_segment, od.order_id, od.order_date, od.order_priority, pd.product_category, pd.product_sub_category, sd.ship_mode, sd.ship_date 
FROM market_fact m 
INNER JOIN shipping_dimen sd ON m.ship_id=sd.ship_id
INNER JOIN prod_dimen pd ON m.prod_id=pd.prod_id
INNER JOIN cust_dimen cd ON m.cust_id=cd.cust_id 
INNER JOIN orders_dimen od ON m.ord_id=od.ord_id;

-- 2.	Find the top 3 customers who have the maximum number of orders

SELECT * FROM cust_dimen;
SELECT count(order_id) FROM orders_dimen;
SELECT * FROM market_fact;


SELECT * FROM (SELECT *, dense_rank() over (ORDER BY no_of_orders DESC ) Ranking FROM (SELECT cust_id, count(order_id) no_of_orders FROM 
(SELECT distinct m.cust_id, m.ord_id, od.order_id FROM market_fact m INNER JOIN orders_dimen od on m.ord_id = od.ord_id)t1 
GROUP BY cust_id ORDER BY count(order_id) DESC)t2)t3 WHERE Ranking <= 3   ;


-- 3.	Create a new column DaysTakenForDelivery that contains the date difference of Order_Date and Ship_Date.

ALTER TABLE shipping_dimen ADD COLUMN DaysTakenForDelivery INT ;
SELECT * FROM shipping_dimen ORDER BY DaysTakenForDelivery DESC;
SELECT * FROM cust_dimen;
SELECT * FROM orders_dimen;

SET SQL_SAFE_UPDATES = 0;

UPDATE shipping_dimen SET ship_date = str_to_date(ship_date, '%d-%m-%Y');
UPDATE orders_dimen SET order_date = str_to_date(order_date, '%d-%m-%Y');


UPDATE shipping_dimen s INNER JOIN orders_dimen o ON s.order_id = o.order_id  SET DaysTakenForDelivery = datediff(cast(ship_date AS date), cast(order_date as date)) WHERE DaysTakenForDelivery is NULL;

-- 4.	Find the customer whose order took the maximum time to get delivered.
 
 SELECT m.cust_id, customer_name, ord_id FROM cust_dimen cd INNER JOIN market_fact m ON cd.cust_id = m.cust_id WHERE ord_id IN ( select ord_id FROM orders_dimen WHERE order_id IN 
 (select od.order_id FROM shipping_dimen sd INNER JOIN orders_dimen od ON sd.order_id = od.order_id WHERE datediff(ship_date, order_date)
 = ( SELECT max(datediff(ship_date, order_date))  FROM shipping_dimen sd INNER JOIN orders_dimen od ON sd.order_id = od.order_id )));

-- 5.	Retrieve total sales made by each product from the data (use Windows function)

SELECT distinct pd.prod_id, sum(sales) OVER (partition by prod_id ) total_sales FROM prod_dimen pd INNER JOIN market_fact m on pd.prod_id = m.prod_id ORDER BY total_sales DESC ;

-- 6.	Retrieve total profit made from each product from the data (use windows function)

SELECT distinct pd.prod_id, sum(profit) OVER (partition by prod_id ) total_profit FROM prod_dimen pd INNER JOIN market_fact m on pd.prod_id = m.prod_id ORDER BY total_profit DESC;

-- 7	Count the total number of unique customers in January and how many of them came back every month over the entire year in 2011

SELECT DISTINCT YEAR(order_date), MONTH(order_date), count(cust_id) OVER (PARTITION BY month(order_date) order by month(order_date)) Total_Number_of_Unique_Customers
FROM combined_table
WHERE year(order_date)=2011 AND cust_id
IN (SELECT DISTINCT cust_id
FROM combined_table
WHERE month(order_date)=1
AND year(order_date)=2011);


-- 8.	Retrieve month-by-month customer retention rate since the start of the business.(using views)

Create view Visit_log AS
SELECT cust_id, TIMESTAMPDIFF(month,'2009-01-01', order_date) AS visit_month
FROM combined_table
GROUP BY cust_id, visit_month
ORDER BY cust_id, visit_month;
   
   
    Create view Time_Lapse AS
SELECT distinct cust_id,
visit_month,
lead(visit_month, 1) over(
partition BY cust_id
ORDER BY cust_id, visit_month) led
FROM Visit_log;
   
    CREATE VIEW time_lapse_calculated AS
SELECT cust_id,
           visit_month,
           led,
           led - visit_month AS time_diff
FROM Time_Lapse;
