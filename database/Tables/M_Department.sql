CREATE TABLE [dbo].[M_Department] (
    [ID]           INT            IDENTITY (1, 1) NOT NULL,
    [DepCode]      VARCHAR (10)   NOT NULL,
    [DepName]      VARCHAR (40)   NOT NULL,
    [DepLeader]    VARCHAR (10)   NULL,
    [Directions]   VARCHAR (MAX)  NULL,
    [DepLevel]     INT            NULL,
    [ParentsDep]   VARCHAR (10)   NULL,
    [OrgChartFlag] BIT            DEFAULT ((1)) NULL,
    [Horqueue]     INT            NULL,
    [IsEnable]     BIT            DEFAULT ((1)) NOT NULL,
    [DepGroup]     INT            NOT NULL,
    CONSTRAINT [PK__M_Depart__3214EC2799095914] PRIMARY KEY CLUSTERED ([ID] ASC)
);


GO

