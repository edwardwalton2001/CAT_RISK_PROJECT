import pandas as pd


# 1. Load datasets

exposure = pd.read_csv("CSV_Files/Exposure.csv")
policy = pd.read_csv("CSV_Files/Policy.csv")
hazard = pd.read_csv("CSV_Files/Hazard.csv")


# 2. Define data quality checks

def check_duplicate_locations(exposure):
    duplicate_locations = exposure[
        exposure.duplicated(subset=["LocationID"], keep=False)
    ]

    return duplicate_locations


def check_missing_policy_ids(exposure):
    missing_policy_ids = exposure[
        exposure["PolicyID"].isna()
    ]

    return missing_policy_ids


def check_missing_hazard_ids(exposure):
    missing_hazard_ids = exposure[
        exposure["HazardZoneID"].isna()
    ]

    return missing_hazard_ids


def check_invalid_tiv(exposure):
    invalid_tiv = exposure[
        exposure["TotalTIV_USD"] <= 0
    ]

    return invalid_tiv


def check_tiv_reconciliation(exposure):
    tiv_reconciliation_errors = exposure[
        exposure["TotalTIV_USD"]
        != (
            exposure["BuildingTIV_USD"]
            + exposure["ContentsTIV_USD"]
            + exposure["BusinessInterruptionTIV_USD"]
        )
    ]

    return tiv_reconciliation_errors


def check_invalid_coordinates(exposure):
    invalid_coordinates = exposure[
        (exposure["Latitude"] < -90)
        | (exposure["Latitude"] > 90)
        | (exposure["Longitude"] < -180)
        | (exposure["Longitude"] > 180)
        | (exposure["Latitude"].isna())
        | (exposure["Longitude"].isna())
    ]

    return invalid_coordinates


def check_missing_construction(exposure):
    missing_construction = exposure[
        exposure["ConstructionCode"].isna()
    ]

    return missing_construction


def check_missing_occupancy(exposure):
    missing_occupancy = exposure[
        exposure["Occupancy"].isna()
    ]

    return missing_occupancy


def check_missing_year_built(exposure):
    missing_year_built = exposure[
        exposure["YearBuilt"].isna()
    ]

    return missing_year_built


def check_unmatched_policy_ids(exposure, policy):
    unmatched_policy_ids = exposure[
        exposure["PolicyID"].notna()
        & ~exposure["PolicyID"].isin(policy["PolicyID"])
    ]

    return unmatched_policy_ids


def check_unmatched_hazard_ids(exposure, hazard):
    unmatched_hazard_ids = exposure[
        exposure["HazardZoneID"].notna()
        & ~exposure["HazardZoneID"].isin(hazard["HazardZoneID"])
    ]

    return unmatched_hazard_ids


# 3. Run all data quality checks

checks = {
    "Duplicate Location IDs": check_duplicate_locations(exposure),
    "Missing Policy IDs": check_missing_policy_ids(exposure),
    "Missing Hazard Zone IDs": check_missing_hazard_ids(exposure),
    "Zero or Negative TIV": check_invalid_tiv(exposure),
    "TIV Reconciliation Failures": check_tiv_reconciliation(exposure),
    "Invalid or Missing Coordinates": check_invalid_coordinates(exposure),
    "Missing Construction Codes": check_missing_construction(exposure),
    "Missing Occupancy": check_missing_occupancy(exposure),
    "Missing Year Built": check_missing_year_built(exposure),
    "Unmatched Policy IDs": check_unmatched_policy_ids(exposure, policy),
    "Unmatched Hazard Zone IDs": check_unmatched_hazard_ids(exposure, hazard)
}


# 4. Display data quality report

print("\nEXPOSURE DATA QUALITY REPORT")
print("=" * 45)

print("Exposure records:", exposure.shape[0])
print("Policy records:", policy.shape[0])
print("Hazard records:", hazard.shape[0])

print("-" * 45)

for check_name, result in checks.items():
    print(check_name + ":", len(result))

print("=" * 45)



# 5. Calculate total number of QA flags

total_flags = 0

for result in checks.values():
    total_flags = total_flags + len(result)

print("Total QA flags:", total_flags)


if total_flags == 0:
    print("No data quality issues identified.")
else:
    print("Data quality issues identified.")



# 6. Create QA summary table

qa_summary = pd.DataFrame({
    "Check": checks.keys(),
    "Records_Flagged": [
        len(result) for result in checks.values()
    ]
})



# 7. Combine flagged records

flagged_records = []

for check_name, result in checks.items():

    if not result.empty:
        result = result.copy()
        result["QA_Issue"] = check_name
        flagged_records.append(result)


if flagged_records:
    flagged_records = pd.concat(
        flagged_records,
        ignore_index=True
    )
else:
    flagged_records = pd.DataFrame()



# 8. Export QA results

qa_summary.to_csv(
    "Outputs/qa_summary.csv",
    index=False
)

flagged_records.to_csv(
    "Outputs/flagged_exposure_records.csv",
    index=False
)

print("\nQA results exported successfully.")