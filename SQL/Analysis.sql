-- Average policy TIV

WITH policy_exposure AS (
    SELECT
        policy_id,
        SUM(total_tiv_usd) AS total_policy_tiv,
        COUNT(location_id) AS location_count,
        AVG(total_tiv_usd) AS avg_location_tiv
    FROM exposure
    GROUP BY policy_id
)

SELECT
    policy.policy_id,
    policy.policy_type,
    policy.policy_limit_usd,
    policy_exposure.total_policy_tiv,
    policy_exposure.location_count,
    policy_exposure.avg_location_tiv
FROM policy_exposure
INNER JOIN policy
    ON policy_exposure.policy_id = policy.policy_id

WHERE policy_exposure.total_policy_tiv > (
    SELECT AVG(total_policy_tiv)
    FROM policy_exposure
)

AND policy_exposure.location_count >= 3

ORDER BY policy_exposure.total_policy_tiv DESC;


--Which polices have the greatest concentration of exposure?

SELECT
    exposure.policy_id,
    exposure.region,
    SUM(total_tiv_usd) AS total_policy_tiv,
    COUNT(location_id) AS location_count
FROM exposure
LEFT JOIN hazard ON exposure.hazard_zone_id = hazard.hazard_zone_id
WHERE hazard_band = 'Severe'
GROUP BY exposure.policy_id,
         exposure.region
ORDER BY total_policy_tiv DESC;


--Which regions have the most exposure?

SELECT
    exposure.region,
    SUM(exposure.total_tiv_usd) AS total_tiv,
    COUNT(exposure.location_id) AS location_count
FROM exposure
GROUP BY exposure.region
ORDER BY total_tiv DESC;



-- Policy limit vs exposure

WITH policy_exposure AS (
    SELECT
        exposure.policy_id,
        policy.policy_limit_usd,

        SUM(exposure.total_tiv_usd) AS total_policy_tiv,
        COUNT(exposure.location_id) AS location_count, -- This counts how many exposure locations belong to each policy.

        SUM( -- Calculates the sum of those severe tiv's
            CASE
                WHEN hazard.hazard_band = 'Severe' -- Only selecting polcies where SEVERE
                THEN exposure.total_tiv_usd
                ELSE 0
            END
        ) AS severe_tiv

    FROM exposure -- From exposure as it connects the hazard and policy tables with common fields

    LEFT JOIN policy
        ON exposure.policy_id = policy.policy_id -- Joined by policy_id as there is no common policy_limit

    LEFT JOIN hazard
        ON exposure.hazard_zone_id = hazard.hazard_zone_id -- Exposure tells which hazard zone a location belongs to
                                                           -- Hazard tells information about that zone
                                                           -- This also allows the CASE to access the hazard band

    GROUP BY
        exposure.policy_id, -- Grouping by policy_id adds all locations together belonging to each policy
        policy.policy_limit_usd -- Inlcuidng this but not aggregating
)

SELECT
    policy_exposure.policy_id,
    policy_exposure.policy_limit_usd,
    policy_exposure.total_policy_tiv,
    policy_exposure.location_count,
    policy_exposure.severe_tiv,
   
    policy_exposure.total_policy_tiv / -- Dividing the total_policy_tiv by the policy_limit gives the ratio
        NULLIF(policy_exposure.policy_limit_usd, 0) AS exposure_to_limit_ratio -- NUll used so if something like 40/0 occurs it retunrs NULL.

FROM policy_exposure

ORDER BY policy_exposure.total_policy_tiv DESC;


-- Which regions have the greatest concentration of severe hazard exposure?
 
WITH exposure_region AS (
    SELECT
        exposure.region,
        SUM(exposure.total_tiv_usd) AS total_tiv,

        SUM(
            CASE
                WHEN hazard.hazard_band = 'Severe'
                THEN exposure.total_tiv_usd
                ELSE 0 
            END
        ) AS severe_tiv,

        SUM(
            CASE
                WHEN hazard.hazard_band = 'Severe'
                THEN 1
                ELSE 0
            END
        ) AS severe_location_count

    FROM exposure
    
    LEFT JOIN hazard 
        ON exposure.hazard_zone_id = hazard.hazard_zone_id
    
    GROUP BY exposure.region
)

SELECT
    exposure_region.region,
    exposure_region.total_tiv,
    exposure_region.severe_tiv,
    exposure_region.severe_location_count,

    (
        exposure_region.severe_tiv /
        NULLIF(exposure_region.total_tiv, 0)
    ) * 100.00 AS severe_tiv_percentage

FROM exposure_region

ORDER BY severe_tiv_percentage DESC;



--Which policy and hazard-zone combinations represent the greatest accumulation risk?

WITH policy_exposure AS ( -- Aggregates location level exposure at policy level
    SELECT
        exposure.policy_id,
        policy.policy_limit_usd,
        
        SUM(total_tiv_usd) AS total_policy_tiv, -- Calculates the total TIV across all locations belonging to each policy
        
        COUNT(location_id) AS location_count -- Counts how many locations belong to that policy
    FROM exposure

    JOIN policy ON 
        exposure.policy_id = policy.policy_id
    
    GROUP BY exposure.policy_id,
             policy.policy_limit_usd
),

policy_hazard_exposure AS( -- Aggregates exposure by policy and hazard zone
    SELECT
        exposure.policy_id,
        exposure.hazard_zone_id,
        hazard.hazard_band,

        SUM(exposure.total_tiv_usd) AS zone_tiv,-- Calculates TIV for each policy within each individual hazard zone.

        COUNT(exposure.location_id) AS zone_location_count -- Counts the locations for each policy within each hazard zone.
    
    FROM exposure

    LEFT JOIN hazard ON exposure.hazard_zone_id = hazard.hazard_zone_id

    GROUP BY 
    exposure.policy_id,
    exposure.hazard_zone_id,
    hazard.hazard_band

)  

SELECT -- Combines policy-level exposure with hazard-zone exposure to measure concentration within each policy.
    policy_exposure.policy_id,
    policy_exposure.total_policy_tiv,
    policy_exposure.policy_limit_usd,
    policy_hazard_exposure.zone_location_count,
    policy_hazard_exposure.hazard_band,
    policy_hazard_exposure.zone_tiv,
    policy_hazard_exposure.hazard_zone_id,
    
    
(
    policy_hazard_exposure.zone_tiv/
        NULLIF(policy_exposure.total_policy_tiv,0)  -- Dividing zone tiv by total policy tiv to calculate the percentage of the policy's total TIV that is concentrated within that specific hazard zone.
)*100.00 AS hazard_zone_share_of_policy_tiv,

policy_hazard_exposure.zone_tiv/
    NULLIF(policy_exposure.policy_limit_usd,0) AS zone_tiv_to_limit_ratio -- Calculates the hazard-zone TIV relative to the policy limit

FROM policy_exposure

JOIN policy_hazard_exposure ON policy_hazard_exposure.policy_id = policy_exposure.policy_id


WHERE   (
        policy_hazard_exposure.zone_tiv/
        NULLIF(policy_exposure.total_policy_tiv,0) -- Filters for cases where at least 25% of the policy's total TIV is concentrated within one specfic hazard zone.
) *100.00>= 25


AND     (
        policy_hazard_exposure.zone_tiv/
        NULLIF(policy_exposure.policy_limit_usd,0) -- Filters for cases where the hazard-zone TIV is equal to or exceeds the policy limit.
) >= 1


ORDER BY policy_hazard_exposure.zone_tiv DESC, 
         zone_tiv_to_limit_ratio DESC;
         


--Which states have the greatest concentration of insured value, and how dependent is each state's exposure on its largest hazard zone?

WITH state_exposure AS(
    SELECT
        exposure.state,
        
        SUM(exposure.total_tiv_usd) AS total_state_tiv, -- Calculates TIV for each state.

        COUNT(location_id) AS state_location_count -- Counts the total number of locations within each state.
    FROM exposure

    GROUP BY exposure.state
), 

state_hazard_exposure AS ( -- Aggregates exposure to one row per state and hazard-zone combination.
    SELECT
        exposure.state,
        exposure.hazard_zone_id,
        
        SUM(exposure.total_tiv_usd) AS state_zone_tiv, -- Calculates TIV in each individual hazard zone
        
        COUNT(exposure.location_id) AS zone_location_count -- -- Counts locations within each state and hazard-zone combination.
    FROM exposure

    GROUP BY
        exposure.state,
        exposure.hazard_zone_id
),

ranked_zones AS ( -- Compares state-level exposure with hazard-zone exposure and ranks hazard zones by TIV within each state.
    SELECT
        state_exposure.state,
        state_exposure.total_state_tiv,
        state_exposure.state_location_count,

        state_hazard_exposure.state_zone_tiv,
        state_hazard_exposure.hazard_zone_id,
        state_hazard_exposure.zone_location_count,

    ROW_NUMBER() OVER ( 
    PARTITION BY state_exposure.state -- Restarts the hazard-zone ranking for each state
    ORDER BY state_hazard_exposure.state_zone_tiv DESC -- Ranks hazard zones from highest to lowest TIV within each state.
    ) AS zone_rank,

( 
    state_hazard_exposure.state_zone_tiv/
        NULLIF(state_exposure.total_state_tiv,0) -- Calculates the share of total TIV each hazard zone represent relative to the state total TIV.
)*100 AS zone_share_tiv
    
    FROM state_exposure
    
    JOIN state_hazard_exposure ON state_exposure.state = state_hazard_exposure.state -- Joins state totals to each state's hazard-zone totals so zone exposure can be compared with overall state exposure.

)

SELECT
    ranked_zones.state,
    ranked_zones.total_state_tiv,
    ranked_zones.state_location_count,
    ranked_zones.hazard_zone_id,
    ranked_zones.state_zone_tiv,
    ranked_zones.zone_location_count,
    ranked_zones.zone_share_tiv
       
FROM ranked_zones

WHERE ranked_zones.zone_rank = 1 -- Keeps only the hazard zone with the largest TIV within each state.

ORDER BY ranked_zones.zone_share_tiv DESC; -- Ranks states by the percentage of total state TIV
