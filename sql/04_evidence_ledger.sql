-- ==============================================================================
-- 04_EVIDENCE_LEDGER.SQL — Hash-chained Evidence Ledger (MVP)
-- record_hash = SHA2(prev_hash || payload_canonical, 256)
-- Canonical payload is a deterministic pipe-delimited concatenation of the
-- ledger's own structured columns (recomputed at verify-time from current row
-- state, never trusted from the stored PAYLOAD_CANONICAL text) — this ensures
-- any direct tamper to any structured column (e.g. ANSWER_TEXT) is detected.
-- Idempotent DDL. Does not touch RAW, DOC, or CURATED schemas.
-- ==============================================================================

USE ROLE ARGUS_ADMIN;
USE WAREHOUSE ARGUS_WH;
USE DATABASE ARGUS;
USE SCHEMA AUDIT;

-- 1. Sequence for monotonic SEQ values
-- ORDER is required: default NOORDER sequences do not guarantee NEXTVAL values
-- increase in call order, which would break chain-walk verification by SEQ.
CREATE SEQUENCE IF NOT EXISTS ARGUS.AUDIT.EVIDENCE_SEQ START = 1 INCREMENT = 1 ORDER;

-- 2. EVIDENCE_LEDGER table
CREATE TABLE IF NOT EXISTS ARGUS.AUDIT.EVIDENCE_LEDGER (
    SEQ                 NUMBER(18,0)  NOT NULL,
    EVIDENCE_ID         VARCHAR(64)   NOT NULL,
    CREATED_AT          TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    ACTOR_ROLE          VARCHAR(128)  NOT NULL,
    ACTOR_USER          VARCHAR(128)  NOT NULL,
    WAREHOUSE           VARCHAR(128),
    QUESTION            VARCHAR(2000),
    RESOLVED_INTENT     VARCHAR(500),
    GENERATED_SQL       VARCHAR(8000),
    SOURCE_ROW_KEYS     VARIANT,
    RETRIEVED_CHUNKS    VARIANT,
    ANSWER_TEXT         VARCHAR(4000),
    PAYLOAD_CANONICAL   VARCHAR(16000) NOT NULL,
    PREV_HASH           VARCHAR(64)   NOT NULL,
    RECORD_HASH         VARCHAR(64)   NOT NULL,
    CONSTRAINT PK_EVIDENCE_LEDGER PRIMARY KEY (SEQ)
);

-- 3. SP_RECORD_EVIDENCE — appends one hash-chained row.
-- payload VARIANT expected keys (all optional, default to empty):
--   question, resolved_intent, generated_sql, source_row_keys (array),
--   retrieved_chunks (array), answer_text
CREATE OR REPLACE PROCEDURE ARGUS.AUDIT.SP_RECORD_EVIDENCE(PAYLOAD VARIANT)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_seq               NUMBER;
    v_evidence_id       VARCHAR;
    v_actor_role        VARCHAR;
    v_actor_user        VARCHAR;
    v_warehouse         VARCHAR;
    v_question          VARCHAR;
    v_resolved_intent   VARCHAR;
    v_generated_sql     VARCHAR;
    v_source_row_keys   VARIANT;
    v_retrieved_chunks  VARIANT;
    v_answer_text       VARCHAR;
    v_canonical         VARCHAR;
    v_prev_hash         VARCHAR;
    v_record_hash       VARCHAR;
BEGIN
    SELECT ARGUS.AUDIT.EVIDENCE_SEQ.NEXTVAL INTO :v_seq;
    v_evidence_id := 'EVD-' || LPAD(v_seq::VARCHAR, 6, '0');

    v_actor_role := CURRENT_ROLE();
    v_actor_user := CURRENT_USER();
    v_warehouse  := CURRENT_WAREHOUSE();

    v_question         := COALESCE(:PAYLOAD:question::VARCHAR, '');
    v_resolved_intent  := COALESCE(:PAYLOAD:resolved_intent::VARCHAR, '');
    v_generated_sql    := COALESCE(:PAYLOAD:generated_sql::VARCHAR, '');
    v_source_row_keys  := COALESCE(:PAYLOAD:source_row_keys, ARRAY_CONSTRUCT());
    v_retrieved_chunks := COALESCE(:PAYLOAD:retrieved_chunks, ARRAY_CONSTRUCT());
    v_answer_text      := COALESCE(:PAYLOAD:answer_text::VARCHAR, '');

    -- Deterministic canonical serialization (same formula used at verify-time)
    v_canonical := v_evidence_id || '|' ||
                   v_question || '|' ||
                   v_resolved_intent || '|' ||
                   v_generated_sql || '|' ||
                   TO_JSON(v_source_row_keys) || '|' ||
                   TO_JSON(v_retrieved_chunks) || '|' ||
                   v_answer_text;

    v_prev_hash := COALESCE(
        (SELECT RECORD_HASH FROM ARGUS.AUDIT.EVIDENCE_LEDGER ORDER BY SEQ DESC LIMIT 1),
        REPEAT('0', 64)
    );

    v_record_hash := SHA2(v_prev_hash || v_canonical, 256);

    INSERT INTO ARGUS.AUDIT.EVIDENCE_LEDGER (
        SEQ, EVIDENCE_ID, CREATED_AT, ACTOR_ROLE, ACTOR_USER, WAREHOUSE,
        QUESTION, RESOLVED_INTENT, GENERATED_SQL, SOURCE_ROW_KEYS, RETRIEVED_CHUNKS,
        ANSWER_TEXT, PAYLOAD_CANONICAL, PREV_HASH, RECORD_HASH
    )
    SELECT
        :v_seq, :v_evidence_id, CURRENT_TIMESTAMP(), :v_actor_role, :v_actor_user, :v_warehouse,
        :v_question, :v_resolved_intent, :v_generated_sql, :v_source_row_keys, :v_retrieved_chunks,
        :v_answer_text, :v_canonical, :v_prev_hash, :v_record_hash;

    RETURN v_evidence_id;
END;
$$;

-- 4. SP_VERIFY_EVIDENCE_CHAIN — walks the chain, recomputing canonical payload
--    and hash from each row's CURRENT structured column values (never from the
--    stored PAYLOAD_CANONICAL text), so any tamper to any structured column is caught.
CREATE OR REPLACE PROCEDURE ARGUS.AUDIT.SP_VERIFY_EVIDENCE_CHAIN()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_expected_prev_hash VARCHAR DEFAULT REPEAT('0', 64);
    v_recomputed_canonical VARCHAR;
    v_recomputed_hash VARCHAR;
    v_result VARCHAR DEFAULT 'INTACT';
    c_rows CURSOR FOR
        SELECT SEQ, EVIDENCE_ID, QUESTION, RESOLVED_INTENT, GENERATED_SQL,
               SOURCE_ROW_KEYS, RETRIEVED_CHUNKS, ANSWER_TEXT, PREV_HASH, RECORD_HASH
        FROM ARGUS.AUDIT.EVIDENCE_LEDGER
        ORDER BY SEQ ASC;
BEGIN
    FOR row_var IN c_rows DO
        v_recomputed_canonical := row_var.EVIDENCE_ID || '|' ||
                                   COALESCE(row_var.QUESTION, '') || '|' ||
                                   COALESCE(row_var.RESOLVED_INTENT, '') || '|' ||
                                   COALESCE(row_var.GENERATED_SQL, '') || '|' ||
                                   TO_JSON(COALESCE(row_var.SOURCE_ROW_KEYS, ARRAY_CONSTRUCT())) || '|' ||
                                   TO_JSON(COALESCE(row_var.RETRIEVED_CHUNKS, ARRAY_CONSTRUCT())) || '|' ||
                                   COALESCE(row_var.ANSWER_TEXT, '');

        IF (row_var.PREV_HASH != v_expected_prev_hash) THEN
            v_result := 'BROKEN at seq ' || row_var.SEQ || ' (prev_hash mismatch — chain link to prior record was altered)';
            RETURN v_result;
        END IF;

        v_recomputed_hash := SHA2(v_expected_prev_hash || v_recomputed_canonical, 256);

        IF (v_recomputed_hash != row_var.RECORD_HASH) THEN
            v_result := 'BROKEN at seq ' || row_var.SEQ || ' (record_hash mismatch — row content was altered)';
            RETURN v_result;
        END IF;

        v_expected_prev_hash := row_var.RECORD_HASH;
    END FOR;

    RETURN v_result;
END;
$$;

-- 5. V_EVIDENCE_SUMMARY — human-readable projection for auditors
CREATE OR REPLACE VIEW ARGUS.AUDIT.V_EVIDENCE_SUMMARY AS
SELECT
    SEQ,
    EVIDENCE_ID,
    CREATED_AT,
    ACTOR_ROLE,
    ACTOR_USER,
    WAREHOUSE,
    QUESTION,
    RESOLVED_INTENT,
    ANSWER_TEXT,
    LEFT(PREV_HASH, 12) || '...'   AS PREV_HASH_SHORT,
    LEFT(RECORD_HASH, 12) || '...' AS RECORD_HASH_SHORT
FROM ARGUS.AUDIT.EVIDENCE_LEDGER
ORDER BY SEQ;

SELECT 'Evidence ledger deployed successfully' AS STATUS;
