CREATE TABLE [dbo].[D_WorkProcessDetail] (
    [ID]              INT            IDENTITY (1, 1) NOT NULL,
    [WPNo]            VARCHAR (10)   NOT NULL,
    [SNo]             VARCHAR (4)    NOT NULL,
    [ProcessCaption]  NVARCHAR (200) NULL,
    [ProcessCaption2] NVARCHAR (400) NULL,
    [ProcessContent]  NVARCHAR (MAX) NULL,
    [Worker]          VARCHAR (10)   NULL,
    [aStatus]         VARCHAR (1)    NULL,
    [UploadFile]      VARCHAR (200)  NULL,
    [RenameFile]      VARCHAR (200)  NULL,
    [zipFile]         VARCHAR (200)  NULL,
    [Creator]         VARCHAR (10)   NULL,
    [CreateTime]      DATETIME       NULL,
    [Modifier]        VARCHAR (10)   NULL,
    [ModiTime]        DATETIME       NULL,
    CONSTRAINT [PK__D_WorkProcessDetail] PRIMARY KEY CLUSTERED ([ID] ASC)
);


GO

CREATE UNIQUE NONCLUSTERED INDEX [NonClusteredIndex-20240102-090137]
    ON [dbo].[D_WorkProcessDetail]([WPNo] ASC, [SNo] ASC);


GO

