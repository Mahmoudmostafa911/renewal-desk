/* Optional: search without Full-Text falls back to literal text matching. */
USE RenewalDesk;
GO
IF COALESCE(CONVERT(int,FULLTEXTSERVICEPROPERTY('IsFullTextInstalled')),0)<>1
BEGIN
 PRINT 'Full-Text Search is not installed. SearchCases will use CHARINDEX.';
 RETURN;
END;
IF NOT EXISTS(SELECT 1 FROM sys.fulltext_catalogs WHERE name=N'RenewalCasesFT')
 CREATE FULLTEXT CATALOG RenewalCasesFT;
IF NOT EXISTS(SELECT 1 FROM sys.fulltext_indexes WHERE object_id=OBJECT_ID(N'renewal.SupportCases'))
 CREATE FULLTEXT INDEX ON renewal.SupportCases
 (CaseText LANGUAGE 0) KEY INDEX PK_RenewalSupportCases
 ON RenewalCasesFT WITH CHANGE_TRACKING AUTO;
PRINT 'Full-Text is ready; initial population can take a little time.';
GO
SELECT OBJECTPROPERTYEX(OBJECT_ID(N'renewal.SupportCases'),'TableFulltextPopulateStatus') AS PopulationStatus;
