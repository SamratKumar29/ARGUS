# DATA_SOURCES.md — Data Sources & Licensing

## Declarations per Hackathon Rules (§4.3b & §4.4)

All data used in ARGUS is **100% synthetic, fictional, and deterministically generated** by the project's own Snowpark scripts (`python/gen_data.py`).

| Dataset / Table | Source | Generation Method | License / Rights |
|---|---|---|---|
| `ARGUS.RAW.PARTIES` | Synthetic | Seeded Python random generation | Apache-2.0 (Author generated) |
| `ARGUS.RAW.ACCOUNTS` | Synthetic | Seeded Python random generation | Apache-2.0 (Author generated) |
| `ARGUS.RAW.TRANSACTIONS` | Synthetic | Planted structuring & baseline transactions | Apache-2.0 (Author generated) |
| `ARGUS.DOC.POLICY_DOCUMENTS` | Fictional Regulatory Text | Internal AML Policy & Fictional Authority Circulars | Apache-2.0 (Author generated) |
| `ARGUS.DOC.POLICY_RULES` | Extracted Policy Rules | Rule definitions extracted from fictional policy | Apache-2.0 (Author generated) |

### Note on PII and Privacy
No real individuals, entities, banks, account numbers, or real-world PII exist in these datasets. All names, addresses, identification codes, and accounts are fictitious.
