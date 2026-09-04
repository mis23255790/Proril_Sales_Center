CREATE TABLE [dbo].[D_WorkProcessPermission] (
    [ID]         INT          IDENTITY (1, 1) NOT NULL,
    [WPNo]       VARCHAR (10) NOT NULL,
    [EnableType] TINYINT      NOT NULL,
    [Account]    VARCHAR (10) NOT NULL,
    [Creator]    VARCHAR (10) NULL,
    [CreateTime] DATETIME     NULL,
    [Modifier]   VARCHAR (10) NULL,
    [ModiTime]   DATETIME     NULL,
    PRIMARY KEY CLUSTERED ([ID] ASC)
);


GO

