CREATE TABLE [dbo].[COP_DepData] (
    [ID]            INT            IDENTITY (1, 1) NOT NULL,
    [OrderType]     VARCHAR (10)   NULL,
    [OrderName]     NVARCHAR (120) NULL,
    [OrderName_All] NVARCHAR (120) NULL,
    [DepNo]         VARCHAR (10)   NULL,
    [DepName]       NVARCHAR (120) NULL,
    [aStatus]       VARCHAR (1)    NULL,
    [Creator]       NVARCHAR (40)  NULL,
    [CreateTime]    DATETIME       NULL,
    [Modifier]      NVARCHAR (40)  NULL,
    [ModiTime]      DATETIME       NULL,
    CONSTRAINT [PK_COP_DepData] PRIMARY KEY CLUSTERED ([ID] ASC)
);


GO

