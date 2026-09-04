CREATE TABLE [dbo].[D_WorkProcessCustomer] (
    [ID]           INT          IDENTITY (1, 1) NOT NULL,
    [WPNo]         VARCHAR (10) NOT NULL,
    [CustomerNo]   VARCHAR (10) NULL,
    [CustomerType] VARCHAR (10) NULL,
    [aStatus]      VARCHAR (1)  NULL,
    [Creator]      VARCHAR (10) NULL,
    [CreateTime]   DATETIME     NULL,
    [Modifier]     VARCHAR (10) NULL,
    [ModiTime]     DATETIME     NULL,
    CONSTRAINT [PK_D_WorkProcessCustomer] PRIMARY KEY CLUSTERED ([ID] ASC)
);


GO

