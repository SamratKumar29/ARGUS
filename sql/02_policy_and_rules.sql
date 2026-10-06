-- ==============================================================================
-- 02_POLICY_AND_RULES.SQL — Regulation-as-Code: Policy Documents, Chunks, Rules
-- Fictional AML policy for Republic of Verdana (currency VRD, regulator FFIA).
-- Source: data/policy/AML-POL-2026.md
-- Idempotent. No AI functions used (manual structured extraction for MVP).
-- ==============================================================================

USE ROLE ARGUS_ADMIN;
USE WAREHOUSE ARGUS_WH;
USE DATABASE ARGUS;
USE SCHEMA DOC;

-- 1. POLICY_DOCUMENTS — one row per source policy document
CREATE TABLE IF NOT EXISTS ARGUS.DOC.POLICY_DOCUMENTS (
    DOC_CODE        VARCHAR(32)  NOT NULL,
    TITLE           VARCHAR(255) NOT NULL,
    EFFECTIVE_DATE  DATE         NOT NULL,
    SOURCE_PATH     VARCHAR(512) NOT NULL,
    FICTIONAL       BOOLEAN      NOT NULL DEFAULT TRUE,
    LOADED_AT       TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_POLICY_DOCUMENTS PRIMARY KEY (DOC_CODE)
);

-- 2. POLICY_CHUNKS — clause-level chunks of the source document (for citation/search)
CREATE TABLE IF NOT EXISTS ARGUS.DOC.POLICY_CHUNKS (
    CHUNK_ID        VARCHAR(64)  NOT NULL,
    DOC_CODE        VARCHAR(32)  NOT NULL,
    CLAUSE_REF      VARCHAR(32)  NOT NULL,
    CLAUSE_TITLE    VARCHAR(255),
    CHUNK_TEXT      VARCHAR(2000) NOT NULL,
    CONSTRAINT PK_POLICY_CHUNKS PRIMARY KEY (CHUNK_ID),
    CONSTRAINT FK_POLICY_CHUNKS_DOC FOREIGN KEY (DOC_CODE) REFERENCES ARGUS.DOC.POLICY_DOCUMENTS (DOC_CODE)
);

-- 3. POLICY_RULES — Regulation-as-Code: machine-readable obligations extracted from clauses
CREATE TABLE IF NOT EXISTS ARGUS.DOC.POLICY_RULES (
    RULE_ID                 VARCHAR(64)   NOT NULL,
    DOC_CODE                VARCHAR(32)   NOT NULL,
    CLAUSE_REF              VARCHAR(32)   NOT NULL,
    TYPOLOGY_CODE           VARCHAR(32)   NOT NULL,
    OBLIGATION_TEXT         VARCHAR(2000) NOT NULL,
    APPLIES_TO_ENTITY       VARCHAR(16)   NOT NULL,       -- e.g. ACCOUNT
    TRIGGER_METRIC          VARCHAR(64)   NOT NULL,       -- e.g. AGGREGATE_CASH_CREDIT_AMOUNT
    COMPARATOR              VARCHAR(8)    NOT NULL,       -- e.g. '>='
    THRESHOLD_VALUE         NUMBER(18,2)  NOT NULL,
    THRESHOLD_CURRENCY      VARCHAR(8)    NOT NULL,
    MAX_INDIVIDUAL_METRIC   VARCHAR(64),                  -- e.g. MAX_INDIVIDUAL_CASH_CREDIT
    MAX_INDIVIDUAL_COMPARATOR VARCHAR(8),                 -- e.g. '<'
    MAX_INDIVIDUAL_VALUE    NUMBER(18,2),
    LOOKBACK_DAYS           NUMBER(9,0)   NOT NULL,
    FILING_DEADLINE_DAYS    NUMBER(9,0)   NOT NULL,
    CONFIDENCE              FLOAT         NOT NULL DEFAULT 1.0,
    IS_ACTIVE               BOOLEAN       NOT NULL DEFAULT TRUE,
    EXTRACTED_AT            TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_POLICY_RULES PRIMARY KEY (RULE_ID),
    CONSTRAINT FK_POLICY_RULES_DOC FOREIGN KEY (DOC_CODE) REFERENCES ARGUS.DOC.POLICY_DOCUMENTS (DOC_CODE)
);

-- 4. V_ACTIVE_POLICY_RULES — convenience view the detection layer reads from
--    (never hardcode thresholds in detection SQL; always resolve via this view)
CREATE OR REPLACE VIEW ARGUS.DOC.V_ACTIVE_POLICY_RULES AS
SELECT
    RULE_ID,
    DOC_CODE,
    CLAUSE_REF,
    TYPOLOGY_CODE,
    OBLIGATION_TEXT,
    APPLIES_TO_ENTITY,
    TRIGGER_METRIC,
    COMPARATOR,
    THRESHOLD_VALUE,
    THRESHOLD_CURRENCY,
    MAX_INDIVIDUAL_METRIC,
    MAX_INDIVIDUAL_COMPARATOR,
    MAX_INDIVIDUAL_VALUE,
    LOOKBACK_DAYS,
    FILING_DEADLINE_DAYS,
    CONFIDENCE
FROM ARGUS.DOC.POLICY_RULES
WHERE IS_ACTIVE = TRUE;

-- 5. Seed data: the policy document itself
MERGE INTO ARGUS.DOC.POLICY_DOCUMENTS AS tgt
USING (SELECT 'AML-POL-2026' AS DOC_CODE) AS src
ON tgt.DOC_CODE = src.DOC_CODE
WHEN NOT MATCHED THEN INSERT (DOC_CODE, TITLE, EFFECTIVE_DATE, SOURCE_PATH, FICTIONAL)
VALUES (
    'AML-POL-2026',
    'Fictional AML/CFT Policy for the Republic of Verdana',
    '2026-01-01',
    'data/policy/AML-POL-2026.md',
    TRUE
);

-- 6. Seed data: clause chunk for 4.3.2 (the structuring obligation we detect against)
MERGE INTO ARGUS.DOC.POLICY_CHUNKS AS tgt
USING (SELECT 'AML-POL-2026#4.3.2' AS CHUNK_ID) AS src
ON tgt.CHUNK_ID = src.CHUNK_ID
WHEN NOT MATCHED THEN INSERT (CHUNK_ID, DOC_CODE, CLAUSE_REF, CLAUSE_TITLE, CHUNK_TEXT)
VALUES (
    'AML-POL-2026#4.3.2',
    'AML-POL-2026',
    '4.3.2',
    'Structuring obligation',
    'Aggregate cash credits equal to or exceeding VRD 950,000 within any rolling 30-day period, where no individual cash credit reaches VRD 50,000, shall be escalated as potential STRUCTURING. If investigation confirms suspicion, a Suspicious Transaction Report shall be filed with the FFIA within 7 calendar days of confirmation.'
);

-- 7. Seed data: the structuring rule itself (Regulation-as-Code)
MERGE INTO ARGUS.DOC.POLICY_RULES AS tgt
USING (SELECT 'RULE-STRUCTURING-950K' AS RULE_ID) AS src
ON tgt.RULE_ID = src.RULE_ID
WHEN NOT MATCHED THEN INSERT (
    RULE_ID, DOC_CODE, CLAUSE_REF, TYPOLOGY_CODE, OBLIGATION_TEXT,
    APPLIES_TO_ENTITY, TRIGGER_METRIC, COMPARATOR, THRESHOLD_VALUE, THRESHOLD_CURRENCY,
    MAX_INDIVIDUAL_METRIC, MAX_INDIVIDUAL_COMPARATOR, MAX_INDIVIDUAL_VALUE,
    LOOKBACK_DAYS, FILING_DEADLINE_DAYS, CONFIDENCE, IS_ACTIVE
)
VALUES (
    'RULE-STRUCTURING-950K',
    'AML-POL-2026',
    '4.3.2',
    'STRUCTURING',
    'Aggregate cash credits >= VRD 950,000 within a rolling 30-day period, where no individual cash credit reaches VRD 50,000, shall be escalated as potential STRUCTURING. STR filing required within 7 calendar days of confirmation.',
    'ACCOUNT',
    'AGGREGATE_CASH_CREDIT_AMOUNT',
    '>=',
    950000.00,
    'VRD',
    'MAX_INDIVIDUAL_CASH_CREDIT',
    '<',
    50000.00,
    30,
    7,
    1.0,
    TRUE
);

SELECT 'Policy and rules deployed successfully' AS STATUS;
