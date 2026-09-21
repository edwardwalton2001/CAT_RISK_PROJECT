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
