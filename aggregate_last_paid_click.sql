WITH last_paid_click AS (
    SELECT DISTINCT ON (l.lead_id)
        l.lead_id,
        l.amount,
        l.closing_reason,
        l.status_id,
        s.visit_date::date AS visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign
    FROM leads AS l
    INNER JOIN sessions AS s
        ON
            l.visitor_id = s.visitor_id
            AND l.created_at >= s.visit_date
    WHERE s.source IN ('yandex', 'vk')
    ORDER BY l.lead_id ASC, s.visit_date DESC
),

visits AS (
    SELECT
        visit_date::date AS visit_date,
        source AS utm_source,
        medium AS utm_medium,
        campaign AS utm_campaign,
        COUNT(*) AS visitors_count
    FROM sessions
    WHERE source IN ('yandex', 'vk')
    GROUP BY visit_date, utm_source, utm_medium, utm_campaign
),

costs AS (
    SELECT
        campaign_date AS visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM (
        SELECT
            campaign_date,
            utm_source,
            utm_medium,
            utm_campaign,
            daily_spent
        FROM vk_ads
        UNION ALL
        SELECT
            campaign_date,
            utm_source,
            utm_medium,
            utm_campaign,
            daily_spent
        FROM ya_ads
    ) AS t
    GROUP BY visit_date, utm_source, utm_medium, utm_campaign
)

SELECT
    v.visit_date,
    v.visitors_count,
    v.utm_source,
    v.utm_medium,
    v.utm_campaign,
    c.total_cost,
    COUNT(l.lead_id) AS leads_count,
    COUNT(l.lead_id) FILTER (
        WHERE l.closing_reason = 'Успешно реализовано'
        OR l.status_id = 142
    ) AS purchases_count,
    SUM(l.amount) FILTER (
        WHERE l.closing_reason = 'Успешно реализовано'
        OR l.status_id = 142
    ) AS revenue
FROM visits AS v
LEFT JOIN costs AS c
    ON
        v.visit_date = c.visit_date
        AND v.utm_source = c.utm_source
        AND v.utm_medium = c.utm_medium
        AND v.utm_campaign = c.utm_campaign
LEFT JOIN last_paid_click AS l
    USING (visit_date, utm_source, utm_medium, utm_campaign)
GROUP BY
    v.visit_date,
    v.visitors_count,
    v.utm_source,
    v.utm_medium,
    v.utm_campaign,
    c.total_cost
ORDER BY
    revenue DESC NULLS LAST,
    visit_date ASC,
    v.visitors_count DESC,
    utm_source ASC,
    utm_medium ASC,
    utm_campaign ASC;
