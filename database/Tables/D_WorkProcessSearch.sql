CREATE TABLE [dbo].[D_WorkProcessSearch] (
    [ID]         INT          IDENTITY (1, 1) NOT NULL,
    [WPNo]       VARCHAR (10) NOT NULL,
    [PhraseType] VARCHAR (4)  NULL,
    [PhraseCode] VARCHAR (10) NULL,
    [aStatus]    VARCHAR (1)  NULL,
    [Creator]    VARCHAR (10) NULL,
    [CreateTime] DATETIME     NULL,
    [Modifier]   VARCHAR (10) NULL,
    [ModiTime]   DATETIME     NULL,
    PRIMARY KEY CLUSTERED ([ID] ASC)
);


GO

