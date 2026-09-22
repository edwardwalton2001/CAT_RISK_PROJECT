### Catastrophe Exposure Analysis

## Project Overview

This project analyses a simulated insurance exposure portfolio to identify catastrophe risk concentrations across policies, geographic regions, hazard zones, and construction types....
The analysis uses location-level exposure data containing Total Insured Value (TIV), policy information, and hazard characteristics. 
PostgreSQL is used to join, aggregate, and analyse the datasets to identify areas of higher exposure and potential catastrophe risk.

The project focuses on questions such as:

- Which regions have the greatest concentration of insured exposure?
- Which regions have the greatest concentration of Severe hazard exposure?
- Which policies have high exposure relative to their policy limits?
- Which construction types have the greatest exposure to Severe hazard zones?
- Which policy and hazard-zone combinations represent the greatest accumulation risk?
- Which states have the greatest concentration of insured value, and how dependent is each state's exposure on its largest hazard zone?
- How many insured locations are exposed to higher hazard levels?
- How much TIV is located in Severe hazard zones?

- ## Tools Used

- PostgreSQL
- SQL
- pgAdmin
- VS Code
- Excel
- GitHub

- ## Dataset

The project uses three datasets:

- Exposure.csv – location-level insured exposure information.
- Policy.csv – policy limits, deductibles and other policy information.
- Hazard.csv – hazard-zone characteristics and hazard classifications.




## Database Schema

The database consists of three related tables: `exposure`, `policy`, and `hazard`.

# Policy Table

| Column | Data Type |
|---|---|
| policy_id | VARCHAR(20) - Primary Key |
| underwriter_id | VARCHAR(20) |
| policy_type | VARCHAR(100) |
| policy_limit_usd | BIGINT |
| deductible_usd | BIGINT |
| attachment_point_usd | BIGINT |
| participation_share | NUMERIC(5,2) |
| limit_basis | VARCHAR(50) |
| policy_status | VARCHAR(50) |

# Hazard Table

| Column | Data Type |
|---|---|
| hazard_zone_id | VARCHAR(20) - Primary Key |
| region | VARCHAR(50) |
| wind_speed_1in100_mph | INT |
| flood_depth_1in100_m | NUMERIC(10,2) |
| pga_1in475_g | NUMERIC(10,3) |
| wildfire_score_0_100 | INT |
| hail_score_0_100 | INT |
| composite_hazard_score | NUMERIC(10,2) |
| hazard_band | VARCHAR(50) |

# Exposure Table

| Column | Data Type |
|---|---|
| location_id | VARCHAR(20) - Primary Key |
| account_id | VARCHAR(20) |
| policy_id | VARCHAR(20) - Foreign Key |
| region | VARCHAR(50) |
| state | VARCHAR(10) |
| postal_code | INT |
| latitude | NUMERIC(10,5) |
| longitude | NUMERIC(10,5) |
| hazard_zone_id | VARCHAR(20) - Foreign Key |
| occupancy | VARCHAR(100) |
| construction_code | VARCHAR(50) |
| year_built | INT |
| number_of_stories | INT |
| building_tiv_usd | BIGINT |
| contents_tiv_usd | BIGINT |
| business_interruption_tiv_usd | BIGINT |
| total_tiv_usd | BIGINT |

## Table Relationships

exposure.policy_id - policy.policy_id`

exposure.hazard_zone_id - hazard.hazard_zone_id

Exposure sits as the central table connecting both policy and hazard with common fields.


### SQL Analysis

## 1. Exposure by Region

**Question**
Which regions have the greatest concentration of insured exposure?

This analysis aggregates location-level exposure by region to calculate the total insured value (TIV) and number of insured locations.

```sql
SELECT
    exposure.region,
    SUM(exposure.total_tiv_usd) AS total_tiv,
    COUNT(exposure.location_id) AS location_count
FROM exposure
GROUP BY exposure.region
ORDER BY total_tiv DESC;
```

## 2. Exposure by 'Severe' hazard
Which regions have the greatest concentration of Severe hazard exposure?

This analysis aggregates location-level exposure by region with greatest concentration of severe hazard exposure.

```sql
WITH exposure_region AS(
    SELECT
        exposure.region,
        SUM(total_tiv_usd) AS total_tiv, -- Total tiv from all locations in the region
    SUM(
        CASE
            WHEN hazard_band = 'Severe'
            THEN exposure.total_tiv_usd
            ELSE 0 
        END
    ) AS severe_tiv, -- SUM of tiv in severe locations
    
    SUM(
        CASE
            WHEN hazard.hazard_band = 'Severe'
            THEN 1
            ELSE 0
        END
        ) AS severe_location_count -- Using SUM to add up each severe location assigning 'severe' = 1. Adds up each 1 for every region to see which                                        has the most severe locations.
    FROM Exposure
    
    LEFT JOIN hazard ON exposure.hazard_zone_id = hazard.hazard_zone_id
    
    GROUP BY exposure.region
)
SELECT *
FROM exposure_region
ORDER BY exposure_region.total_tiv DESC; -- Ordering by the total_tiv in a descending order.
```

## 3. Exposure vs Policy Limit 

Which policies have the greatest insured exposure relative to their policy limits, and how much of that exposure is located in Severe hazard zones?

This analysis aggregates location-level exposure data to the policy level. It calculates total insured value (TIV), the number of insured locations, TIV located in Severe hazard zones, and the ratio between total TIV and the policy limit.

```sql
WITH policy_exposure AS (
    SELECT
        exposure.policy_id,
        policy.policy_limit_usd,

        SUM(exposure.total_tiv_usd) AS total_policy_tiv,
        COUNT(exposure.location_id) AS location_count, -- This counts how many exposure locations belong to each policy.

        SUM( -- Calculates the sum of those severe tiv's
            CASE
                WHEN hazard.hazard_band = 'Severe' -- Includes TIV only from Severe hazard locations
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
```

## 4. Average policy TIV 

Which policies have above-average total TIV and at least 3 insured locations?

This analysis aggregates exposure at the policy level and identifies policies with above-average total TIV and at least three insured locations. It also shows each policy's type, policy limit, location count, and average TIV per location.

```sql

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
INNER JOIN policy -- Using inner join as only require valid policies with corresponding policy information for this analysis.
    ON policy_exposure.policy_id = policy.policy_id

WHERE policy_exposure.total_policy_tiv > ( -- Finds policies where the total TIV is greater than the average
    SELECT AVG(total_policy_tiv)
    FROM policy_exposure
)

AND policy_exposure.location_count >= 3 -- Only selects policies with at least 3 locations

ORDER BY policy_exposure.total_policy_tiv DESC;
```

## 5. Policy and hazard zone risk

Which policy and hazard-zone combinations represent the greatest accumulation risk?

This analysis aggregates exposure at the policy and hazard-zone level to identify policies with significant exposure concentrated within individual hazard zones. It highlights policy and hazard-zone combinations where more than 25% of the policy's total TIV is located within a single zone and where the hazard-zone TIV equals or exceeds the policy limit.

The results are ranked by hazard-zone TIV in descending order, allowing the largest exposure accumulations to be identified first. The hazard band is also included to provide additional context on the hazard characteristics associated with each concentration.

```sql

WITH policy_exposure AS ( -- Aggregates location level exposure at policy level.
    SELECT
        exposure.policy_id,
        policy.policy_limit_usd,
        
        SUM(total_tiv_usd) AS total_policy_tiv, -- Calculates the total TIV across all locations belonging to each policy.
        
        COUNT(location_id) AS location_count -- Counts how many locations belong to that policy.
    FROM exposure

    JOIN policy ON 
        exposure.policy_id = policy.policy_id
    
    GROUP BY exposure.policy_id,
             policy.policy_limit_usd
),

policy_hazard_exposure AS( -- Aggregates exposure by policy and hazard zone.
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
    NULLIF(policy_exposure.policy_limit_usd,0) AS zone_tiv_to_limit_ratio -- Calculates the hazard-zone TIV relative to the policy limit.

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
```


## 6. Hazard Zone Exposure Concentration by State

Which states have the greatest concentration of insured value, and how dependent is each state's exposure on its largest hazard zone?

This analysis aggregates exposure at the state and hazard-zone level to identify which states have the greatest concentration of insured value within a single hazard zone. It identifies the hazard zone with the highest TIV in each state and calculates the percentage of the state's total TIV concentrated within that zone. The results are ranked by this percentage to highlight states that are most dependent on their largest hazard-zone concentration.

```sql

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
```
## Key Findings
- **Region Exposure:** The east region has the highest concentration of general exposure, whilst the north has the least. The story remains the same       for severe hazard exposure. However, one anomaly is the west region where it ranks third in terms of severe_tiv but has fewer severe_tiv             locations than both central and north regions.
- **Policy Exposure:** POL00097 had the largest total insured value at approximately $30,643,573 distributed across 7 insured locations. Its total
      TIV represented 3 times the policy limit.
- **Severe Hazard Exposure:** POL00275 had $8,586,508 of TIV located within Severe hazard zones, representing 78% of its total policy exposure.
* **Policy Hazard-Zone Concentration:**

  * **Largest Hazard-Zone Exposure:** POL00275 had the largest qualifying hazard-zone exposure, with approximately **$8.6 million in TIV** concentrated within **HZ-W-07**, a **Severe** hazard zone. This represented approximately **32.9%** of the policy's total TIV and **3.4x** its $2.5 million policy limit.
  * **Highest Zone TIV-to-Limit Ratio:** POL00072 had the highest zone TIV-to-limit ratio at approximately **6.4x**. Its hazard zone, **HZ-C-11**, contained approximately **$6.4 million in TIV**, representing **43.6%** of the policy's total exposure. However, this exposure was associated with a **Low** hazard band, demonstrating that a high exposure-to-limit ratio does not necessarily correspond to high hazard severity.
  * **High Concentration and High Hazard:** POL00169 had approximately **64.3%** of its total policy TIV concentrated within **HZ-E-20**, a **High** hazard zone. The zone contained approximately **$5.9 million in TIV**, equivalent to **5.9x** the policy's $1 million limit.
  * **Fully Concentrated Policies:** Several qualifying policies had **100% of their total TIV concentrated within a single hazard zone**, demonstrating cases where all insured value associated with the policy was located within one zone. These cases occurred across different hazard bands, including Low, Moderate and Severe.
* **Concentration Relative to Policy Limit:**

  * **Largest Policy Exposure:** POL00097 had the highest total policy TIV at approximately **$30.6 million** across seven insured locations. Its total TIV was approximately **3.1x** its **$10 million policy limit**, with around **$4.0 million** located in Severe hazard zones.
  * **Highest Exposure-to-Limit Ratio:** POL00308 had the highest exposure-to-limit ratio at approximately **19.1x**, with **$19.1 million** in total TIV compared with a **$1 million policy limit**. Approximately **$10.0 million** of this exposure was located in Severe hazard zones.
  * **Largest Severe Hazard Exposure:** POL00275 had the highest Severe-zone TIV at approximately **$20.2 million** out of **$26.0 million** in total policy TIV. This means approximately **77.7%** of the policy's insured value was associated with Severe hazard zones, while its total TIV was approximately **10.4x** its **$2.5 million policy limit**.

* **State-Hazard Zone Concentration:**

  * **Highest Total State Exposure:** New Jersey had the largest overall exposure, with approximately **$273.7 million in total TIV** across **85 insured locations**. Its largest hazard zone, **HZ-E-09**, contained approximately **$29.4 million**, representing **10.8%** of the state's total TIV.
  * **Greatest Hazard-Zone Concentration:** Texas had the greatest concentration of exposure within a single hazard zone. **HZ-S-06** contained approximately **$35.3 million in TIV**, representing **17.2%** of Texas's total state TIV. This was also the largest individual hazard-zone TIV among the states analysed.
  * **Other Notable Concentrations:** Pennsylvania and Massachusetts had the next-highest single-zone concentrations, with their largest hazard zones accounting for approximately **13.7%** and **13.2%** of total state TIV, respectively.
  * **Lowest Hazard-Zone Concentration:** Louisiana had the lowest concentration within its largest hazard zone at approximately **9.6%**, indicating that its exposure was more dispersed across hazard zones than the other states analysed.


- **Exposure Distribution:** The analysis identified differences in both the absolute amount and relative concentration of Severe hazard exposure          across regions, demonstrating why total TIV and hazard concentration should be considered separately.

