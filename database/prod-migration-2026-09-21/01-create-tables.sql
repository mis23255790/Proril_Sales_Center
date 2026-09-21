-- COP_AvailableAmt / COP_ProductCheck：訂單資料檢核的寫入目標表
-- schema 取自 database/OrderCheckObjectsMigration.sql（50002 測試區已驗證過的版本）
-- 用途：51002 的 proril_sales_center 帳號沒有 PRORIL_WEB 的讀取權限，
--       無法直接跑 OrderCheckObjectsMigration.sql 裡的資料複製區塊（INSERT ... FROM PRORIL_WEB...），
--       所以拆成「這支只建表」+ bcp 匯出匯入資料兩段做。

IF OBJECT_ID('dbo.COP_AvailableAmt') IS NULL
BEGIN
    CREATE TABLE dbo.[COP_AvailableAmt] (
        [ID] int IDENTITY(1,1) NOT NULL,
        [CustNo] varchar(20) NULL,
        [OrderChkNo] varchar(20) NULL,
        [NotifyAmt] numeric(16,3) NULL,
        [OrderAmt] numeric(16,3) NULL,
        [OrderAmtRate] numeric(16,6) NULL,
        [ReceivableSumAmt] numeric(16,3) NULL,
        [ReceivableAmt] numeric(16,3) NULL,
        [GainAmt] numeric(16,3) NULL,
        [UnbilledAmt] numeric(16,3) NULL,
        [PreGainAmt] numeric(16,3) NULL,
        [AvailableAmt] numeric(16,3) NULL,
        [AvailableSetAmt] numeric(16,3) NULL,
        [Memo] nvarchar(500) NULL,
        [aStatus] varchar(1) NULL,
        [Creator] nvarchar(40) NULL,
        [CreateTime] datetime NULL,
        [Modifier] nvarchar(40) NULL,
        [ModiTime] datetime NULL
    );
    ALTER TABLE dbo.[COP_AvailableAmt] ADD CONSTRAINT [PK_COP_AvailableAmt] PRIMARY KEY CLUSTERED ([ID]);
END
GO

IF OBJECT_ID('dbo.COP_ProductCheck') IS NULL
BEGIN
    CREATE TABLE dbo.[COP_ProductCheck] (
        [ID] int IDENTITY(1,1) NOT NULL,
        [ChkNo] varchar(20) NULL,
        [ChkSource] varchar(20) NULL,
        [OrderChkNo] varchar(20) NULL DEFAULT (''),
        [ChkTime] datetime NULL,
        [ProductNo] nvarchar(40) NULL,
        [ProductName] nvarchar(120) NULL,
        [ProductName_EN] nvarchar(120) NULL,
        [ProductSpec] nvarchar(120) NULL,
        [ProductSpec_EN] nvarchar(120) NULL,
        [NoChk] nvarchar(10) NULL DEFAULT (''),
        [PHChk] nvarchar(10) NULL DEFAULT (''),
        [HZChk] nvarchar(10) NULL DEFAULT (''),
        [StartChk] nvarchar(10) NULL DEFAULT (''),
        [VolChk] nvarchar(10) NULL DEFAULT (''),
        [FloatChk] nvarchar(10) NULL DEFAULT (''),
        [WireSpecChk] nvarchar(10) NULL DEFAULT (''),
        [WireSizeChk] nvarchar(10) NULL DEFAULT (''),
        [PlusChk] nvarchar(10) NULL DEFAULT (''),
        [Ext1Chk] nvarchar(10) NULL DEFAULT (''),
        [Ext2Chk] nvarchar(10) NULL DEFAULT (''),
        [Ext3Chk] nvarchar(10) NULL DEFAULT (''),
        [FinChk] nvarchar(10) NULL DEFAULT (''),
        [Memo] nvarchar(500) NULL DEFAULT (''),
        [aStatus] varchar(1) NULL DEFAULT ('Y'),
        [Creator] nvarchar(40) NULL,
        [CreateTime] datetime NULL,
        [Modifier] nvarchar(40) NULL,
        [ModiTime] datetime NULL
    );
    ALTER TABLE dbo.[COP_ProductCheck] ADD CONSTRAINT [PK_COP_ProductCheck] PRIMARY KEY CLUSTERED ([ID]);
END
GO
