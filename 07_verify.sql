/* A small repeatable check after running 01..06. */
USE RenewalDesk;
GO
IF (SELECT COUNT_BIG(*) FROM renewal.SupportCases WHERE CaseId BETWEEN 1 AND 1200)<>1200
 THROW 50103,'Expected 1200 synthetic cases in the training ID range.',1;
IF EXISTS(SELECT 1 FROM renewal.SupportCases WHERE CaseId BETWEEN 1 AND 1200
          AND (Embedding IS NULL OR EmbeddingModel<>N'SQL-topic-rules-v1-NOT-AI'
               OR ISJSON(DetailsJson)<>1))
 THROW 50104,'The synthetic cases are missing valid JSON or SQL topic vectors.',1;
IF OBJECT_ID(N'renewal.SearchCases',N'P') IS NULL
 THROW 50105,'Run 05_search_procedure.sql before verification.',1;
SELECT COUNT_BIG(*) AS TrainingCases,
       COUNT(DISTINCT CaseType) AS DistinctTopics,
       MIN(CreatedAt) AS FirstCase,
       MAX(CreatedAt) AS LastCase
FROM renewal.SupportCases WHERE CaseId BETWEEN 1 AND 1200;
SELECT CaseType,COUNT_BIG(*) AS CasesPerTopic
FROM renewal.SupportCases WHERE CaseId BETWEEN 1 AND 1200
GROUP BY CaseType ORDER BY CaseType;
EXEC renewal.SearchCases @Question=N'Why did my battery fail?',@Keyword=N'battery',@Top=5;
