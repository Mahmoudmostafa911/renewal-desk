/* SQL-only question -> two retrieval lists -> RRF -> extractive answer + documents. */
USE RenewalDesk;
GO
CREATE OR ALTER PROCEDURE renewal.SearchCases
 @Question nvarchar(400),
 @Keyword nvarchar(100)=NULL,
 @Top int=5
AS
BEGIN
 SET NOCOUNT ON;
 IF @Top NOT BETWEEN 1 AND 30
  THROW 50101,'@Top must be between 1 and 30.',1;

 DECLARE @q nvarchar(400)=LOWER(TRIM(@Question));
 DECLARE @topic tinyint = CASE
  WHEN @q LIKE N'%battery%' OR @q LIKE N'%charging%' OR @q LIKE N'%vehicle%' THEN 4
  WHEN @q LIKE N'%renew%' OR @q LIKE N'%subscription%' OR @q LIKE N'%expiry%' THEN 0
  WHEN @q LIKE N'%billing%' OR @q LIKE N'%invoice%' OR @q LIKE N'%tax%' THEN 1
  WHEN @q LIKE N'%login%' OR @q LIKE N'%password%' OR @q LIKE N'%sign in%' THEN 2
  WHEN @q LIKE N'%outage%' OR @q LIKE N'%unavailable%' OR @q LIKE N'%service down%' THEN 3
  WHEN @q LIKE N'%slow%' OR @q LIKE N'%dashboard%' OR @q LIKE N'%performance%' THEN 5
  WHEN @q LIKE N'%contract%' OR @q LIKE N'%agreement%' OR @q LIKE N'%coverage%' THEN 6
  WHEN @q LIKE N'%payment%' OR @q LIKE N'%card%' OR @q LIKE N'%charged%' THEN 7
  ELSE NULL END;
 IF @topic IS NULL
  THROW 50102,'Question not recognized by the eight demo topics. Try battery, billing, login, renewal, outage, performance, contract, payment.',1;

 DECLARE @Vector vector(384) = CAST(CONCAT('[',REPLICATE('0,',@topic),
                                   '1',REPLICATE(',0',383-@topic),']') AS vector(384));
 SET @Keyword=COALESCE(NULLIF(TRIM(@Keyword),N''),
   CASE @topic WHEN 0 THEN N'renew' WHEN 1 THEN N'invoice' WHEN 2 THEN N'password'
    WHEN 3 THEN N'unavailable' WHEN 4 THEN N'battery' WHEN 5 THEN N'dashboard'
    WHEN 6 THEN N'contract' ELSE N'payment' END);

 CREATE TABLE #VectorHits(CaseId int NOT NULL PRIMARY KEY,Distance float NOT NULL,VectorRank int NOT NULL);
 INSERT #VectorHits(CaseId,Distance,VectorRank)
 SELECT CaseId,Distance,ROW_NUMBER() OVER(ORDER BY Distance,CaseId)
 FROM (SELECT TOP(30) CaseId,VECTOR_DISTANCE('cosine',@Vector,Embedding) AS Distance
       FROM renewal.SupportCases
       WHERE EmbeddingModel=N'SQL-topic-rules-v1-NOT-AI' AND Embedding IS NOT NULL
       ORDER BY Distance,CaseId) AS v;

 CREATE TABLE #TextHits(CaseId int NOT NULL PRIMARY KEY,TextScore int NOT NULL);
 IF EXISTS(SELECT 1 FROM sys.fulltext_indexes WHERE object_id=OBJECT_ID(N'renewal.SupportCases'))
 BEGIN
  -- Dynamic SQL keeps the stored procedure usable when Full-Text is not installed.
  DECLARE @Condition nvarchar(300)=CONCAT(N'"',REPLACE(@Keyword,N'"',N''),N'"');
  EXEC sys.sp_executesql
    N'INSERT #TextHits(CaseId,TextScore)
      SELECT c.CaseId,f.[RANK]
      FROM CONTAINSTABLE(renewal.SupportCases,CaseText,@term,30) AS f
      JOIN renewal.SupportCases AS c ON c.CaseId=f.[KEY];',
    N'@term nvarchar(300)',@term=@Condition;
 END
 ELSE
 BEGIN
  INSERT #TextHits(CaseId,TextScore)
  SELECT TOP(30) CaseId,1 FROM renewal.SupportCases
  WHERE CHARINDEX(@Keyword,CaseText)>0 ORDER BY CaseId;
 END;

 ;WITH TextPositions AS
 (
  SELECT CaseId,ROW_NUMBER() OVER(ORDER BY TextScore DESC,CaseId) AS KeywordRank
  FROM #TextHits
 ), Fused AS
 (
  SELECT COALESCE(v.CaseId,t.CaseId) AS CaseId,
   v.Distance,v.VectorRank,t.KeywordRank,
   COALESCE(1.0/(60+v.VectorRank),0.0)+COALESCE(1.0/(60+t.KeywordRank),0.0) AS RRFScore
  FROM #VectorHits AS v FULL OUTER JOIN TextPositions AS t ON v.CaseId=t.CaseId
 )
 SELECT TOP(@Top) f.CaseId,c.CaseType,c.CaseText,c.CreatedAt,
   f.Distance,f.VectorRank,f.KeywordRank,f.RRFScore
 INTO #Final
 FROM Fused AS f JOIN renewal.SupportCases AS c ON c.CaseId=f.CaseId
 ORDER BY f.RRFScore DESC,f.CaseId;

 SELECT TOP(1)
  N'Closest historical case '+CONVERT(nvarchar(20),CaseId)+N': '+CaseText AS ExtractiveAnswer,
  N'Synthetic historical case; not a verified solution or an AI-generated answer.' AS Note
 FROM #Final ORDER BY RRFScore DESC,CaseId;
 SELECT CaseId,CaseType,CaseText AS SourceDocument,CreatedAt,Distance,
        VectorRank,KeywordRank,RRFScore,
        CASE WHEN EXISTS(SELECT 1 FROM sys.fulltext_indexes
           WHERE object_id=OBJECT_ID(N'renewal.SupportCases'))
             THEN N'Full-Text' ELSE N'CHARINDEX fallback' END AS TextEngine
 FROM #Final ORDER BY RRFScore DESC,CaseId;
END;
GO
