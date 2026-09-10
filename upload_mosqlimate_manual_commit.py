#!/usr/bin/env python3
"""
Bulk uploader for IMDC 2026 predictions to the Mosqlimate registry.

Expected directory layout
-------------------------
ROOT/
├── Dengue_Validation1_2022–2023-Season/
│   ├── IMDC2026_Dengue_Validation1_AC.csv
│   ├── IMDC2026_Chikungunya_Validation1_AL.csv
│   └── ...
├── Dengue_Validation2_2023–2024-Season/
│   └── ...
└── ...

The script:
1. discovers CSV files recursively;
2. infers disease, validation number, and UF from each filename;
3. reads the repository and either uses a manual commit or the current Git HEAD;
4. validates the Mosqlimate/IMDC prediction format;
5. uploads each state-level prediction;
6. writes a CSV log and avoids duplicate uploads within the same run.

Safety:
- Default mode is DRY RUN: validation only.
- Actual upload requires the explicit --upload flag.
- Use --published only for definitive public submissions.

Dependencies
------------
pip install pandas python-dotenv mosqlient
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from datetime import date
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import pandas as pd
from dotenv import load_dotenv

try:
    from mosqlient import upload_prediction
except ImportError:
    upload_prediction = None
    
REQUIRED_COLUMNS = [
    "date",
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

ORDERED_VALUE_COLUMNS = [
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

DISEASE_CODES = {
    "dengue": "A90",
    "chikungunya": "A92.0",
    "zika": "A92.5",
}

# IBGE state geocodes used by Mosqlimate adm_1.
UF_CODES = {
    "RO": 11, "AC": 12, "AM": 13, "RR": 14, "PA": 15, "AP": 16, "TO": 17,
    "MA": 21, "PI": 22, "CE": 23, "RN": 24, "PB": 25, "PE": 26, "AL": 27,
    "SE": 28, "BA": 29, "MG": 31, "ES": 32, "RJ": 33, "SP": 35, "PR": 41,
    "SC": 42, "RS": 43, "MS": 50, "MT": 51, "GO": 52, "DF": 53,
}

FILENAME_RE = re.compile(
    r"^IMDC2026_"
    r"(?P<disease>Dengue|Chikungunya|Zika)_"
    r"(?:(?:Validation(?P<validation>\d+))|(?P<forecast>Forecast))_"
    r"(?P<uf>[A-Z]{2})\.csv$",
    flags=re.IGNORECASE,
)


@dataclass
class SubmissionRecord:
    file: str
    repository: str = ""
    commit: str = ""
    disease: str = ""
    validation: str = ""
    uf: str = ""
    adm_1: int | None = None
    start_date: str = ""
    end_date: str = ""
    rows: int = 0
    status: str = ""
    prediction_id: str = ""
    message: str = ""


class ValidationError(ValueError):
    """Raised when a prediction file violates submission rules."""


def run_git(repo_dir: Path, *args: str) -> str:
    command = ["git", "-C", str(repo_dir), *args]
    try:
        result = subprocess.run(
            command,
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError as exc:
        raise RuntimeError("Git is not installed or is not available in PATH.") from exc
    except subprocess.CalledProcessError as exc:
        stderr = exc.stderr.strip() or exc.stdout.strip()
        raise RuntimeError(f"Git command failed in {repo_dir}: {stderr}") from exc
    return result.stdout.strip()


def find_git_root(path: Path) -> Path:
    try:
        root = run_git(path.parent if path.is_file() else path, "rev-parse", "--show-toplevel")
    except RuntimeError as exc:
        raise RuntimeError(f"No Git repository found for {path}.") from exc
    return Path(root).resolve()


def get_commit(repo_dir: Path) -> str:
    commit = run_git(repo_dir, "rev-parse", "HEAD")
    if not re.fullmatch(r"[0-9a-fA-F]{40}", commit):
        raise RuntimeError(f"Invalid Git commit hash in {repo_dir}: {commit!r}")
    return commit.lower()


def ensure_clean_repository(repo_dir: Path, allow_dirty: bool) -> None:
    status = run_git(repo_dir, "status", "--porcelain")
    if status and not allow_dirty:
        raise RuntimeError(
            f"Repository has uncommitted changes: {repo_dir}. "
            "Commit the files or pass --allow-dirty."
        )


def remote_to_repository(remote: str) -> str:
    """Convert HTTPS or SSH Git remote URL to owner/repository."""
    remote = remote.strip()

    # git@github.com:owner/repository.git
    ssh_match = re.match(r"^[^@]+@[^:]+:(?P<path>.+)$", remote)
    if ssh_match:
        repo_path = ssh_match.group("path")
    else:
        parsed = urlparse(remote)
        if parsed.scheme and parsed.netloc:
            repo_path = parsed.path.lstrip("/")
        else:
            repo_path = remote

    repo_path = re.sub(r"\.git$", "", repo_path).strip("/")
    parts = repo_path.split("/")

    if len(parts) < 2:
        raise RuntimeError(f"Cannot infer owner/repository from remote URL: {remote!r}")

    return "/".join(parts[-2:])


def get_repository_name(repo_dir: Path, remote_name: str) -> str:
    try:
        remote = run_git(repo_dir, "remote", "get-url", remote_name)
    except RuntimeError as exc:
        raise RuntimeError(
            f"Remote {remote_name!r} was not found in {repo_dir}."
        ) from exc
    return remote_to_repository(remote)


def parse_filename(csv_path: Path) -> tuple[str, str, str, int]:
    match = FILENAME_RE.match(csv_path.name)
    if not match:
        raise ValidationError(
            "Filename must match either "
            "IMDC2026_<Disease>_Validation<N>_<UF>.csv or "
            "IMDC2026_<Disease>_Forecast_<UF>.csv"
        )

    disease_name = match.group("disease").lower()
    disease_code = DISEASE_CODES[disease_name]
    validation = match.group("validation")
    submission = f"Validation{validation}" if validation else "Forecast"
    uf = match.group("uf").upper()

    if uf not in UF_CODES:
        raise ValidationError(f"Unknown Brazilian UF code: {uf}")

    return disease_code, submission, uf, UF_CODES[uf]


def normalize_columns(df: pd.DataFrame) -> pd.DataFrame:
    normalized = df.copy()
    normalized.columns = [str(c).strip().lower() for c in normalized.columns]

    # Common harmless CSV artifact.
    unnamed = [c for c in normalized.columns if c.startswith("unnamed:")]
    if unnamed:
        normalized = normalized.drop(columns=unnamed)

    missing = [c for c in REQUIRED_COLUMNS if c not in normalized.columns]
    if missing:
        raise ValidationError(f"Missing required columns: {missing}")

    extra = [c for c in normalized.columns if c not in REQUIRED_COLUMNS]
    if extra:
        print(f"  Warning: ignoring extra columns: {extra}", file=sys.stderr)

    return normalized[REQUIRED_COLUMNS].copy()


def validate_prediction(csv_path: Path, expected_rows: int | None) -> pd.DataFrame:
    try:
        df = pd.read_csv(csv_path)
    except Exception as exc:
        raise ValidationError(f"Could not read CSV: {exc}") from exc

    if df.empty:
        raise ValidationError("CSV is empty.")

    df = normalize_columns(df)

    # Dates
    dates = pd.to_datetime(df["date"], format="%Y-%m-%d", errors="coerce")
    if dates.isna().any():
        bad_rows = (dates.isna()).to_numpy().nonzero()[0].tolist()
        raise ValidationError(f"Invalid dates at zero-based rows: {bad_rows}")

    if dates.duplicated().any():
        duplicates = dates[dates.duplicated()].dt.strftime("%Y-%m-%d").tolist()
        raise ValidationError(f"Duplicate dates: {duplicates}")

    if not dates.is_monotonic_increasing:
        raise ValidationError("Dates are not sorted in increasing order.")

    non_sunday = dates[dates.dt.dayofweek != 6]
    if not non_sunday.empty:
        samples = non_sunday.dt.strftime("%Y-%m-%d").head(10).tolist()
        raise ValidationError(f"All weekly dates must be Sundays. Invalid: {samples}")

    if len(dates) > 1:
        gaps = dates.diff().dropna()
        invalid_gaps = gaps[gaps != pd.Timedelta(days=7)]
        if not invalid_gaps.empty:
            positions = invalid_gaps.index.tolist()
            raise ValidationError(
                "Dates must be continuous weekly Sundays; "
                f"invalid interval ending at rows: {positions}"
            )

    if expected_rows is not None:
        allowed_rows = (
            expected_rows
            if isinstance(expected_rows, (list, tuple, set))
            else [expected_rows]
        )

        if len(df) not in allowed_rows:
            raise ValidationError(
                f"Expected one of {sorted(allowed_rows)} weekly row counts, "
                f"found {len(df)}."
            )

    # Numeric values
    for column in ORDERED_VALUE_COLUMNS:
        df[column] = pd.to_numeric(df[column], errors="coerce")

    if df[ORDERED_VALUE_COLUMNS].isna().any().any():
        locations = []
        mask = df[ORDERED_VALUE_COLUMNS].isna()
        for row_idx, column in zip(*mask.to_numpy().nonzero()):
            locations.append(f"row {row_idx}, column {ORDERED_VALUE_COLUMNS[column]}")
        raise ValidationError("NaN/non-numeric values: " + "; ".join(locations[:20]))

    import numpy as np
    values = df[ORDERED_VALUE_COLUMNS].to_numpy(dtype=float)

    if not np.isfinite(values).all():
        raise ValidationError("Prediction contains infinite values.")

    if (values < 0).any():
        row_idx, col_idx = np.argwhere(values < 0)[0]
        raise ValidationError(
            f"Negative value at row {row_idx}, "
            f"column {ORDERED_VALUE_COLUMNS[col_idx]}."
        )

    # lower_95 <= ... <= pred <= ... <= upper_95
    differences = np.diff(values, axis=1)
    bad_order = np.argwhere(differences < 0)
    if bad_order.size:
        row_idx, left_idx = bad_order[0]
        left = ORDERED_VALUE_COLUMNS[left_idx]
        right = ORDERED_VALUE_COLUMNS[left_idx + 1]
        raise ValidationError(
            f"Non-nested interval at row {row_idx}: {left} > {right}."
        )

    # Store canonical ISO dates. Mosqlient accepts a DataFrame.
    df["date"] = dates.dt.strftime("%Y-%m-%d")
    return df


def build_description(
    disease_code: str,
    validation: str,
    uf: str,
    repo_dir: Path,
    template: str | None,
) -> str:
    disease_label = {
        "A90": "Dengue",
        "A92.0": "Chikungunya",
        "A92.5": "Zika",
    }[disease_code]

    if template:
        return template.format(
            disease=disease_label,
            disease_code=disease_code,
            validation=validation,
            uf=uf,
            repository=repo_dir.name,
        )

    if validation == "Forecast":
        return (
            f"IMDC 2026 {disease_label} forecast, "
            f"2026–2027 season, state {uf}; source repository {repo_dir.name}."
        )

    return (
        f"IMDC 2026 {disease_label} forecast, "
        f"{validation}, stcleate {uf}; source repository {repo_dir.name}."
    )


def response_to_id(response: Any) -> str:
    if isinstance(response, dict):
        return str(response.get("id", ""))
    if isinstance(response, str):
        try:
            parsed = json.loads(response)
            if isinstance(parsed, dict):
                return str(parsed.get("id", ""))
        except json.JSONDecodeError:
            return ""
    return ""


def discover_csv_files(root: Path, pattern: str) -> list[Path]:
    files = sorted(p.resolve() for p in root.rglob(pattern) if p.is_file())
    return [p for p in files if FILENAME_RE.match(p.name)]


def process_file(
    csv_path: Path,
    api_key: str | None,
    args: argparse.Namespace,
) -> SubmissionRecord:
    record = SubmissionRecord(file=str(csv_path))

    try:
        disease_code, validation, uf, adm_1 = parse_filename(csv_path)
        repo_dir = find_git_root(csv_path)

        repository = get_repository_name(repo_dir, args.remote)

        if args.commit:
            if not re.fullmatch(r"[0-9a-fA-F]{40}", args.commit):
                raise ValidationError(
                    "--commit must be a complete 40-character hexadecimal Git hash."
                )
            commit = args.commit.lower()
        else:
            ensure_clean_repository(repo_dir, args.allow_dirty)
            commit = get_commit(repo_dir)

        prediction = validate_prediction(csv_path, args.expected_rows)

        description = build_description(
            disease_code=disease_code,
            validation=validation,
            uf=uf,
            repo_dir=repo_dir,
            template=args.description_template,
        )

        record.repository = repository
        record.commit = commit
        record.disease = disease_code
        record.validation = validation
        record.uf = uf
        record.adm_1 = adm_1
        record.start_date = prediction["date"].iloc[0]
        record.end_date = prediction["date"].iloc[-1]
        record.rows = len(prediction)

        if not args.upload:
            record.status = "VALIDATED"
            record.message = "Dry run; not uploaded."
            return record

        if upload_prediction is None:
            raise RuntimeError(
                "mosqlient is not installed. Run: pip install mosqlient"
            )
        if not api_key:
            raise RuntimeError(
                f"API key not found in environment variable {args.api_key_env!r}."
            )

        response = upload_prediction(
            api_key=api_key,
            repository=repository,
            disease=disease_code,
            description=description,
            commit=commit,
            case_definition=args.case_definition,
            published=args.published,
            adm_level=1,
            adm_0="BRA",
            adm_1=adm_1,
            prediction=prediction,
        )

        record.status = "UPLOADED"
        record.prediction_id = response_to_id(response)
        record.message = str(response)

    except Exception as exc:
        record.status = "ERROR"
        record.message = str(exc)

    return record


def write_log(records: list[SubmissionRecord], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    pd.DataFrame([asdict(record) for record in records]).to_csv(output, index=False)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate and bulk-upload IMDC 2026 CSV predictions."
    )
    parser.add_argument(
        "root",
        nargs="?",
        default=".",
        help="Root directory containing the local Git repositories.",
    )
    parser.add_argument(
        "--pattern",
        default="IMDC2026_*_*.csv",
        help="Recursive glob used to discover prediction files.",
    )
    parser.add_argument(
        "--upload",
        action="store_true",
        help="Actually upload. Without this flag, the script only validates.",
    )
    parser.add_argument(
        "--published",
        action="store_true",
        help="Publish uploaded predictions publicly. Default: unpublished.",
    )
    parser.add_argument(
        "--case-definition",
        choices=("probable", "reported"),
        default="probable",
        help="Case definition used in all files. IMDC normally uses probable.",
    )
    parser.add_argument(
        "--api-key-env",
        default="API_KEY",
        help="Environment variable containing the Mosqlimate API key.",
    )
    parser.add_argument(
        "--env-file",
        default=".env",
        help="Path to .env file. Default: .env",
    )
    parser.add_argument(
        "--remote",
        default="origin",
        help="Git remote used to infer owner/repository. Default: origin",
    )
    parser.add_argument(
        "--commit",
        default=None,
        help=(
            "Manual 40-character Git commit hash to associate with all submissions. "
            "If omitted, the current Git HEAD is used."
        ),
    )
    parser.add_argument(
        "--expected-rows",
        type=int,
        nargs="+",
        default=[52, 53],
        help=(
            "Required number of weekly rows per file. "
            "Default: 52 53. Example: --expected-rows 52 53"
        ),
    )
    parser.add_argument(
        "--allow-dirty",
        action="store_true",
        help="Allow repositories with uncommitted changes.",
    )
    parser.add_argument(
        "--continue-on-error",
        action="store_true",
        help="Continue after an error. Default behavior already processes all files; "
             "this option is retained for explicitness.",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=0.5,
        help="Seconds between API uploads. Default: 0.5",
    )
    parser.add_argument(
        "--log",
        default=f"mosqlimate_upload_log_{date.today().isoformat()}.csv",
        help="Output CSV log path.",
    )
    parser.add_argument(
        "--description-template",
        default=None,
        help=(
            "Optional format string. Available fields: {disease}, {disease_code}, "
            "{validation}, {uf}, {repository}."
        ),
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = Path(args.root).expanduser().resolve()
    if args.expected_rows == [0]:
        args.expected_rows = None

    if not root.is_dir():
        print(f"ERROR: root directory does not exist: {root}", file=sys.stderr)
        return 2

    load_dotenv(args.env_file)
    api_key = os.getenv(args.api_key_env)

    files = discover_csv_files(root, args.pattern)
    if not files:
        print(
            f"No matching prediction CSV files found under {root}.",
            file=sys.stderr,
        )
        return 2

    mode = "UPLOAD" if args.upload else "DRY RUN"
    visibility = "published" if args.published else "unpublished"
    print(f"Mode: {mode}; visibility: {visibility}")
    print(f"Discovered {len(files)} prediction file(s).\n")

    records: list[SubmissionRecord] = []

    # Prevent an accidental duplicate call for the same logical submission.
    seen_keys: set[tuple[str, str, str, str]] = set()

    for index, csv_path in enumerate(files, start=1):
        print(f"[{index}/{len(files)}] {csv_path}")

        record = process_file(csv_path, api_key, args)

        logical_key = (
            record.repository,
            record.disease,
            record.validation,
            record.uf,
        )
        if record.status != "ERROR" and logical_key in seen_keys:
            record.status = "ERROR"
            record.message = (
                "Duplicate logical submission in this run: "
                f"{logical_key}"
            )
        elif record.status != "ERROR":
            seen_keys.add(logical_key)

        records.append(record)

        print(
            f"  {record.status}: disease={record.disease or '-'}, "
            f"UF={record.uf or '-'}, rows={record.rows or '-'}, "
            f"dates={record.start_date or '-'}..{record.end_date or '-'}"
        )
        if record.status == "ERROR":
            print(f"  Reason: {record.message}", file=sys.stderr)

        if args.upload and index < len(files):
            time.sleep(max(0.0, args.delay))

    log_path = Path(args.log).expanduser().resolve()
    write_log(records, log_path)

    uploaded = sum(r.status == "UPLOADED" for r in records)
    validated = sum(r.status == "VALIDATED" for r in records)
    errors = sum(r.status == "ERROR" for r in records)

    print("\nSummary")
    print(f"  Uploaded:  {uploaded}")
    print(f"  Validated: {validated}")
    print(f"  Errors:    {errors}")
    print(f"  Log:       {log_path}")

    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())