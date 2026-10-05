# ARGUS — Audit-Ready Governed Risk & Uncovered-Signal Copilot

> **Snowflake CoCo CLI Hackathon 2026** — Problem Statement #1: *Risk, Fraud and Regulatory Intelligence Copilot*  
> **Tagline**: *"From signal → evidence → filing. Every number provable. Every claim cited."*

---

## 🎯 Executive Summary
ARGUS is a Snowflake-native financial-crime intelligence copilot that transforms raw transactional signals and regulatory policies into audit-ready, cryptographically verifiable regulatory findings.

### Vertical Slice Workflow:
1. **Signal**: Automated detection engine scans synthetic transactions and flags structuring/smurfing behavior exceeding aggregate thresholds.
2. **Policy Linkage**: Each alert binds directly to machine-readable fictional AML policy rules (`rule_id`, `clause_ref`, reporting deadlines).
3. **Evidence Ledger**: All queries, source row keys, metrics, and policy citations are logged into an immutable, hash-chained ledger (`AUDIT.EVIDENCE_LEDGER`).
4. **Tamper Verification**: A stored procedure (`SP_VERIFY_EVIDENCE_CHAIN`) walks the cryptographic SHA-256 chain to prove evidence integrity.
5. **STR Narrative**: An automated narrative generator drafts Suspicious Transaction Reports citing verified facts and obligations.

---

## 🏛️ Architecture & Database Structure
- **Database**: `ARGUS`
  - `RAW`: `PARTIES`, `ACCOUNTS`, `TRANSACTIONS`
  - `DOC`: `POLICY_DOCUMENTS`, `POLICY_RULES`
  - `CURATED`: `ALERTS`, `ALERT_CONTRIBUTIONS`
  - `AUDIT`: `EVIDENCE_LEDGER`, `CASES`, `FILINGS`
- **Compute**: `ARGUS_WH` (X-Small, Auto-suspend 60s) with `ARGUS_RM` Resource Monitor.

---

## 🚀 Quickstart
```bash
# 1. Bootstrap database, schemas, warehouse & roles
snow sql -f sql/00_bootstrap.sql

# 2. Deploy raw tables
snow sql -f sql/01_raw_ddl.sql

# 3. Seed synthetic data (deterministic, <100k rows)
python3 python/gen_data.py

# 4. Deploy policy corpus & rules
snow sql -f sql/02_policy_and_rules.sql

# 5. Run structuring detection
snow sql -f sql/03_detection.sql

# 6. Deploy evidence ledger & verification procedures
snow sql -f sql/04_evidence_ledger.sql

# 7. Run full end-to-end verification test
pytest tests/test_ledger_integrity.py
```
