CREATE TABLE [dbo].[CRM_CustomerMemo] (
    [ID]         INT             IDENTITY (1, 1) NOT NULL,
    [CustomerNo] VARCHAR (20)    NULL,
    [MemoType]   NVARCHAR (40)   NULL,
    [MemoDesc]   NVARCHAR (1000) NULL,
    [FileName]   NVARCHAR (200)  NULL,
    [aStatus]    VARCHAR (1)     NULL,
    [Creator]    VARCHAR (40)    NULL,
    [CreateTime] DATETIME        NULL,
    [Modifier]   VARCHAR (40)    NULL,
    [ModiTime]   DATETIME        NULL,
    CONSTRAINT [PK_CRM_CustomerMemo] PRIMARY KEY CLUSTERED ([ID] ASC)
);


GO

