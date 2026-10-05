# AGENTS.md — Project Instructions for ARGUS

## Project Overview
- **Project**: ARGUS — Audit-Ready Governed Risk & Uncovered-Signal Copilot
- **Track**: Problem Statement #1 — Risk, Fraud and Regulatory Intelligence Copilot
- **Tagline**: *"From signal → evidence → filing. Every number provable. Every claim cited."*

## Non-Negotiable Constraints
1. **100% Snowflake-Native**: All storage, processing, detection, and ledger verification run on Snowflake. No external compute or external vector databases.
2. **100% Synthetic Data**: All transactions, accounts, parties, and regulatory policies are strictly synthetic and fictional. No real PII.
3. **Deterministic & Modest Scale**: Test datasets must not exceed 100,000 rows. Use fixed random seeds for total reproducibility.
4. **Strict Cost Control**:
   - Single `XSMALL` warehouse (`ARGUS_WH`) with `AUTO_SUSPEND = 60` and `AUTO_RESUME = TRUE`.
   - Never run unapproved bulk or expensive AI operations.
   - Resource monitor attached to prevent unexpected credit burn.
5. **Idempotence & Portability**: Every SQL script must be idempotent (`CREATE OR REPLACE` / `IF NOT EXISTS`) and runnable top-to-bottom in isolation.
6. **No Secret Leaks**: Never hardcode credentials, tokens, or account passwords in any tracked repository file.

## Conventions
- **Object Names**: `UPPER_SNAKE_CASE` (e.g., `ARGUS.RAW.TRANSACTIONS`, `ARGUS_WH`).
- **File Names**: `snake_case` (e.g., `00_bootstrap.sql`, `gen_data.py`).
- **Definition of Done for Changes**: Code written, deployed to Snowflake, verified with query output shown, and committed with clear phase/change tags.
