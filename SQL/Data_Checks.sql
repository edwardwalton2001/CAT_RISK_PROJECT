-- 1. TIV Reconciliation
-- Checks whether reported total TIV equals the sum of its components


SELECT
    exposure.location_id,
    exposure.building_tiv_usd,
    exposure.contents_tiv_usd,
    exposure.business_interruption_tiv_usd,
    exposure.total_tiv_usd
FROM exposure
WHERE exposure.total_tiv_usd <>
      exposure.building_tiv_usd
      + exposure.contents_tiv_usd
      + exposure.business_interruption_tiv_usd;



-- 2. Missing Policy and Hazard-Zone Identifiers
-- Checks for NULL, blank or whitespace-only identifiers


SELECT
    exposure.location_id,
    exposure.policy_id,
    exposure.hazard_zone_id
FROM exposure
WHERE exposure.policy_id IS NULL
   OR TRIM(exposure.policy_id) = ''
   OR exposure.hazard_zone_id IS NULL
   OR TRIM(exposure.hazard_zone_id) = '';



-- 3. Zero or Negative TIV
-- Identifies locations with invalid zero or negative total TIV


SELECT
    exposure.location_id,
    exposure.total_tiv_usd
FROM exposure
WHERE exposure.total_tiv_usd <= 0;


-- 4. Hazard-Zone ID Validation
-- Identifies exposure records whose hazard-zone ID does not match a corresponding record in the hazard table


SELECT
    exposure.location_id,
    exposure.hazard_zone_id,
    hazard.hazard_zone_id
FROM exposure
LEFT JOIN hazard
    ON exposure.hazard_zone_id = hazard.hazard_zone_id
WHERE exposure.hazard_zone_id IS NOT NULL
  AND hazard.hazard_zone_id IS NULL;