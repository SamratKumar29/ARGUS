-- ==============================================================================
-- 01_RAW_DDL.SQL — Raw Tables for Parties, Accounts, Transactions, Ground Truth
-- Schema matches data/generated/*.csv produced by python/gen_data.py exactly.
-- Fictional world: Republic of Verdana, currency VRD, regulator FFIA.
-- ==============================================================================

USE ROLE ARGUS_ADMIN;
USE WAREHOUSE ARGUS_WH;
USE DATABASE ARGUS;
USE SCHEMA RAW;

-- 1. Parties Table
-- CSV: party_id,party_type,full_name,dob,nationality,occupation,is_pep,
--      risk_rating,onboarded_at,national_id_masked_source,email,phone
CREATE OR REPLACE TABLE ARGUS.RAW.PARTIES (
    PARTY_ID                   VARCHAR(16)  NOT NULL,
    PARTY_TYPE                 VARCHAR(16)  NOT NULL,
    FULL_NAME                  VARCHAR(255) NOT NULL,
    DOB                        DATE,
    NATIONALITY                VARCHAR(32)  NOT NULL,
    OCCUPATION                 VARCHAR(128),
    IS_PEP                     BOOLEAN      NOT NULL DEFAULT FALSE,
    RISK_RATING                VARCHAR(16)  NOT NULL DEFAULT 'LOW',
    ONBOARDED_AT                DATE        NOT NULL,
    NATIONAL_ID_MASKED_SOURCE  VARCHAR(64),
    EMAIL                      VARCHAR(255),
    PHONE                      VARCHAR(32),
    CONSTRAINT PK_PARTIES PRIMARY KEY (PARTY_ID)
);

-- 2. Accounts Table
-- CSV: account_id,party_id,account_type,currency,branch_code,region,
--      opened_at,closed_at,status,dormancy_flag,last_activity_at
CREATE OR REPLACE TABLE ARGUS.RAW.ACCOUNTS (
    ACCOUNT_ID          VARCHAR(16)  NOT NULL,
    PARTY_ID            VARCHAR(16)  NOT NULL,
    ACCOUNT_TYPE        VARCHAR(16)  NOT NULL,
    CURRENCY            VARCHAR(8)   NOT NULL DEFAULT 'VRD',
    BRANCH_CODE         VARCHAR(16)  NOT NULL,
    REGION              VARCHAR(16)  NOT NULL,
    OPENED_AT           DATE         NOT NULL,
    CLOSED_AT           DATE,
    STATUS              VARCHAR(16)  NOT NULL DEFAULT 'ACTIVE',
    DORMANCY_FLAG       BOOLEAN      NOT NULL DEFAULT FALSE,
    LAST_ACTIVITY_AT    DATE,
    CONSTRAINT PK_ACCOUNTS PRIMARY KEY (ACCOUNT_ID),
    CONSTRAINT FK_ACCOUNTS_PARTY FOREIGN KEY (PARTY_ID) REFERENCES ARGUS.RAW.PARTIES (PARTY_ID)
);

-- 3. Transactions Table
-- CSV: txn_id,account_id,txn_ts,amount,currency,direction,channel,txn_type,
--      counterparty_account,counterparty_name,counterparty_country,mcc,
--      device_id,is_cash,narrative
CREATE OR REPLACE TABLE ARGUS.RAW.TRANSACTIONS (
    TXN_ID                  VARCHAR(16)     NOT NULL,
    ACCOUNT_ID              VARCHAR(16)     NOT NULL,
    TXN_TS                  TIMESTAMP_NTZ   NOT NULL,
    AMOUNT                  NUMBER(18, 2)   NOT NULL,
    CURRENCY                VARCHAR(8)      NOT NULL DEFAULT 'VRD',
    DIRECTION               VARCHAR(8)      NOT NULL,
    CHANNEL                 VARCHAR(16)     NOT NULL,
    TXN_TYPE                VARCHAR(32)     NOT NULL,
    COUNTERPARTY_ACCOUNT    VARCHAR(32),
    COUNTERPARTY_NAME       VARCHAR(255),
    COUNTERPARTY_COUNTRY    VARCHAR(8),
    MCC                     VARCHAR(16),
    DEVICE_ID               VARCHAR(16),
    IS_CASH                 BOOLEAN         NOT NULL DEFAULT FALSE,
    NARRATIVE               VARCHAR(512),
    CONSTRAINT PK_TRANSACTIONS PRIMARY KEY (TXN_ID),
    CONSTRAINT FK_TRANSACTIONS_ACCOUNT FOREIGN KEY (ACCOUNT_ID) REFERENCES ARGUS.RAW.ACCOUNTS (ACCOUNT_ID)
);

-- 4. Ground Truth Table (planted-typology labels, for demo/test verification only —
--    not used by detection logic itself, which must derive alerts independently)
-- CSV: entity_id,entity_type,typology_code,label,injected_at,window_start,window_end,notes
CREATE OR REPLACE TABLE ARGUS.RAW.GROUND_TRUTH (
    ENTITY_ID       VARCHAR(16)  NOT NULL,
    ENTITY_TYPE     VARCHAR(16)  NOT NULL,
    TYPOLOGY_CODE   VARCHAR(32)  NOT NULL,
    LABEL           VARCHAR(16)  NOT NULL,
    INJECTED_AT     DATE         NOT NULL,
    WINDOW_START    DATE,
    WINDOW_END      DATE,
    NOTES           VARCHAR(512)
);

COMMENT ON TABLE ARGUS.RAW.PARTIES IS 'Fictional synthetic customer entities (Republic of Verdana) for ARGUS risk demo';
COMMENT ON TABLE ARGUS.RAW.ACCOUNTS IS 'Fictional synthetic account entities, currency VRD';
COMMENT ON TABLE ARGUS.RAW.TRANSACTIONS IS 'Fictional synthetic transaction records with planted structuring patterns';
COMMENT ON TABLE ARGUS.RAW.GROUND_TRUTH IS 'Planted-typology ground truth labels for test/demo verification, not for detection logic';

SELECT 'RAW DDL deployed successfully' AS STATUS;
