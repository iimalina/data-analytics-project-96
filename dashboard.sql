WITH ads AS (
    SELECT
        utm_source,
        SUM(daily_spent) AS total_cost
    FROM vk_ads
    GROUP BY utm_source

    UNION ALL

    SELECT
        utm_source,
        SUM(daily_spent) AS total_cost
    FROM ya_ads
    GROUP BY utm_source
),

ads_agg AS (
    SELECT
        utm_source,
        SUM(total_cost) AS total_cost
    FROM ads
    GROUP BY utm_source
),

visitors AS (
    SELECT
        source AS utm_source,
        COUNT(visitor_id) AS visitors_count
    FROM sessions
    GROUP BY source
),

last_paid_click AS (
    SELECT DISTINCT ON (l.lead_id)
        l.lead_id,
        s.source AS utm_source,
        l.amount,
        l.closing_reason,
        l.status_id
    FROM leads l
    JOIN sessions s
        ON l.visitor_id = s.visitor_id
       AND s.visit_date <= l.created_at
    WHERE s.medium != 'organic'
    ORDER BY
        l.lead_id,
        s.visit_date DESC
),

leads_agg AS (
    SELECT
        utm_source,
        COUNT(lead_id) AS leads_count,

        COUNT(CASE
            WHEN closing_reason = 'Успешно реализовано'
              OR status_id = 142
            THEN lead_id
        END) AS purchases_count,

        SUM(CASE
            WHEN closing_reason = 'Успешно реализовано'
              OR status_id = 142
            THEN amount
            ELSE 0
        END) AS revenue
    FROM last_paid_click
    GROUP BY utm_source
),

base AS (
    SELECT
        COALESCE(v.utm_source, a.utm_source, l.utm_source) AS utm_source,

        COALESCE(v.visitors_count, 0) AS visitors_count,
        COALESCE(a.total_cost, 0) AS total_cost,
        COALESCE(l.leads_count, 0) AS leads_count,
        COALESCE(l.purchases_count, 0) AS purchases_count,
        COALESCE(l.revenue, 0) AS revenue

    FROM visitors v

    FULL JOIN ads_agg a
        ON v.utm_source = a.utm_source

    FULL JOIN leads_agg l
        ON COALESCE(v.utm_source, a.utm_source) = l.utm_source
)

SELECT
    utm_source,
    visitors_count,
    total_cost,
    leads_count,
    purchases_count,
    revenue,

    ROUND(total_cost::numeric / NULLIF(visitors_count, 0), 2) AS cpu,
    ROUND(total_cost::numeric / NULLIF(leads_count, 0), 2) AS cpl,
    ROUND(total_cost::numeric / NULLIF(purchases_count, 0), 2) AS cppu,
    ROUND((revenue - total_cost)::numeric / NULLIF(total_cost, 0) * 100, 2) AS roi

FROM base
ORDER BY revenue DESC NULLS LAST;