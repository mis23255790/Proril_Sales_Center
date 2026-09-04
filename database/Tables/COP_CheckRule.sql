CREATE TABLE [dbo].[COP_CheckRule] (
    [ID]         INT            IDENTITY (1, 1) NOT NULL,
    [RecType]    VARCHAR (40)   NULL,
    [ChkField]   VARCHAR (40)   NULL,
    [ERPField]   VARCHAR (40)   NULL,
    [ChkRule]    NVARCHAR (120) NULL,
    [ChkLevel]   NVARCHAR (10)  NULL,
    [PassFlag]   VARCHAR (1)    NULL,
    [Memo]       NVARCHAR (500) NULL,
    [aStatus]    VARCHAR (1)    NULL,
    [Creator]    NVARCHAR (40)  NULL,
    [CreateTime] DATETIME       NULL,
    [Modifier]   NVARCHAR (40)  NULL,
    [ModiTime]   DATETIME       NULL,
    CONSTRAINT [PK_COP_CheckRule] PRIMARY KEY CLUSTERED ([ID] ASC)
);


GO

