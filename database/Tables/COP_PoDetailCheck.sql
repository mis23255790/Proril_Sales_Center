CREATE TABLE [dbo].[COP_PoDetailCheck] (
    [ID]            INT            IDENTITY (1, 1) NOT NULL,
    [OrderChkNo]    VARCHAR (20)   NULL,
    [ChkTime]       DATETIME       NULL,
    [COP_Source]    NVARCHAR (20)  NULL,
    [PoNo]          NVARCHAR (20)  NULL,
    [SNo]           VARCHAR (4)    NULL,
    [ProductNo]     NVARCHAR (20)  NULL,
    [ProductNoChk]  NVARCHAR (20)  CONSTRAINT [DF_COP_PoDetailCheck_ProductNoChk] DEFAULT ('Y') NULL,
    [QtyChk]        NVARCHAR (20)  CONSTRAINT [DF_COP_PoDetailCheck_QtyChk] DEFAULT ('Y') NULL,
    [AmtChk]        NVARCHAR (20)  CONSTRAINT [DF_COP_PoDetailCheck_AmtChk] DEFAULT ('Y') NULL,
    [PriceChk]      NVARCHAR (20)  CONSTRAINT [DF_COP_PoDetailCheck_FinChk2] DEFAULT ('Y') NULL,
    [PackListChk]   NVARCHAR (20)  CONSTRAINT [DF_COP_PoDetailCheck_FinChk1] DEFAULT ('Y') NULL,
    [LinkTypeChk]   NVARCHAR (20)  CONSTRAINT [DF_COP_PoDetailCheck_PackListChk1] DEFAULT ('Y') NULL,
    [LinkNoChk]     NVARCHAR (20)  CONSTRAINT [DF_COP_PoDetailCheck_LinkTypeChk2] DEFAULT ('Y') NULL,
    [LinkSNoChk]    NVARCHAR (20)  CONSTRAINT [DF_COP_PoDetailCheck_LinkTypeChk1] DEFAULT ('Y') NULL,
    [LinkQtyChk]    NVARCHAR (20)  CONSTRAINT [DF_COP_PoDetailCheck_LinkSNoChk1] DEFAULT ('Y') NULL,
    [LinkPriceChk]  NVARCHAR (20)  CONSTRAINT [DF_COP_PoDetailCheck_LinkQtyChk1] DEFAULT ('Y') NULL,
    [LinkChk]       NVARCHAR (20)  CONSTRAINT [DF_COP_PoDetailCheck_LinkPriceChk1] DEFAULT ('Y') NULL,
    [MOQAmtChk]     NVARCHAR (20)  CONSTRAINT [DF_COP_PoDetailCheck_LinkChk1] DEFAULT ('Y') NULL,
    [LinkMOQAmtChk] NVARCHAR (20)  CONSTRAINT [DF_COP_PoDetailCheck_MOQAmtChk1] DEFAULT ('Y') NULL,
    [FinChk]        NVARCHAR (20)  CONSTRAINT [DF_COP_PoDetailCheck_FinChk] DEFAULT ('Y') NULL,
    [Memo]          NVARCHAR (500) NULL,
    [aStatus]       VARCHAR (1)    NULL,
    [Creator]       NVARCHAR (40)  NULL,
    [CreateTime]    DATETIME       NULL,
    [Modifier]      NVARCHAR (40)  NULL,
    [ModiTime]      DATETIME       NULL,
    CONSTRAINT [PK_COP_PoDetailCheck] PRIMARY KEY CLUSTERED ([ID] ASC)
);


GO

