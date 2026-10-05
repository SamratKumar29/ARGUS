-- ==============================================================================
-- 99_TEARDOWN.SQL — Cleanup script for ARGUS
-- ==============================================================================

USE ROLE ACCOUNTADMIN;

DROP DATABASE IF EXISTS ARGUS;
DROP WAREHOUSE IF EXISTS ARGUS_WH;
DROP RESOURCE MONITOR IF EXISTS ARGUS_RM;

DROP ROLE IF EXISTS ARGUS_AUDITOR;
DROP ROLE IF EXISTS ARGUS_COMPLIANCE_OFFICER;
DROP ROLE IF EXISTS ARGUS_FRAUD_ANALYST;
DROP ROLE IF EXISTS ARGUS_ADMIN;

SELECT 'Teardown completed successfully' AS STATUS;
