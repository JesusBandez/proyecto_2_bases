


-- Query 2
SELECT c.*, avg(d.delivery_time_actual - os.status_time) as dispatch_time
FROM placed_order po
JOIN order_status os ON po.id = os.placed_order_id
JOIN status_catalog sc ON os.status_catalog_id = sc.id and sc.status_name = 'order confirmed'
JOIN delivery d ON  d.placed_order_id = po.id
JOIN city c ON c.id = po.delivery_city_id
GROUP BY c.id
ORDER BY dispatch_time DESC
LIMIT 5

-- Query 4
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