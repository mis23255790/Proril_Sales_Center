CREATE TABLE [dbo].[COP_PassCheck] (
    [ID]         INT            IDENTITY (1, 1) NOT NULL,
    [OrderChkNo] VARCHAR (20)   NULL,
    [Sno]        VARCHAR (4)    NULL,
    [PassTime]   DATETIME       NULL,
    [PassItems]  VARCHAR (40)   NULL,
    [PassMemo]   NVARCHAR (500) NULL,
    [Memo]       NVARCHAR (500) NULL,
    [aStatus]    VARCHAR (1)    NULL,
    [Creator]    NVARCHAR (40)  NULL,
    [CreateTime] DATETIME       NULL,
    [Modifier]   NVARCHAR (40)  NULL,
    [ModiTime]   DATETIME       NULL,
    CONSTRAINT [PK_COP_PassCheck] PRIMARY KEY CLUSTERED ([ID] ASC)
);


GO

