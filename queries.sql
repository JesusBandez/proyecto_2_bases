-- Query a
with top5_orders as (
	SELECT p.id, customer_id, SUM(o.price) as suma
	FROM placed_order p
	JOIN order_item o ON p.id = o.placed_order_id
	JOIN order_status os ON os.placed_order_id = p.id
	JOIN status_catalog s ON os.status_catalog_id = s.id
	WHERE s.status_name ='order confirmed'
	GROUP BY p.id, p.customer_id
	ORDER BY suma desc
	Limit (SELECT COUNT(*)*0.05
		   FROM placed_order p
		   JOIN order_item o ON p.id = o.placed_order_id
		  )
	)
SELECT c.* 
FROM Customer c
JOIN top5_orders t ON c.id = t.customer_id


-- Query b
SELECT c.*, avg(d.delivery_time_actual - os.status_time) as dispatch_time
FROM placed_order po
JOIN order_status os ON po.id = os.placed_order_id
JOIN status_catalog sc ON os.status_catalog_id = sc.id and sc.status_name = 'order confirmed'
JOIN delivery d ON  d.placed_order_id = po.id
JOIN city c ON c.id = po.delivery_city_id
GROUP BY c.id
ORDER BY dispatch_time DESC
LIMIT 5

-- query c
with customer_total_10 as (
	SELECT customer_id, sum(price) total
	FROM placed_order p
	JOIN order_item o ON p.id = o.placed_order_id
	JOIN order_status os ON os.placed_order_id = p.id
	JOIN status_catalog s ON os.status_catalog_id = s.id
	WHERE s.status_name ='order confirmed'
	GROUP BY customer_id
	ORDER BY total desc
	LIMIT 10
	)
SELECT c.* 
FROM Customer c
JOIN customer_total_10 t ON c.id = t.customer_id

-- Query d
WITH items_dispatch_time as (
	SELECT i.* , avg(d.delivery_time_actual - os.status_time) as dispatch_time
	FROM item i
	JOIN order_item oi ON i.id = oi.item_id
	JOIN placed_order po ON po.id = oi.placed_order_id
	JOIN order_status os ON po.id = os.placed_order_id
	JOIN status_catalog sc ON os.status_catalog_id = sc.id and sc.status_name = 'order confirmed'
	JOIN delivery d ON  d.placed_order_id = po.id
	GROUP BY i.id
	ORDER BY dispatch_time DESC
), max_dispatch_time as (
	SELECT MAX(dispatch_time) as dispatch_time FROM items_dispatch_time
)

SELECT * FROM items_dispatch_time
NATURAL JOIN max_dispatch_time