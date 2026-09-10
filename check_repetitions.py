from pathlib import Path
from collections import defaultdict
import hashlib
import pandas as pd

ROOT = Path(
    "/Users/americo/Desktop/WorkSpace/"
    "3rd_imdc_lncc_clidengo26chikungunya"
)

PATTERN = "IMDC2026_*.csv"

PREDICTION_COLUMNS = [
    "lower_95",
    "lower_90",
    "lower_80",
    "lower_50",
    "pred",
    "upper_50",
    "upper_80",
    "upper_90",
    "upper_95",
]


def read_csv_robustly(path: Path) -> pd.DataFrame:
    """
    Read a CSV while automatically detecting comma/semicolon/tab separators.
    """
    try:
        df = pd.read_csv(
            path,
            sep=None,
            engine="python",
            encoding="utf-8-sig",
        )
    except Exception as exc:
        raise RuntimeError(f"Could not read {path}: {exc}") from exc

    # Normalize column names.
    df.columns = [
        str(column)
        .strip()
        .lower()
        .replace(" ", "_")
        for column in df.columns
    ]

    return df


def canonical_prediction_content(df: pd.DataFrame) -> bytes:
    """
    Construct a canonical representation of the numerical predictions.
    Dates and filenames are intentionally ignored.
    """
    missing = [
        column
        for column in PREDICTION_COLUMNS
        if column not in df.columns
    ]

    if missing:
        raise ValueError(
            f"Missing columns {missing}. "
            f"Columns found: {list(df.columns)}"
        )

    values = df[PREDICTION_COLUMNS].copy()

    for column in PREDICTION_COLUMNS:
        values[column] = pd.to_numeric(
            values[column],
            errors="raise",
        )

    # Remove inconsequential floating-point formatting differences.
    values = values.round(12)

    return values.to_csv(
        index=False,
        float_format="%.12g",
    ).encode("utf-8")


groups = defaultdict(list)
invalid_files = []

files = sorted(ROOT.rglob(PATTERN))

print(f"Found {len(files)} CSV files.\n")

for path in files:
    try:
        df = read_csv_robustly(path)
        content = canonical_prediction_content(df)
        digest = hashlib.sha256(content).hexdigest()
        groups[digest].append(path)

    except Exception as exc:
        invalid_files.append((path, str(exc)))


duplicate_groups = {
    digest: paths
    for digest, paths in groups.items()
    if len(paths) > 1
}

print("=" * 90)
print("REPEATED PREDICTION MATRICES")
print("=" * 90)

if not duplicate_groups:
    print("No exactly repeated prediction matrices were found.")
else:
    for group_number, paths in enumerate(
        duplicate_groups.values(),
        start=1,
    ):
        print(f"\nDuplicate group {group_number}:")
        for path in paths:
            print(f"  {path}")


print("\n" + "=" * 90)
print("FILES THAT COULD NOT BE ANALYZED")
print("=" * 90)

if not invalid_files:
    print("All files were read successfully.")
else:
    for path, reason in invalid_files:
        print(f"\nFile: {path}")
        print(f"Reason: {reason}")
