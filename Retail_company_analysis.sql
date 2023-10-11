DROP TABLE info;

CREATE TABLE info
(
    product_name VARCHAR(100),
    product_id VARCHAR(11) PRIMARY KEY,
    description VARCHAR(700)
);

DROP TABLE finance;

CREATE TABLE finance
(
    product_id VARCHAR(11) PRIMARY KEY,
    listing_price FLOAT,
    sale_price FLOAT,
    discount FLOAT,
    revenue FLOAT
);

DROP TABLE reviews;

CREATE TABLE reviews
(
    product_id VARCHAR(11) PRIMARY KEY,
    rating FLOAT,
    reviews FLOAT
);

DROP TABLE traffic;

CREATE TABLE traffic
(
    product_id VARCHAR(11) PRIMARY KEY,
    last_visited TIMESTAMP
);

DROP TABLE brands;

CREATE TABLE brands
(
    product_id VARCHAR(11) PRIMARY KEY,
    brand VARCHAR(7)
);

\copy info FROM 'info_v2.csv' DELIMITER ',' CSV HEADER;
\copy finance FROM 'finance.csv' DELIMITER ',' CSV HEADER;
\copy reviews FROM 'reviews_v2.csv' DELIMITER ',' CSV HEADER;
\copy traffic FROM 'traffic_v3.csv' DELIMITER ',' CSV HEADER;
\copy brands FROM 'brands_v2.csv' DELIMITER ',' CSV HEADER;


-- Analysis 
-- 1. Counting missing values
SELECT count(*) as total_rows,
    count(i.description) as count_description,
    count(f.listing_price) as count_listing_price,
    count(t.last_visited) as count_last_visited
FROM info i 
JOIN finance f
ON i.product_id = f.product_id 
JOIN traffic t
ON i.product_id = t.product_id;

-- 2. Nike vs Adidas pricing
SELECT b.brand, 
       CAST(listing_price AS Integer) as listing_price, 
       COUNT(f.*)
FROM brands b
JOIN finance f
ON b.product_id = f.product_id
WHERE f.listing_price > 0
GROUP BY b.brand, listing_price
ORDER BY listing_price DESC;

-- 3. Labeling price ranges
SELECT b.brand,
        COUNT(f.*),
        SUM(f.revenue) as total_revenue,
        CASE WHEN f.listing_price < 42 THEN 'Budget'
             WHEN f.listing_price >= 42 AND f.listing_price < 74 THEN 'Average'
             WHEN f.listing_price >= 74 AND f.listing_price < 129 THEN 'Expensive'
            ELSE 'Elite' 
        END AS price_category
FROM brands b
JOIN finance f
ON b.product_id = f.product_id
WHERE b.brand IS NOT NULL
GROUP BY b.brand, price_category
ORDER BY total_revenue DESC;

-- 4. Average discount by brand
SELECT b.brand,
       AVG(discount)*100 as average_discount
FROM brands b
JOIN finance f
ON b.product_id = f.product_id
WHERE b.brand IS NOT NULL
GROUP BY b.brand;

-- 5. Correlation between revenue and reviews
SELECT CORR(f.revenue, r.reviews) AS review_revenue_corr
FROM finance f
JOIN reviews r
ON f.product_id = r.product_id;

-- 6. Ratings and reviews by product description length
SELECT TRUNC(Length(description)/100.0) *100 as description_length,
       ROUND(AVG(CAST(rating AS numeric)),2) as  average_rating
FROM info i
JOIN reviews r 
ON i.product_id = r.product_id
WHERE description IS NOT NULL
GROUP BY description_length
ORDER BY description_length;

-- 7.Reviews by month and brand
SELECT b.brand, 
       DATE_PART('month', last_visited) as month,
       COUNT(r.*) as num_reviews
FROM brands b
JOIN traffic t
ON b.product_id = t.product_id
JOIN reviews r
ON r.product_id = t.product_id
WHERE b.brand IS NOT NULL
GROUP BY b.brand, month
HAVING DATE_PART('month', last_visited) IS NOT NULL
ORDER BY b.brand, month;

-- 8. Top Revenue Generated Products with Brands
WITH highest_revenue_product AS
(  
   SELECT i.product_name,
          b.brand,
          revenue
   FROM finance f
   JOIN info i
   ON f.product_id = i.product_id
   JOIN brands b
   ON b.product_id = i.product_id
   WHERE product_name IS NOT NULL 
     AND revenue IS NOT NULL 
     AND brand IS NOT NULL
)
SELECT product_name,
       brand,
       revenue,
        RANK() OVER (ORDER BY revenue DESC) AS product_rank
FROM highest_revenue_product
LIMIT 10;

-- 9.  Footwear product performance
with footwear AS 
( SELECT i.description, 
         f.revenue
  FROM info i
  INNER JOIN finance f
  ON i.product_id = f.product_id
  WHERE i.description ILIKE '%shoe%' 
        OR i.description ILIKE '%trainer%' 
        OR i.description ILIKE '%foot%' 
        AND i.description IS NOT NULL 
)
select COUNT(*) as num_footwear_products,
       percentile_disc(0.5) WITHIN GROUP(ORDER BY revenue) as median_footwear_revenue
FROM footwear;

-- 10. Clothing product performance
with footwear AS 
( SELECT i.description, 
         f.revenue
  FROM info i
  INNER JOIN finance f
  ON i.product_id = f.product_id
  WHERE i.description ILIKE '%shoe%' 
        OR i.description ILIKE '%trainer%' 
        OR i.description ILIKE '%foot%' 
        AND i.description IS NOT NULL 
)
select COUNT(i.*) as num_clothing_products,
       percentile_disc(0.5) WITHIN GROUP(ORDER BY revenue) as median_clothing_revenue
FROM info i
INNER JOIN finance f
ON i.product_id = f.product_id
WHERE i.description NOT IN (select description from footwear);
