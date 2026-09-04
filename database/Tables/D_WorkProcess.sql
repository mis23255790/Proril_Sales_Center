CREATE TABLE [dbo].[D_WorkProcess] (
    [ID]             INT           IDENTITY (1, 1) NOT NULL,
    [WPNo]           VARCHAR (10)  NOT NULL,
    [SopTitle]       VARCHAR (200) NOT NULL,
    [Descript]       VARCHAR (MAX) NULL,
    [PhraseList]     VARCHAR (500) NOT NULL,
    [VerNo]          VARCHAR (40)  NULL,
    [PubFlag]        BIT           NULL,
    [FinFlag]        BIT           CONSTRAINT [DF_D_WorkProcess_FinFlag] DEFAULT ((0)) NULL,
    [ProgressStatus] INT           NULL,
    [PubDate]        DATETIME      NULL,
    [aStatus]        VARCHAR (1)   NULL,
    [Leader]         VARCHAR (10)  NULL,
    [Authorize]      VARCHAR (10)  NULL,
    [Creator]        VARCHAR (10)  NULL,
    [CreateTime]     DATETIME      NULL,
    [Modifier]       VARCHAR (10)  NULL,
    [ModiTime]       DATETIME      NULL,
    CONSTRAINT [PK__D_WorkPr__3214EC27BF8FA6A7] PRIMARY KEY CLUSTERED ([ID] ASC)
);


GO

