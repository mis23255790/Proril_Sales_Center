CREATE TABLE [dbo].[M_Function] (
    [ID]           INT           IDENTITY (1, 1) NOT NULL,
    [FunctionNo]   INT           NOT NULL,
    [FunctionName] VARCHAR (20)  NULL,
    [SystemNo]     INT           NOT NULL,
    [GroupNo]      INT           NULL,
    [GroupName]    VARCHAR (20)  NULL,
    [ImagrePath]   VARCHAR (50)  NULL,
    [Href]         NVARCHAR (50) NULL,
    [aStatus]      VARCHAR (1)   DEFAULT ('Y') NULL,
    [RedirectHref] NVARCHAR (50) NULL,
    CONSTRAINT [PK__M_Functi__3214EC2746E5CF47] PRIMARY KEY CLUSTERED ([ID] ASC)
);


GO

