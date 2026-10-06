# ARGUS — Audit-Ready Governed Risk & Uncovered-Signal Copilot

> **Snowflake CoCo CLI Hackathon 2026** — Problem Statement #1: *Risk, Fraud and Regulatory Intelligence Copilot*
> **Tagline**: *"From signal → evidence → filing. Every number provable. Every claim cited."*

---

## Status: One-Day MVP (Vertical Slice)

This repository currently implements a **descoped, one-day MVP vertical slice** of the full ARGUS architecture
described in `snowflakeplan.md`. Everything below under **"Implemented"** has been built, deployed to a live
Snowflake account, and verified with query output. Everything under **"Future Work"** is explicitly **not
implemented yet** — it is documented so the repository does not claim functionality that does not exist.

All data is 100% synthetic and fictional (Republic of **Verdana**, currency **VRD**, regulator **FFIA**,
fictional policy `AML-POL-2026`). No real entities, accounts, or PII are used anywhere.

---

## Implemented (Working End-to-End)

1. **Synthetic data**: 90 parties, 130 accounts, 2,932 transactions, 32 ground-truth labels (20 planted
   `STRUCTURING` accounts + 12 `BENIGN_LOOKALIKE` accounts), loaded into `ARGUS.RAW.*`.
2. **Structuring detection**: a dynamic, non-hardcoded threshold detection query joins live transactions
   against machine-readable policy rules (`ARGUS.DOC.POLICY_RULES`) and raises exactly the 20 planted
   accounts as `STRUCTURING` alerts in `ARGUS.CURATED.ALERTS`, with **zero false positives** on the 12
   benign lookalikes.
3. **Regulation-as-Code policy linkage**: each alert carries `RULE_ID`, `CLAUSE_REF` (`4.3.2`), the
   aggregate/individual amounts that triggered it, and a computed STR filing deadline — all sourced from
   `ARGUS.DOC.POLICY_RULES`, not hardcoded in the detection SQL.
4. **Hash-chained evidence ledger**: `ARGUS.AUDIT.EVIDENCE_LEDGER` records every investigative
   question/answer as a SHA-256 hash-chained row (`RECORD_HASH = SHA2(PREV_HASH || PAYLOAD_CANONICAL, 256)`).
5. **Tamper verification**: `ARGUS.AUDIT.SP_VERIFY_EVIDENCE_CHAIN()` walks the chain and recomputes hashes
   from live row data. Demonstrated end-to-end: `INTACT` → tamper a row → `BROKEN at seq <N>` → restore the
   row → `INTACT` again.
6. **Idempotency**: policy/document/rule seeding uses `MERGE ... WHEN NOT MATCHED`; alert generation uses a
   `NOT IN` dedup guard against existing non-suppressed alerts. Re-running `02_policy_and_rules.sql` or
   `03_detection.sql` does not duplicate rows.
7. **Runnable demo worksheet**: `worksheets/demo.sql` walks a single planted account (`ACC-00001`) through
   transactions → alert → policy clause → new evidence record → `INTACT` → tamper → `BROKEN` → restore →
   `INTACT` → final evidence summary.

### Database Objects (as deployed)

- **Database**: `ARGUS`
  - `RAW`: `PARTIES` (90 rows), `ACCOUNTS` (130 rows), `TRANSACTIONS` (2,932 rows), `GROUND_TRUTH` (32 rows)
  - `DOC`: `POLICY_DOCUMENTS` (1 row), `POLICY_CHUNKS` (1 row), `POLICY_RULES` (1 row), view `V_ACTIVE_POLICY_RULES`
  - `CURATED`: `ALERTS` (20 rows, all `STRUCTURING` / `OPEN`)
  - `AUDIT`: sequence `EVIDENCE_SEQ` (created `ORDER` — required for correct chain-walk ordering),
    table `EVIDENCE_LEDGER`, procedures `SP_RECORD_EVIDENCE(VARIANT)` / `SP_VERIFY_EVIDENCE_CHAIN()`,
    view `V_EVIDENCE_SUMMARY`
- **Compute**: single `ARGUS_WH` warehouse (`XSMALL`, `AUTO_SUSPEND=60`, `AUTO_RESUME=TRUE`), guarded by
  resource monitor `ARGUS_RM` (50-credit monthly quota, notify at 50%/75%, suspend at 90%, suspend
  immediately at 100%).
- **Roles**: `ARGUS_ADMIN`, `ARGUS_FRAUD_ANALYST`, `ARGUS_COMPLIANCE_OFFICER`, `ARGUS_AUDITOR`.

### How Data Was Loaded (Important Deviation From the Original Plan)

`PUT`/`COPY INTO` from the local client to an internal stage failed in this environment with a TLS
certificate error (`unable to get local issuer certificate`) and was confirmed to be an unfixable
environment limitation, not a data or SQL issue. As a result, the existing CSV fixtures under
`data/generated/` were loaded via literal, batched `INSERT INTO ... VALUES (...)` statements instead of
stage-based `COPY INTO`. `python/csv_to_insert_sql.py` is a read-only helper that converts the CSVs into
those batched INSERT files under `sql/_generated_inserts/` — it never regenerates or alters the underlying
data. If `PUT`/`COPY INTO` works in your environment, you can use `data/generated/*.csv` directly with a
standard stage + `COPY INTO` instead.

---

## Future Work (Not Implemented — Explicitly Deferred)

The following are part of the original architecture (`snowflakeplan.md`) and are **not present in this
repository**. They are not referenced by any deployed object, demo, or test:

- **STR Narrative Generation** — no automated Suspicious Transaction Report drafting exists yet. The
  evidence ledger stores structured investigative Q&A, but no narrative-generation procedure or AI call
  has been built.
- **Cortex Search** — no search service, index, or corpus has been created over the policy documents.
- **Semantic Views / Cortex Analyst** — no semantic model or semantic view has been created.
- **Cortex Agents** — no agent object, tool, or orchestration has been created.
- **Streamlit app** — no UI exists; all interaction is via SQL worksheets.
- **`CASES`, `FILINGS`, `ALERT_CONTRIBUTIONS`** tables from the original plan — not created.
- **`python/deploy.py`** — not created; deployment so far has been done by running each `sql/*.sql` file
  directly against Snowflake.
- **`tests/test_ledger_integrity.py`** — not created; the ledger tamper/restore test has been run manually
  via `worksheets/demo.sql` and verified interactively, but there is no automated pytest suite yet.

These will only be started if there is substantial time remaining after the MVP vertical slice above is
fully stable and demoed.

---

## Quickstart (What Actually Exists Today)

```bash
# 1. Bootstrap database, schemas, warehouse, resource monitor & roles (idempotent)
#    Run sql/00_bootstrap.sql against your Snowflake account (e.g. via a worksheet,
#    or `cortex` / `snow sql`, depending on what works in your environment).

# 2. Deploy raw tables
#    Run sql/01_raw_ddl.sql

# 3. Load synthetic data
#    The CSVs in data/generated/ were already generated (python/gen_data.py, seed=42).
#    Load them either via COPY INTO from a stage (if PUT works in your environment),
#    or via the pre-generated batched INSERT files under sql/_generated_inserts/
#    (used in this environment because PUT/COPY INTO were blocked by a sandbox TLS issue).

# 4. Deploy policy corpus & rules (idempotent — MERGE-based seeding)
#    Run sql/02_policy_and_rules.sql

# 5. Run structuring detection (idempotent — dedup-guarded alert insert)
#    Run sql/03_detection.sql

# 6. Deploy evidence ledger & verification procedures
#    Run sql/04_evidence_ledger.sql

# 7. Run the end-to-end demo
#    Run worksheets/demo.sql top-to-bottom in a single Snowflake session
#    (it uses a session variable to link the tamper/restore steps to the
#    evidence record it just created).
```

No automated `deploy.py` or pytest harness exists yet — see **Future Work** above.

---

## Repository Layout

```
AGENTS.md                      Project conventions & non-negotiable constraints
DATA_SOURCES.md                Description of synthetic data sources
README.md                      This file
.gitignore
data/
  generated/                   Synthetic CSV fixtures (parties, accounts, transactions, ground_truth)
  policy/AML-POL-2026.md        Fictional AML policy document
python/
  gen_data.py                   Deterministic synthetic data generator (seed=42)
  csv_to_insert_sql.py           Read-only CSV -> batched INSERT SQL converter (workaround for PUT/COPY)
sql/
  00_bootstrap.sql               Warehouse, database, schemas, resource monitor, roles
  01_raw_ddl.sql                 RAW schema tables
  02_policy_and_rules.sql        DOC schema: policy documents/chunks/rules (idempotent seed)
  03_detection.sql                CURATED.ALERTS + dynamic structuring detection
  04_evidence_ledger.sql          AUDIT.EVIDENCE_LEDGER, SP_RECORD_EVIDENCE, SP_VERIFY_EVIDENCE_CHAIN
  99_teardown.sql                 Teardown script
  _generated_inserts/             Generated INSERT batches used to load the CSV fixtures
worksheets/
  demo.sql                        End-to-end runnable demo (account -> alert -> clause -> evidence -> tamper test)
```
