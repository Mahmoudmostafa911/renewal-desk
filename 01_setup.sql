/* RenewalDesk SQL-only, on SQL Server 2025 Developer. Safe to rerun. */
IF DB_ID(N'RenewalDesk') IS NULL EXEC(N'CREATE DATABASE RenewalDesk');
GO
USE RenewalDesk;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO
IF SCHEMA_ID(N'renewal') IS NULL EXEC(N'CREATE SCHEMA renewal');
GO
IF OBJECT_ID(N'renewal.SupportCases',N'U') IS NULL
BEGIN
 CREATE TABLE renewal.SupportCases
 (
  CaseId int NOT NULL CONSTRAINT PK_RenewalSupportCases PRIMARY KEY,
  CustomerId int NOT NULL,
  CreatedAt datetime2(0) NOT NULL,
  CaseText nvarchar(1000) NOT NULL,
  RawContact nvarchar(300) NOT NULL,
  DetailsJson nvarchar(max) NOT NULL,
  CaseType nvarchar(30) NOT NULL,
  EmbeddingModel nvarchar(128) NULL,
  Embedding vector(384) NULL,
  CONSTRAINT CK_RenewalCaseJson CHECK (ISJSON(DetailsJson)=1),
  CONSTRAINT CK_RenewalCaseType CHECK (CaseType IN
   (N'renewal',N'billing',N'login',N'outage',N'battery',N'performance',N'contract',N'payment'))
 );
END;
GO
IF COL_LENGTH(N'renewal.SupportCases',N'Channel') IS NULL
 ALTER TABLE renewal.SupportCases
 ADD Channel AS CONVERT(nvarchar(30),JSON_VALUE(DetailsJson,'$.channel'));
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes
 WHERE object_id=OBJECT_ID(N'renewal.SupportCases') AND name=N'IX_RenewalCases_Customer_Date')
 CREATE INDEX IX_RenewalCases_Customer_Date
 ON renewal.SupportCases(CustomerId,CreatedAt DESC) INCLUDE(CaseType);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes
 WHERE object_id=OBJECT_ID(N'renewal.SupportCases') AND name=N'IX_RenewalCases_Channel_Type')
 CREATE INDEX IX_RenewalCases_Channel_Type
 ON renewal.SupportCases(Channel,CaseType) INCLUDE(CreatedAt);
GO
SELECT DB_NAME() AS DatabaseName,OBJECT_ID(N'renewal.SupportCases',N'U') AS SupportCasesTableId;
