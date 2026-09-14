CREATE TABLE [dbo].[M_System] (
    [ID]           INT           IDENTITY (1, 1) NOT NULL,
    [SystemNo]     INT           NOT NULL,
    [SystemName]   NVARCHAR (20) NOT NULL,
    [SystemType]   INT           NOT NULL,
    [TypeName]     NVARCHAR (20) NULL,
    [Sort]         INT           NOT NULL,
    [ImagePath]    VARCHAR (50)  NULL,
    [Href]         NVARCHAR (50) DEFAULT ('') NOT NULL,
    [RedirectHref] NVARCHAR (50) NULL,
    CONSTRAINT [PK__M_System__3214EC279302271C] PRIMARY KEY CLUSTERED ([ID] ASC)
);


GO

