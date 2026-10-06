-- =============================================================================
-- ARGUS — One-Day MVP Demonstration Worksheet
-- =============================================================================
-- Purpose: End-to-end walkthrough of the vertical slice —
--   planted structuring account -> transactions -> alert -> policy clause ->
--   evidence recorded -> hash-chain verified -> tampered -> re-verified ->
--   restored -> re-verified.
--
-- Scope guard: this worksheet is READ-ONLY against RAW/CURATED/DOC, and only
-- writes to AUDIT.EVIDENCE_LEDGER via the existing SP_RECORD_EVIDENCE
-- procedure plus two UPDATE statements used solely for the tamper/restore
-- demonstration on evidence SEQ created by THIS run. No data is regenerated
-- or reloaded. No Cortex Search, Semantic Views, Cortex Agents, or
-- Streamlit objects are touched.
--
-- Demo account: ACC-00001 (planted STRUCTURING account, confirmed present in
-- ARGUS.CURATED.ALERTS as ALERT-ACC-00001-STRUCTURING).
-- =============================================================================

USE ROLE ARGUS_ADMIN;
USE WAREHOUSE ARGUS_WH;
USE DATABASE ARGUS;

-- -----------------------------------------------------------------------------
-- Step 1: Show the selected planted account's transactions
-- -----------------------------------------------------------------------------
SELECT
    TXN_ID,
    ACCOUNT_ID,
    TXN_TS,
    AMOUNT,
    CURRENCY,
    DIRECTION,
    CHANNEL,
    TXN_TYPE,
    IS_CASH,
    NARRATIVE
FROM ARGUS.RAW.TRANSACTIONS
WHERE ACCOUNT_ID = 'ACC-00001'
ORDER BY TXN_TS;

-- -----------------------------------------------------------------------------
-- Step 2: Show its CURATED.ALERTS row
-- -----------------------------------------------------------------------------
SELECT
    ALERT_ID,
    ALERT_TS,
    ENTITY_ID,
    ENTITY_TYPE,
    TYPOLOGY_CODE,
    RULE_ID,
    CLAUSE_REF,
    SEVERITY,
    RAW_SCORE,
    STATUS,
    AS_OF_DATE,
    DETECTION_RUN_ID,
    EXPLANATION,
    AGGREGATE_AMOUNT,
    MAX_INDIVIDUAL_AMOUNT,
    FILING_DEADLINE_DATE
FROM ARGUS.CURATED.ALERTS
WHERE ENTITY_ID = 'ACC-00001'
  AND TYPOLOGY_CODE = 'STRUCTURING';

-- -----------------------------------------------------------------------------
-- Step 3: Join the alert to DOC.POLICY_RULES and display clause 4.3.2
-- -----------------------------------------------------------------------------
SELECT
    a.ALERT_ID,
    a.ENTITY_ID,
    a.RULE_ID,
    a.CLAUSE_REF,
    a.STATUS,
    a.AGGREGATE_AMOUNT,
    a.MAX_INDIVIDUAL_AMOUNT,
    a.FILING_DEADLINE_DATE,
    r.DOC_CODE,
    r.TYPOLOGY_CODE,
    r.OBLIGATION_TEXT,
    r.THRESHOLD_VALUE,
    r.THRESHOLD_CURRENCY,
    r.MAX_INDIVIDUAL_VALUE,
    r.LOOKBACK_DAYS,
    r.FILING_DEADLINE_DAYS
FROM ARGUS.CURATED.ALERTS a
JOIN ARGUS.DOC.POLICY_RULES r
  ON a.RULE_ID = r.RULE_ID
WHERE a.ENTITY_ID = 'ACC-00001'
  AND a.TYPOLOGY_CODE = 'STRUCTURING'
  AND r.CLAUSE_REF = '4.3.2';

-- -----------------------------------------------------------------------------
-- Step 4: Call SP_RECORD_EVIDENCE with a factual investigation result
-- -----------------------------------------------------------------------------
CALL ARGUS.AUDIT.SP_RECORD_EVIDENCE(
    OBJECT_CONSTRUCT(
        'question', 'DEMO: What is the structuring exposure and policy basis for ACC-00001?',
        'resolved_intent', 'DEMO_EXPLAIN_ALERT',
        'generated_sql', NULL,
        'source_row_keys', ARRAY_CONSTRUCT('ALERT-ACC-00001-STRUCTURING'),
        'retrieved_chunks', NULL,
        'answer_text', 'ACC-00001 breached RULE-STRUCTURING-950K (clause 4.3.2 of AML-POL-2026): aggregate cash credits of VRD 968,202.00 with a maximum individual cash credit of VRD 48,991.00, both consistent with structuring to avoid the VRD 50,000 single-transaction threshold. Filing deadline: 2026-09-29.'
    )
);

-- Capture the SEQ just written, for use in the tamper/restore steps below.
SET demo_seq = (
    SELECT MAX(SEQ) FROM ARGUS.AUDIT.EVIDENCE_LEDGER
);

SELECT $demo_seq AS DEMO_EVIDENCE_SEQ;

-- -----------------------------------------------------------------------------
-- Step 5: Call SP_VERIFY_EVIDENCE_CHAIN and show INTACT
-- -----------------------------------------------------------------------------
CALL ARGUS.AUDIT.SP_VERIFY_EVIDENCE_CHAIN();

-- -----------------------------------------------------------------------------
-- Step 6: Tamper with one evidence row (the row just written in Step 4)
-- -----------------------------------------------------------------------------
UPDATE ARGUS.AUDIT.EVIDENCE_LEDGER
SET ANSWER_TEXT = 'TAMPERED: this answer was altered after the fact and does not match the recorded hash.'
WHERE SEQ = $demo_seq;

-- -----------------------------------------------------------------------------
-- Step 7: Verify and show BROKEN at the expected sequence
-- -----------------------------------------------------------------------------
CALL ARGUS.AUDIT.SP_VERIFY_EVIDENCE_CHAIN();

-- -----------------------------------------------------------------------------
-- Step 8: Restore the row to its original, factual content
-- -----------------------------------------------------------------------------
UPDATE ARGUS.AUDIT.EVIDENCE_LEDGER
SET ANSWER_TEXT = 'ACC-00001 breached RULE-STRUCTURING-950K (clause 4.3.2 of AML-POL-2026): aggregate cash credits of VRD 968,202.00 with a maximum individual cash credit of VRD 48,991.00, both consistent with structuring to avoid the VRD 50,000 single-transaction threshold. Filing deadline: 2026-09-29.'
WHERE SEQ = $demo_seq;

-- -----------------------------------------------------------------------------
-- Step 9: Verify and show INTACT
-- -----------------------------------------------------------------------------
CALL ARGUS.AUDIT.SP_VERIFY_EVIDENCE_CHAIN();

-- -----------------------------------------------------------------------------
-- Reference: full evidence summary after this demo run
-- -----------------------------------------------------------------------------
SELECT * FROM ARGUS.AUDIT.V_EVIDENCE_SUMMARY ORDER BY SEQ;
