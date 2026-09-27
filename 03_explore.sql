/* Regex, JSON, data quality, B-tree indexes, exact vector distance. */
USE RenewalDesk;
GO
SELECT TOP (12) CaseId,RawContact,
 REGEXP_SUBSTR(RawContact,N'01[0-9]{9}') AS Phone,
 REGEXP_SUBSTR(RawContact,N'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}') AS Email,
 REGEXP_REPLACE(RawContact,N'\+campaign',N'') AS CleanContact
FROM renewal.SupportCases ORDER BY CaseId;

SELECT TOP (12) CaseId,CaseType,Channel,
 JSON_VALUE(DetailsJson,'$.priority') AS Priority,
 JSON_VALUE(DetailsJson,'$.product') AS Product,
 JSON_QUERY(DetailsJson,'$.tags') AS TagsArray
FROM renewal.SupportCases ORDER BY CaseId;

SELECT Channel,CaseType,COUNT_BIG(*) AS Cases
FROM renewal.SupportCases
GROUP BY Channel,CaseType ORDER BY Channel,CaseType;

-- In SSMS enable Ctrl+M (Include Actual Execution Plan), then F5.
SET STATISTICS IO ON;
SELECT CaseId,CreatedAt,CaseType FROM renewal.SupportCases
WHERE CustomerId=101 AND CreatedAt>='20260101' AND CreatedAt<'20270101'
ORDER BY CreatedAt DESC;
SELECT CaseId,Channel,CaseType FROM renewal.SupportCases
WHERE Channel=N'email' AND CaseType=N'renewal';
SET STATISTICS IO OFF;

-- A vector is stored directly in SQL. Same topic -> same manually defined vector.
DECLARE @BatteryQuery vector(384) = CAST(CONCAT('[',REPLICATE('0,',4),'1',
                                          REPLICATE(',0',379),']') AS vector(384));
SELECT TOP (10) CaseId,CaseType,CaseText,
 VECTOR_DISTANCE('cosine',@BatteryQuery,Embedding) AS CosineDistance
FROM renewal.SupportCases
WHERE EmbeddingModel=N'SQL-topic-rules-v1-NOT-AI'
ORDER BY CosineDistance,CaseId;
