CREATE TABLE [dbo].[CRM_Customer] (
    [ID]              INT            IDENTITY (1, 1) NOT NULL,
    [CustomerNo]      VARCHAR (20)   NULL,
    [CustomerSource]  VARCHAR (20)   CONSTRAINT [DF_CRM_Customer_CustomerSource] DEFAULT ('') NULL,
    [ERPCustomerNo]   VARCHAR (20)   CONSTRAINT [DF_CRM_Customer_ERPCustomerNo] DEFAULT ('') NULL,
    [LongName]        NVARCHAR (200) NULL,
    [ShortName]       NVARCHAR (40)  NULL,
    [ContactName]     NVARCHAR (60)  CONSTRAINT [DF_CRM_Customer_ContactName] DEFAULT ('') NULL,
    [ContactTEL1]     NVARCHAR (40)  CONSTRAINT [DF_CRM_Customer_ContactTEL1] DEFAULT ('') NULL,
    [ContactTEL2]     NVARCHAR (40)  CONSTRAINT [DF_CRM_Customer_ContactTEL2] DEFAULT ('') NULL,
    [ContactFAX]      NVARCHAR (40)  CONSTRAINT [DF_CRM_Customer_ContactFAX] DEFAULT ('') NULL,
    [ContactEMail]    NVARCHAR (100) CONSTRAINT [DF_CRM_Customer_ContactEMail] DEFAULT ('') NULL,
    [Addr1]           NVARCHAR (100) CONSTRAINT [DF_CRM_Customer_ContactEMail2] DEFAULT ('') NULL,
    [Addr2]           NVARCHAR (100) CONSTRAINT [DF_CRM_Customer_ContactEMail1] DEFAULT ('') NULL,
    [AreaCode]        VARCHAR (10)   CONSTRAINT [DF_CRM_Customer_AreaCode] DEFAULT ('') NULL,
    [CountryCode]     VARCHAR (10)   CONSTRAINT [DF_CRM_Customer_CountryCode] DEFAULT ('') NULL,
    [SalesNo]         VARCHAR (20)   CONSTRAINT [DF_CRM_Customer_SalesNo] DEFAULT ('') NULL,
    [SalesName]       NVARCHAR (40)  CONSTRAINT [DF_CRM_Customer_SalesName] DEFAULT ('') NULL,
    [PotentialCustom] VARCHAR (1)    CONSTRAINT [DF_CRM_Customer_potentialCustom] DEFAULT ('N') NULL,
    [ERPHeadCustomer] VARCHAR (20)   CONSTRAINT [DF_CRM_Customer_ERPHeadCustomer] DEFAULT ('') NULL,
    [ERPSource]       NVARCHAR (20)  CONSTRAINT [DF_CRM_Customer_ERP_Source] DEFAULT ('') NULL,
    [Memo]            NVARCHAR (500) CONSTRAINT [DF_CRM_Customer_Memo] DEFAULT ('') NULL,
    [aStatus]         VARCHAR (1)    CONSTRAINT [DF_CRM_Customer_aStatus] DEFAULT ('Y') NULL,
    [Creator]         VARCHAR (40)   NULL,
    [CreateTime]      DATETIME       NULL,
    [Modifier]        VARCHAR (40)   NULL,
    [ModiTime]        DATETIME       NULL,
    CONSTRAINT [PK_CRM_Customer] PRIMARY KEY CLUSTERED ([ID] ASC)
);


GO

