-- Kenya Mobile Money: the 10 advanced questions in SQL.
-- Dialect: SQLite 3.25+ (window functions). Table: txns, loaded from the CSV.
-- Each query starts with a "-- name: qN" line so the notebook can run them one by one.

-- name: q1
-- Monthly fee revenue and month-over-month growth (completed only)
WITH monthly AS (
    SELECT strftime('%Y-%m', transaction_timestamp) AS month,
           SUM(transaction_fee_kes)                 AS fee_revenue
    FROM txns
    WHERE status = 'Completed'
    GROUP BY month
)
SELECT month,
       ROUND(fee_revenue, 2) AS fee_revenue,
       ROUND(100.0 * (fee_revenue - LAG(fee_revenue) OVER (ORDER BY month))
             / LAG(fee_revenue) OVER (ORDER BY month), 2) AS mom_pct
FROM monthly
ORDER BY month;

-- name: q2
-- Busiest weekday x hour block (0 = Sunday in SQLite)
SELECT CAST(strftime('%w', transaction_timestamp) AS INTEGER) AS weekday,
       CAST(strftime('%H', transaction_timestamp) AS INTEGER) AS hour,
       COUNT(*) AS txn_count
FROM txns
WHERE status = 'Completed'
GROUP BY weekday, hour
ORDER BY txn_count DESC
LIMIT 5;

-- name: q3
-- Top 3 customers by value within each county
WITH totals AS (
    SELECT county, customer_id, customer_name, SUM(amount_kes) AS total_value
    FROM txns
    WHERE status = 'Completed'
    GROUP BY county, customer_id, customer_name
),
ranked AS (
    SELECT *, RANK() OVER (PARTITION BY county ORDER BY total_value DESC) AS rnk
    FROM totals
)
SELECT county, rnk, customer_id, customer_name, ROUND(total_value, 2) AS total_value
FROM ranked
WHERE rnk <= 3
ORDER BY county, rnk;

-- name: q4
-- Days whose volume exceeded 1.5x the trailing 7-day average
WITH daily AS (
    SELECT DATE(transaction_timestamp) AS day, COUNT(*) AS txns
    FROM txns
    WHERE status = 'Completed'
    GROUP BY day
),
rolled AS (
    SELECT day, txns,
           AVG(txns) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rolling_7d
    FROM daily
)
SELECT COUNT(*) AS spike_days
FROM rolled
WHERE txns > 1.5 * rolling_7d;

-- name: q5
-- RFM scores (quintiles) and segment sizes
WITH base AS (
    SELECT customer_id,
           JULIANDAY((SELECT MAX(transaction_timestamp) FROM txns WHERE status = 'Completed'))
             - JULIANDAY(MAX(transaction_timestamp)) AS recency_days,
           COUNT(*)        AS frequency,
           SUM(amount_kes) AS monetary
    FROM txns
    WHERE status = 'Completed'
    GROUP BY customer_id
),
scored AS (
    SELECT *,
           6 - NTILE(5) OVER (ORDER BY recency_days) AS r,
           NTILE(5) OVER (ORDER BY frequency)         AS f,
           NTILE(5) OVER (ORDER BY monetary)          AS m
    FROM base
)
SELECT CASE WHEN r >= 4 AND f >= 4 AND m >= 4 THEN 'Champions'
            WHEN r <= 2 AND f >= 3              THEN 'At risk'
            WHEN r >= 4                         THEN 'Recent'
            ELSE 'Others' END AS segment,
       COUNT(*) AS customers
FROM scored
GROUP BY segment
ORDER BY customers DESC;

-- name: q6
-- Failure + reversal rate by channel x transaction type (all statuses)
SELECT channel, transaction_type,
       COUNT(*) AS txns,
       ROUND(100.0 * SUM(status IN ('Failed', 'Reversed')) / COUNT(*), 2) AS problem_rate_pct
FROM txns
GROUP BY channel, transaction_type
HAVING COUNT(*) >= 20
ORDER BY problem_rate_pct DESC
LIMIT 5;

-- name: q7
-- Effective fee rate by amount band
SELECT CASE WHEN amount_kes <= 500   THEN '1. 0-500'
            WHEN amount_kes <= 1000  THEN '2. 501-1,000'
            WHEN amount_kes <= 5000  THEN '3. 1,001-5,000'
            WHEN amount_kes <= 20000 THEN '4. 5,001-20,000'
            ELSE '5. 20,000+' END AS band,
       COUNT(*) AS txns,
       ROUND(100.0 * AVG(transaction_fee_kes / amount_kes), 3) AS avg_fee_rate_pct
FROM txns
WHERE status = 'Completed' AND amount_kes > 0
GROUP BY band
ORDER BY band;

-- name: q8
-- 10 customers with the shortest average gap between transactions
WITH ordered AS (
    SELECT customer_id, customer_name,
           JULIANDAY(transaction_timestamp)
             - JULIANDAY(LAG(transaction_timestamp) OVER (PARTITION BY customer_id ORDER BY transaction_timestamp)) AS gap_days
    FROM txns
    WHERE status = 'Completed'
)
SELECT customer_id, customer_name, ROUND(AVG(gap_days), 2) AS avg_gap_days, COUNT(gap_days) + 1 AS txns
FROM ordered
GROUP BY customer_id, customer_name
HAVING COUNT(gap_days) >= 1
ORDER BY avg_gap_days
LIMIT 10;

-- name: q9
-- New vs returning customers per month
WITH firsts AS (
    SELECT customer_id, strftime('%Y-%m', MIN(transaction_timestamp)) AS cohort
    FROM txns
    WHERE status = 'Completed'
    GROUP BY customer_id
),
active AS (
    SELECT DISTINCT customer_id, strftime('%Y-%m', transaction_timestamp) AS month
    FROM txns
    WHERE status = 'Completed'
)
SELECT a.month,
       SUM(a.month = f.cohort) AS new_customers,
       SUM(a.month > f.cohort) AS returning_customers
FROM active a
JOIN firsts f USING (customer_id)
GROUP BY a.month
ORDER BY a.month;

-- name: q10
-- Pareto: cumulative share of value by county
WITH by_county AS (
    SELECT county, SUM(amount_kes) AS value
    FROM txns
    WHERE status = 'Completed'
    GROUP BY county
)
SELECT county,
       ROUND(value, 2) AS value,
       ROUND(100.0 * SUM(value) OVER (ORDER BY value DESC) / SUM(value) OVER (), 2) AS cumulative_pct
FROM by_county
ORDER BY value DESC;
