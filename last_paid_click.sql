WITH paid_sessions AS (
    SELECT
        s.visitor_id,
        s.visit_date,
        s.source,
        s.medium,
        s.campaign
    FROM sessions AS s
    WHERE s.medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),

joined_data AS (
    SELECT
        ps.visitor_id,
        ps.visit_date,
        ps.source,
        ps.medium,
        ps.campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        ROW_NUMBER() OVER (
            PARTITION BY ps.visitor_id, l.lead_id
            ORDER BY ps.visit_date DESC
        ) AS rn
    FROM paid_sessions AS ps
    LEFT JOIN leads AS l
        ON
            ps.visitor_id = l.visitor_id
            AND ps.visit_date <= l.created_at
)

SELECT
    visitor_id,
    visit_date,
    source AS utm_source,
    medium AS utm_medium,
    campaign AS utm_campaign,
    lead_id,
    created_at,
    amount,
    closing_reason,
    status_id
FROM joined_data
WHERE rn = 1
ORDER BY
    amount DESC NULLS LAST,
    visit_date ASC,
    utm_source ASC,
    utm_medium ASC,
    utm_campaign ASC
LIMIT 10;
