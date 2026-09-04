CREATE TABLE [dbo].[M_WorkProcessType] (
    [ID]         INT           IDENTITY (1, 1) NOT NULL,
    [TypeCode]   VARCHAR (10)  NOT NULL,
    [TypeName]   VARCHAR (40)  NOT NULL,
    [Descript]   VARCHAR (MAX) NULL,
    [aStatus]    VARCHAR (1)   NULL,
    [Creator]    VARCHAR (10)  NULL,
    [CreateTime] DATETIME      NULL,
    PRIMARY KEY CLUSTERED ([ID] ASC)
);


GO

