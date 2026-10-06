#!/usr/bin/env python3
"""Read existing generated CSVs as-is and emit batched INSERT INTO SQL files.
Does NOT regenerate or alter any data - pure read -> SQL-escape -> write.
"""
import csv
from pathlib import Path

BASE = Path(__file__).resolve().parents[1]
DATA = BASE / "data" / "generated"
OUT = BASE / "sql" / "_generated_inserts"
OUT.mkdir(parents=True, exist_ok=True)

def esc(v):
    if v is None or v == "":
        return "NULL"
    return "'" + v.replace("'", "''") + "'"

def esc_bool(v):
    return "TRUE" if v.strip().upper() == "TRUE" else "FALSE"

def esc_num(v):
    return v if v not in (None, "") else "NULL"

TABLES = {
    "parties": {
        "table": "ARGUS.RAW.PARTIES",
        "cols": "PARTY_ID, PARTY_TYPE, FULL_NAME, DOB, NATIONALITY, OCCUPATION, IS_PEP, RISK_RATING, ONBOARDED_AT, NATIONAL_ID_MASKED_SOURCE, EMAIL, PHONE",
        "row": lambda r: f"({esc(r['party_id'])}, {esc(r['party_type'])}, {esc(r['full_name'])}, "
                          f"{esc(r['dob'])}, {esc(r['nationality'])}, {esc(r['occupation'])}, "
                          f"{esc_bool(r['is_pep'])}, {esc(r['risk_rating'])}, {esc(r['onboarded_at'])}, "
                          f"{esc(r['national_id_masked_source'])}, {esc(r['email'])}, {esc(r['phone'])})",
        "batch": 300,
    },
    "accounts": {
        "table": "ARGUS.RAW.ACCOUNTS",
        "cols": "ACCOUNT_ID, PARTY_ID, ACCOUNT_TYPE, CURRENCY, BRANCH_CODE, REGION, OPENED_AT, CLOSED_AT, STATUS, DORMANCY_FLAG, LAST_ACTIVITY_AT",
        "row": lambda r: f"({esc(r['account_id'])}, {esc(r['party_id'])}, {esc(r['account_type'])}, "
                          f"{esc(r['currency'])}, {esc(r['branch_code'])}, {esc(r['region'])}, "
                          f"{esc(r['opened_at'])}, {esc(r['closed_at'])}, {esc(r['status'])}, "
                          f"{esc_bool(r['dormancy_flag'])}, {esc(r['last_activity_at'])})",
        "batch": 300,
    },
    "transactions": {
        "table": "ARGUS.RAW.TRANSACTIONS",
        "cols": "TXN_ID, ACCOUNT_ID, TXN_TS, AMOUNT, CURRENCY, DIRECTION, CHANNEL, TXN_TYPE, COUNTERPARTY_ACCOUNT, COUNTERPARTY_NAME, COUNTERPARTY_COUNTRY, MCC, DEVICE_ID, IS_CASH, NARRATIVE",
        "row": lambda r: f"({esc(r['txn_id'])}, {esc(r['account_id'])}, {esc(r['txn_ts'])}, "
                          f"{esc_num(r['amount'])}, {esc(r['currency'])}, {esc(r['direction'])}, "
                          f"{esc(r['channel'])}, {esc(r['txn_type'])}, {esc(r['counterparty_account'])}, "
                          f"{esc(r['counterparty_name'])}, {esc(r['counterparty_country'])}, {esc(r['mcc'])}, "
                          f"{esc(r['device_id'])}, {esc_bool(r['is_cash'])}, {esc(r['narrative'])})",
        "batch": 100,
    },
    "ground_truth": {
        "table": "ARGUS.RAW.GROUND_TRUTH",
        "cols": "ENTITY_ID, ENTITY_TYPE, TYPOLOGY_CODE, LABEL, INJECTED_AT, WINDOW_START, WINDOW_END, NOTES",
        "row": lambda r: f"({esc(r['entity_id'])}, {esc(r['entity_type'])}, {esc(r['typology_code'])}, "
                          f"{esc(r['label'])}, {esc(r['injected_at'])}, {esc(r['window_start'])}, "
                          f"{esc(r['window_end'])}, {esc(r['notes'])})",
        "batch": 300,
    },
}

def main():
    total_rows = 0
    for name, cfg in TABLES.items():
        csv_path = DATA / f"{name}.csv"
        with csv_path.open(newline="", encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
        total_rows += len(rows)
        batch_size = cfg["batch"]
        batch_files = []
        for i in range(0, len(rows), batch_size):
            batch = rows[i:i + batch_size]
            values = ",\n".join(cfg["row"](r) for r in batch)
            sql = f"INSERT INTO {cfg['table']} ({cfg['cols']}) VALUES\n{values};\n"
            out_path = OUT / f"{name}_batch_{i // batch_size + 1:02d}.sql"
            out_path.write_text(sql, encoding="utf-8")
            batch_files.append(out_path.name)
        print(f"{name}: {len(rows)} rows -> {len(batch_files)} batch file(s): {batch_files}")
    print(f"TOTAL ROWS: {total_rows}")

if __name__ == "__main__":
    main()
