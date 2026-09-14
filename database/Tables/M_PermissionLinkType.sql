CREATE TABLE [dbo].[M_PermissionLinkType] (
    [ID]                 INT          IDENTITY (1, 1) NOT NULL,
    [FunctionNo]         INT          NOT NULL,
    [LinkType]           TINYINT      NOT NULL,
    [LinkTypeName]       VARCHAR (50) NOT NULL,
    [ParentLinkTypeID]   INT          NULL,
    [Creator]            VARCHAR (10) NULL,
    [CreateTime]         DATETIME     NULL,
    [Modifier]           VARCHAR (10) NULL,
    [ModifyTime]         DATETIME     NULL,
    CONSTRAINT [PK_M_PermissionLinkType] PRIMARY KEY CLUSTERED ([ID] ASC)
);


GO

CREATE UNIQUE NONCLUSTERED INDEX [NonClusteredIndex-20231116-083304]
    ON [dbo].[M_PermissionLinkType]([FunctionNo] ASC, [LinkType] ASC, [ParentLinkTypeID] ASC);


GO

