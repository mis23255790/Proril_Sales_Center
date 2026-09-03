/*
 * 訂單資料檢核（OrderInfoVerifyApi）相關的 View / 預存程序 / 函式 / 表，
 * 從 PRORIL_WEB 搬到 Proril_Sales_Center。
 *
 * 背景：Proril_Sales_Center 已經有 M_User/M_Permission/H_FileLink/COP_CheckRule/
 * COP_DepData 以及業務議題 8 張表（見 PortingNotes.md）。這支腳本補上訂單資料檢核
 * 剩下的部分，讓這個模組可以完全脫離 PRORIL_WEB 運作。
 *
 * 完整依賴關係是逐一追蹤 sys.sql_expression_dependencies 遞迴查出來的，經過兩輪確認
 * 沒有遺漏：
 *   - 7 個 View：全部透過四段式命名 [192.168.1.200].{DB}.dbo.{table} 查詢 ERP linked
 *     server（鼎新 ERP，PRORIL/TWPR/DSCSYS 三個資料庫），沒有寫死本地資料庫名稱。
 *     Linked server 是 SQL Server instance 層級設定，同一台主機、不同資料庫都能用，
 *     已在 Proril_Sales_Center 下實測 `SELECT TOP 1 * FROM PRORIL_WEB.dbo.CRM_Customer`
 *     可行，確認遷移後這些 View 查得到即時 ERP 資料，不是凍結快照。
 *   - 5 個預存程序：讀寫的表全部是 unqualified 本地表名（COP_PoCheck 等），
 *     沒有寫死 PRORIL_WEB，搬過來後會自動讀寫 Proril_Sales_Center 自己的表。
 *   - 1 個純運算函式，無外部依賴。
 *   - 5 張表：COP_PoCheck/COP_PoDetailCheck/COP_PassCheck（prc_COPOrderChk/
 *     prc_COPPassCheck 的寫入目標）+ COP_AvailableAmt/COP_ProductCheck
 *     （prc_COPGetCredit/prc_ProductChk_COP 的寫入目標，執行檢核時的副產物紀錄表）。
 *
 * 特別注意：
 *   1. `V_Product_English_All` 這個 View 的儲存文字裡，CREATE VIEW 開頭寫的是
 *      舊名字 [V_Produce_English_All]（sp_rename 只改 sys.objects.name，
 *      不會更新已儲存的定義文字，這是 SQL Server 的已知行為）。這支腳本已經
 *      手動修正成正確名稱 V_Product_English_All，不是謄寫錯誤。
 *   2. 這 5 張表的欄位型別是直接查 PRORIL_WEB 目前的 sys.columns 得出的，
 *      跟本次搬移之前 api/Data/OrderInfoVerifyEntities.cs 依照 1.0 EF Core scaffold
 *      模型寫的型別有出入（那份 scaffold 對這幾個 Chk 欄位標示是 varchar(20)，
 *      但實際 DB 現在是 nvarchar(40)——1.0 的 EF 模型顯然沒有跟著 DB 異動更新過）。
 *      這支腳本以「查詢當下的真實 DB schema」為準；api/ 那邊的 EF 對映之後需要
 *      跟著訂正，這支腳本本身不影響 EF 查詢語意（EF 只用來讀，不靠這幾個屬性寫入）。
 *   3. 這 5 張表沒有中文編碼風險——PRORIL_WEB 現況裡這些欄位本來就是 nvarchar，
 *      不像業務議題那批舊表還留著 varchar 存中文，不需要額外覆寫型別。
 *   4. 所有 CREATE VIEW/PROCEDURE/FUNCTION 都用 CREATE OR ALTER，可重複執行；
 *      CREATE TABLE 用 IF OBJECT_ID(...) IS NULL 防呆，重跑不會報錯也不會清空既有資料。
 *   5. 資料複製區塊（表結構之後那段 INSERT）在表已經有資料時會自動跳過，
 *      避免重跑腳本造成資料重複。
 *
 * 執行前建議：
 *   - 確認連到的是 Proril_Sales_Center（192.168.1.142,50002），不是 PRORIL_WEB。
 *   - prc_COPOrderChk / prc_ProductChk_COP 內容很長（各 700+ 行），業務邏輯完整、
 *     未經改寫，執行前建議自己再核對一次跟來源是否一致
 *     （來源可查 SELECT OBJECT_DEFINITION(OBJECT_ID('PRORIL_WEB.dbo.prc_COPOrderChk'))）。
 */

USE Proril_Sales_Center;
GO

-- ============================================================
-- 1. 資料表（結構）
-- ============================================================

IF OBJECT_ID('dbo.COP_PoCheck') IS NULL
BEGIN
    CREATE TABLE dbo.[COP_PoCheck] (
        [ID] int IDENTITY(1,1) NOT NULL,
        [OrderChkNo] varchar(20) NULL,
        [ChkTime] datetime NULL,
        [COP_Source] nvarchar(20) NULL,
        [PoNo] nvarchar(20) NULL,
        [SumAmt] numeric(16,3) NULL,
        [SumQty] numeric(16,3) NULL,
        [CustAmt] numeric(16,3) NULL,
        [AvailableAmt] numeric(16,3) NULL,
        [DepChk] nvarchar(20) NULL DEFAULT ('Y'),
        [DepBlankChk] nvarchar(20) NULL DEFAULT ('Y'),
        [PackListBlankChk] nvarchar(20) NULL DEFAULT ('Y'),
        [PriceBlankChk] nvarchar(20) NULL DEFAULT ('Y'),
        [PreDateChk] nvarchar(20) NULL DEFAULT ('Y'),
        [CustSumAmtChk] nvarchar(20) NULL DEFAULT ('Y'),
        [CustAmtZeroChk] nvarchar(20) NULL DEFAULT ('Y'),
        [CustPOChk] nvarchar(20) NULL DEFAULT ('Y'),
        [TransChk] nvarchar(20) NULL DEFAULT ('Y'),
        [TradeChk] nvarchar(20) NULL DEFAULT ('Y'),
        [OutPortChk] nvarchar(20) NULL DEFAULT ('Y'),
        [InPortChk] nvarchar(20) NULL DEFAULT ('Y'),
        [UpFileChk] nvarchar(20) NULL DEFAULT ('Y'),
        [DetailChk] nvarchar(20) NULL DEFAULT ('Y'),
        [RateChk] nvarchar(20) NULL DEFAULT ('Y'),
        [PaidChk] nvarchar(20) NULL DEFAULT ('Y'),
        [AvailableChk] nvarchar(20) NULL DEFAULT ('Y'),
        [Credit30WChk] nvarchar(20) NULL DEFAULT ('Y'),
        [ProcessCodeChk] nvarchar(20) NULL DEFAULT ('Y'),
        [FinChk] nvarchar(20) NULL DEFAULT ('Y'),
        [Memo] nvarchar(500) NULL,
        [aStatus] varchar(1) NULL,
        [Creator] nvarchar(40) NULL,
        [CreateTime] datetime NULL,
        [Modifier] nvarchar(40) NULL,
        [ModiTime] datetime NULL
    );
    ALTER TABLE dbo.[COP_PoCheck] ADD CONSTRAINT [PK_COP_PoCheck] PRIMARY KEY CLUSTERED ([ID]);
END
GO

IF OBJECT_ID('dbo.COP_PoDetailCheck') IS NULL
BEGIN
    CREATE TABLE dbo.[COP_PoDetailCheck] (
        [ID] int IDENTITY(1,1) NOT NULL,
        [OrderChkNo] varchar(20) NULL,
        [ChkTime] datetime NULL,
        [COP_Source] nvarchar(20) NULL,
        [PoNo] nvarchar(20) NULL,
        [SNo] varchar(4) NULL,
        [ProductNo] nvarchar(20) NULL,
        [ProductNoChk] nvarchar(20) NULL DEFAULT ('Y'),
        [QtyChk] nvarchar(20) NULL DEFAULT ('Y'),
        [AmtChk] nvarchar(20) NULL DEFAULT ('Y'),
        [PriceChk] nvarchar(20) NULL DEFAULT ('Y'),
        [PackListChk] nvarchar(20) NULL DEFAULT ('Y'),
        [LinkTypeChk] nvarchar(20) NULL DEFAULT ('Y'),
        [LinkNoChk] nvarchar(20) NULL DEFAULT ('Y'),
        [LinkSNoChk] nvarchar(20) NULL DEFAULT ('Y'),
        [LinkQtyChk] nvarchar(20) NULL DEFAULT ('Y'),
        [LinkPriceChk] nvarchar(20) NULL DEFAULT ('Y'),
        [LinkChk] nvarchar(20) NULL DEFAULT ('Y'),
        [MOQAmtChk] nvarchar(20) NULL DEFAULT ('Y'),
        [LinkMOQAmtChk] nvarchar(20) NULL DEFAULT ('Y'),
        [FinChk] nvarchar(20) NULL DEFAULT ('Y'),
        [Memo] nvarchar(500) NULL,
        [aStatus] varchar(1) NULL,
        [Creator] nvarchar(40) NULL,
        [CreateTime] datetime NULL,
        [Modifier] nvarchar(40) NULL,
        [ModiTime] datetime NULL
    );
    ALTER TABLE dbo.[COP_PoDetailCheck] ADD CONSTRAINT [PK_COP_PoDetailCheck] PRIMARY KEY CLUSTERED ([ID]);
END
GO

IF OBJECT_ID('dbo.COP_PassCheck') IS NULL
BEGIN
    CREATE TABLE dbo.[COP_PassCheck] (
        [ID] int IDENTITY(1,1) NOT NULL,
        [OrderChkNo] varchar(20) NULL,
        [Sno] varchar(4) NULL,
        [PassTime] datetime NULL,
        [PassItems] varchar(40) NULL,
        [PassMemo] nvarchar(500) NULL,
        [Memo] nvarchar(500) NULL,
        [aStatus] varchar(1) NULL,
        [Creator] nvarchar(40) NULL,
        [CreateTime] datetime NULL,
        [Modifier] nvarchar(40) NULL,
        [ModiTime] datetime NULL
    );
    ALTER TABLE dbo.[COP_PassCheck] ADD CONSTRAINT [PK_COP_PassCheck] PRIMARY KEY CLUSTERED ([ID]);
END
GO

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

-- ============================================================
-- 2. 資料複製（一次性快照，比照 PortingNotes.md 記錄的其他表）
--    已有資料就跳過，避免重跑腳本造成重複。
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM dbo.COP_PoCheck)
BEGIN
    SET IDENTITY_INSERT dbo.[COP_PoCheck] ON;
    INSERT INTO dbo.[COP_PoCheck] (
        [ID],[OrderChkNo],[ChkTime],[COP_Source],[PoNo],[SumAmt],[SumQty],[CustAmt],[AvailableAmt],
        [DepChk],[DepBlankChk],[PackListBlankChk],[PriceBlankChk],[PreDateChk],
        [CustSumAmtChk],[CustAmtZeroChk],[CustPOChk],[TransChk],[TradeChk],
        [OutPortChk],[InPortChk],[UpFileChk],[DetailChk],[RateChk],
        [PaidChk],[AvailableChk],[Credit30WChk],[ProcessCodeChk],[FinChk],
        [Memo],[aStatus],[Creator],[CreateTime],[Modifier],[ModiTime])
    SELECT
        [ID],[OrderChkNo],[ChkTime],[COP_Source],[PoNo],[SumAmt],[SumQty],[CustAmt],[AvailableAmt],
        [DepChk],[DepBlankChk],[PackListBlankChk],[PriceBlankChk],[PreDateChk],
        [CustSumAmtChk],[CustAmtZeroChk],[CustPOChk],[TransChk],[TradeChk],
        [OutPortChk],[InPortChk],[UpFileChk],[DetailChk],[RateChk],
        [PaidChk],[AvailableChk],[Credit30WChk],[ProcessCodeChk],[FinChk],
        [Memo],[aStatus],[Creator],[CreateTime],[Modifier],[ModiTime]
    FROM PRORIL_WEB.dbo.[COP_PoCheck];
    SET IDENTITY_INSERT dbo.[COP_PoCheck] OFF;
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.COP_PoDetailCheck)
BEGIN
    SET IDENTITY_INSERT dbo.[COP_PoDetailCheck] ON;
    INSERT INTO dbo.[COP_PoDetailCheck] (
        [ID],[OrderChkNo],[ChkTime],[COP_Source],[PoNo],[SNo],[ProductNo],
        [ProductNoChk],[QtyChk],[AmtChk],[PriceChk],[PackListChk],
        [LinkTypeChk],[LinkNoChk],[LinkSNoChk],[LinkQtyChk],[LinkPriceChk],
        [LinkChk],[MOQAmtChk],[LinkMOQAmtChk],[FinChk],
        [Memo],[aStatus],[Creator],[CreateTime],[Modifier],[ModiTime])
    SELECT
        [ID],[OrderChkNo],[ChkTime],[COP_Source],[PoNo],[SNo],[ProductNo],
        [ProductNoChk],[QtyChk],[AmtChk],[PriceChk],[PackListChk],
        [LinkTypeChk],[LinkNoChk],[LinkSNoChk],[LinkQtyChk],[LinkPriceChk],
        [LinkChk],[MOQAmtChk],[LinkMOQAmtChk],[FinChk],
        [Memo],[aStatus],[Creator],[CreateTime],[Modifier],[ModiTime]
    FROM PRORIL_WEB.dbo.[COP_PoDetailCheck];
    SET IDENTITY_INSERT dbo.[COP_PoDetailCheck] OFF;
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.COP_PassCheck)
BEGIN
    SET IDENTITY_INSERT dbo.[COP_PassCheck] ON;
    INSERT INTO dbo.[COP_PassCheck] (
        [ID],[OrderChkNo],[Sno],[PassTime],[PassItems],[PassMemo],
        [Memo],[aStatus],[Creator],[CreateTime],[Modifier],[ModiTime])
    SELECT
        [ID],[OrderChkNo],[Sno],[PassTime],[PassItems],[PassMemo],
        [Memo],[aStatus],[Creator],[CreateTime],[Modifier],[ModiTime]
    FROM PRORIL_WEB.dbo.[COP_PassCheck];
    SET IDENTITY_INSERT dbo.[COP_PassCheck] OFF;
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.COP_AvailableAmt)
BEGIN
    SET IDENTITY_INSERT dbo.[COP_AvailableAmt] ON;
    INSERT INTO dbo.[COP_AvailableAmt] (
        [ID],[CustNo],[OrderChkNo],[NotifyAmt],[OrderAmt],[OrderAmtRate],
        [ReceivableSumAmt],[ReceivableAmt],[GainAmt],[UnbilledAmt],[PreGainAmt],
        [AvailableAmt],[AvailableSetAmt],[Memo],[aStatus],[Creator],[CreateTime],[Modifier],[ModiTime])
    SELECT
        [ID],[CustNo],[OrderChkNo],[NotifyAmt],[OrderAmt],[OrderAmtRate],
        [ReceivableSumAmt],[ReceivableAmt],[GainAmt],[UnbilledAmt],[PreGainAmt],
        [AvailableAmt],[AvailableSetAmt],[Memo],[aStatus],[Creator],[CreateTime],[Modifier],[ModiTime]
    FROM PRORIL_WEB.dbo.[COP_AvailableAmt];
    SET IDENTITY_INSERT dbo.[COP_AvailableAmt] OFF;
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.COP_ProductCheck)
BEGIN
    SET IDENTITY_INSERT dbo.[COP_ProductCheck] ON;
    INSERT INTO dbo.[COP_ProductCheck] (
        [ID],[ChkNo],[ChkSource],[OrderChkNo],[ChkTime],[ProductNo],[ProductName],
        [ProductName_EN],[ProductSpec],[ProductSpec_EN],[NoChk],[PHChk],
        [HZChk],[StartChk],[VolChk],[FloatChk],[WireSpecChk],
        [WireSizeChk],[PlusChk],[Ext1Chk],[Ext2Chk],[Ext3Chk],[FinChk],
        [Memo],[aStatus],[Creator],[CreateTime],[Modifier],[ModiTime])
    SELECT
        [ID],[ChkNo],[ChkSource],[OrderChkNo],[ChkTime],[ProductNo],[ProductName],
        [ProductName_EN],[ProductSpec],[ProductSpec_EN],[NoChk],[PHChk],
        [HZChk],[StartChk],[VolChk],[FloatChk],[WireSpecChk],
        [WireSizeChk],[PlusChk],[Ext1Chk],[Ext2Chk],[Ext3Chk],[FinChk],
        [Memo],[aStatus],[Creator],[CreateTime],[Modifier],[ModiTime]
    FROM PRORIL_WEB.dbo.[COP_ProductCheck];
    SET IDENTITY_INSERT dbo.[COP_ProductCheck] OFF;
END
GO

-- ============================================================
-- 3. 函式
-- ============================================================

CREATE OR ALTER FUNCTION [dbo].[fu_RemoveParentheses]
(
    @InputString NVARCHAR(MAX) -- 輸入的字串
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    WHILE CHARINDEX('(', @InputString) > 0 AND CHARINDEX(')', @InputString) > CHARINDEX('(', @InputString)
    BEGIN
        SET @InputString = STUFF(
            @InputString,
            CHARINDEX('(', @InputString),
            CHARINDEX(')', @InputString) - CHARINDEX('(', @InputString) + 1,
            ''
        );
    END;

    RETURN @InputString;
END;
GO

-- ============================================================
-- 4. View（7 個，全部改用 CREATE OR ALTER，可重複執行）
-- ============================================================

-- 20250602 Mars
-- 客戶訂單檢核作業,查詢客戶分量計價使用
CREATE OR ALTER   VIEW [dbo].[V_COPMOQ]
AS

select top 100000 '芳晟' ERPSource,rtrim(MB.MB001) CustomerNo,rtrim(MB.MB002) ProductNo,rtrim(MB1.MB002) ProductName,MB.MB003 Unit,
       MB.MB009 CheckDate,MB.MB004 Currency,MB.MB017 StartDate,MB.MB018 EndDate,MC.MC009 StartDate_D,MB.MB007 ByQtyFlag,
	   ISNULL(MC.MC004,'') ByQtyCurrency,ISNULL(MC.MC005,0) Qty,ISNULL(MC.MC006,0) ByQtyPrice
from [192.168.1.200].PRORIL.dbo.COPMB MB
LEFT JOIN [192.168.1.200].PRORIL.dbo.COPMC MC ON MC.MC001 = MB.MB001 AND MC.MC002 = MB.MB002
      AND ((MB017 <= MC.MC009 OR (MB017=''))) AND ((MC.MC009 <= MB018) OR (MB018=''))
LEFT JOIN [192.168.1.200].PRORIL.dbo.INVMB MB1 ON MB.MB002 = MB1.MB001
WHERE 1=1
AND MB.MB007 = 'Y'
and MC.MC009 is not null
AND ((MB.MB017 <= CONVERT(VARCHAR(8),GETDATE(),112) OR (MB.MB017=''))) AND ((CONVERT(VARCHAR(8),GETDATE(),112) <= MB.MB018) OR (MB.MB018=''))
AND MB.MB001 > '8' AND MB.MB001 < '89'

UNION

select top 100000 '浦瑞' ERPSource,rtrim(MB.MB001) CustomerNo,rtrim(MB.MB002) ProductNo,rtrim(MB1.MB002) ProductName,MB.MB003 Unit,
       MB.MB009 CheckDate,MB.MB004 Currency,MB.MB017 StartDate,MB.MB018 EndDate,MC.MC009 StartDate_D,MB.MB007 ByQtyFlag,
	   ISNULL(MC.MC004,'') ByQtyCurrency,ISNULL(MC.MC005,0) Qty,ISNULL(MC.MC006,0) ByQtyPrice
from [192.168.1.200].TWPR.dbo.COPMB MB
LEFT JOIN [192.168.1.200].TWPR.dbo.COPMC MC ON MC.MC001 = MB.MB001 AND MC.MC002 = MB.MB002
      AND ((MB017 <= MC.MC009 OR (MB017=''))) AND ((MC.MC009 <= MB018) OR (MB018=''))
LEFT JOIN [192.168.1.200].PRORIL.dbo.INVMB MB1 ON MB.MB002 = MB1.MB001
WHERE 1=1
AND MB.MB007 = 'Y'
and MC.MC009 is not null
AND ((MB.MB017 <= CONVERT(VARCHAR(8),GETDATE(),112) OR (MB.MB017=''))) AND ((CONVERT(VARCHAR(8),GETDATE(),112) <= MB.MB018) OR (MB.MB018=''))
AND MB.MB001 > '1' AND MB.MB001 < 'A'
GO

-- 靜態對照表，浮球/插頭等中英文對照不檢核清單，無資料表依賴
CREATE OR ALTER     VIEW [dbo].[V_COPNoChk]
AS

select 'CAP-RUN' as C01,'Capacitor-Run' as E01
union
select 'CE浮球' as C01,'CE Float switch' as E01
union
select 'CE浮球' as C01,'CE  Float switc' as E01
union
select 'CE浮球-FOX G09' as C01,'CE Float switch' as E01
union
select '浮球-FOX G09' as C01,'Float switch FOX G09' as E01
union
select 'UL浮球' as C01,'UL Float switch' as E01
union
select 'AC藍立浮球' as C01,'AC Float switch' as E01
union
select 'D.O.L.' as C01,'D.O.L' as E01
union
select 'D.O.L' as C01,'D.O.L.' as E01
union
select 'MOUSE A 浮球' as C01,'MOUSE A Float switch' as E01
union
select '無電纜線' as C01,'Without Cable.' as E01
union
select '美插(NEMA-5-15P)' as C01,'NEMA-5-15P Plug' as E01
union
select '橫插(NEMA-6-15P)' as C01,'NEMA-6-15P Plug' as E01
union
select '無插' as C01,'No Plug' as E01
union
select '以插' as C01,'Israel Plug' as E01
union
select '澳插' as C01,'Australia Plug' as E01
union
select '直歐(CEE7-VII)' as C01,'CEE7-VII Plug' as E01
union
select '鎖附式南非插' as C01,'South Africa Plug' as E01
union
select 'UK射出插頭' as C01,'UK Plug' as E01
union
select 'UK工業插(FPPPLUG110)' as C01,'UK Industrial Plug' as E01
union
select '英插(TYPE G)' as C01,'UK Plug' as E01
union
select '丹麥插(TYPE K)' as C01,'TYPE K Plug' as E01
GO

-- 20250327 Mars
-- CRM系統使用的客戶資料
CREATE OR ALTER   VIEW [dbo].[V_ERPCustomer]
AS

select '浦瑞ERP' ERPSource,
rtrim(MA001) MA001,rtrim(MA002) MA002,rtrim(MA003) MA003,MA004,MA005,
MA006,MA007,MA008,MA009,MA010,
MA016,MA017,MA018,MA019,MA020,
MA021,MA022,MA023,MA024,MA025,
MA026,MA027,MA065 ERPHeadCustomer,MA066,MA082
from [192.168.1.200].TWPR.dbo.COPMA MA
WHERE 1=1
and  MA001 NOT LIKE '8%' OR MA001 = 'TWPR'
union
select '芳晟ERP' ERPSource,
rtrim(MA001) MA001,rtrim(MA002) MA002,rtrim(MA003) MA003,MA004,MA005,
MA006,MA007,MA008,MA009,MA010,
MA016,MA017,MA018,MA019,MA020,
MA021,MA022,MA023,MA024,MA025,
MA026,MA027,MA065,MA066,MA082
from [192.168.1.200].PRORIL.dbo.COPMA MA
WHERE 1=1
AND MA001 > '8'
AND MA001 < '89'
GO

-- 20250120 建立
-- 訂單檢核查詢使用
CREATE OR ALTER     VIEW [dbo].[V_POList]
AS
-- 國內訂單 未確認
select DISTINCT '芳晟ERP' COP_Source,MQ.MQ002 單別名稱,TC001 單別,TC002 單號,TC003 訂單日期,TC013 價格條件,'' 預交日,
TC004 客戶代號,ISNULL(MA.MA002,'') 客戶名稱,isnull(TC005,'') 部門代號,TC006 業務人員,ISNULL(MV.MV002,'') 業務名稱,TC010 送貨地址一,
TC011 送貨地址二,TC014 付款條件,TC016 課稅別,TC019 運輸方式,TC008 幣別,TC009 匯率,TC029 訂單金額,TC031 總數量,TC038 PACKINGLIST備註,
TC012 客戶單號,TC068 交易條件,ISNULL(NK.NK002,'') 交易條件名稱,TC020 起始港口,TC021 目的港口,TC018 連絡人,TC066 TEL_NO,TC067 FAX_NO,
'' 附件檔案,case when TC014 like '%T/T%' or TC014 like '%TT%' then 'Y' else 'N' end 付款檢核,TC.TC049 流程代號,
TD.TD016 FinFlag, 'N' ConfirmFlag
 FROM [192.168.1.200].PRORIL.dbo.COPTC TC
INNER JOIN [192.168.1.200].PRORIL.dbo.COPTD TD ON TC.TC001 = TD.TD001 and TC.TC002 = TD.TD002
INNER JOIN [192.168.1.200].PRORIL.dbo.CMSMQ MQ ON MQ.MQ001 = TC.TC001
LEFT JOIN [192.168.1.200].PRORIL.dbo.COPMA MA ON MA.MA001 = TC.TC004
LEFT JOIN [192.168.1.200].PRORIL.dbo.CMSMV MV ON MV.MV001 = TC.TC006
LEFT JOIN [192.168.1.200].PRORIL.dbo.CMSNK NK ON NK.NK001 = TC.TC068
WHERE 1=1
and TC.TC027 = 'N' and TD.TD021 = 'N'
and TD.TD016 <> 'y'

UNION
-- 國內訂單 已確認
select DISTINCT '芳晟ERP' COP_Source,MQ.MQ002 單別名稱,TC001 單別,TC002 單號,TC003 訂單日期,TC013 價格條件,'' 預交日,
TC004 客戶代號,ISNULL(MA.MA002,'') 客戶名稱,isnull(TC005,'') 部門代號,TC006 業務人員,ISNULL(MV.MV002,'') 業務名稱,TC010 送貨地址一,
TC011 送貨地址二,TC014 付款條件,TC016 課稅別,TC019 運輸方式,TC008 幣別,TC009 匯率,TC029 訂單金額,TC031 總數量,TC038 PACKINGLIST備註,
TC012 客戶單號,TC068 交易條件,ISNULL(NK.NK002,'') 交易條件名稱,TC020 起始港口,TC021 目的港口,TC018 連絡人,TC066 TEL_NO,TC067 FAX_NO,
'' 附件檔案,case when TC014 like '%T/T%' or TC014 like '%TT%' then 'Y' else 'N' end 付款檢核,TC.TC049 流程代號,
TD.TD016 FinFlag, 'Y' ConfirmFlag
 FROM [192.168.1.200].PRORIL.dbo.COPTC TC
INNER JOIN [192.168.1.200].PRORIL.dbo.COPTD TD ON TC.TC001 = TD.TD001 and TC.TC002 = TD.TD002
INNER JOIN [192.168.1.200].PRORIL.dbo.CMSMQ MQ ON MQ.MQ001 = TC.TC001
LEFT JOIN [192.168.1.200].PRORIL.dbo.COPMA MA ON MA.MA001 = TC.TC004
LEFT JOIN [192.168.1.200].PRORIL.dbo.CMSMV MV ON MV.MV001 = TC.TC006
LEFT JOIN [192.168.1.200].PRORIL.dbo.CMSNK NK ON NK.NK001 = TC.TC068
WHERE 1=1
and TC.TC027 = 'Y' and TD.TD021 = 'Y'
and TD.TD016 <> 'y'

UNION

-- 國外訂單 未確認
select DISTINCT '浦瑞ERP' COP_Source,MQ.MQ002 ,TC001 ,TC002 ,TC003 ,TC013,'',
TC004 ,ISNULL(MA.MA002,'') MA002,isnull(TC005,'') TC005 ,TC006 ,
ISNULL(MV.MV002,'') MV002,TC010 ,TC011 ,TC014 ,TC016 ,TC019 ,TC008 ,TC009 ,TC029 ,TC031 ,TC038 ,
TC012 ,TC068 ,ISNULL(NK.NK002,'') NK002, TC020 ,TC021,TC018,TC066,TC067,'',case when TC014 like '%T/T%' or TC014 like '%TT%' then 'Y' else 'N' end 付款檢核,
TC.TC049 流程代號,
TD.TD016,  'Y' ConfirmFlag
 FROM [192.168.1.200].TWPR.dbo.COPTC TC
INNER JOIN [192.168.1.200].TWPR.dbo.COPTD TD ON TC.TC001 = TD.TD001 and TC.TC002 = TD.TD002
INNER JOIN [192.168.1.200].TWPR.dbo.CMSMQ MQ ON MQ.MQ001 = TC.TC001
LEFT JOIN [192.168.1.200].TWPR.dbo.COPMA MA ON MA.MA001 = TC.TC004
LEFT JOIN [192.168.1.200].PRORIL.dbo.CMSMV MV ON MV.MV001 = TC.TC006
LEFT JOIN [192.168.1.200].PRORIL.dbo.CMSNK NK ON NK.NK001 = TC.TC068
WHERE 1=1
and TC.TC027 = 'N' and TD.TD021 = 'N'
and TD.TD016 <> 'y'

UNION

-- 國外訂單 已確認
select DISTINCT '浦瑞ERP' COP_Source,MQ.MQ002 ,TC001 ,TC002 ,TC003 ,TC013,'',
TC004 ,ISNULL(MA.MA002,'') MA002,isnull(TC005,'') TC005 ,TC006 ,
ISNULL(MV.MV002,'') MV002,TC010 ,TC011 ,TC014 ,TC016 ,TC019 ,TC008 ,TC009 ,TC029 ,TC031 ,TC038 ,
TC012 ,TC068 ,ISNULL(NK.NK002,'') NK002, TC020 ,TC021,TC018,TC066,TC067,'',case when TC014 like '%T/T%' or TC014 like '%TT%' then 'Y' else 'N' end 付款檢核,
TC.TC049 流程代號,
TD.TD016,  'Y' ConfirmFlag
 FROM [192.168.1.200].TWPR.dbo.COPTC TC
INNER JOIN [192.168.1.200].TWPR.dbo.COPTD TD ON TC.TC001 = TD.TD001 and TC.TC002 = TD.TD002
INNER JOIN [192.168.1.200].TWPR.dbo.CMSMQ MQ ON MQ.MQ001 = TC.TC001
LEFT JOIN [192.168.1.200].TWPR.dbo.COPMA MA ON MA.MA001 = TC.TC004
LEFT JOIN [192.168.1.200].PRORIL.dbo.CMSMV MV ON MV.MV001 = TC.TC006
LEFT JOIN [192.168.1.200].PRORIL.dbo.CMSNK NK ON NK.NK001 = TC.TC068
WHERE 1=1
and TC.TC027 = 'Y' and TD.TD021 = 'Y'
and TD.TD016 <> 'y'
GO

-- 20250120 建立
-- 訂單檢核查詢使用
CREATE OR ALTER   VIEW [dbo].[V_PODetailList]
AS

-- 國內訂單
select DISTINCT '芳晟ERP' COP_Source,TD001 單別,TD002 單號,TD003 序號,
TD004 品號,TD005 品名,TD006 規格,RTRIM(MV1.MV003) 英文品名,RTRIM(MV1.MV004) 英文規格,TC008 幣別,TC009 匯率,
TD008 訂單數量,TD010 單位,TD011 外幣單價,TD012 外幣金額,TC009*TD012 台幣金額,TD013 預交日,TD017 前置單別,TD018 前置單號,TD019 前置序號,
TB.TB007 前置數量,TB.TB009 前置單價,TD.TD016 FinFlag
 FROM [192.168.1.200].PRORIL.dbo.COPTC TC
INNER JOIN [192.168.1.200].PRORIL.dbo.COPTD TD ON TC.TC001 = TD.TD001 and TC.TC002 = TD.TD002
INNER JOIN [192.168.1.200].PRORIL.dbo.CMSMQ MQ ON MQ.MQ001 = TC.TC001
LEFT JOIN [192.168.1.200].PRORIL.dbo.MOCTA TA ON TA.TA026 = TC.TC001 AND TA.TA027 = TC.TC002 AND TA.TA028 = TD.TD003
LEFT JOIN [192.168.1.200].PRORIL.dbo.COPMA MA ON MA.MA001 = TC.TC004
LEFT JOIN [192.168.1.200].PRORIL.dbo.CMSMV MV ON MV.MV001 = TC.TC006
LEFT JOIN [192.168.1.200].PRORIL.dbo.INVMV MV1 ON MV1.MV001 = TD004
LEFT JOIN [192.168.1.200].PRORIL.dbo.COPTB TB ON TB.TB001 = TD.TD017 AND TB.TB002 = TD.TD018 AND TB.TB003 = TD.TD019
WHERE 1=1
and TD.TD016 <> 'y'

UNION

select DISTINCT '浦瑞ERP' COP_Source,TD001 單別,TD002 單號,TD003 序號,
TD004 品號,TD005 品名,TD006 規格,RTRIM(MV1.MV003) 英文品名,RTRIM(MV1.MV004) 英文規格,TC008 幣別,TC009 匯率,
TD008 訂單數量,TD010 單位,TD011 本幣單價,TD012 本幣金額,TC009*TD012 台幣金額,TD013 預交日,TD017 前置單別,TD018 前置單號,TD019 前置序號,
TB.TB007 前置數量,TB.TB009 前置單價,TD.TD016 FinFlag
 FROM [192.168.1.200].TWPR.dbo.COPTC TC
INNER JOIN [192.168.1.200].TWPR.dbo.COPTD TD ON TC.TC001 = TD.TD001 and TC.TC002 = TD.TD002
INNER JOIN [192.168.1.200].TWPR.dbo.CMSMQ MQ ON MQ.MQ001 = TC.TC001
LEFT JOIN [192.168.1.200].PRORIL.dbo.MOCTA TA ON TA.TA026 = TC.TC001 AND TA.TA027 = TC.TC002 AND TA.TA028 = TD.TD003
LEFT JOIN [192.168.1.200].TWPR.dbo.COPMA MA ON MA.MA001 = TC.TC004
LEFT JOIN [192.168.1.200].PRORIL.dbo.CMSMV MV ON MV.MV001 = TC.TC006
LEFT JOIN [192.168.1.200].PRORIL.dbo.INVMV MV1 ON MV1.MV001 = TD004
LEFT JOIN [192.168.1.200].TWPR.dbo.COPTB TB ON TB.TB001 = TD.TD017 AND TB.TB002 = TD.TD018 AND TB.TB003 = TD.TD019
WHERE 1=1
and TD.TD016 <> 'y'
GO

/****** Author: Mars 20241112         ******/
/****** 用於品號顯示英文名稱使用      ******/
-- 注意：來源儲存文字裡物件名稱是舊名 V_Produce_English_All（sp_rename 遺留），
-- 這裡已手動修正成正確名稱 V_Product_English_All，不是謄寫錯誤。
CREATE OR ALTER VIEW [dbo].[V_Product_English_All]
AS

SELECT top 1000000 RTRIM(MB.MB001) AS ProductNo,RTRIM(MB.MB002) AS ProductName,
RTRIM(MB.MB003) AS Specification,
RTRIM(MV.MV003) AS ProductName_E,RTRIM(MV.MV004) AS Specification_E
FROM [192.168.1.200].PRORIL.dbo.INVMV MV
INNER JOIN [192.168.1.200].PRORIL.dbo.INVMB MB ON RTRIM(MV.MV001) = RTRIM(MB.MB001)
WHERE 1=1
order by RTRIM(MB.MB001)
GO

-- 20250214 Mars
-- 訂單檢核上傳附件檔案使用的資料集
CREATE OR ALTER     VIEW [dbo].[V_UpFileData]
AS

select Parent,replace(KeyValues,'||','-') as KeyValues,CompanyID,UserID,[Type],SeqNo,[FileName],DocID,Revision,AddDate,AddTime,KeyFields
from [192.168.1.200].DSCSYS.dbo.ATTACH
WHERE 1=1
GO

-- ============================================================
-- 5. 預存程序（5 個，依賴順序：先建 prc_COPGetCredit，
--    再建呼叫它的 prc_COPGetCredit_CRM / prc_COPOrderChk；
--    SQL Server 對 CREATE PROCEDURE 本來就是延遲名稱解析，
--    順序其實不強制，這裡排序純粹是方便閱讀）
-- ============================================================

-- =============================================
-- Author:		Mars
-- Create date: 20250227
-- Description:	訂單檢核時取得客戶信用額度金額,回傳[信用可超出額][信用餘額]兩個金額
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[prc_COPGetCredit]

@InCustNo varchar(40), -- 客戶代號
@Executor varchar(40) -- 執行人員

AS
BEGIN


DECLARE

@MA065 varchar(50) = '',
@MA014 varchar(50) = '',

@NotifyAmt numeric (16,3) = 0, --  訂貨(出貨通知)金額
@OrderAmt numeric (16,3) = 0, --  未出貨訂單總金額
@OrderAmtRate numeric (16,6) = 0, --  未出貨訂單金額比率
@ReceivableSumAmt numeric (16,3) = 0, --  應收合計金額
@ReceivableAmt numeric (16,3) = 0, --  應收金額
@GainAmt numeric (16,3) = 0, --  已出貨抵預收金額
@UnbilledAmt numeric (16,3) = 0, --  未結帳銷貨
@PreGainAmt numeric (16,3) = 0, --  預收金額
@AvailableAmt numeric (16,3) = 0, --  信用餘額
@AvailableSetAmt numeric (16,3) = 0, --  信用可超出額


@Memo varchar(500),
@aStatus varchar(1),

@RET VARCHAR(50),

@Field NVARCHAR(50),
@Value NVARCHAR(50),
@where NVARCHAR(500),
@statement NVARCHAR(500),

@CreateTime datetime


  SET @CreateTime = GETDATE()

  BEGIN TRANSACTION
  --開啟交易

    BEGIN TRY

  --程式邏輯:
  --  1.未出貨訂單金額比率 分為總公司請款及個別請款兩類
  --    總公司請款旗標為COPMA.MA066 = Y
  --    判斷是否為[信用額度依總公司控管]
  --    按照此旗標分成兩個取得可用額度的邏輯,各自取值
  --  2.訂貨(出貨通知)金額 = 未出貨訂單總金額 * 未出貨訂單金額比率
  --  3.應收合計金額 = 應收金額 + 已出貨抵預收金額 + 未結帳銷貨 - 預收金額 + 訂貨(出貨通知)金額
  --  4.信用餘額 = 設定額度金額 - 應收合計金額

-- MA065          	總店號	V	10.0	總店的代號
-- MA066          	總公司請款	V	1.0	Y/N
-- MA082          	信用額度依總公司控管	V	1.0	Y/N[DEF:"N"] //890801

      -- 1.判斷是否為[信用額度依總公司控管]
		select @MA065 = case when MA065 = '' then @InCustNo else MA065 end,@MA014 = MA014 from [192.168.1.200].TWPR.dbo.COPMA MA
		where 1=1
		and MA066 = 'Y'
		and MA082 = 'Y'
    	AND (MA001 = @InCustNo OR (MA065 = @InCustNo AND MA082 = 'Y' ))


		print @MA065

		if (@MA065 <> '') -- 歸總公司控管客戶
		begin
            -- 2.訂貨(出貨通知)金額 = 未出貨訂單總金額 * 未出貨訂單金額比率
			--@OrderAmt numeric (16,3) = 0, --  未出貨訂單總金額

			select @NotifyAmt = ISNULL(SUM((TD008-TD009) * TD011 * MA.MA094),0)
			FROM [192.168.1.200].TWPR.dbo.COPTD TD
			INNER JOIN [192.168.1.200].TWPR.dbo.COPTC TC ON TC.TC001 = TD.TD001 and TC.TC002 = TD.TD002
			LEFT JOIN ( SELECT MA.MA001,MA.MA082,CASE WHEN MA.MA082 = 'Y' THEN MA.MA065 ELSE MA.MA001 END MA065,CASE WHEN MA.MA082 = 'Y' THEN MA1.MA094 ELSE MA.MA094 END MA094  FROM  [192.168.1.200].TWPR.dbo.COPMA MA
							   LEFT JOIN [192.168.1.200].TWPR.dbo.COPMA MA1 ON MA.MA082 = 'Y' AND MA1.MA001 = MA.MA065) MA ON MA.MA001 = TC.TC004
			WHERE 1=1
			and TC.TC027 = 'Y' and TD.TD021 = 'Y' and TD.TD016 = 'N'
			AND MA.MA065 = @MA065
			and ((TD.TD001 >= '2702' and TD.TD001 <= '2798') or (TD.TD001 = '2210'))
			AND TD008<>TD009

			PRINT '@NotifyAmt = ' + CAST(@NotifyAmt AS VARCHAR(100))

			select @OrderAmtRate = MA.MA094, @OrderAmt = SUM((TD008-TD009) * TD011)
			FROM [192.168.1.200].TWPR.dbo.COPTD TD
			INNER JOIN [192.168.1.200].TWPR.dbo.COPTC TC ON TC.TC001 = TD.TD001 and TC.TC002 = TD.TD002
			LEFT JOIN ( SELECT MA.MA001,MA.MA082,CASE WHEN MA.MA082 = 'Y' THEN MA.MA065 ELSE MA.MA001 END MA065,CASE WHEN MA.MA082 = 'Y' THEN MA1.MA094 ELSE MA.MA094 END MA094  FROM  [192.168.1.200].TWPR.dbo.COPMA MA
							   LEFT JOIN [192.168.1.200].TWPR.dbo.COPMA MA1 ON MA.MA082 = 'Y' AND MA1.MA001 = MA.MA065) MA ON MA.MA001 = TC.TC004
			WHERE 1=1
			and TC.TC027 = 'Y' and TD.TD021 = 'Y' and TD.TD016 = 'N'
			AND MA.MA065 = @MA065
			and ((TD.TD001 >= '2702' and TD.TD001 <= '2798') or (TD.TD001 = '2210'))
			AND TD008<>TD009
			GROUP BY MA.MA065,MA.MA094


            --  3.應收合計金額 = 應收金額 - 預收金額 + 已出貨抵預收金額 + 未結帳銷貨  + 訂貨(出貨通知)金額
			-- 應收金額
		    SELECT @ReceivableAmt = ISNULL(sum(TA029+TA030-TA031-TA047),0)
			FROM [192.168.1.200].TWPR.dbo.ACRTA ACRTA
			INNER JOIN [192.168.1.200].TWPR.dbo.COPMA COPMA ON MA001=TA004
			LEFT JOIN [192.168.1.200].TWPR.dbo.CMSMQ CMSMQ ON MQ001=TA001
			LEFT JOIN [192.168.1.200].TWPR.dbo.CMSMF CMSMF ON MF001=TA009
			WHERE 1=1
			AND TA025='Y'
			AND TA027='N'
			AND TA019='N'
			AND (MA001 = @MA065 OR (MA065 = @MA065 AND MA082 = 'Y' ))
			and TA001 IN ('6111','6112','6601')

			PRINT '@ReceivableAmt = ' + CAST(@ReceivableAmt AS VARCHAR(100))

			-- 預收金額
		    SELECT @PreGainAmt = ISNULL(sum(TA029),0)
			FROM [192.168.1.200].TWPR.dbo.ACRTA ACRTA
			INNER JOIN [192.168.1.200].TWPR.dbo.COPMA COPMA ON MA001=TA004
			LEFT JOIN [192.168.1.200].TWPR.dbo.CMSMQ CMSMQ ON MQ001=TA001
			LEFT JOIN [192.168.1.200].TWPR.dbo.CMSMF CMSMF ON MF001=TA009
			WHERE 1=1
			AND TA025='Y'
			AND TA027='N'
			AND TA019='N'
			AND (MA001 = @MA065 OR (MA065 = @MA065 AND MA082 = 'Y' ))
			and TA001 IN ('6212')

			PRINT '@PreGainAmt = ' + CAST(@PreGainAmt AS VARCHAR(100))

			-- 已出貨抵預收金額
		    SELECT @GainAmt = ISNULL(sum(TA031),0)
			FROM [192.168.1.200].TWPR.dbo.ACRTA ACRTA
			INNER JOIN [192.168.1.200].TWPR.dbo.COPMA COPMA ON MA001=TA004
			LEFT JOIN [192.168.1.200].TWPR.dbo.CMSMQ CMSMQ ON MQ001=TA001
			LEFT JOIN [192.168.1.200].TWPR.dbo.CMSMF CMSMF ON MF001=TA009
			WHERE 1=1
			AND TA025='Y'
			AND TA027='N'
			AND TA019='N'
			AND (MA001 = @MA065 OR (MA065 = @MA065 AND MA082 = 'Y'))
			and TA001 IN ('6212')

			PRINT '@GainAmt = ' + CAST(@GainAmt AS VARCHAR(100))

			-- 未結帳銷貨
			SELECT @UnbilledAmt = ISNULL(SUM(DISTINCT TH.TH035),0)
			FROM [192.168.1.200].TWPR.dbo.COPTH TH
			LEFT JOIN [192.168.1.200].TWPR.dbo.COPTG TG ON TG.TG001 = TH.TH001 AND TG.TG002 = TH.TH002
			INNER JOIN [192.168.1.200].TWPR.dbo.COPMA MA ON MA.MA001 = TG.TG004
			WHERE 1=1
			AND TH.TH020 = 'Y'
			AND TH.TH026 = 'N'
			AND (MA001 = @MA065 OR (MA065 = @MA065 AND MA082 = 'Y'))

			PRINT '@UnbilledAmt = ' + CAST(@UnbilledAmt AS VARCHAR(100))

			SET @ReceivableSumAmt = @ReceivableAmt - @PreGainAmt + @GainAmt + @UnbilledAmt + @NotifyAmt

			PRINT '@ReceivableSumAmt = ' + CAST(@ReceivableSumAmt AS VARCHAR(100))

			--  4.信用餘額 = 設定額度金額 - 應收合計金額
			-- ERP設定額度金額
			SELECT @AvailableSetAmt = MA033 * (1+MA034),@MA014 = MA014 FROM [192.168.1.200].TWPR.dbo.COPMA
			where 1=1
			and MA001 = @MA065

			PRINT '@AvailableSetAmt = ' + CAST(@AvailableSetAmt AS VARCHAR(100))

			set @AvailableAmt = @AvailableSetAmt - @ReceivableSumAmt

			PRINT '@AvailableAmt = ' + CAST(@AvailableAmt AS VARCHAR(100))
		end
		else
		begin
            print '111'

            -- 2.訂貨(出貨通知)金額 = 未出貨訂單總金額 * 未出貨訂單金額比率
			select @NotifyAmt = ISNULL(SUM((TD008-TD009) * TD011 * MA.MA094),0)
			FROM [192.168.1.200].TWPR.dbo.COPTD TD
			INNER JOIN [192.168.1.200].TWPR.dbo.COPTC TC ON TC.TC001 = TD.TD001 and TC.TC002 = TD.TD002
			LEFT JOIN ( SELECT MA.MA001,MA.MA082,CASE WHEN MA.MA082 = 'Y' THEN MA.MA065 ELSE MA.MA001 END MA065,CASE WHEN MA.MA082 = 'Y' THEN MA1.MA094 ELSE MA.MA094 END MA094  FROM  [192.168.1.200].TWPR.dbo.COPMA MA
						LEFT JOIN [192.168.1.200].TWPR.dbo.COPMA MA1 ON MA.MA082 = 'Y' AND MA1.MA001 = MA.MA065) MA ON MA.MA001 = TC.TC004
			WHERE 1=1
			and TC.TC027 = 'Y' and TD.TD021 = 'Y' and TD.TD016 = 'N'
			AND MA.MA065 = @InCustNo
			and ((TD.TD001 >= '2702' and TD.TD001 <= '2798') or (TD.TD001 = '2210'))
			AND TD008<>TD009

			select @OrderAmtRate = MA.MA094, @OrderAmt = SUM((TD008-TD009) * TD011)
			FROM [192.168.1.200].TWPR.dbo.COPTD TD
			INNER JOIN [192.168.1.200].TWPR.dbo.COPTC TC ON TC.TC001 = TD.TD001 and TC.TC002 = TD.TD002
			LEFT JOIN ( SELECT MA.MA001,MA.MA082,CASE WHEN MA.MA082 = 'Y' THEN MA.MA065 ELSE MA.MA001 END MA065,CASE WHEN MA.MA082 = 'Y' THEN MA1.MA094 ELSE MA.MA094 END MA094  FROM  [192.168.1.200].TWPR.dbo.COPMA MA
							   LEFT JOIN [192.168.1.200].TWPR.dbo.COPMA MA1 ON MA.MA082 = 'Y' AND MA1.MA001 = MA.MA065) MA ON MA.MA001 = TC.TC004
			WHERE 1=1
			and TC.TC027 = 'Y' and TD.TD021 = 'Y' and TD.TD016 = 'N'
			AND MA.MA065 = @InCustNo
			and ((TD.TD001 >= '2702' and TD.TD001 <= '2798') or (TD.TD001 = '2210'))
			AND TD008<>TD009
			GROUP BY MA.MA065,MA.MA094

			PRINT '@NotifyAmt = ' + CAST(@NotifyAmt AS VARCHAR(100))

            --  3.應收合計金額 = 應收金額 - 預收金額 + 已出貨抵預收金額 + 未結帳銷貨  + 訂貨(出貨通知)金額
		    SELECT @ReceivableAmt = ISNULL(sum(TA029+TA030-TA031-TA047),0)
			FROM [192.168.1.200].TWPR.dbo.ACRTA ACRTA
			INNER JOIN [192.168.1.200].TWPR.dbo.COPMA COPMA ON MA001=TA004
			LEFT JOIN [192.168.1.200].TWPR.dbo.CMSMQ CMSMQ ON MQ001=TA001
			LEFT JOIN [192.168.1.200].TWPR.dbo.CMSMF CMSMF ON MF001=TA009
			WHERE 1=1
			AND TA025='Y'
			AND TA027='N'
			AND TA019='N'
			AND (MA001 = @InCustNo OR (MA065 = @InCustNo AND MA082 = 'Y' ))
			and TA001 IN ('6111','6112','6601')

			PRINT '@ReceivableAmt = ' + CAST(@ReceivableAmt AS VARCHAR(100))

			-- 預收金額
		    SELECT @PreGainAmt = ISNULL(sum(TA029),0)
			FROM [192.168.1.200].TWPR.dbo.ACRTA ACRTA
			INNER JOIN [192.168.1.200].TWPR.dbo.COPMA COPMA ON MA001=TA004
			LEFT JOIN [192.168.1.200].TWPR.dbo.CMSMQ CMSMQ ON MQ001=TA001
			LEFT JOIN [192.168.1.200].TWPR.dbo.CMSMF CMSMF ON MF001=TA009
			WHERE 1=1
			AND TA025='Y'
			AND TA027='N'
			AND TA019='N'
			AND (MA001 = @InCustNo OR (MA065 = @InCustNo AND MA082 = 'Y' ))
			and TA001 IN ('6212')

			PRINT '@PreGainAmt = ' + CAST(@PreGainAmt AS VARCHAR(100))

			-- 已出貨抵預收金額
		    SELECT @GainAmt = ISNULL(sum(TA031),0)
			FROM [192.168.1.200].TWPR.dbo.ACRTA ACRTA
			INNER JOIN [192.168.1.200].TWPR.dbo.COPMA COPMA ON MA001=TA004
			LEFT JOIN [192.168.1.200].TWPR.dbo.CMSMQ CMSMQ ON MQ001=TA001
			LEFT JOIN [192.168.1.200].TWPR.dbo.CMSMF CMSMF ON MF001=TA009
			WHERE 1=1
			AND TA025='Y'
			AND TA027='N'
			AND TA019='N'
			AND (MA001 = @InCustNo OR (MA065 = @InCustNo AND MA082 = 'Y'))
			and TA001 IN ('6212')

			PRINT '@GainAmt = ' + CAST(@GainAmt AS VARCHAR(100))

			-- 未結帳銷貨
			SELECT @UnbilledAmt = ISNULL(SUM(DISTINCT TH.TH035),0)
			FROM [192.168.1.200].TWPR.dbo.COPTH TH
			LEFT JOIN [192.168.1.200].TWPR.dbo.COPTG TG ON TG.TG001 = TH.TH001 AND TG.TG002 = TH.TH002
			INNER JOIN [192.168.1.200].TWPR.dbo.COPMA MA ON MA.MA001 = TG.TG004
			WHERE 1=1
			AND TH.TH020 = 'Y'
			AND TH.TH026 = 'N'
			AND (MA001 = @InCustNo OR (MA065 = @InCustNo AND MA082 = 'Y'))

			PRINT '@UnbilledAmt = ' + CAST(@UnbilledAmt AS VARCHAR(100))

			SET @ReceivableSumAmt = @ReceivableAmt - @PreGainAmt + @GainAmt + @UnbilledAmt + @NotifyAmt

			PRINT '@ReceivableSumAmt = ' + CAST(@ReceivableSumAmt AS VARCHAR(100))

			--  4.信用餘額 = 設定額度金額 - 應收合計金額

			-- ERP設定額度金額
			SELECT @AvailableSetAmt = MA033 * (1+MA034),@MA014 = MA014 FROM [192.168.1.200].TWPR.dbo.COPMA
			where 1=1
			and MA001 = @InCustNo

			PRINT '@AvailableSetAmt = ' + CAST(@AvailableSetAmt AS VARCHAR(100))

			set @AvailableAmt = @AvailableSetAmt - @ReceivableSumAmt

			PRINT '@AvailableAmt = ' + CAST(@AvailableAmt AS VARCHAR(100))

		end

  --  2.訂貨(出貨通知)金額 = 未出貨訂單總金額 * 未出貨訂單金額比率
  --    @NotifyAmt = @OrderAmt * @OrderAmtRate
  --  3.應收合計金額 = 應收金額 - 預收金額 + 已出貨抵預收金額 + 未結帳銷貨  + 訂貨(出貨通知)金額
  --    @ReceivableSumAmt = @ReceivableAmt - @PreGainAmt + @GainAmt + @UnbilledAmt + @NotifyAmt
  --  4.信用餘額 = 設定額度金額 - 應收合計金額
  --    @AvailableAmt = @AvailableSetAmt - @ReceivableSumAmt

        INSERT INTO COP_AvailableAmt (
          CustNo,OrderChkNo,NotifyAmt,OrderAmt,OrderAmtRate,
		  ReceivableSumAmt,ReceivableAmt,GainAmt,UnbilledAmt,PreGainAmt,
		  AvailableAmt,AvailableSetAmt,Memo,aStatus,Creator,CreateTime)
		select
          @InCustNo,'',@NotifyAmt,@OrderAmt,@OrderAmtRate,
		  @ReceivableSumAmt,@ReceivableAmt,@GainAmt,@UnbilledAmt,@PreGainAmt,
		  @AvailableAmt,@AvailableSetAmt,'','Y',@Executor,@CreateTime

		select @ReceivableAmt as 應收金額,@UnbilledAmt as 未結帳銷貨,@NotifyAmt as 訂貨出貨通知金額,@PreGainAmt as 預收金額,@GainAmt as 已出貨抵預收金額,
		       @ReceivableSumAmt as 應收合計金額,@OrderAmt as 未出貨訂單總金額,@OrderAmtRate as 未出貨訂單金額比率,
			   @AvailableSetAmt as 信用可超出額,@AvailableAmt as 信用餘額

       COMMIT


	END TRY

	BEGIN CATCH

		ROLLBACK;

		PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR(MAX));
		PRINT 'Error Message: ' + ERROR_MESSAGE();

    END CATCH


END
GO

-- =============================================
-- Author:		Mars
-- Create date: 20250227
-- Description:	訂單檢核時取得客戶信用額度金額,回傳[信用可超出額][信用餘額]兩個金額（幣別分開版本）
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[prc_COPGetCredit_CRM]

@InCustNo varchar(40), -- 客戶代號
@Executor varchar(40) -- 執行人員

AS
BEGIN


DECLARE

@MA065 varchar(50) = '',
@MA014 varchar(50) = '',

@NotifyAmt numeric (16,3) = 0,
@OrderAmt numeric (16,3) = 0,
@OrderAmtRate numeric (16,6) = 0,
@ReceivableSumAmt numeric (16,3) = 0,
@ReceivableAmt numeric (16,3) = 0,
@GainAmt numeric (16,3) = 0,
@UnbilledAmt numeric (16,3) = 0,
@PreGainAmt numeric (16,3) = 0,
@AvailableAmt numeric (16,3) = 0,
@AvailableSetAmt numeric (16,3) = 0,


@Memo varchar(500),
@aStatus varchar(1),

@RET VARCHAR(50),

@Field NVARCHAR(50),
@Value NVARCHAR(50),
@where NVARCHAR(500),
@statement NVARCHAR(500),
@CreateTime datetime


  SET @CreateTime = GETDATE()

    BEGIN TRANSACTION
  --開啟交易

    BEGIN TRY

		SELECT @MA014 = MA014 FROM [192.168.1.200].TWPR.dbo.COPMA
		where 1=1
		and MA001 = @InCustNo

      print 'exec prc_COPGetCredit'

	  -- 呼叫[prc_COPGetCredit] 取得相關金額
	  -- 建立暫存表來存放結果
	  CREATE TABLE #TempCreditData (
		應收金額 numeric (16,3),
		未結帳銷貨  numeric (16,3),
		訂貨出貨通知金額  numeric (16,3),
		預收金額  numeric (16,3),
		已出貨抵預收金額  numeric (16,3),
		應收合計金額  numeric (16,3),
	    未出貨訂單總金額  numeric (16,3),
		未出貨訂單金額比率  numeric (16,6),
		信用可超出額  numeric (16,3),
		信用餘額  numeric (16,3)
        );

	  INSERT INTO #TempCreditData
	  exec prc_COPGetCredit @InCustNo, @Executor

	  select 應收金額,未結帳銷貨,訂貨出貨通知金額,預收金額,已出貨抵預收金額,
             應收合計金額,未出貨訂單總金額,未出貨訂單金額比率,
		     信用可超出額,信用餘額,@MA014 AS 幣別  FROM #TempCreditData

      -- 清除暫存表
	  DROP TABLE #TempCreditData;



       COMMIT


	END TRY

	BEGIN CATCH

		ROLLBACK;

		PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR(MAX));
		PRINT 'Error Message: ' + ERROR_MESSAGE();

    END CATCH


END
GO

-- =============================================
-- Author:		Mars
-- Create date: 20250121
-- Description:	品號名稱基本資料檢核
--   20250312:因應訂單檢核要區分不同ERP,另外拆為[prc_ProductChk_COP]
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[prc_ProductChk_COP]

@ChkType varchar(20), -- 檢核類別  A:全部成品,P:品號檢核,訂單檢核序號:訂單檢核(例:20250205002)
@ChkSource varchar(40), -- 訂單檢核:傳入訂單單號, 功能檢核:傳入功能代碼,例: BomQuery
@ERPSource varchar(40), -- ERP資料庫別 '芳晟ERP' OR '浦瑞ERP'
@InProductNo varchar(40), -- 檢核品號
@Executor varchar(40), -- 執行人員
@result VARCHAR(40) OUTPUT    --傳回結果



AS
BEGIN
DECLARE
@TotalNum INT,
@TotalNum_E INT,
@TotalNum_S INT,
@Num INT,
@MB001 NVARCHAR(20),
@MB002 NVARCHAR(120),
@MB003 NVARCHAR(120),
@TmpStr NVARCHAR(120),
@ValStr NVARCHAR(50),
@TmpIdx INT,
@ProductNo NVARCHAR(20),
@ProductName NVARCHAR(120),
@ProductSpec NVARCHAR(120),
@ProductName_EN NVARCHAR(120),
@ProductSpec_EN NVARCHAR(120),

@C01 NVARCHAR(50),
@C02 NVARCHAR(50),
@C03 NVARCHAR(50),
@C04 NVARCHAR(50),
@C05 NVARCHAR(50),
@C06 NVARCHAR(50),
@C07 NVARCHAR(50),
@C08 NVARCHAR(50),
@C09 NVARCHAR(50),
@C10 NVARCHAR(50),
@C11 NVARCHAR(50),
@C12 NVARCHAR(50),

@E01 NVARCHAR(50),
@E02 NVARCHAR(50),
@E03 NVARCHAR(50),
@E04 NVARCHAR(50),
@E05 NVARCHAR(50),
@E06 NVARCHAR(50),
@E07 NVARCHAR(50),
@E08 NVARCHAR(50),
@E09 NVARCHAR(50),
@E10 NVARCHAR(50),
@E11 NVARCHAR(50),
@E12 NVARCHAR(50),

@NoChk NVARCHAR(10),
@PHChk NVARCHAR(10),
@HZChk NVARCHAR(10),
@StartChk NVARCHAR(10),
@VolChk NVARCHAR(10),
@FloatChk NVARCHAR(10),
@WireSpecChk NVARCHAR(10),
@WireSizeChk NVARCHAR(10),
@PlusChk NVARCHAR(10),
@Ext1Chk NVARCHAR(10),
@Ext2Chk NVARCHAR(10),
@Ext3Chk NVARCHAR(10),

@FinChk NVARCHAR(10),

@ModelName_Spec NVARCHAR(50),

@ModelName NVARCHAR(50),
@Phase NVARCHAR(20),
@Frequency NVARCHAR(20),
@Voltage NVARCHAR(20),

@ChkNo varchar(20),

@OrderChkNo varchar(20),

@Memo NVARCHAR(500),

@CreateTime datetime




  SET @CreateTime = GETDATE()

  BEGIN TRANSACTION
  --開啟交易

    BEGIN TRY

    -- 品名拆解後各項目的暫存資料檔
	CREATE TABLE [dbo].[#TmpDataSet](
		[ID] [int] IDENTITY(1,1) NOT NULL,
		[ProductNo] [nvarchar](120) NULL,
		[ProductName] [nvarchar](120) NULL,
		[Specification] [nvarchar](120) NULL,
		[ProductName_E] [nvarchar](120) NULL,
		[Specification_E] [nvarchar](120) NULL,
		[FType] [nvarchar](50) NULL,
		[F01] [nvarchar](50) NULL,
		[F02] [nvarchar](50) NULL,
		[F03] [nvarchar](50) NULL,
		[F04] [nvarchar](50) NULL,
		[F05] [nvarchar](50) NULL,
		[F06] [nvarchar](50) NULL,
		[F07] [nvarchar](50) NULL,
		[F08] [nvarchar](50) NULL,
		[F09] [nvarchar](50) NULL,
		[F10] [nvarchar](50) NULL,
		[F11] [nvarchar](50) NULL,
		[F12] [nvarchar](50) NULL
		)


    	--  取得品號相關資料
        IF (@ERPSource = '芳晟ERP')
		BEGIN
			SELECT @ProductName = RTRIM(MB.MB002),
				   @ProductSpec = RTRIM(MB.MB003),
				   @ProductName_EN = RTRIM(MV.MV003),
				   @ProductSpec_EN = RTRIM(MV.MV004)
			FROM [192.168.1.200].PRORIL.dbo.INVMB MB
			LEFT JOIN [192.168.1.200].PRORIL.dbo.INVMV MV ON MV.MV001 = MB.MB001
			WHERE 1=1
			AND MB.MB001 = @InProductNo
        END
        ELSE
		BEGIN
			SELECT @ProductName = RTRIM(MB.MB002),
				   @ProductSpec = RTRIM(MB.MB003),
				   @ProductName_EN = RTRIM(MV.MV003),
				   @ProductSpec_EN = RTRIM(MV.MV004)
			FROM [192.168.1.200].TWPR.dbo.INVMB MB
			LEFT JOIN [192.168.1.200].TWPR.dbo.INVMV MV ON MV.MV001 = MB.MB001
			WHERE 1=1
			AND MB.MB001 = @InProductNo
         END
      --程式邏輯:
      --1.先比對所有項目是否符合
      --2.按照項目數量及內容判斷項目類型,將比對結果寫入適當的旗標
      --  其中8項的有兩種不同組合,必須特別判斷

      --1.先比對所有項目是否符合
        -- 解析中文品名
		SET @Num =1
		SET @TmpStr = @ProductName
        SET @TotalNum = (LEN(RTRIM(@TmpStr)) - LEN(REPLACE(RTRIM(@TmpStr),'，',''))) / LEN('，') + 1

		-- 中文品名第一個字元如果是中文字要從第二組開始解析
        IF (UNICODE(SUBSTRING(@TmpStr, 1, 1)) BETWEEN 0x4E00 AND 0x9FFF)
		BEGIN
    	  SET @TmpIdx = CHARINDEX('，',@TmpStr)
	  	  SET @TmpStr = SUBSTRING(@TmpStr,@TmpIdx+1,LEN(@TmpStr)-@TmpIdx)
          SET @TotalNum = (LEN(RTRIM(@TmpStr)) - LEN(REPLACE(RTRIM(@TmpStr),'，',''))) / LEN('，') + 1
        END

        WHILE (@Num <= @TotalNum)
		BEGIN
			SET @TmpIdx = CHARINDEX('，',@TmpStr)

			IF (@TmpIdx > 0)
			BEGIN
			  SET @ValStr = SUBSTRING(@TmpStr,1,@TmpIdx-1)
			  SET @TmpStr = SUBSTRING(@TmpStr,@TmpIdx+1,LEN(@TmpStr)-@TmpIdx)
            END
			ELSE
			BEGIN
			  SET @ValStr = @TmpStr
			  SET @TmpStr = @TmpStr
			END

			if (@Num = 1)
			BEGIN
				SET @C01 = @ValStr
			END
			ELSE if (@Num = 2)
			BEGIN
				SET @C02 = @ValStr
			END
			ELSE if (@Num = 3)
			BEGIN
				SET @C03 = @ValStr
			END
			ELSE if (@Num = 4)
			BEGIN
				SET @C04 = @ValStr
			END
			ELSE if (@Num = 5)
			BEGIN
				SET @C05 = @ValStr
			END
			ELSE if (@Num = 6)
			BEGIN
				SET @C06 = @ValStr
			END
			ELSE if (@Num = 7)
			BEGIN
				SET @C07 = @ValStr
			END
			ELSE if (@Num = 8)
			BEGIN
				SET @C08 = @ValStr
			END
			ELSE if (@Num = 9)
			BEGIN
				SET @C09 = @ValStr
			END
			ELSE if (@Num = 10)
			BEGIN
				SET @C10 = @ValStr
			END
			ELSE if (@Num = 11)
			BEGIN
				SET @C11 = @ValStr
			END
			ELSE if (@Num = 12)
			BEGIN
				SET @C12 = @ValStr
			END

			SET @Num = @Num + 1
       END

        -- 解析英文品名
        SET @Num =1
		SET @TmpStr = @ProductName_EN
        SET @TotalNum_E = (LEN(RTRIM(@TmpStr)) - LEN(REPLACE(RTRIM(@TmpStr),'，',''))) / LEN('，') + 1

		WHILE (@Num <= @TotalNum_E)
		BEGIN
			SET @TmpIdx = CHARINDEX('，',@TmpStr)
			IF (@TmpIdx > 0)
			BEGIN
			  SET @ValStr = SUBSTRING(@TmpStr,1,@TmpIdx-1)
			  SET @TmpStr = SUBSTRING(@TmpStr,@TmpIdx+1,LEN(@TmpStr)-@TmpIdx)
            END
			ELSE
			BEGIN
			  SET @ValStr = @TmpStr
			  SET @TmpStr = @TmpStr
			END

			if (@Num = 2)
			BEGIN
				SET @E01 = @ValStr
			END
			ELSE if (@Num = 3)
			BEGIN
				SET @E02 = @ValStr
			END
			ELSE if (@Num = 4)
			BEGIN
				SET @E03 = @ValStr
			END
			ELSE if (@Num = 5)
			BEGIN
				SET @E04 = @ValStr
			END
			ELSE if (@Num = 6)
			BEGIN
				SET @E05 = @ValStr
			END
			ELSE if (@Num = 7)
			BEGIN
				SET @E06 = @ValStr
			END
			ELSE if (@Num = 8)
			BEGIN
				SET @E07 = @ValStr
			END
			ELSE if (@Num = 9)
			BEGIN
				SET @E08 = @ValStr
			END
			ELSE if (@Num = 10)
			BEGIN
				SET @E09 = @ValStr
			END
			ELSE if (@Num = 11)
			BEGIN
				SET @E10 = @ValStr
			END
			ELSE if (@Num = 12)
			BEGIN
				SET @E11 = @ValStr
			END
			ELSE if (@Num = 13)
			BEGIN
				SET @E12= @ValStr
			END

			SET @Num = @Num + 1
       END

        -- 解析中文規格
		SET @Num =1
		SET @TmpStr = @ProductSpec
        SET @TotalNum_S = (LEN(RTRIM(@TmpStr)) - LEN(REPLACE(RTRIM(@TmpStr),'，',''))) / LEN('，') + 1

		WHILE (@Num <= @TotalNum_S)
		BEGIN
			SET @TmpIdx = CHARINDEX('，',@TmpStr)
			IF (@TmpIdx > 0)
			BEGIN
			  SET @ValStr = SUBSTRING(@TmpStr,1,@TmpIdx-1)
			  SET @TmpStr = SUBSTRING(@TmpStr,@TmpIdx+1,LEN(@TmpStr)-@TmpIdx)
            END
			ELSE
			BEGIN
			  SET @ValStr = @TmpStr
			  SET @TmpStr = @TmpStr
			END

			if (@Num = 4)
			BEGIN
				SET @ModelName_Spec = @ValStr
			END

			SET @Num = @Num + 1
        END

	   DROP TABLE #TmpDataSet

      SET @OrderChkNo = ''


      IF (@ChkType = 'A')
	  BEGIN
	    SET @ChkNo = @ChkSource
      END
	  ELSE IF (@ChkType = 'P')
	  BEGIN
		  -- 取得檢核序號
		SELECT
			CONVERT(VARCHAR(8), GETDATE(), 112) +
			RIGHT(
				'0000' +
				CONVERT(VARCHAR(4),
					ISNULL(MAX(CAST(SUBSTRING(ChkNo, 9, 4) AS INT)), 0) + 1
				),
			4)
		FROM COP_ProductCheck
		WHERE ChkNo LIKE CONVERT(VARCHAR(8), GETDATE(), 112) + '%'

      END
	  ELSE
	  BEGIN
		  -- 取得品號檢核序號
		  SELECT @ChkNo = CASE WHEN MAX(ChkNo) IS NULL THEN ISNULL(MAX(ChkNo),CONVERT(VARCHAR(12),getdate(),112) +
									  substring('0000'+convert(varchar(4),1),len(convert(varchar(4),1))+1,4))
			   ELSE CONVERT(VARCHAR(12),getdate(),112) + substring('0000'+convert(varchar(4),CONVERT(INT,SUBSTRING(MAX(ChkNo),9,4)) + 1),
							len(convert(varchar(3),CONVERT(INT,SUBSTRING(MAX(ChkNo),9,4)) + 1))+1,4) END
		  FROM COP_ProductCheck
		  WHERE 1=1
		  AND ChkNo LIKE CONVERT(VARCHAR(12),getdate(),112)+'%'

          SET @OrderChkNo = @ChkType -- 訂單檢核時傳入訂單檢核序號
      END

      --2.按照項目數量及內容判斷項目類型,將比對結果寫入適當的旗標

	  set @NoChk = 'Y'
	  set @PHChk = 'Y'
	  set @HZChk = 'Y'
	  set @StartChk = 'Y'
	  set @VolChk = 'Y'
	  set @FloatChk = 'Y'
	  set @WireSpecChk = 'Y'
	  set @WireSizeChk = 'Y'
	  set @PlusChk = 'Y'
	  set @Ext1Chk = 'Y'
	  set @Ext2Chk = 'Y'
	  set @Ext3Chk = 'Y'

	  set @FinChk = 'N'
	  set @Memo = ''


-------- 資料檢核----------
      -- 1~5項各種組合類型的檢核邏輯都相同
      -- 型號檢查
	  if ((@E01 <> @C01) and (@E01 <> @ModelName_Spec) )
	  begin
    	if EXISTS(select * from V_COPNoChk where C01 = @C01 and E01 = @E01)
	    begin
	      set @NoChk = 'P'
	    end
		else
		begin
	      set @NoChk = 'N'
		  set @Memo = @Memo + '型號錯誤:中文-- '+ @C01 +' <> 英文-- '+ @E01 + ' <> 規格-- '+ @ModelName_Spec + '; '
        end
	  end


	  -- F02:PH檢查 @E02 = @C02
	  if (@E02 <> @C02)
	  begin
	    if EXISTS(select * from V_COPNoChk where C01 = @C02 and E01 = @E02)
	    begin
	      set @PHChk = 'P'
	    end
	    else
		begin
  	      set @PHChk = 'N'
	  	  set @Memo = @Memo + 'PH錯誤:中-- '+ @C02 + ' <> 英-- '+ @E02+ '; '
        end
	  end

	  -- F03:HZ檢查 @E03 = @C03
	  if (@E03 <> @C03 )
	  begin
	    if EXISTS(select * from V_COPNoChk where C01 = @C03 and E01 = @E03)
	    begin
	      set @HZChk = 'P'
	    end
	    else
		begin
  	      set @HZChk = 'N'
		  set @Memo = @Memo + 'HZ錯誤:中-- '+ @C03 + ' <> 英-- '+ @E03+ '; '
        end
	  end

	  -- F04:啟動檢查 @E04 = @C04
	  if (@E04 <> @C04 )
	  begin
	    if EXISTS(select * from V_COPNoChk where C01 = @C04 and E01 = @E04)
	    begin
	      set @StartChk = 'P'
	    end
	    else
		begin
  	      set @StartChk = 'N'
		  set @Memo = @Memo + '啟動錯誤:中-- '+ @C04 + ' <> 英-- '+ @E04+ '; '
        end
	  end

	  -- F05:電壓檢查 @E05 = @C05
	  if (@E05 <> @C05 )
	  begin
	    if EXISTS(select * from V_COPNoChk where C01 = @C05 and E01 = @E05)
	    begin
	      set @VolChk = 'P'
	    end
	    else
		begin
	      set @VolChk = 'N'
		  set @Memo = @Memo + '電壓錯誤:中-- '+ @C05 + ' <> 英-- '+ @E05+ '; '
        end
	  end

	  -- F06:線規檢查 @E06 = @C06
	  if (@E06 <> @C06 )
	  begin
	    if ( (@TotalNum = 6) or  (@TotalNum = 7) or ( (@TotalNum = 8) and (CHARINDEX('浮球',@C06) = 0)) )
		begin
		  if EXISTS(select * from V_COPNoChk where C01 = @C06 and E01 = @E06)
		  begin
			set @WireSpecChk = 'P'
		  end
		  else
		  begin
	        set @WireSpecChk = 'N'
		    set @Memo = @Memo + '線規錯誤:中-- '+ @C06 + ' <> 英-- '+ @E06+ '; '
          end
        end
		else if ( ((@TotalNum = 8) and (CHARINDEX('浮球',@C06) > 0)) or (@TotalNum = 9) )
		begin
		  if EXISTS(select * from V_COPNoChk where C01 = @C06 and E01 = @E06)
		  begin
			set @FloatChk = 'P'
		  end
		  else
		  begin
	        set @FloatChk = 'N'
		    set @Memo = @Memo + '浮球錯誤:中-- '+ @C06 + ' <> 英-- '+ @E06+ '; '
          end
        end
	  end

	  -- F07:線徑檢查 @E07 = @C07
	  if (@E07 <> @C07 )
	  begin
	    if ( (@TotalNum = 7) or ( (@TotalNum = 8) and (CHARINDEX('浮球',@C06) = 0)) )
		begin
		  if EXISTS(select * from V_COPNoChk where C01 = @C07 and E01 = @E07)
		  begin
			set @WireSizeChk = 'P'
		  end
		  else
		  begin
		    -- 線徑去括號後再檢核
            if ((SELECT dbo.fu_RemoveParentheses(@E07)) <> (SELECT dbo.fu_RemoveParentheses(@C07)) )
			begin
    	      set @WireSizeChk = 'N'
	          set @Memo = @Memo + '線徑錯誤:中-- '+ @C07 + ' <> 英-- '+ @E07+ '; '
            end
          end
        end
		else if ( ((@TotalNum = 8) and (CHARINDEX('浮球',@C06) > 0)) or (@TotalNum = 9) )
		begin
		  if EXISTS(select * from V_COPNoChk where C01 = @C07 and E01 = @E07)
		  begin
			set @WireSpecChk = 'P'
		  end
		  else
		  begin
	        set @WireSpecChk = 'N'
		    set @Memo = @Memo + '線規錯誤:中-- '+ @C07 + ' <> 英-- '+ @E07+ '; '
          end
        end
	  end

	  -- F08:插頭檢查 @E08 = @C08
      if (@E08 <> @C08 )
	  begin
	    if ( ( (@TotalNum = 8) and (CHARINDEX('浮球',@C06) = 0)) )
		begin
		  if EXISTS(select * from V_COPNoChk where C01 = @C08 and E01 = @E08)
		  begin
			set @PlusChk = 'P'
		  end
		  else
		  begin
    	    set @PlusChk = 'N'
	        set @Memo = @Memo + '插頭錯誤:中-- '+ @C08 + ' <> 英-- '+ @E08+ '; '
          end
        end
		else if ( ((@TotalNum = 8) and (CHARINDEX('浮球',@C06) > 0)) or (@TotalNum = 9) )
		begin
		  if EXISTS(select * from V_COPNoChk where C01 = @C08 and E01 = @E08)
		  begin
			set @WireSizeChk = 'P'
		  end
		  else
		  begin
		    -- 線徑去括號後再檢核
            if ((SELECT dbo.fu_RemoveParentheses(@E08)) <> (SELECT dbo.fu_RemoveParentheses(@C08)) )
  		    begin
    	      set @WireSizeChk = 'N'
	          set @Memo = @Memo + '線徑錯誤:中-- '+ @C08 + ' <> 英-- '+ @E08+ '; '
            end
          end
        end
	  end

	  -- F09:插頭檢查 @E09 = @C09
      if (@E09 <> @C09 )
	  begin
	    if (@TotalNum = 9)
		begin
		  if EXISTS(select * from V_COPNoChk where C01 = @C09 and E01 = @E09)
		  begin
			set @PlusChk = 'P'
		  end
		  else
		  begin
    	    set @PlusChk = 'N'
	        set @Memo = @Memo + '插頭錯誤:中-- '+ @C09 + ' <> 英-- '+ @E09+ '; '
          end
        end
	  end

	  if     @NoChk <> 'N'
	     and @PHChk <> 'N'
		 and @HZChk <> 'N'
		 and @StartChk <> 'N'
		 and @VolChk <> 'N'
		 and @FloatChk <> 'N'
		 and @WireSpecChk <> 'N'
		 and @WireSizeChk <> 'N'
		 and @PlusChk <> 'N'

	     set @FinChk = 'Y'


	  -- 寫入檢核資料
      INSERT INTO [dbo].[COP_ProductCheck] (
	  [ChkNo],[ChkSource],[OrderChkNo],[ChkTime],[ProductNo],[ProductName]
      ,[ProductName_EN],[ProductSpec],[ProductSpec_EN],[NoChk],[PHChk]
      ,[HZChk],[StartChk],[VolChk],[FloatChk],[WireSpecChk]
	  ,[WireSizeChk],[PlusChk],[FinChk],[Memo],[aStatus]
	  ,[Creator],[CreateTime] )
	  select
      @ChkNo,@ChkSource,@OrderChkNo,@CreateTime,@InProductNo,@ProductName
	  ,@ProductName_EN,@ProductSpec,@ProductSpec_EN,@NoChk,@PHChk
	  ,@HZChk,@StartChk,@VolChk,@FloatChk,@WireSpecChk
	  ,@WireSizeChk,@PlusChk,@FinChk,@Memo,'Y'
	  ,@Executor,@CreateTime

	   IF (@ChkType = 'P')
	   begin
	     select * from [COP_ProductCheck] where ChkNo = @ChkNo
         SET  @result = 'SUCCESS'
       end
	   else
	   begin
         SET  @result = @FinChk
	   end

       COMMIT


	END TRY

	BEGIN CATCH

		SET  @result = 'error'
		ROLLBACK;

		PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR(MAX));
		PRINT 'Error Message: ' + ERROR_MESSAGE();

    END CATCH


END
GO

-- =============================================
-- Author:		Mars
-- Create date: 20250203
-- Description:	訂單主檔及明細資料檢核
-- Add:20250305 增加可用額度檢核規則
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[prc_COPOrderChk]

@InSource varchar(40), -- 訂單單號來源
@InPoNo varchar(40), -- 訂單單號 單別 + '-' + 單號
@InCustAmt NUMERIC(16,3), -- 客戶訂單金額
@InPaidChk varchar(20), -- 付款確認旗標
@Executor varchar(40), -- 執行人員
@result VARCHAR(40) OUTPUT    --傳回結果



AS
BEGIN


DECLARE

-- 主檔檢核欄位
@TC001 NVARCHAR(20), --單別,
@TC002 NVARCHAR(20), --單號,
@MQ002 NVARCHAR(40), --單別名稱,
@TC003 NVARCHAR(20), --訂單日期,
@TC004 NVARCHAR(20), --客戶代號,
@MA002 NVARCHAR(120), --客戶名稱,
@TC005 NVARCHAR(20), --部門代號,
@TC006 NVARCHAR(20), --業務人員,
@MV002 NVARCHAR(120), --業務名稱,
@TC010 NVARCHAR(120), --送貨地址,
@TC014 NVARCHAR(120), --付款條件,
@TC016 NVARCHAR(10), --課稅別,
@TC019 NVARCHAR(10), --運輸方式,
@TC008 NVARCHAR(10), --幣別,
@TC009 NUMERIC(16,3), --匯率,
@TC029 NUMERIC(16,3), --訂單金額,
@TC031 NUMERIC(16,3), --總數量,
@TC038 NVARCHAR(120), --PACKINGLIST備註,
@TD013 NVARCHAR(20), --預交日,
@TA033 NVARCHAR(120), -- 計劃批號,
@TC012 NVARCHAR(120), --客戶單號,
@TC068 NVARCHAR(10), --交易條件,
@TC020 NVARCHAR(120), --起始港口,
@TC021 NVARCHAR(120), --目的港口
@TC013 NVARCHAR(40), -- 價格條件
@FileName NVARCHAR(120),
@Rate NUMERIC(16,3), --匯率設定數值,


-- 主檔檢核結果
@SumAmt	NUMERIC(16,3),
@SumQty	NUMERIC(16,3),
@DepChk NVARCHAR(20) = 'Y',
@DepBlankChk NVARCHAR(20) = 'Y',
@PackListBlankChk NVARCHAR(20) = 'Y',
@PriceBlankChk NVARCHAR(20) = 'Y',
@PreDateChk NVARCHAR(20) = 'Y',
@CustSumAmtChk NVARCHAR(20) = 'Y',
@CustAmtZeroChk NVARCHAR(20) = 'Y',
@CustPOChk NVARCHAR(20) = 'Y',
@TransChk NVARCHAR(20) = 'Y',
@TradeChk NVARCHAR(20) = 'Y',
@OutPortChk	 NVARCHAR(20) = 'Y',
@InPortChk NVARCHAR(20) = 'Y',
@ProductNoChk_M NVARCHAR(20) = 'Y',
@UpFileChk NVARCHAR(20) = 'Y',
@DetailChk NVARCHAR(20) = 'Y',
@RateChk NVARCHAR(20) = 'Y',
@PaidChk NVARCHAR(20) = 'Y', --是否已付款
@AvailableChk NVARCHAR(20) = 'Y',
@Credit30WChk NVARCHAR(20) = 'Y',
@FinChk_M NVARCHAR(20),
@Memo_M NVARCHAR(500),

-- 訂單明細項目檢核欄位
@TD001 NVARCHAR(20), --單別,
@TD002 NVARCHAR(20), --單號,
@TD003 NVARCHAR(20), --序號,
@TD004 NVARCHAR(20), --品號,
@TD005 NVARCHAR(120), --品名,
@TD006 NVARCHAR(120), --規格,
@TD008 NUMERIC(16,3), --訂單數量,
@TD010 NVARCHAR(20), --單位,
@TD011 NUMERIC(16,3), --外幣單價,
@TD012 NUMERIC(16,3), --外幣金額,
@TD017 NVARCHAR(20), --前置單別,
@TD018 NVARCHAR(20), --前置單號,
@TD019 NVARCHAR(20), --前置序號,
@TB007 NUMERIC(16,3), --前置數量,
@TB009 NUMERIC(16,3), --前置單價,
@ProcessCode NVARCHAR(20), --流程代號, 20260518 加入

@PreDate_D NVARCHAR(20), --預交日
@FinFlag_D NVARCHAR(20), --訂單明細完成旗標


-- 明細項目檢核結果
@ProductNoChk NVARCHAR(10),
@QtyChk NVARCHAR(10),
@AmtChk NVARCHAR(10),
@PriceChk NVARCHAR(20),
@PackListChk NVARCHAR(20),

@LinkTypeChk NVARCHAR(10),
@LinkNoChk NVARCHAR(10),
@LinkSNoChk NVARCHAR(10),
@LinkQtyChk NVARCHAR(10),
@LinkPriceChk NVARCHAR(10),
@LinkChk NVARCHAR(10),
@MOQAmtChk NVARCHAR(10),
@LinkMOQAmtChk NVARCHAR(10),
@ProcessCodeChk NVARCHAR(10),

@ByQtyFlag NVARCHAR(10),
@ByQtyPrice numeric (16,3) = 0,

@FinChk_D NVARCHAR(10),
@Memo_D NVARCHAR(500),


@PLDate VARCHAR(12), -- PACKING LIST 日期

@PriceDate VARCHAR(12), -- 價格條件日期

@ChkNo varchar(20),
@OrderChkNo varchar(20),

@RET VARCHAR(50),

-- 信用額度相關金額
@NotifyAmt numeric (16,3) = 0, --  訂貨(出貨通知)金額
@OrderAmt numeric (16,3) = 0, --  未出貨訂單總金額
@OrderAmtRate numeric (16,6) = 0, --  未出貨訂單金額比率
@ReceivableSumAmt numeric (16,3) = 0, --  應收合計金額
@ReceivableAmt numeric (16,3) = 0, --  應收金額
@GainAmt numeric (16,3) = 0, --  已出貨抵預收金額
@UnbilledAmt numeric (16,3) = 0, --  未結帳銷貨
@PreGainAmt numeric (16,3) = 0, --  預收金額
@AvailableAmt numeric (16,3) = 0, --  信用餘額
@AvailableSetAmt numeric (16,3) = 0, --  設定額度金額

@CreateTime datetime


  SET @CreateTime = GETDATE()

  BEGIN TRANSACTION
  --開啟交易

    BEGIN TRY


	-- 檢核訂單是否存在 暫先不做防呆

	-- 取得訂單主檔記錄資料
	SELECT
	  @TC001 = 單別,@MQ002 = 單別名稱,@TC005 = 部門代號, @TC038 = [PACKINGLIST備註], @TC029 = 訂單金額, @TC031 = 總數量, @TC012 = 客戶單號,
	  @TC003 = 訂單日期,@TC019 = 運輸方式, @TC068 = 交易條件, @TC020 = 起始港口, @TC021 = 目的港口,  @TC013  = 價格條件, @TC008 = 幣別,
	  @TC009 = 匯率, @FileName  = 附件檔案,@TC004 = 客戶代號,@ProcessCode = 流程代號
    FROM V_POList
	where 1=1
	and COP_Source = @InSource
	and 單別 + '-' + 單號 = @InPoNo

	set @DepChk = 'Y'
	set @DepBlankChk = 'Y'
	set @PackListBlankChk = 'Y'
	set @PriceBlankChk = 'Y'
	set @CustSumAmtChk = 'Y'
	set @CustAmtZeroChk = 'Y'
	set @CustPOChk = 'Y'
	set @TransChk = 'Y'
	set @TradeChk = 'Y'
	set @OutPortChk = 'Y'
	set @InPortChk = 'Y'
	set @PreDateChk = 'Y'
	set @ProductNoChk_M = 'Y'
	set @UpFileChk = 'Y'
	set @RateChk = 'Y'
	set @PaidChk = 'Y'
	set @AvailableChk = 'Y'
	set @Credit30WChk = 'Y'
	set @ProcessCodeChk = 'Y'
	set @FinChk_M = 'N'
	set @Memo_M = ''

	set @DetailChk = 'Y'

	-- 檢核訂單主檔資料
	  --  1.部門不得空白,和單別要對應
	  if (@TC005= '')
	  begin
	    set @DepBlankChk = 'N'
	  end
	  else if not EXISTS(select * from COP_DepData where OrderType = @TC001 and DepNo = @TC005)
	  begin
	    set @DepChk = 'N'
	  end

	  --  2.日期注意事項
	  --  PACKING LIST備註 前四碼為月日<出貨月日(明細的預交日)
	  --  詢問單 不檢核
      -- 取當天日期年份可能會出現錯誤,改為取訂單日期的年份
	  set @PLDate = SUBSTRING(@TC003,1,4) + SUBSTRING(@TC038,1,4)

	  print '@PLDate : '+@PLDate
	  if ((@TC001 not in ('2700','2200')) and (@MQ002 not like '%詢問單%') )
	  begin
		  if (@TC038= '')
		  begin
			set @PackListBlankChk = 'N'
		  end
      end

      --  3.主檔價格條件 = 明細檔預交日
	  --    @.不可為空白
	  --    @.詢問單不檢核

		-- 設置語言為英文以解析英語日期格式
		SET LANGUAGE English;

		set @PriceDate = '0000'

		BEGIN TRY
			-- 確保 @TC013 是有效日期才轉換
			IF ISDATE(@TC013) = 1
				SET @PriceDate = CONVERT(varchar(12), CONVERT(DATETIME, @TC013), 112);
			ELSE
				THROW 50001, '日期格式錯誤: @TC013 不是有效日期', 1;
		END TRY
		BEGIN CATCH
			PRINT @PriceDate + ' 轉換錯誤';
			PRINT ERROR_MESSAGE();
			-- 繼續執行不拋出錯誤
		END CATCH;

		-- 設置語言回中文
		SET LANGUAGE 繁體中文;

		print @PriceDate

	  if ((@TC001 not in ('2700','2200')) and (@MQ002 not like '%詢問單%') )
	  begin
		  if (@TC013= '')
		  begin
			set @PriceBlankChk = 'N'
		  end
      end

	  --  4.判斷客人訂單金額≦ERP訂單金額
	  if (@InCustAmt = 0)
	  begin
	    set @CustAmtZeroChk = 'W'
	  end
	  ELSE if (@InCustAmt > @TC029)
	  begin
	    set @CustSumAmtChk = 'N'
	  end

   --  5.客戶單號不得為空白
      if (@TC012= '')
	  begin
	    set @CustPOChk = 'N'
	  end

   --  6.運輸方式 不得為空白
      if (@TC019= '')
	  begin
	    set @TransChk = 'N'
	  end

   --  7.交易條件 不得為空白
      if (@TC068= '')
	  begin
	    set @TradeChk = 'N'
	  end

   --  8.出口港 不得為空白
      if ((@TC020= '') AND (@InSource = '浦瑞ERP') AND (@TC001 <> '2210'))
	  begin
	    set @OutPortChk = 'N'
	  end

   --  9.目的地港 不得為空白
      if ((@TC021= '') AND (@InSource = '浦瑞ERP') AND (@TC001 <> '2210'))
	  begin
	    set @InPortChk = 'N'
	  end

   -- 10.訂單明細不可有多個預交日期
      if exists(select 單別,單號 ,COUNT(*) 筆數 FROM V_POList where COP_Source = @InSource AND 單別 + '-' + 單號 = @InPoNo group by COP_Source,單別,單號 having COUNT(*) > 1)
	  begin
	    set @PreDateChk = 'N'
	  end

   --  11.附件檔案必需上傳
	  if ((@TC001 not in ('2700','2200')) and (@MQ002 not like '%詢問單%') )
		  if not exists(SELECT * FROM [V_UpFileData] where KeyValues = @InPoNo)
		  begin
			set @UpFileChk = 'N'
		  end


   -- 12.檢核匯率
   -- @TC008 = 幣別, @TC009 = 匯率
      set @Rate = 0
      if (@InSource = '浦瑞ERP')
	  begin
		SELECT @Rate = MG003 FROM [192.168.1.200].TWPR.dbo.CMSMG
		WHERE 1=1
		AND MG001 = @TC008
		AND MG002 =(
		SELECT MAX(MG002) MG002 FROM [192.168.1.200].TWPR.dbo.CMSMG
		WHERE 1=1
		AND MG001 = @TC008)
	  end
	  else
      begin
		SELECT @Rate = MG003 FROM [192.168.1.200].PRORIL.dbo.CMSMG
		WHERE 1=1
		AND MG001 = @TC008
		AND MG002 =(
		SELECT MAX(MG002) MG002 FROM [192.168.1.200].PRORIL.dbo.CMSMG
		WHERE 1=1
		AND MG001 = @TC008)
	  end

	  IF (@Rate <> @TC009)
	  begin
	    set @RateChk = 'N'
	  end


      print 'exec prc_COPGetCredit'

	  -- 呼叫[prc_COPGetCredit] 取得相關金額
	  -- 建立暫存表來存放結果
	  CREATE TABLE #TempCreditData (
		應收金額 numeric (16,3), --  ReceivableAmt
		未結帳銷貨  numeric (16,3), -- UnbilledAmt
		訂貨出貨通知金額  numeric (16,3), -- NotifyAmt
		預收金額  numeric (16,3), --  PreGainAmt
		已出貨抵預收金額  numeric (16,3), --  GainAmt
		應收合計金額  numeric (16,3), -- ReceivableSumAmt
	    未出貨訂單總金額  numeric (16,3), -- OrderAmt
		未出貨訂單金額比率  numeric (16,6), -- OrderAmtRate
		信用可超出額  numeric (16,3), -- AvailableSetAmt
		信用餘額  numeric (16,3) --  AvailableAmt
        );

	  INSERT INTO #TempCreditData
	  exec prc_COPGetCredit @TC004, @Executor

	  select @ReceivableAmt = 應收金額,@UnbilledAmt = 未結帳銷貨,@NotifyAmt = 訂貨出貨通知金額,@PreGainAmt = 預收金額,@GainAmt = 已出貨抵預收金額,
		     @ReceivableSumAmt = 應收合計金額,@OrderAmt = 未出貨訂單總金額,@OrderAmtRate = 未出貨訂單金額比率,
		     @AvailableSetAmt = 信用可超出額,@AvailableAmt = 信用餘額 FROM #TempCreditData


      -- 清除暫存表
	  DROP TABLE #TempCreditData;


      -- 13.檢核信用額度
	  IF ((@TC029 > @AvailableAmt) AND (@InSource = '浦瑞ERP')  and (@TC004 not like '101%'))
	  begin
	    set @AvailableChk = 'N'
	  end

     -- 14.檢核101信用額度不可超過30W
     --    未出貨訂單總金額 - 已出貨抵預收金額  + 待檢核的[訂單金額] <= 30W
	  IF ((@TC004 like '101%') AND (@InSource = '浦瑞ERP'))
	  begin
		print '@OrderAmt - @GainAmt + @TC029 = ' + CAST(@OrderAmt - @GainAmt + @TC029 AS VARCHAR(100))
	    if (@OrderAmt - @GainAmt + @TC029 >= 300000)
		begin
	      set @Credit30WChk = 'N'
        end
	  end


	  print '@TC008' + ': ' + @TC008 +'--@@TC004' + ': ' + @TC004 +'--@@ProcessCode' + ': ' + @ProcessCode
	  -- 20260518 增加檢核流程代號檢核
		--15.訂單當中對應幣別的流程代號是否正確
		--  1.幣別EUR，對應流程代號E2
		--  2.幣別USD，對應流程代號U2
		--  3.但幣別USD，客戶代號是501開頭的，對應流程代號A3
		--  4.幣別AUD，對應流程代號A2
	  IF (not (@TC008 = 'EUR' and @ProcessCode = 'E2')) and
	     (not (@TC008 = 'USD' and @ProcessCode = 'U2')) and
	     (not (@TC008 = 'USD' and @TC004 like '501%' and @ProcessCode = 'A3')) and
	     (not (@TC008 = 'AUD' and @ProcessCode = 'A2'))
	  begin
	    print '流程代號檢核  ' + @InPoNo
		  -- 20260525 國外訂單以及單別為 2702 2705 2706  才需要檢核
	    if (@InSource = '浦瑞ERP') and (@TC001 in ('2702','2705','2706'))
		  set @ProcessCodeChk = 'N'
	  end


	  print '@OrderAmt' + CAST(@OrderAmt AS VARCHAR(100))
	  print '@GainAmt' + CAST(@GainAmt AS VARCHAR(100))

	-- 寫入檢核結果到[COP_PoCheck]
	-- 取得檢核序號
	SELECT @OrderChkNo = CASE WHEN MAX(OrderChkNo) IS NULL THEN ISNULL(MAX(OrderChkNo),CONVERT(VARCHAR(12),getdate(),112) +
								substring('0000'+convert(varchar(4),1),len(convert(varchar(4),1))+1,4))
		ELSE CONVERT(VARCHAR(12),getdate(),112) + substring('0000'+convert(varchar(4),CONVERT(INT,SUBSTRING(MAX(OrderChkNo),9,4)) + 1),
					len(convert(varchar(3),CONVERT(INT,SUBSTRING(MAX(OrderChkNo),9,4)) + 1))+1,4) END
	FROM COP_PoCheck
	WHERE 1=1
	AND OrderChkNo LIKE CONVERT(VARCHAR(12),getdate(),112)+'%'

	-- 檢核訂單明細資料
	-- 此部份會是一個資料集,以迴圈逐筆檢核
	-- 取得訂單明細資料
	DECLARE CRS CURSOR FOR
	SELECT
	單別,單號,序號,品號,訂單數量,外幣單價,預交日,前置單別,前置單號,前置序號, 前置數量, 前置單價,FinFlag
	FROM V_PODetailList
	WHERE 1=1
	and COP_Source = @InSource
	and 單別 + '-' + 單號 = @InPoNo


	OPEN CRS
	FETCH NEXT FROM CRS INTO @TD001,@TD002,@TD003,@TD004,@TD008,@TD011,@PreDate_D,@TD017,@TD018,@TD019,@TB007,@TB009,@FinFlag_D

	while(@@fetch_status != -1)
	begin

      set @ProductNoChk = 'Y'
      set @QtyChk = 'Y'
      set @AmtChk = 'Y'
	  set @PackListChk = 'Y'
	  set @PriceChk = 'Y'
	  set @LinkTypeChk = 'Y'
	  set @LinkNoChk = 'Y'
	  set @LinkSNoChk = 'Y'
	  set @LinkQtyChk = 'Y'
	  set @LinkPriceChk = 'Y'
	  set @LinkChk = 'Y'
	  set @MOQAmtChk = 'Y'
	  set @LinkMOQAmtChk = 'Y'
      set @FinChk_D = 'N'
      set @Memo_D = ''


    --明細檢核規則:
      --  1.品號正確性,中英文品名及規格內容是否符合邏輯
	  IF ((@TD004 LIKE '5%') AND (@TD004 NOT LIKE '58%'))
	  begin
        EXEC prc_ProductChk_COP @OrderChkNo,@InPoNo,@InSource,@TD004,@Executor,@RET OUTPUT

        if (@RET = 'N')
		begin
		  set @ProductNoChk = 'N'
		end
	  end

      --  2.訂單數量≠0
	  if (@TD008 = 0)
	  begin
	    set @QtyChk = 'N'
	  end

      --  3.單價≠0
	  if (@TD011 = 0)
	  begin
	    set @AmtChk = 'N'
	  end

		  print '@PLDate ' + @PLDate
		  print '@PreDate_D ' + @PreDate_D

	  if ((@TC001 not in ('2700','2200')) and (@MQ002 not like '%詢問單%') )
	  begin

		  print '@@TC001 ' + @TC001

		  if (@PLDate >= @PreDate_D)
		  begin
			set @PackListChk = 'N'
    		print '@PackListChk ' + @PackListChk
		  end


		  if (@PriceDate <> @PreDate_D)
		  begin
			set @PriceChk = 'N'
		  end
      end

	  ---------------------------------------------------------------------------------
	  -- 20250603 Mars
	  -- 分量計價檢核
	  -- 取得此客戶及品號是否有分量計價設定

	  -- 檢核訂單單價
	  Set @ByQtyPrice = @TD011
	  SELECT @ByQtyPrice = min(ByQtyPrice) FROM  V_COPMOQ
      WHERE 1=1
	  and ByQtyFlag = 'Y'
	  and CustomerNo = @TC004
	  and ProductNo = @TD004
	  and Qty <= @TD008

	  if (@ByQtyPrice <> @TD011)
	  begin
    	set @MOQAmtChk = 'N'
	  end

	  -- 檢核報價單單價
	  Set @ByQtyPrice = @TB009
	  SELECT @ByQtyPrice = min(ByQtyPrice) FROM  V_COPMOQ
      WHERE 1=1
	  and ByQtyFlag = 'Y'
	  and CustomerNo = @TC004
	  and ProductNo = @TD004
	  and Qty <= @TB007

	  if (@ByQtyPrice <> @TB009)
	  begin
    	set @LinkMOQAmtChk = 'N'
	  end


	  -- 20250314 前置單據相關檢核
	  if ((@TC001 not in ('2700','2200')) and (@MQ002 not like '%詢問單%') )
	  begin
		  if (isnull(@TD017,'') = '')
		  begin
			set @LinkTypeChk = 'N'
		  end

		  if (isnull(@TD018,'') = '')
		  begin
			set @LinkNoChk = 'N'
		  end

		  if (isnull(@TD019,'') = '')
		  begin
			set @LinkSNoChk = 'N'
		  end

		  if (isnull(@TB007,0) <> @TD008)
		  begin
			set @LinkQtyChk = 'W'
		  end

		  if (isnull(@TB009,0) <> @TD011)
		  begin
			set @LinkPriceChk = 'W'
		  end

		  if (@TB007 is null)
		  begin
			set @LinkChk = 'N'
		  end
      end

	-- 寫入檢核結果到[COP_PoDetailCheck]

		if @ProductNoChk = 'Y' and
		 @QtyChk = 'Y' and
		 @AmtChk = 'Y' and
		 @PackListChk = 'Y' and
		 @PriceChk = 'Y' and

		 @LinkTypeChk = 'Y' and
		 @LinkNoChk = 'Y' and
		 @LinkSNoChk = 'Y' and
		 @LinkQtyChk in ('Y','W') and
		 @LinkPriceChk in ('Y','W') and
		 @LinkChk = 'Y' and
		 @MOQAmtChk = 'Y' and
		 @LinkMOQAmtChk = 'Y'
        begin
		  set @FinChk_D = 'Y'
        end
		else
		begin
		  set @FinChk_D = 'N'
          set @DetailChk = 'N' -- 主檔的明細項目檢核旗標
		end

	  -- 寫入訂單明細項目檢核資料
      INSERT INTO COP_PoDetailCheck (
        OrderChkNo,ChkTime,COP_Source,PoNo,SNo,ProductNo,
		ProductNoChk,QtyChk,AmtChk,PackListChk,PriceChk,
		LinkTypeChk,LinkNoChk,LinkSNoChk,LinkQtyChk,LinkPriceChk,
		LinkChk,MOQAmtChk,LinkMOQAmtChk,
		FinChk,Memo,aStatus,Creator,CreateTime)
	  select
        @OrderChkNo,@CreateTime,@InSource,@InPoNo,@TD003,@TD004,
		@ProductNoChk,@QtyChk,@AmtChk,@PackListChk,@PriceChk,
		@LinkTypeChk,@LinkNoChk,@LinkSNoChk,@LinkQtyChk,@LinkPriceChk,
		@LinkChk,@MOQAmtChk,@LinkMOQAmtChk,
		@FinChk_D,@Memo_D,'Y',@Executor,@CreateTime

      FETCH NEXT FROM CRS INTO @TD001,@TD002,@TD003,@TD004,@TD008,@TD011,@PreDate_D,@TD017,@TD018,@TD019,@TB007,@TB009,@FinFlag_D

	 end
	 close CRS
	 deallocate CRS

     -- 寫入訂單主檔檢核資料
        set @FinChk_M = 'Y'

		if @DepChk = 'N' or
		 @DepBlankChk = 'N' or
		 @PackListBlankChk = 'N' or
		 @PriceBlankChk = 'N' or
		 @PreDateChk = 'N' or

		 @CustSumAmtChk = 'N' or
		 @CustAmtZeroChk = 'N' or
		 @CustPOChk = 'N' or
		 @TransChk = 'N' or
		 @TradeChk = 'N' or

		 @OutPortChk = 'N' or
		 @InPortChk = 'N' or
		 @UpFileChk = 'N' or
         @DetailChk = 'N' or
		 @RateChk = 'N' or

		 @PaidChk = 'N' or
		 @AvailableChk = 'N' or
 	     @Credit30WChk = 'N' or
		 @ProcessCodeChk = 'N'

         begin
		   set @FinChk_M = 'N'
		 end

print	@DepChk+','+@DepBlankChk+','+@PackListBlankChk+','+@PriceBlankChk+','+@PreDateChk+','+
		@CustSumAmtChk+','+@CustAmtZeroChk+','+@CustPOChk+','+@TransChk+','+@TradeChk+','+
		@OutPortChk+','+@InPortChk+','+@UpFileChk+','+@DetailChk+','+@RateChk+','+
		@InPaidChk+','+@AvailableChk + ','+@Credit30WChk +','+ @ProcessCodeChk +','+ @FinChk_M

print '@FinChk_M:  ' + @FinChk_M



      INSERT INTO COP_PoCheck (
        OrderChkNo,ChkTime,COP_Source,PoNo,SumAmt,SumQty,CustAmt,AvailableAmt,
		DepChk,DepBlankChk,PackListBlankChk,PriceBlankChk,PreDateChk,
		CustSumAmtChk,CustAmtZeroChk,CustPOChk,TransChk,TradeChk,
		OutPortChk,InPortChk,UpFileChk,DetailChk,RateChk,
		PaidChk,AvailableChk,Credit30WChk,ProcessCodeChk,FinChk,Memo,aStatus,
		Creator,CreateTime)
	  select
        @OrderChkNo,@CreateTime,@InSource,@InPoNo,@TC029,@TC031,@InCustAmt,@AvailableAmt,
		@DepChk,@DepBlankChk,@PackListBlankChk,@PriceBlankChk,@PreDateChk,
		@CustSumAmtChk,@CustAmtZeroChk,@CustPOChk,@TransChk,@TradeChk,
		@OutPortChk,@InPortChk,@UpFileChk,@DetailChk,@RateChk,
		@InPaidChk,@AvailableChk,@Credit30WChk,@ProcessCodeChk,@FinChk_M,@Memo_M,'Y',
	    @Executor,@CreateTime

       COMMIT

	   SET  @result = 'SUCCESS'

	END TRY

	BEGIN CATCH

		SET  @result = 'error'
		ROLLBACK;

		PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR(MAX));
		PRINT 'Error Message: ' + ERROR_MESSAGE();

    END CATCH

     PRINT @result

END
GO

-- =============================================
-- Author:		Mars
-- Create date: 20250219
-- Description:	訂單檢核特淮作業
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[prc_COPPassCheck]

@InOrderChkNo varchar(40), -- 訂單檢核序號
@PassItem varchar(40), -- 特淮項目
@PassMemo varchar(500), -- 特淮說明
@Executor varchar(40), -- 執行人員
@result VARCHAR(40) OUTPUT    --傳回結果



AS
BEGIN


DECLARE


@OrderChkNo varchar(40),
@Sno varchar(40),
@PassTime datetime,
@Memo varchar(500),
@aStatus varchar(1),

-- 主檔檢核結果
@SumAmt	NUMERIC(16,3),
@SumQty	NUMERIC(16,3),
@DepChk NVARCHAR(20),
@DepBlankChk NVARCHAR(20),
@PackListBlankChk NVARCHAR(20),
@PriceBlankChk NVARCHAR(20),
@PreDateChk NVARCHAR(20),
@CustSumAmtChk NVARCHAR(20),
@CustAmtZeroChk NVARCHAR(20),
@CustPOChk NVARCHAR(20),
@TransChk NVARCHAR(20),
@TradeChk NVARCHAR(20),
@OutPortChk	 NVARCHAR(20),
@InPortChk NVARCHAR(20),
@UpFileChk NVARCHAR(20),
@RateChk NVARCHAR(20),
@PaidChk NVARCHAR(20),
@AvailableChk NVARCHAR(20),
@Credit30WChk NVARCHAR(20),
@DetailChk NVARCHAR(20),
@FinChk_M NVARCHAR(20),


@RET VARCHAR(50),

@Field NVARCHAR(50),
@Value NVARCHAR(50),
@where NVARCHAR(500),
@statement NVARCHAR(500),

@CreateTime datetime


  SET @CreateTime = GETDATE()

  BEGIN TRANSACTION
  --開啟交易

    BEGIN TRY

	--程式邏輯:
 --     1.將特淮項目檢核旗標改為 P

		set @Field = @PassItem
		set @Value = 'P'
		SET @where = ' WHERE 1 = 1 '

		set @statement = 'update COP_PoCheck set '

		SET @statement = @statement + @Field + ' = ''' + @Value + ''''

		SET @where = @where + ' AND OrderChkNo = '''+@InOrderChkNo +''' '

		set @statement = @statement + @where

		print @where

		print @statement

		EXEC sp_executesql @statement


 --     2.逐項產生[COP_PassCheck]特淮記錄資料

      -- 取得Sno
	  SELECT @Sno = CASE WHEN MAX(Sno) IS NULL THEN '0001'
		ELSE  substring('0000'+ convert(varchar(4),CONVERT(int,MAX(Sno)) + 1 ), LEN(convert(varchar(4),CONVERT(int,MAX(Sno)) + 1 )) +1,4) END
      FROM COP_PassCheck
      WHERE 1=1
      AND OrderChkNo = @InOrderChkNo

      -- 寫入特淮記錄
      INSERT INTO COP_PassCheck (
        OrderChkNo,Sno,PassTime,PassItems,PassMemo,
		Memo,aStatus,Creator,CreateTime)
	  select
        @InOrderChkNo,@Sno,@CreateTime,@PassItem,@PassMemo,
		'','Y',@Executor,@CreateTime

		-- 更新檢核主檔資料

		set @FinChk_M = 'N'

	    select
          @DepChk = DepChk,
          @DepBlankChk = DepBlankChk,
          @PackListBlankChk = PackListBlankChk,
          @PriceBlankChk = PriceBlankChk,
          @PreDateChk = PreDateChk,
          @CustSumAmtChk = CustSumAmtChk,
          @CustAmtZeroChk = CustAmtZeroChk,
          @CustPOChk = CustPOChk,
          @TransChk = TransChk,
          @TradeChk = TradeChk,
          @OutPortChk = OutPortChk,
          @InPortChk = InPortChk,
          @UpFileChk = UpFileChk,
          @RateChk = RateChk,
          @PaidChk = PaidChk,
          @AvailableChk = AvailableChk,
          @Credit30WChk = Credit30WChk,
          @DetailChk = DetailChk
		from COP_PoCheck where OrderChkNo = @InOrderChkNo

     -- 寫入訂單主檔檢核資料
		if @DepChk = 'N' or
		 @DepBlankChk = 'N' or
		 @PackListBlankChk = 'N' or
		 @PriceBlankChk = 'N' or
		 @PreDateChk = 'N' or

		 @CustSumAmtChk = 'N' or
		 @CustAmtZeroChk = 'N' or
		 @CustPOChk = 'N' or
		 @TransChk = 'N' or
		 @TradeChk = 'N' or

		 @OutPortChk = 'N' or
		 @InPortChk = 'N' or
		 @UpFileChk = 'N' or
         @DetailChk = 'N' or
		 @RateChk = 'N' or

		 @PaidChk = 'N' or
		 @AvailableChk = 'N' or
		 @Credit30WChk = 'N'

		  set @FinChk_M = 'N'
		else
          set @FinChk_M = 'Y'

		update COP_PoCheck set FinChk = @FinChk_M
		where OrderChkNo = @InOrderChkNo

       COMMIT

	   SET  @result = 'SUCCESS'



	END TRY

	BEGIN CATCH

		SET  @result = 'error'
		ROLLBACK;

		PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR(MAX));
		PRINT 'Error Message: ' + ERROR_MESSAGE();

    END CATCH

     PRINT @result

END
GO

-- ============================================================
-- 完成。驗證方式（皆為唯讀，不影響資料）：
--   SELECT TOP 5 * FROM Proril_Sales_Center.dbo.V_POList;
--   SELECT * FROM Proril_Sales_Center.dbo.V_COPNoChk;  -- 應該有 22 筆固定對照資料
--   EXEC Proril_Sales_Center.dbo.prc_COPGetCredit @InCustNo = '801CA1', @Executor = 'test';
-- ============================================================
