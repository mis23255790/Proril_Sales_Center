CREATE TABLE [dbo].[M_Permission] (
    [ID]                   INT          IDENTITY (1, 1) NOT NULL,
    [LinkNumber]           VARCHAR (10) NULL,
    [FunctionNo]           INT          NOT NULL,
    [Creator]              VARCHAR (10) NULL,
    [LinkType]             TINYINT      NOT NULL,
    [CreateTime]           DATETIME     NULL,
    [PermissionLinkTypeID] INT          NULL,
    [Modifier]             VARCHAR (40) NULL,
    [ModiTime]             DATETIME     NULL,
    PRIMARY KEY CLUSTERED ([ID] ASC)
);


GO

