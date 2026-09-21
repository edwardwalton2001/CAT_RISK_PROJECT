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


