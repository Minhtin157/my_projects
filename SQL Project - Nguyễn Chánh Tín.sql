Data source: https://console.cloud.google.com/bigquery?project=alert-parsec-369410&ws=!1m5!1m4!4m3!1sbigquery-public-data!2sgoogle_analytics_sample!3sga_sessions_20170801

1. Calculate total visit, pageview, transaction and revenue for Jan, Feb and March 2017 order by month

with sub as (
SELECT  FORMAT_DATE('%Y%m', (parse_date('%Y%m%d', date))) as month,
        sum(totals.visits) as visita, 
        sum(totals.pageviews) as pageviews,
        sum(totals.transactions) as transactions,
        sum(totals.totalTransactionRevenue)/1000000 as revenue
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
where _table_suffix between '0101' and '0331' 
group by 1
)

select month, visits, total_pageviews, transactions, revenue
from sub
order by 1  

2. Calculate bounce rate per traffic source in July 2017
#standardSQL
select trafficSource.source
       , sum(totals.visits) as total_visit
       , sum(totals.bounces) as total_no_of_bounces
       ,100*sum(totals.bounces)/sum(totals.visits) as bounce_rate
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`
group by trafficSource.source
order by total_visit DESC

3. Calculate revenue by traffic source by week, by month in June 2017

with week_revenue as
       (SELECT FORMAT_DATE('%Y%W', (parse_date('%Y%m%d', date))) as time
              ,'week' as time_type
              ,trafficSource.source
              ,sum(totals.totalTransactionRevenue)/1000000 as total_revenue
       FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201706*`
       group by 1,2,3  
       )

,month_revenue as (
       SELECT FORMAT_DATE('%Y%m', (parse_date('%Y%m%d', date))) as time
              ,'month' as time_type
              ,trafficSource.source
              ,sum(totals.totalTransactionRevenue)/1000000 as total_revenue
       FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201706*`
       group by 1,2,3 
       )

,final as (
       select time, week_revenue.time_type, week_revenue.source, week_revenue.total_revenue
       from week_revenue
       where week_revenue.total_revenue is not null
       union distinct
       SELECT time, month_revenue.time_type,month_revenue.source, month_revenue.total_revenue
       from month_revenue
       where month_revenue.total_revenue is not null
       order by total_revenue desc)

select time_type, time, source, final.total_revenue
from final
order by source, time



4. Average number of product pageviews by purchaser type (purchasers vs non-purchasers) in June, July 2017. Note: totals.transactions >=1 for purchaser and totals.transactions is null for non-purchaser
#standardSQL

with purchaser as (
       select  format_date("%Y%m" , parse_DATE("%Y%m%d", date)) as month, 
               sum(totals.pageviews)/count(distinct fullVisitorID) as avg_pageviews_purchase
       FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
       where _table_suffix between '0601' and '0731' 
       and totals.transactions is not null 
       group by month
),
non_purchaser as (
       select format_date("%Y%m" , parse_DATE("%Y%m%d", date)) as month, 
              sum(totals.pageviews)/count(distinct fullVisitorID) as avg_pageviews_non_purchase
       FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
       where _table_suffix between '0601' and '0731' 
       and totals.transactions is null 
       group by FORMAT_DATE('%Y%m', (parse_date('%Y%m%d', date)))      
)

select  s1.*
       ,s2.avg_pageviews_non_purchase
from purchaser as s1
inner join non_purchaser as s2
using (month)
order by month



5. Average number of transactions per user that made a purchase in July 2017

select  format_date("%Y%m" , parse_DATE("%Y%m%d", date)) as month, 
        sum(totals.transactions) /count(distinct fullVisitorID) as Avg_total_transactions_per_user
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
where _table_suffix between '0701' and '0731' 
 and totals.transactions is not null 
group by month

6. Average amount of money spent per session

select  sum(totals.totalTransactionRevenue)/count(totals.transactions) as avg_revenue_by_user_per_visit
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*` 
where totals.transactions is not null


7. Other products purchased by customers who purchased product "YouTube Men's Vintage Henley" in July 2017. Output should show product name and the quantity was ordered #standardSQL

with customer_ID as (
       SELECT distinct fullVisitorId
       FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*` ,
       unnest(hits) as hits,
       unnest(product) as product
       where v2ProductName = "YouTube Men's Vintage Henley" 
       and productRevenue is not null)

select v2ProductName as other_purchased_products, sum(productQuantity) as quantity
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*` ,
unnest(hits) as hits,
unnest(hits.product) as product
-- where fullVisitorId in 
--        (Select fullVisitorId From customer_ID) 
--        and productRevenue is not null and v2ProductName != "YouTube Men's Vintage Henley"
inner join customer_ID using(fullVisitorId) 
group by other_purchased_products
order by quantity desc

8.Calculate cohort map from pageview to addtocart to purchase in last 3 month. For example, 100% pageview then 40% add_to_cart and 10% purchase.


with product_view as (
       SELECT FORMAT_DATE('%Y%m', (parse_date('%Y%m%d', date))) as month,
       COUNT(v2ProductName) as num_product_view
       FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*` ,
       unnest(hits) as hits,
       unnest(hits.product) as product
       where _table_suffix between '0101' and '0331' and eCommerceAction.action_type in ('2')
       group by month),

add_to_cart as (
       SELECT FORMAT_DATE('%Y%m', (parse_date('%Y%m%d', date))) as month,
       COUNT(v2ProductName) as num_addtocart
       FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*` ,
       unnest(hits) as hits,
       unnest(hits.product) as product
       where _table_suffix between '0101' and '0331' and eCommerceAction.action_type in ('3')
       group by month),

purchase as (
       SELECT FORMAT_DATE('%Y%m', (parse_date('%Y%m%d', date))) as month,
       COUNT(v2ProductName) as num_purchase
       FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*` ,
       unnest(hits) as hits,
       unnest(hits.product) as product
       where _table_suffix between '0101' and '0331' and eCommerceAction.action_type in ('6')
       and product.productRevenue is not null
       group by month)

select product_view.month, num_product_view, num_addtocart, num_purchase, 
       round(100*num_addtocart/num_product_view,2) as add_to_cart_rate,
       round(100*num_purchase/num_product_view, 2) as purchase_rate
from product_view
inner join add_to_cart
using (month)
inner join purchase
using (month)
order by month