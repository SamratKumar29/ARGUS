# AML-POL-2026

> **SYNTHETIC AND FICTIONAL.** Created solely for the ARGUS hackathon prototype. This document is not legal guidance, contains no real regulatory text, and refers only to the fictional Republic of Verdana, fictional currency VRD, and fictional Federal Financial Intelligence Authority (FFIA).

## 1. Purpose and scope

### 1.1 Purpose
This policy establishes fictional controls for detecting, investigating, documenting, and reporting financial-crime indicators in ARGUS demonstration data.

### 1.2 Scope
The policy applies to fictional Verdana customer parties, accounts, cash activity, transfers, cases, and filings processed by the prototype.

## 2. Customer due diligence

### 2.1 Identification
A party shall have a synthetic identifier, party type, occupation or business activity, and risk rating before account activation.

### 2.2 Expected activity
The institution shall record expected monthly turnover and source of funds. Activity consistent with a documented business profile may be reviewed as a legitimate look-alike rather than automatically treated as suspicious.

### 2.3 Enhanced review
A HIGH-risk party shall receive enhanced review at least every 365 days.

## 3. Transaction monitoring

### 3.1 Monitoring basis
Monitoring shall use reproducible transaction records and effective-dated rules. Every alert shall retain the rule identifier and clause reference used at detection time.

### 3.2 Data quality
Transactions missing account identifier, timestamp, direction, currency, or amount shall be quarantined before monitoring.

### 3.3 Explainability
Every alert shall record observable factors, factor values, and a human-readable explanation.

## 4. Cash and structuring controls

### 4.1 Single-transaction ceiling
A cash credit of VRD 50,000 or more shall be handled by the fictional large-cash review process.

### 4.2 Sub-threshold activity
A cash credit below VRD 50,000 is sub-threshold activity and shall be included in rolling aggregation.

### 4.3 Aggregation
Rolling aggregation shall be evaluated by account using transaction time and credit direction.

### 4.3.1 Lookback
The applicable structuring lookback is 30 consecutive calendar days.

### 4.3.2 Structuring obligation
Aggregate cash credits equal to or exceeding VRD 950,000 within any rolling 30-day period, where no individual cash credit reaches VRD 50,000, shall be escalated as potential STRUCTURING. If investigation confirms suspicion, a Suspicious Transaction Report shall be filed with the FFIA within 7 calendar days of confirmation.

### 4.3.3 Legitimate look-alikes
A threshold match shall not by itself establish suspicion. The reviewer shall compare activity with documented occupation, expected monthly turnover, source of funds, known counterparties, and recurring business seasonality. Any suppression shall retain a specific reason.

## 5. Other monitoring scenarios

### 5.1 Mule activity
Fan-in followed by rapid fan-out within 72 hours, combined with a shared device or beneficiary, shall be escalated as potential MULE_RING activity.

### 5.2 Dormant reactivation
An account inactive for at least 180 days followed by five or more high-value debits within 7 days shall be escalated as potential DORMANT_REACTIVATION.

### 5.3 Round trip
Funds returning to an originating account within 14 days and no more than four transfer hops shall be escalated as potential ROUND_TRIP activity.

### 5.4 Corridor monitoring
Transfers involving a synthetic HIGH-risk corridor inconsistent with the customer profile shall be escalated as potential HIGH_RISK_CORRIDOR activity.

### 5.5 Card-not-present velocity
Ten or more card-not-present transactions within 60 minutes across incompatible synthetic locations shall be escalated as potential CNP_BURST activity.

### 5.6 Watchlist similarity
A synthetic name similarity score equal to or above 0.92 shall require manual WATCHLIST_NEAR_MATCH review; similarity alone shall not establish identity.

## 6. Investigation and escalation

### 6.1 Triage
Alerts shall be assigned a status, severity, as-of date, detection run identifier, and accountable reviewer.

### 6.2 Evidence
Quantitative claims shall be traceable to source-row keys. Policy claims shall cite document code and clause reference.

### 6.3 Case opening
A confirmed alert requiring investigation shall be opened as a case with a policy-derived deadline.

### 6.4 Maker-checker
The person who opens a case shall not approve the same case.

## 7. Reporting

### 7.1 STR content
An STR narrative shall distinguish observed facts, analytical conclusions, and unresolved limitations, and shall cite applicable policy clauses.

### 7.2 Filing clock
Where clause 4.3.2 applies, the filing deadline is 7 calendar days after confirmation.

### 7.3 No invented facts
Generated narratives shall not introduce facts absent from governed data or cited evidence.

## 8. Record retention and audit

### 8.1 Evidence ledger
Each material investigation action shall create an evidence record containing the actor, role, question or action, generated SQL where applicable, source keys, retrieved policy chunks, tool calls, and answer or result.

### 8.2 Integrity
Evidence records shall be hash-chained in sequence so later verification can identify the first altered record.

### 8.3 Retention
Prototype evidence, cases, and filings shall be retained for 2,555 days unless the dataset is reset for a documented demonstration.

## 9. Governance

### 9.1 Access
Access shall follow least privilege and role scope. Masked identifiers shall not be exposed to unauthorized roles.

### 9.2 Reproducibility
Synthetic-data generation shall record the seed and generator version. Detection shall record its as-of date and rule version.

### 9.3 Fictional status
FFIA, Verdana, VRD, all persons, accounts, transactions, thresholds, and obligations in this document are fictional and must not be represented as real requirements.
