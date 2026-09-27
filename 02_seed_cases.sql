/* Rebuilds ONLY the synthetic RenewalDesk cases CaseId 1..1200; no Python or CSV.
   Do not run in a production database. Safe to rerun for this training project. */
USE RenewalDesk;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET XACT_ABORT ON;
GO
IF EXISTS (SELECT 1 FROM sys.vector_indexes
           WHERE object_id=OBJECT_ID(N'renewal.SupportCases'))
 THROW 50100,'A preview vector index exists; load the training rows before creating it.',1;

;WITH N AS
(
 SELECT 1 AS CaseId
 UNION ALL SELECT CaseId+1 FROM N WHERE CaseId<1200
), Base AS
(
 SELECT CaseId,100+(CaseId*37)%240 AS CustomerId,
        (CaseId-1)%8 AS TopicNo,
        CASE WHEN CaseId%3=0 THEN N'email'
             WHEN CaseId%3=1 THEN N'web' ELSE N'phone' END AS ChannelValue,
        CASE WHEN CaseId%9=0 THEN N'high' ELSE N'normal' END AS PriorityValue
 FROM N
)
SELECT CaseId,CustomerId,
 DATEADD(MINUTE,CaseId,DATEADD(DAY,CaseId%365,CONVERT(datetime2(0),'20260101',112))) AS CreatedAt,
 CONVERT(nvarchar(1000),CONCAT(CASE TopicNo
  WHEN 0 THEN CASE WHEN ((CaseId-1)/8)%2=1 THEN N'Our subscription renewal is due next week; please confirm the terms' ELSE N'Need to renew the business subscription before expiry' END
  WHEN 1 THEN CASE WHEN ((CaseId-1)/8)%2=1 THEN N'The latest invoice appears to have an incorrect tax amount' ELSE N'Invoice shows a duplicate charge this month' END
  WHEN 2 THEN CASE WHEN ((CaseId-1)/8)%2=1 THEN N'Account access failed after the password reset' ELSE N'Cannot sign in after changing my password' END
  WHEN 3 THEN CASE WHEN ((CaseId-1)/8)%2=1 THEN N'The application service is down for our support team' ELSE N'Service unavailable since this morning' END
  WHEN 4 THEN CASE WHEN ((CaseId-1)/8)%2=1 THEN N'The vehicle will not start; the battery may need replacement' ELSE N'The fleet vehicle battery failed after charging' END
  WHEN 5 THEN CASE WHEN ((CaseId-1)/8)%2=1 THEN N'Query performance dropped and the report refresh is slow' ELSE N'The dashboard is slow and the report takes too long' END
  WHEN 6 THEN CASE WHEN ((CaseId-1)/8)%2=1 THEN N'Please review the agreement coverage and renewal terms' ELSE N'Please clarify the contract terms and coverage' END
  WHEN 7 THEN CASE WHEN ((CaseId-1)/8)%2=1 THEN N'The card was charged but the payment still shows as pending' ELSE N'Payment by card is not reflected in the account' END
 END,
 CASE WHEN CaseId%11=0 THEN N' - follow-up on a previous ticket'
      WHEN CaseId%13=0 THEN N' - affects multiple users'
      WHEN CaseId%17=0 THEN N' - urgent before next billing cycle'
      ELSE N'' END)) AS CaseText,
 CONVERT(nvarchar(300),CONCAT(N'Call 010',RIGHT(CONCAT('00000000',10000000+CaseId*7919),8),
    N', email customer',CustomerId,N'+campaign@example.org')) AS RawContact,
 CONVERT(nvarchar(max),CONCAT(N'{"channel":"',ChannelValue,N'","priority":"',PriorityValue,
    N'","product":"',CASE WHEN TopicNo=4 THEN N'Fleet' ELSE N'Subscription' END,
    N'","tags":["',CASE TopicNo WHEN 0 THEN N'renewal' WHEN 1 THEN N'billing'
      WHEN 2 THEN N'login' WHEN 3 THEN N'outage' WHEN 4 THEN N'battery'
      WHEN 5 THEN N'performance' WHEN 6 THEN N'contract' ELSE N'payment' END,
    N'","synthetic"],"caseReference":"CASE-',RIGHT(CONCAT('000000',CaseId),6),N'"}')) AS DetailsJson,
 CONVERT(nvarchar(30),CASE TopicNo WHEN 0 THEN N'renewal' WHEN 1 THEN N'billing'
     WHEN 2 THEN N'login' WHEN 3 THEN N'outage' WHEN 4 THEN N'battery'
     WHEN 5 THEN N'performance' WHEN 6 THEN N'contract' ELSE N'payment' END) AS CaseType,
 CONVERT(nvarchar(128),N'SQL-topic-rules-v1-NOT-AI') AS EmbeddingModel,
 /* 384 numbers, but ONLY one manually chosen topic coordinate is 1.
    This is a rules demo, NOT a machine-learned embedding. */
 CAST(CONCAT('[',REPLICATE('0,',TopicNo),'1',REPLICATE(',0',383-TopicNo),']') AS vector(384)) AS Embedding
INTO #Seed
FROM Base
OPTION (MAXRECURSION 0);

BEGIN TRANSACTION;
UPDATE t SET t.CustomerId=s.CustomerId,t.CreatedAt=s.CreatedAt,
 t.CaseText=s.CaseText,t.RawContact=s.RawContact,t.DetailsJson=s.DetailsJson,
 t.CaseType=s.CaseType,t.EmbeddingModel=s.EmbeddingModel,t.Embedding=s.Embedding
FROM renewal.SupportCases AS t JOIN #Seed AS s ON s.CaseId=t.CaseId;
INSERT renewal.SupportCases
 (CaseId,CustomerId,CreatedAt,CaseText,RawContact,DetailsJson,CaseType,EmbeddingModel,Embedding)
SELECT s.CaseId,s.CustomerId,s.CreatedAt,s.CaseText,s.RawContact,s.DetailsJson,
       s.CaseType,s.EmbeddingModel,s.Embedding
FROM #Seed AS s
WHERE NOT EXISTS(SELECT 1 FROM renewal.SupportCases AS t WHERE t.CaseId=s.CaseId);
COMMIT TRANSACTION;

SELECT COUNT_BIG(*) AS LoadedTrainingCases,
       MIN(EmbeddingModel) AS VectorSource,MAX(EmbeddingModel) AS VectorSourceMax
FROM renewal.SupportCases WHERE CaseId BETWEEN 1 AND 1200;
