CREATE TABLE [dbo].[M_PermissionGroup] (
    [ID]         INT           IDENTITY (1, 1) NOT NULL,
    [GroupType]  INT           NOT NULL,
    [GroupNo]    VARCHAR (10)  NULL,
    [FunctionNo] INT           NULL,
    [LinkType]   TINYINT       NULL,
    [TypeDesc]   NVARCHAR (50) NULL,
    [GroupDesc]  NVARCHAR (50) NULL,
    [aStatus]    VARCHAR (1)   NULL,
    [Creator]    VARCHAR (10)  NULL,
    [CreateTime] DATETIME      NULL,
    [Modifier]   VARCHAR (10)  NULL,
    [ModiTime]   DATETIME      NULL,
    CONSTRAINT [PK_M_PermissionGroup] PRIMARY KEY CLUSTERED ([ID] ASC)
);


GO

