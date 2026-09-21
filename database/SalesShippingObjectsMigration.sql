/*
 * 銷貨檢索（MixSalesShipApi）相關的資料表 / 預存程序，
 * 從 PRORIL_WEB 搬到 Proril_Sales_Center。
 *
 * 背景：業務議題 8 張表 + M_User/M_Permission/H_FileLink/COP_CheckRule/COP_DepData
 * 已在 Proril_Sales_Center（見 PortingNotes.md）；訂單資料檢核那批由
 * OrderCheckObjectsMigration.sql 負責。這支腳本補上銷貨檢索的部分。
 *
 * 依賴關係是把三支預存程序的定義逐行讀過、並用 sys.sql_expression_dependencies
 * 交叉確認得出的：
 *   - 1 張表：COP_SalesOrder（ERP 銷貨單明細快取，也是兩支查詢 SP 的結果集形狀）。
 *   - 3 個預存程序：prc_QuerySalesOrder（依品號 TH004 分群）、
 *     prc_QuerySalesOrder_1（依銷貨單 TH001+TH002 分群）、
 *     prc_ImportSalesOrder（從鼎新 ERP 增量補 COP_SalesOrder，前兩支進來第一件事就是叫它）。
 *   - 0 個 View、0 個函式。
 *
 * 特別注意：
 *   1. **prc_ImportSalesOrder 裡有兩處寫死 `PRORIL_WEB.dbo.COP_SalesOrder`**
 *      （判斷「這筆 ERP 銷貨單有沒有匯入過」的 LEFT JOIN）。這支腳本已經把那兩處
 *      改成不帶資料庫名稱的 `dbo.COP_SalesOrder`，讓它讀寫自己所在資料庫的表。
 *      沒改的話，搬過來之後會拿新庫的空表去跟舊庫比對，導致重複匯入或整批不匯入。
 *   2. **`PRORIL_WEB.dbo.NPS_D_Order` 的參照刻意保留**（銘版序號 SerialNosJson 的來源）。
 *      那張表屬於別的模組（1.0 的 sp_ImportPurchaseOrder / sp_UpdatePurchaseOrder /
 *      prc_ReImportTestOrder 在寫，V_UnfinOrder 在讀），這次不搬。兩個資料庫在同一個
 *      SQL Server instance，三段式跨庫查詢可行，所以維持現狀是對的；哪天 NPS_D_Order
 *      也搬過來，記得回頭把這兩處的資料庫前綴拿掉。
 *      （NPS_D_Order 的 JOIN 條件不用動：它跟 ERP 欄位都是 Chinese_Taiwan_Stroke_BIN。）
 *   3. **`dbo.COP_SalesOrder CSO` 的 JOIN 條件加了 `COLLATE DATABASE_DEFAULT`**（原本沒有），
 *      就是第 1 點那兩處判斷「匯入過沒有」的 LEFT JOIN。原因是兩個資料庫的定序不同：
 *      `PRORIL_WEB` 是 Chinese_Taiwan_Stroke_BIN，`Proril_Sales_Center` 是
 *      SQL_Latin1_General_CP1_CI_AS（見 PortingNotes.md「為什麼有 7 個欄位型別跟來源不一樣」）。
 *      linked server `[192.168.1.200]` 的 `collation compatible` 是 off、沒指定
 *      collation name，ERP 欄位沿用遠端的 Chinese_Taiwan_Stroke_BIN；在 PRORIL_WEB 底下
 *      兩側剛好相同，搬到新庫就變成本地 Latin1 對 ERP Chinese_Taiwan_Stroke_BIN，
 *      **`CREATE PROCEDURE` 當場**就報 Msg 468 collation conflict（不是執行時才爆，
 *      因為參照的物件都存在、沒有延後解析可言）。加 COLLATE DATABASE_DEFAULT 把 ERP 那一側
 *      對齊當前資料庫，在兩個庫底下都成立。
 *      **副作用**：這三個欄位的比對從 BIN（區分大小寫）變成 CI（不分大小寫）。
 *      比對鍵是銷貨單別+單號+序號這種英數代號，實務上不會有只差大小寫的兩筆，但要知道。
 *
 *      以上 1、3 兩點是這支腳本對邏輯做的**全部**修改，其餘與來源一字不差。
 *   4. **這幾支 SP 會寫資料**：查詢端點看起來是唯讀，其實 prc_QuerySalesOrder(_1) 進來
 *      就先 EXEC prc_ImportSalesOrder，對 COP_SalesOrder 做 INSERT + 去重 DELETE。
 *      切連線之後，查詢寫進去的是新庫、1.0 那邊仍寫舊庫，兩邊的快取表從此各自成長
 *      （內容都是從同一份 ERP 拉的，不影響正確性，只是不會互相同步）。
 *   5. **COP_SalesOrder 在 PRORIL_WEB 還有一個讀者：`V_SalesTotal`**（1.0 的
 *      MixSalesShipApi/GetSalesTotal 客戶頁籤在用，2.0 還沒搬那支）。它留在 PRORIL_WEB
 *      讀舊庫的快取表，不受這次搬移影響；等那支也搬過來時要一併處理。
 *   6. 欄位型別是直接查 PRORIL_WEB 當下的 sys.columns 得出的，不是照 1.0 的 EF scaffold 抄。
 *   7. CREATE PROCEDURE 全部改成 CREATE OR ALTER，可重複執行；CREATE TABLE 用
 *      IF OBJECT_ID(...) IS NULL 防呆；資料複製區塊在表已經有資料時自動跳過。
 *
 * 怎麼執行：走 database/scripts/run-objects-migration.ps1，不要直接把檔案丟進 SSMS
 * 執行（檔案是 UTF-8 無 BOM，下面 prc_ImportSalesOrder 裡有 '浦瑞ERP'/'芳晟ERP' 這種
 * 中文字串常值，用錯編碼開會變亂碼寫進資料；那支 ps1 一律用 sqlcmd -f 65001）：
 *
 *   .\scripts\run-objects-migration.ps1 -Script SalesShippingObjectsMigration.sql -Environment snapshot
 *   .\scripts\run-objects-migration.ps1 -Script SalesShippingObjectsMigration.sql -Environment snapshot -Execute
 *
 * 不加 -Execute 只做檢查：目標庫與這裡的 USE 對帳、linked server 在不在、
 * 物件現況、SET PARSEONLY ON 驗語法。
 *
 * 執行前建議：
 *   - 確認連到的是 Proril_Sales_Center（192.168.1.142,50002），不是 PRORIL_WEB。
 *   - 確認 instance 上的 linked server [192.168.1.200] 可用（prc_ImportSalesOrder 靠它
 *     查鼎新 ERP 的 PRORIL / TWPR 兩個資料庫）。
 *   - 三支 SP 共 700 多行，內容未經改寫（除了上面第 1、3 點），執行前建議自己再核對一次：
 *     SELECT OBJECT_DEFINITION(OBJECT_ID('PRORIL_WEB.dbo.prc_QuerySalesOrder'))
 */

USE Proril_Sales_Center;
GO

-- ============================================================
-- 1. 資料表（結構）
-- ============================================================

IF OBJECT_ID('dbo.COP_SalesOrder') IS NULL
BEGIN
    CREATE TABLE dbo.[COP_SalesOrder] (
        [ID]             int IDENTITY(1,1) NOT NULL,
        [COP_Source]     nvarchar(10) NULL CONSTRAINT [DF_COP_SalesOrder_COP_Source] DEFAULT (''),
        [TG003]          nvarchar(50) NULL CONSTRAINT [DF_COP_SalesOrder_TH0011] DEFAULT (''),
        [TH001]          nvarchar(50) NOT NULL CONSTRAINT [DF_COP_SalesOrder_TH001] DEFAULT (''),
        [TH002]          nvarchar(50) NOT NULL,
        [TH003]          nvarchar(50) NOT NULL,
        [TH004]          nvarchar(40) NULL,
        [TH005]          nvarchar(120) NULL,
        [TH006]          nvarchar(120) NULL,
        [TH009]          nvarchar(6) NULL,
        [TH007]          nvarchar(10) NULL,
        [TH008]          numeric(16, 3) NULL,
        [SumQty]         numeric(16, 3) NULL CONSTRAINT [DF_COP_SalesOrder_SumQty] DEFAULT ((0)),
        [TH012]          numeric(21, 6) NULL,
        [TH013]          numeric(21, 6) NULL,
        [TG011]          nvarchar(4) NULL,
        [TG012]          numeric(16, 3) NULL,
        [TH037]          numeric(21, 6) NULL,
        [TH038]          numeric(21, 6) NULL,
        [SumAmt]         numeric(21, 6) NULL CONSTRAINT [DF_COP_SalesOrder_SumAmt] DEFAULT ((0)),
        [TH024]          numeric(16, 3) NULL,
        [TH014]          nvarchar(4) NULL,
        [TH015]          nvarchar(11) NULL,
        [TH016]          nvarchar(4) NULL,
        [TH018]          nvarchar(255) NULL CONSTRAINT [DF_COP_SalesOrder_TH018] DEFAULT (''),
        [TC012]          nvarchar(20) NULL CONSTRAINT [DF_COP_SalesOrder_TH0181] DEFAULT (''),
        [SerialNosJson]  nvarchar(max) NULL,
        [TA001]          nchar(4) NULL,
        [TA002]          nchar(11) NULL,
        [PlanNumber]     nvarchar(40) NULL,
        [TA026]          nvarchar(4) NULL,
        [TA027]          nvarchar(11) NULL,
        [TA028]          nvarchar(4) NULL,
        [SerialNosJson1] nvarchar(max) NULL,
        [TA0011]         nchar(4) NULL,
        [TA0021]         nchar(11) NULL,
        [PlanNumber1]    nvarchar(40) NULL,
        [CustomerNo]     varchar(20) NULL,
        [CustomerName]   nvarchar(80) NULL,
        [Memo]           nvarchar(500) NULL,
        [FooterFlag]     varchar(1) NULL CONSTRAINT [DF_COP_SalesOrder_FooterFlag] DEFAULT (''),
        [aStatus]        varchar(1) NULL,
        [Creator]        nvarchar(40) NULL,
        [CreateTime]     datetime NULL,
        [Modifier]       nvarchar(40) NULL,
        [ModiTime]       datetime NULL,
        CONSTRAINT [PK_COP_SalesOrder] PRIMARY KEY CLUSTERED ([ID] ASC)
    );
END
GO

-- ============================================================
-- 2. 資料複製（只在新表是空的時候跑）
--
-- COP_SalesOrder 是快取表，理論上清空後讓 prc_ImportSalesOrder 自己從 ERP 重拉也會長回來，
-- 但那會變成一次全量匯入（ERP 端幾年份的銷貨單），而且 PlanNumber / SerialNosJson 這些
-- 是匯入當下的 ERP 狀態、事後不一定重現得出來，所以照樣把既有資料整批複製過來。
-- ============================================================

IF OBJECT_ID('dbo.COP_SalesOrder') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.COP_SalesOrder)
BEGIN
    SET IDENTITY_INSERT dbo.COP_SalesOrder ON;

    INSERT INTO dbo.COP_SalesOrder (
        [ID], [COP_Source], [TG003], [TH001], [TH002], [TH003], [TH004], [TH005], [TH006],
        [TH009], [TH007], [TH008], [SumQty], [TH012], [TH013], [TG011], [TG012], [TH037],
        [TH038], [SumAmt], [TH024], [TH014], [TH015], [TH016], [TH018], [TC012],
        [SerialNosJson], [TA001], [TA002], [PlanNumber], [TA026], [TA027], [TA028],
        [SerialNosJson1], [TA0011], [TA0021], [PlanNumber1], [CustomerNo], [CustomerName],
        [Memo], [FooterFlag], [aStatus], [Creator], [CreateTime], [Modifier], [ModiTime])
    SELECT
        [ID], [COP_Source], [TG003], [TH001], [TH002], [TH003], [TH004], [TH005], [TH006],
        [TH009], [TH007], [TH008], [SumQty], [TH012], [TH013], [TG011], [TG012], [TH037],
        [TH038], [SumAmt], [TH024], [TH014], [TH015], [TH016], [TH018], [TC012],
        [SerialNosJson], [TA001], [TA002], [PlanNumber], [TA026], [TA027], [TA028],
        [SerialNosJson1], [TA0011], [TA0021], [PlanNumber1], [CustomerNo], [CustomerName],
        [Memo], [FooterFlag], [aStatus], [Creator], [CreateTime], [Modifier], [ModiTime]
    FROM PRORIL_WEB.dbo.COP_SalesOrder;

    SET IDENTITY_INSERT dbo.COP_SalesOrder OFF;
END
GO

-- ============================================================
-- 3. 預存程序：prc_ImportSalesOrder
--    （與來源的差異：兩處 PRORIL_WEB.dbo.COP_SalesOrder 改成 dbo.COP_SalesOrder，
--      同兩處的 JOIN 條件加 COLLATE DATABASE_DEFAULT，見檔頭第 1、3 點）
-- ============================================================





-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[prc_ImportSalesOrder]

@Executor varchar(40), -- 執行人員
@result VARCHAR(50) OUTPUT  --傳回結果

AS
BEGIN
DECLARE 

@aStatus varchar(1),
@Creator varchar(40), 
@CreateTime datetime

SET @Creator = 'ImportSalesOrder'

if (@Executor <> '')
  SET @Creator = @Executor


SET @CreateTime = GETDATE()

  --開啟交易
  BEGIN TRANSACTION;
    BEGIN TRY

	    -- 匯入國外銷貨單資料
        insert into COP_SalesOrder (COP_Source,TG003,
		TH001,TH002,TH003,TH004,TH005,
		TH006,TH009,TH007,TH008,TH012,
		TH013,TG011,TG012,TH037,TH038,
		TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
		TA001,TA002,PlanNumber,CustomerNo,CustomerName,
		Memo,aStatus,Creator,CreateTime)

		SELECT DISTINCT '浦瑞ERP' COP_Source,TG.TG003 銷貨日期,
		TH.TH001 銷貨單別,TH.TH002 銷貨單號,TH.TH003 銷貨序號,TH.TH004 品號,TH.TH005 品名,
		TH.TH006 規格,TH.TH009 單位,TH.TH007 倉別,TH.TH008 數量,TH.TH012 單價,
		TH.TH013 金額,TG.TG011 幣別,TG.TG012 匯率,TH.TH037 本幣未稅金額,TH.TH038 本幣稅額,
		TH.TH024 贈品數量,TH.TH014 訂單單別,TH.TH015 訂單單號,TH.TH016 訂單序號,TH.TH018 備註, TC.TC012 客戶單號, NULL 銘版序號,
		'' 製令單別,'' 製令單號,RTRIM(TA.TA033) AS PlanNumber,TG.TG004 as 客戶代號,MA.MA002 as 客戶名稱,
		'','Y',@Creator,@CreateTime--,*
		--  select *
		FROM [192.168.1.200].TWPR.dbo.COPTH TH
--		LEFT JOIN [192.168.1.200].PBS.dbo.OrderDTB TB ON TB.OrderNo = rtrim(TH.TH014+'-'+TH.TH015) AND TB.OrderSeq = TH.TH016
        -- 2026-09-21 註解掉：PRORIL_WEB.dbo.NPS_D_Order 的跨庫 JOIN 在部分環境（51002）執行帳號
        -- 對 PRORIL_WEB 沒有 SELECT 權限會直接失敗；SerialNosJson 改由 SerialNoSyncHostedService
        -- 排程另外補寫，見 api/Services/SerialNoSyncHostedService.cs。
        -- LEFT join PRORIL_WEB.dbo.NPS_D_Order TB on TB.OrderType+'-'+ rtrim(TB.OrderNo)+TB.OrderSno = TH.TH014 + '-'+ RTRIM(TH.TH015) + TH.TH016
-- 		LEFT JOIN [192.168.1.200].PRORIL.dbo.MOCTA TA ON TH.TH014 = TA.TA026 and TH.TH015 = TA.TA027 and TH.TH016 = TA.TA028 AND TH.TH004 = TA.TA006 AND TA.TA013 ='Y' AND  TA.TA011 = 'Y'-- 製令單 AND  TA.TA011 <> 'y'
		LEFT JOIN (SELECT DISTINCT TA001,TA002,TA026,TA027,TA028,TA006,TA033 FROM [192.168.1.200].PRORIL.dbo.MOCTA WHERE TA013 ='Y' AND  TA011 = 'Y') TA ON TH.TH014 = TA.TA026 and TH.TH015 = TA.TA027 and TH.TH016 = TA.TA028 AND TH.TH004 = TA.TA006
		LEFT JOIN [192.168.1.200].PRORIL.dbo.COPTC TC ON TC.TC001 = TH.TH014 AND TC.TC002 = TH.TH015
		LEFT JOIN [192.168.1.200].TWPR.dbo.COPTG TG ON TG.TG001 = TH.TH001 AND TG.TG002 = TH.TH002 
		LEFT JOIN [192.168.1.200].TWPR.dbo.COPMA MA ON MA.MA001 = TG.TG004
		LEFT JOIN dbo.COP_SalesOrder CSO ON CSO.TH001 = TH.TH001 COLLATE DATABASE_DEFAULT and CSO.TH002 = TH.TH002 COLLATE DATABASE_DEFAULT and CSO.TH003 = TH.TH003 COLLATE DATABASE_DEFAULT
		WHERE 1=1
		AND TH.TH020 = 'Y'
		AND TH.TH001 LIKE '28%'
		AND CSO.TH001 IS NULL
		--AND TA.TA001 IS NULL -- 查無製令及訂單的浦瑞銷貨單
		--AND TG.TG001 IS not NULL
		order by TH.TH001,TH.TH002,TH.TH003


	    -- 匯入國內銷貨單資料
        insert into COP_SalesOrder (COP_Source,TG003,
		TH001,TH002,TH003,TH004,TH005,
		TH006,TH009,TH007,TH008,TH012,
		TH013,TG011,TG012,TH037,TH038,
		TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
		TA001,TA002,PlanNumber,CustomerNo,CustomerName,
		Memo,aStatus,Creator,CreateTime)

		SELECT DISTINCT '芳晟ERP' COP_Source,TG.TG003,
		TH.TH001 銷貨單別,TH.TH002 銷貨單號,TH.TH003 銷貨序號,TH.TH004 品號,TH.TH005 品名,
		TH.TH006 規格,TH.TH009 單位,TH.TH007 倉別,TH.TH008 數量,TH.TH012 單價,
		TH.TH013 金額,TG.TG011 幣別,TG.TG012 匯率,TH.TH037 本幣未稅金額,TH.TH038 本幣稅額,
		TH.TH024 贈品數量,TH.TH014 訂單單別,TH.TH015 訂單單號,TH.TH016 訂單序號,TH.TH018 備註, TC.TC012 客戶單號,NULL 銘版序號,
		'' 製令單別,'' 製令單號,RTRIM(TA.TA033) AS PlanNumber,TG.TG004 as 客戶代號,MA.MA002 as 客戶名稱,
		'','Y',@Creator,@CreateTime--,*
--      select *
		FROM [192.168.1.200].PRORIL.dbo.COPTH TH
--		LEFT JOIN [192.168.1.200].PBS.dbo.OrderDTB TB ON TB.OrderNo = rtrim(TH.TH014+'-'+TH.TH015) AND TB.OrderSeq = TH.TH016
        -- 2026-09-21 註解掉，理由同上一個 INSERT（國外銷貨單）那段。
        -- LEFT join PRORIL_WEB.dbo.NPS_D_Order TB on TB.OrderType+'-'+ rtrim(TB.OrderNo)+TB.OrderSno = TH.TH014 + '-'+ RTRIM(TH.TH015) + TH.TH016
--		LEFT JOIN [192.168.1.200].PRORIL.dbo.MOCTA TA ON TH.TH014 = TA.TA026 and TH.TH015 = TA.TA027 and TH.TH016 = TA.TA028 AND TH.TH004 = TA.TA006 AND TA.TA013 ='Y' AND  TA.TA011 = 'Y' --AND  TA.TA011 <> 'y'-- 製令單
		LEFT JOIN (SELECT DISTINCT TA001,TA002,TA026,TA027,TA028,TA006,TA033 FROM [192.168.1.200].PRORIL.dbo.MOCTA WHERE TA013 ='Y' AND  TA011 = 'Y') TA ON TH.TH014 = TA.TA026 and TH.TH015 = TA.TA027 and TH.TH016 = TA.TA028 AND TH.TH004 = TA.TA006
		LEFT JOIN [192.168.1.200].PRORIL.dbo.COPTC TC ON TC.TC001 = TH.TH014 AND TC.TC002 = TH.TH015
		LEFT JOIN [192.168.1.200].PRORIL.dbo.COPTG TG ON TG.TG001 = TH.TH001 AND TG.TG002 = TH.TH002 
		LEFT JOIN [192.168.1.200].PRORIL.dbo.COPMA MA ON MA.MA001 = TG.TG004
		LEFT JOIN dbo.COP_SalesOrder CSO ON CSO.TH001 = TH.TH001 COLLATE DATABASE_DEFAULT and CSO.TH002 = TH.TH002 COLLATE DATABASE_DEFAULT and CSO.TH003 = TH.TH003 COLLATE DATABASE_DEFAULT
		WHERE 1=1
		AND TH.TH020 = 'Y'
		AND TH.TH001 LIKE '23%'
		AND CSO.TH001 IS NULL
		--AND TH.TH004 LIKE '5%'
		--AND TA.TA001 IS NULL -- 查無製令及訂單的浦瑞銷貨單
		--AND TG.TG001 IS not NULL
		order by TH.TH001,TH.TH002,TH.TH003

		-- 刪除重覆資料
		delete CSO
		-- select *
		-- select distinct CSO.COP_Source,CSO.TH001,CSO.TH002,CSO.TH003,CSO.TH004
		from COP_SalesOrder CSO 
		inner join 
		  (select COP_Source,TH001,TH002,TH003,TH004, min(ID) ID from COP_SalesOrder
		   where 1=1
		   GROUP BY COP_Source,TH001,TH002,TH003,TH004 HAVING COUNT(*) > 1) F on F.TH001 = CSO.TH001 and F.TH002 = CSO.TH002 and F.TH003 = CSO.TH003
		where 1=1
		and CSO.ID <> F.ID


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
-- 4. 預存程序：prc_QuerySalesOrder（依品號 TH004 分群）
-- ============================================================








-- =============================================
-- Author:		Name
-- Create date: 20241118
-- Description: 業務出貨單資料查詢
-- =============================================


CREATE OR ALTER PROCEDURE [dbo].[prc_QuerySalesOrder]

@InCustomerNo varchar(20), -- 客戶編號
@ProductNo_Type varchar(1), -- 品號類型 A:不選(全部記錄) 1:全選(目前只有5,x) 5:成品 x:非成品
@ProductNo varchar(40), -- 品號
@ProductName varchar(120), -- 品名
@ProductSpecification varchar(120), -- 規格
@StartDate varchar(40), -- 起始日期
@EndDate varchar(40), -- 終止日期
@SerialNo varchar(40), -- 銘版序號
@PoNo varchar(120), -- 訂單號
@InPlanNumber varchar(120), -- 計劃批號
@GroupType varchar(100), -- 統計群組類別
@GroupDesc varchar(10) -- 統計群組排序


AS
BEGIN
DECLARE 



@ID int,
@CreateTime datetime,

@statement nvarchar(4000),
@where nvarchar(1000),
@orderby nvarchar(500),

@COP_Source nvarchar(10),

-- 20260605 以銷貨單號排序,造成[銷貨單統計]頁面資料錯誤,增加[TG003]改為以銷貨日期排序
@TG003 nvarchar(50), 
--------------------------------------------------------------------------------------

@TH001 nvarchar(50),
@TH002 nvarchar(50),
@TH003 nvarchar(50),
@TH004 nvarchar(40),
@TH005 nvarchar(120),
@TH006 nvarchar(120),
@TH009 nvarchar(6),
@TH007 nvarchar(10),
@TH008 numeric(16, 3),
@TH012 numeric(21, 6),
@TH013 numeric(21, 6),
@TG011 nvarchar(4),
@TG012 numeric(16, 3),
@TH037 numeric(21, 6),
@TH038 numeric(21, 6),
@TH024 numeric(16, 3),
@TH014 nvarchar(4),
@TH015 nvarchar(11),
@TH016 nvarchar(4),
@SerialNosJson nvarchar(max),
@TA001 nchar(4),
@TA002 nchar(11),
@PlanNumber nvarchar(40),
@TA026 nvarchar(4),
@TA027 nvarchar(11),
@TA028 nvarchar(4),
@SerialNosJson1 nvarchar(max),
@TA0011 nchar(4),
@TA0021 nchar(11),
@PlanNumber1 nvarchar(40),
@CustomerNo varchar(20),
@CustomerName nvarchar(80),
@Memo nvarchar(500),
@aStatus varchar(1),
@Creator nvarchar(40),
--@CreateTime datetime,
@Modifier nvarchar(40),
@ModiTime datetime,


@TH018 nvarchar(255),
@TC012 nvarchar(20),


@HeaderWrite varchar(1) ,
@FooterWrite varchar(1) ,
@FooterFlag varchar(1) ,
@GroupFlag varchar(1) ,

-- 加總計算
@RecCnt int,
@RecIdx int,
@SumQty numeric(16, 3),
@SumAmt numeric(16, 3),
@TotalQty numeric(16, 3),
@TotalAmt numeric(16, 3),
@SumProductNo varchar(40),


@ret VARCHAR(50)  --傳回結果

  exec prc_ImportSalesOrder 'system',@ret

  BEGIN TRANSACTION;
  --開啟交易

    -- 建立匯出使用的資料集
	CREATE TABLE [dbo].[#SalesOrder](
		[ID] [int] IDENTITY(1,1) NOT NULL,
		[COP_Source] [nvarchar](10)  NULL,
		[TG003] [nvarchar](50)  NULL,
		[TH001] [nvarchar](50)  NULL,
		[TH002] [nvarchar](50)  NULL,
		[TH003] [nvarchar](50)  NULL,
		[TH004] [nvarchar](40) NULL,
		[TH005] [nvarchar](120) NULL,
		[TH006] [nvarchar](120) NULL,
		[TH009] [nvarchar](6) NULL,
		[TH007] [nvarchar](10) NULL,
		[TH008] [numeric](16, 3) NULL,
		[SumQty] [numeric](16, 3) NULL,
		[TH012] [numeric](21, 6) NULL,
		[TH013] [numeric](21, 6) NULL,
		[TG011] [nvarchar](4) NULL,
		[TG012] [numeric](16, 3) NULL,
		[TH037] [numeric](21, 6) NULL,
		[TH038] [numeric](21, 6) NULL,
		[SumAmt] [numeric](21, 6) NULL,
		[TH024] [numeric](16, 3) NULL,
		[TH014] [nvarchar](4) NULL,
		[TH015] [nvarchar](11) NULL,
		[TH016] [nvarchar](4) NULL,
		[TH018] [nvarchar](255) NULL,
		[TC012] [nvarchar](20) NULL,
		[SerialNosJson] [nvarchar](max) NULL,
		[TA001] [nchar](4) NULL,
		[TA002] [nchar](11) NULL,
		[PlanNumber] [nvarchar](40) NULL,
		[TA026] [nvarchar](4) NULL,
		[TA027] [nvarchar](11) NULL,
		[TA028] [nvarchar](4) NULL,
		[SerialNosJson1] [nvarchar](max) NULL,
		[TA0011] [nchar](4) NULL,
		[TA0021] [nchar](11) NULL,
		[PlanNumber1] [nvarchar](40) NULL,
		[CustomerNo] [varchar](20) NULL,
		[CustomerName] [nvarchar](80) NULL,
		[Memo] [nvarchar](500) NULL,
        [FooterFlag] [varchar](1) null,
        [aStatus] [varchar](1) NULL,
		[Creator] [nvarchar](40) NULL,
		[CreateTime] [datetime] NULL,
		[Modifier] [nvarchar](40) NULL,
		[ModiTime] [datetime] NULL)


    BEGIN TRY

	  SET @CreateTime = GETDATE()

	  set @FooterFlag = 'N'

	  SET @statement = '
	    insert into #SalesOrder (COP_Source,TG003,
		  TH001,TH002,TH003,TH004,TH005,
		  TH006,TH009,TH007,TH008,TH012,
		  TH013,TG011,TG012,TH037,TH038,
		  TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
		  TA001,TA002,PlanNumber,CustomerNo,CustomerName,Memo,FooterFlag,aStatus,Creator,CreateTime) 
        select DISTINCT COP_Source,TG003,
          TH001,TH002,TH003,TH004,TH005,
		  TH006,TH009,TH007,TH008,TH012,
		  TH013,TG011,TG012,TH037,TH038,
		  TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
		  TA001,TA002,PlanNumber,CustomerNo,CustomerName,Memo,''N'',aStatus,Creator,CreateTime 
		from COP_SalesOrder CSO
	  '

      SET @where = ' WHERE 1 = 1 '
      SET @orderby = ''
      

      -- 取得查詢資料集

	    IF (ISNULL(@InCustomerNo,'') <> '')
		BEGIN
		  SET @where = @where + ' AND CustomerNo = '''+ @InCustomerNo + ''''
		END

		-- 品號類型 A:不選(全部記錄) 1:全選(目前只有5,x) 5:成品 x:非成品
	    IF (ISNULL(@ProductNo_Type,'A') <> 'A' and ISNULL(@ProductNo_Type,'A') <> 'a')
		BEGIN
		  SET @where = @where + ' AND TH004 LIKE  '''+ @ProductNo_Type + '%'' '
		END
		else
	    IF (ISNULL(@ProductNo_Type,'A') = 'a')
		BEGIN
		  SET @where = @where + ' AND substring(TH004,1,1) in (''5'',''x'') '
		END

	    IF (ISNULL(@ProductNo,'') <> '')
		BEGIN
		  SET @where = @where + ' AND TH004 LIKE  ''%'+ @ProductNo + '%'' '
		END

	    IF (ISNULL(@ProductName,'') <> '')
		BEGIN
		  SET @where = @where + ' AND TH005 LIKE  ''%'+ @ProductName + '%'' '
		END

	    IF (ISNULL(@ProductSpecification,'') <> '')
		BEGIN
		  SET @where = @where + ' AND TH006 LIKE  ''%'+ @ProductSpecification + '%'' '
		END

--		PRINT @StartDate

	    IF (ISNULL(@StartDate,'') <> '')
		BEGIN
		  SET @where = @where + 
		  ' AND CONVERT(date,cast(SUBSTRING(TH002,1,3)+1911 as varchar(4))+SUBSTRING(TH002,4,4)) >= CONVERT(date,'''+ @StartDate + ''')' 
		END

	    IF (ISNULL(@EndDate,'') <> '')
		BEGIN
		  SET @where = @where + 
		  ' AND CONVERT(date,cast(SUBSTRING(TH002,1,3)+1911 as varchar(4))+SUBSTRING(TH002,4,4)) <= CONVERT(date,'''+ @EndDate + ''')' 
		END

	    IF (ISNULL(@SerialNo,'') <> '')
		BEGIN
		  SET @where = @where + ' AND SerialNosJson LIKE  ''%'+ @SerialNo + '%'' '
		END

	    IF (ISNULL(@PoNo,'') <> '')
		BEGIN
		  SET @where = @where + ' AND TH014 + ''-'' + TH015  LIKE ''%'+ @PoNo + '%'''
		END


	    IF (ISNULL(@InPlanNumber,'') <> '')
		BEGIN
		  SET @where = @where + ' AND PlanNumber LIKE ''%'+ @InPlanNumber + '%'''
		END


	    IF (ISNULL(@GroupType,'') <> '')
		BEGIN
		  SET @orderby = ' ORDER BY '+ @GroupType + ' ' + @GroupDesc
		END



        -- 寫入暫存檔做為計算及整理使用

       SET @statement = @statement + @where + @orderby
 
       PRINT 'STATEMENT: ' + @statement

--	   DECLARE crs CURSOR FOR

       EXEC sp_executesql @statement

	   SELECT * into #tmpCSO FROM  [#SalesOrder]

	   delete from [#SalesOrder]

--	  select * from #tmpCSO

--    drop table #tmpCSO

--    drop table [#SalesOrder]

		-- 按群組計算統計資料

		-- 逐筆寫入並產生Footer

          DECLARE CRS CURSOR FOR 
		  select COP_Source,TG003,
		  TH001,TH002,TH003,TH004,TH005,
		  TH006,TH009,TH007,TH008,TH012,
		  TH013,TG011,TG012,TH037,TH038,
		  TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
		  TA001,TA002,PlanNumber,CustomerNo,CustomerName,Memo,aStatus,Creator,CreateTime
		  FROM #tmpCSO
			order by ID

			OPEN CRS 
			FETCH NEXT FROM CRS INTO  @COP_Source,@TG003,
		    @TH001,@TH002,@TH003,@TH004,@TH005,
		    @TH006,@TH009,@TH007,@TH008,@TH012,
		    @TH013,@TG011,@TG012,@TH037,@TH038,
		    @TH024,@TH014,@TH015,@TH016,@TH018,@TC012,@SerialNosJson,
		    @TA001,@TA002,@PlanNumber,@CustomerNo,@CustomerName,@Memo,@aStatus,@Creator,@CreateTime

			set @SumProductNo = ''
			set @RecCnt = 0
			set @RecIdx = 0
			set @SumQty = 0
			set @SumAmt = 0
			set @TotalQty = 0
			set @TotalAmt = 0
			set @FooterWrite = 'N'
			set @FooterFlag = 'N'
            set @GroupFlag = 'N'


			while(@@fetch_status != -1)
			begin
			  -- 總數計算
			  SET @TotalQty = @TotalQty + @TH008
			  SET @TotalAmt = @TotalAmt + @TH037 + @TH038

    	      SET @SumQty = @SumQty + @TH008
              SET @SumAmt = @SumAmt + @TH037 + @TH038

                -- 寫入記錄
				insert into #SalesOrder (COP_Source,TG003,
				TH001,TH002,TH003,TH004,TH005,
				TH006,TH009,TH007,TH008,SumQty,TH012,
				TH013,TG011,TG012,TH037,TH038,SumAmt,
				TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
				TA001,TA002,PlanNumber,CustomerNo,CustomerName,Memo,FooterFlag,aStatus,Creator,CreateTime) 

				select  @COP_Source,@TG003,
				@TH001,@TH002,@TH003,@TH004,@TH005,
				@TH006,@TH009,@TH007,@TH008,@TH008,@TH012,
				@TH013,@TG011,@TG012,@TH037,@TH038,@TH037+@TH038,
				@TH024,@TH014,@TH015,@TH016,@TH018,@TC012,@SerialNosJson,
				@TA001,@TA002,@PlanNumber,@CustomerNo,@CustomerName,@Memo,@FooterFlag,@aStatus,@Creator,@CreateTime

        	   SET @RecIdx = @RecIdx + 1

			   print @TH004

			   SELECT @RecCnt = count(*) FROM #tmpCSO
				WHERE 1=1
				AND TH004 = @TH004

               print @RecCnt
               print @RecIdx


--			   if (@RecCnt > 1  AND @SumProductNo <> @TH004) 
			   if (@RecCnt > 1  AND @RecIdx = @RecCnt) 
               begin
                   set @GroupFlag = 'Y'

                   print '@SumProductNo : ' +  @SumProductNo

                   print '@TH004 : ' +  @TH004

					set @FooterFlag = 'Y'
					set @FooterWrite = 'Y'

					-- 產生Footer記錄
					insert into #SalesOrder (COP_Source,TG003,
					TH001,TH002,TH003,TH004,TH005,
					TH006,TH009,TH007,TH008,SumQty,TH012,
					TH013,TG011,TG012,TH037,TH038,SumAmt,
					TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
					TA001,TA002,PlanNumber,CustomerNo,CustomerName,
					Memo,FooterFlag,aStatus,Creator,CreateTime) 

					select  '','',
					'','','',@SumProductNo,@TH005,
					@TH006,NULL,'',@SumQty,@SumQty,NULL,
					NULL,'',NULL,NULL,NULL,@SumAmt,
					NULL,'','','','','','',
					'','','','','',
					'',@FooterFlag,'Y','',null

				    set @RecIdx = 0
					set @SumQty = 0
					set @SumAmt = 0
					set @SumProductNo = @TH004
					set @FooterWrite = 'N'
					set @FooterFlag = 'N'

                end 
				else
			    if (@RecCnt = 1 ) 
                begin
				    set @RecIdx = 0
					set @SumQty = 0
					set @SumAmt = 0
					set @SumProductNo = @TH004
					set @FooterWrite = 'N'
					set @FooterFlag = 'N'
--					set @FooterFlag = 'S'
			    end

				set @SumProductNo = @TH004

				FETCH NEXT FROM CRS INTO @COP_Source,@TG003,
				@TH001,@TH002,@TH003,@TH004,@TH005,
				@TH006,@TH009,@TH007,@TH008,@TH012,
				@TH013,@TG011,@TG012,@TH037,@TH038,
				@TH024,@TH014,@TH015,@TH016,@TH018,@TC012,@SerialNosJson,
				@TA001,@TA002,@PlanNumber,@CustomerNo,@CustomerName,@Memo,@aStatus,@Creator,@CreateTime
			
			end
			-- 產生Total記錄
			insert into #SalesOrder (COP_Source,TG003,
			TH001,TH002,TH003,TH004,TH005,
			TH006,TH009,TH007,TH008,SumQty,TH012,
			TH013,TG011,TG012,TH037,TH038,SumAmt,
			TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
			TA001,TA002,PlanNumber,CustomerNo,CustomerName,
			Memo,FooterFlag,aStatus,Creator,CreateTime) 

			select  '','',
			'','','','Total','',
			@TH006,NULL,'',@TotalQty,@TotalQty,NULL,
			NULL,'',NULL,NULL,NULL,@TotalAmt,
			NULL,'','','','','','',
			'','','','','',
			'','T','Y','',null

			close CRS
			deallocate CRS

       -- 群組條件下單一記錄填入 S

	   UPDATE A SET FooterFlag = 'S'
	   -- select *  
		from #SalesOrder A
		INNER JOIN (
			select TH004,COUNT(*) CNT from #SalesOrder
			where 1=1
			AND FooterFlag <> 'Y'
			group by TH004 having COUNT(*) =1
			) B ON B.TH004 = A.TH004


---	   drop table tmp_SalesOrder
	
--	   select * into tmp_SalesOrder from #SalesOrder order by ID
	   select * from #SalesOrder order by ID
        
--	    SET  @ret = 'SUCCESS' 
      

	  DROP TABLE  #tmpCSO

	  DROP TABLE #SalesOrder

      COMMIT

	END TRY

	BEGIN CATCH

--		SET  @ret = 'error'
		ROLLBACK;

		PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR(MAX));
		PRINT 'Error Message: ' + ERROR_MESSAGE();

    END CATCH

--    SET  @result = @ret

--    PRINT @result


END


GO

-- ============================================================
-- 5. 預存程序：prc_QuerySalesOrder_1（依銷貨單 TH001+TH002 分群）
-- ============================================================

-- =============================================
-- Author:    Name
-- Create date: 20241217
-- Description: 業務出貨單資料查詢,銷貨單群組 (已新增 TH013 加總，TG011不同值時顯示NULL)
-- =============================================

CREATE OR ALTER PROCEDURE [dbo].[prc_QuerySalesOrder_1]

@InCustomerNo varchar(20), -- 客戶編號
@ProductNo_Type varchar(1), -- 品號類型 A:不選(全部記錄) 1:全選(目前只有5,x) 5:成品 x:非成品
@ProductNo varchar(40), -- 品號
@ProductName varchar(120), -- 品名
@ProductSpecification varchar(120), -- 規格
@StartDate varchar(40), -- 起始日期
@EndDate varchar(40), -- 終止日期
@SerialNo varchar(40), -- 銘版序號
@PoNo varchar(120), -- 訂單號
@OrderType varchar(4), -- 銷貨單別
@OrderNo varchar(12), -- 銷貨單號
@InPlanNumber varchar(120), -- 計劃批號
@GroupType varchar(100), -- 統計群組類別
@GroupDesc varchar(10) -- 統計群組排序

AS
BEGIN
DECLARE 

@ID int,
@CreateTime datetime,

@statement nvarchar(4000),
@where nvarchar(1000),
@orderby nvarchar(500),

@COP_Source nvarchar(10),
@TG003 nvarchar(50),
@TH001 nvarchar(50),
@TH002 nvarchar(50),
@TH003 nvarchar(50),
@TH004 nvarchar(40),
@TH005 nvarchar(120),
@TH006 nvarchar(120),
@TH009 nvarchar(6),
@TH007 nvarchar(10),
@TH008 numeric(16, 3),
@TH012 numeric(21, 6),
@TH013 numeric(21, 6),
@TG011 nvarchar(4),
@TG012 numeric(16, 3),
@TH037 numeric(21, 6),
@TH038 numeric(21, 6),
@TH024 numeric(16, 3),
@TH014 nvarchar(4),
@TH015 nvarchar(11),
@TH016 nvarchar(4),
@SerialNosJson nvarchar(max),
@TA001 nchar(4),
@TA002 nchar(11),
@PlanNumber nvarchar(40),
@TA026 nvarchar(4),
@TA027 nvarchar(11),
@TA028 nvarchar(4),
@SerialNosJson1 nvarchar(max),
@TA0011 nchar(4),
@TA0021 nchar(11),
@PlanNumber1 nvarchar(40),
@CustomerNo varchar(20),
@CustomerName nvarchar(80),
@Memo nvarchar(500),
@aStatus varchar(1),
@Creator nvarchar(40),
@Modifier nvarchar(40),
@ModiTime datetime,

@TH018 nvarchar(255),
@TC012 nvarchar(20),

@HeaderWrite varchar(1) ,
@FooterWrite varchar(1) ,
@FooterFlag varchar(1) ,
@GroupFlag varchar(1) ,

-- 加總計算
@RecCnt int,
@RecIdx int,
@SumQty numeric(16, 3),
@SumAmt numeric(16, 3),
@SumTH013 numeric(21, 6),   -- TH013 小計變數
@TotalQty numeric(16, 3),
@TotalAmt numeric(16, 3),
@TotalTH013 numeric(21, 6), -- TH013 總計變數
@SumNo varchar(40),

-- 判斷 TG011 幣別是否一致的控制變數
@FirstTG011 nvarchar(4),
@HasDiffTG011 varchar(1),
@TotalFirstTG011 nvarchar(4),
@TotalHasDiffTG011 varchar(1),

@ret VARCHAR(50)  --傳回結果

exec prc_ImportSalesOrder 'system',@ret

  BEGIN TRANSACTION;
  --開啟交易

  CREATE TABLE [dbo].[#SalesOrder_1](
    [ID] [int] IDENTITY(1,1) NOT NULL,
    [COP_Source] [nvarchar](10)  NULL,
    [TG003] [nvarchar](50)  NULL,
    [TH001] [nvarchar](50)  NULL,
    [TH002] [nvarchar](50)  NULL,
    [TH003] [nvarchar](50)  NULL,
    [TH004] [nvarchar](40) NULL,
    [TH005] [nvarchar](120) NULL,
    [TH006] [nvarchar](120) NULL,
    [TH009] [nvarchar](6) NULL,
    [TH007] [nvarchar](10) NULL,
    [TH008] [numeric](16, 3) NULL,
    [SumQty] [numeric](16, 3) NULL,
    [TH012] [numeric](21, 6) NULL,
    [TH013] [numeric](21, 6) NULL,
    [TG011] [nvarchar](4) NULL,
    [TG012] [numeric](16, 3) NULL,
    [TH037] [numeric](21, 6) NULL,
    [TH038] [numeric](21, 6) NULL,
    [SumAmt] [numeric](21, 6) NULL,
    [TH024] [numeric](16, 3) NULL,
    [TH014] [nvarchar](4) NULL,
    [TH015] [nvarchar](11) NULL,
    [TH016] [nvarchar](4) NULL,
    [TH018] [nvarchar](255) NULL,
    [TC012] [nvarchar](20) NULL,
    [SerialNosJson] [nvarchar](max) NULL,
    [TA001] [nchar](4) NULL,
    [TA002] [nchar](11) NULL,
    [PlanNumber] [nvarchar](40) NULL,
    [TA026] [nvarchar](4) NULL,
    [TA027] [nvarchar](11) NULL,
    [TA028] [nvarchar](4) NULL,
    [SerialNosJson1] [nvarchar](max) NULL,
    [TA0011] [nchar](4) NULL,
    [TA0021] [nchar](11) NULL,
    [PlanNumber1] [nvarchar](40) NULL,
    [CustomerNo] [varchar](20) NULL,
    [CustomerName] [nvarchar](80) NULL,
    [Memo] [nvarchar](500) NULL,
    [FooterFlag] [varchar](1) null,
    [aStatus] [varchar](1) NULL,
    [Creator] [nvarchar](40) NULL,
    [CreateTime] [datetime] NULL,
    [Modifier] [nvarchar](40) NULL,
    [ModiTime] [datetime] NULL)

    BEGIN TRY

    SET @CreateTime = GETDATE()
    set @FooterFlag = 'N'

    SET @statement = '
      insert into #SalesOrder_1 (COP_Source,TG003,
      TH001,TH002,TH003,TH004,TH005,
      TH006,TH009,TH007,TH008,TH012,
      TH013,TG011,TG012,TH037,TH038,
      TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
      TA001,TA002,PlanNumber,CustomerNo,CustomerName,Memo,FooterFlag,aStatus,Creator,CreateTime) 
        select DISTINCT COP_Source,TG003,
          TH001,TH002,TH003,TH004,TH005,
      TH006,TH009,TH007,TH008,TH012,
      TH013,TG011,TG012,TH037,TH038,
      TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
      TA001,TA002,PlanNumber,CustomerNo,CustomerName,Memo,''N'',aStatus,Creator,CreateTime 
    from COP_SalesOrder CSO
    '

      SET @where = ' WHERE 1 = 1 '
      SET @orderby = ''
      
      IF (ISNULL(@InCustomerNo,'') <> '')
    BEGIN
      SET @where = @where + ' AND CustomerNo = '''+ @InCustomerNo + ''''
    END

      IF (ISNULL(@ProductNo_Type,'A') <> 'A' and ISNULL(@ProductNo_Type,'A') <> 'a')
    BEGIN
      SET @where = @where + ' AND TH004 LIKE  '''+ @ProductNo_Type + '%'' '
    END
    else
      IF (ISNULL(@ProductNo_Type,'a') = 'a')
    BEGIN
      SET @where = @where + ' AND substring(TH004,1,1) in (''5'',''x'') '
    END

      IF (ISNULL(@ProductNo,'') <> '')
    BEGIN
      SET @where = @where + ' AND TH004 LIKE  ''%'+ @ProductNo + '%'' '
    END

      IF (ISNULL(@ProductName,'') <> '')
    BEGIN
      SET @where = @where + ' AND TH005 LIKE  ''%'+ @ProductName + '%'' '
    END

      IF (ISNULL(@ProductSpecification,'') <> '')
    BEGIN
      SET @where = @where + ' AND TH006 LIKE  ''%'+ @ProductSpecification + '%'' '
    END

      IF (ISNULL(@StartDate,'') <> '')
    BEGIN
      SET @where = @where + 
      ' AND CONVERT(date,cast(SUBSTRING(TH002,1,3)+1911 as varchar(4))+SUBSTRING(TH002,4,4)) >= CONVERT(date,'''+ @StartDate + ''')' 
    END

      IF (ISNULL(@EndDate,'') <> '')
    BEGIN
      SET @where = @where + 
      ' AND CONVERT(date,cast(SUBSTRING(TH002,1,3)+1911 as varchar(4))+SUBSTRING(TH002,4,4)) <= CONVERT(date,'''+ @EndDate + ''')' 
    END

      IF (ISNULL(@SerialNo,'') <> '')
    BEGIN
      SET @where = @where + ' AND SerialNosJson LIKE  ''%'+ @SerialNo + '%'' '
    END

      IF (ISNULL(@PoNo,'') <> '')
    BEGIN
      SET @where = @where + ' AND TH014 + ''-'' + TH015  LIKE ''%'+ @PoNo + '%'''
    END

      IF (ISNULL(@OrderType,'') <> '')
    BEGIN
      SET @where = @where + ' AND TH001 = '''+ @OrderType + ''''
    END

      IF (ISNULL(@OrderNo,'') <> '')
    BEGIN
      SET @where = @where + ' AND TH002 = '''+ @OrderNo + ''''
    END

      IF (ISNULL(@InPlanNumber,'') <> '')
    BEGIN
      SET @where = @where + ' AND PlanNumber LIKE ''%'+ @InPlanNumber + '%'''
    END

      IF (ISNULL(@GroupType,'') <> '')
    BEGIN
      SET @orderby = ' ORDER BY TG003,COP_Source,TH001,TH002,TH003 ' 
    END

       SET @statement = @statement + @where + @orderby
 
       PRINT 'STATEMENT: ' + @statement

       EXEC sp_executesql @statement

     SELECT * into #tmpCSO_1 FROM  [#SalesOrder_1]

     delete from [#SalesOrder_1]

      DECLARE CRS CURSOR FOR 
      select COP_Source,TG003,
      TH001,TH002,TH003,TH004,TH005,
      TH006,TH009,TH007,TH008,TH012,
      TH013,TG011,TG012,TH037,TH038,
      TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
      TA001,TA002,PlanNumber,CustomerNo,CustomerName,Memo,aStatus,Creator,CreateTime
      FROM #tmpCSO_1
      order by ID

      OPEN CRS 
      FETCH NEXT FROM CRS INTO @COP_Source,@TG003,
        @TH001,@TH002,@TH003,@TH004,@TH005,
        @TH006,@TH009,@TH007,@TH008,@TH012,
        @TH013,@TG011,@TG012,@TH037,@TH038,
        @TH024,@TH014,@TH015,@TH016,@TH018,@TC012,@SerialNosJson,
        @TA001,@TA002,@PlanNumber,@CustomerNo,@CustomerName,@Memo,@aStatus,@Creator,@CreateTime

      set @SumNo = ''
      set @RecCnt = 0
      set @RecIdx = 0
      set @SumQty = 0
      set @SumAmt = 0
      set @SumTH013 = 0
      set @TotalQty = 0
      set @TotalAmt = 0
      set @TotalTH013 = 0
      set @FooterWrite = 'N'
      set @FooterFlag = 'N'
      set @GroupFlag = 'N'

      -- 初始化 TG011 檢查欄位
      set @FirstTG011 = NULL
      set @HasDiffTG011 = 'N'
      set @TotalFirstTG011 = NULL
      set @TotalHasDiffTG011 = 'N'

      while(@@fetch_status != -1)
      begin
        -- 檢查全域的 TG011 幣別是否一致 (計算 Total 用)
        IF (@TotalFirstTG011 IS NULL)
        BEGIN
          SET @TotalFirstTG011 = ISNULL(@TG011, '')
        END
        ELSE IF (@TotalFirstTG011 <> ISNULL(@TG011, ''))
        BEGIN
          SET @TotalHasDiffTG011 = 'Y'
        END

        -- 檢查單一銷貨單群組內的 TG011 幣別是否一致 (計算 Footer 用)
        IF (@FirstTG011 IS NULL)
        BEGIN
          SET @FirstTG011 = ISNULL(@TG011, '')
        END
        ELSE IF (@FirstTG011 <> ISNULL(@TG011, ''))
        BEGIN
          SET @HasDiffTG011 = 'Y'
        END

        -- 總數計算
        SET @TotalQty = @TotalQty + ISNULL(@TH008, 0)
        SET @TotalAmt = @TotalAmt + ISNULL(@TH037, 0) + ISNULL(@TH038, 0)
        SET @TotalTH013 = @TotalTH013 + ISNULL(@TH013, 0)

        SET @SumQty = @SumQty + ISNULL(@TH008, 0)
        SET @SumAmt = @SumAmt + ISNULL(@TH037, 0) + ISNULL(@TH038, 0)
        SET @SumTH013 = @SumTH013 + ISNULL(@TH013, 0)

        -- 寫入記錄
        insert into #SalesOrder_1 (COP_Source,TG003,
        TH001,TH002,TH003,TH004,TH005,
        TH006,TH009,TH007,TH008,SumQty,TH012,
        TH013,TG011,TG012,TH037,TH038,SumAmt,
        TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
        TA001,TA002,PlanNumber,CustomerNo,CustomerName,Memo,FooterFlag,aStatus,Creator,CreateTime) 

        select  @COP_Source,@TG003,
        @TH001,@TH002,@TH003,@TH004,@TH005,
        @TH006,@TH009,@TH007,@TH008,@TH008,@TH012,
        @TH013,@TG011,@TG012,@TH037,@TH038,ISNULL(@TH037,0)+ISNULL(@TH038,0),
        @TH024,@TH014,@TH015,@TH016,@TH018,@TC012,@SerialNosJson,
        @TA001,@TA002,@PlanNumber,@CustomerNo,@CustomerName,@Memo,@FooterFlag,@aStatus,@Creator,@CreateTime

        SET @RecIdx = @RecIdx + 1

        print @TH004

        SELECT @RecCnt = count(*) FROM #tmpCSO_1
        WHERE 1=1
        AND TH001 = @TH001
        AND TH002 = @TH002

        print @RecCnt
        print @RecIdx

        if (@RecCnt > 1  AND @RecIdx = @RecCnt) 
        begin
          set @GroupFlag = 'Y'

          print '@SumNo : ' +  @SumNo
          print '@TH001 : ' +  @TH001 + ' ' + @TH002

          set @FooterFlag = 'Y'
          set @FooterWrite = 'Y'

          -- 產生Footer記錄 (小計)：若 TG011 有不同值，TH013 給 NULL
          insert into #SalesOrder_1 (COP_Source,TG003,
          TH001,TH002,TH003,TH004,TH005,
          TH006,TH009,TH007,TH008,SumQty,TH012,
          TH013,TG011,TG012,TH037,TH038,SumAmt,
          TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
          TA001,TA002,PlanNumber,CustomerNo,CustomerName,
          Memo,FooterFlag,aStatus,Creator,CreateTime) 

          select  '','',
          @TH001,@TH002,'','','',
          '','','',@SumQty,@SumQty,NULL,
          CASE WHEN @HasDiffTG011 = 'Y' THEN NULL ELSE @SumTH013 END,'',NULL,NULL,NULL,@SumAmt,
          NULL,'','','','','','',
          '','','',@CustomerNo,@CustomerName,
          '',@FooterFlag,'Y','',null

          set @RecIdx = 0
          set @SumQty = 0
          set @SumAmt = 0
          set @SumTH013 = 0
          set @FirstTG011 = NULL        -- 重置小計幣別
          set @HasDiffTG011 = 'N'       -- 重置異動標記
          set @SumNo = @TH001 + @TH002
          set @FooterWrite = 'N'
          set @FooterFlag = 'N'

        end 
        else
          if (@RecCnt = 1 ) 
          begin
            set @RecIdx = 0
            set @SumQty = 0
            set @SumAmt = 0
            set @SumTH013 = 0
            set @FirstTG011 = NULL      -- 重置小計幣別
            set @HasDiffTG011 = 'N'     -- 重置異動標記
            set @SumNo = @TH001 + @TH002
            set @FooterWrite = 'N'
            set @FooterFlag = 'N'
          end

          set @SumNo = @TH001 + @TH002

        FETCH NEXT FROM CRS INTO @COP_Source,@TG003,
        @TH001,@TH002,@TH003,@TH004,@TH005,
        @TH006,@TH009,@TH007,@TH008,@TH012,
        @TH013,@TG011,@TG012,@TH037,@TH038,
        @TH024,@TH014,@TH015,@TH016,@TH018,@TC012,@SerialNosJson,
        @TA001,@TA002,@PlanNumber,@CustomerNo,@CustomerName,@Memo,@aStatus,@Creator,@CreateTime
      
      end

      -- 產生 Total 記錄 (總計)：若整體查詢結果中 TG011 有不同值，TH013 給 NULL
      insert into #SalesOrder_1 (COP_Source,TG003,
      TH001,TH002,TH003,TH004,TH005,
      TH006,TH009,TH007,TH008,SumQty,TH012,
      TH013,TG011,TG012,TH037,TH038,SumAmt,
      TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
      TA001,TA002,PlanNumber,CustomerNo,CustomerName,
      Memo,FooterFlag,aStatus,Creator,CreateTime) 

      select  '','',
      '','','','','',
      '','','',@TotalQty,@TotalQty,NULL,
      CASE WHEN @TotalHasDiffTG011 = 'Y' THEN NULL ELSE @TotalTH013 END,'',NULL,NULL,NULL,@TotalAmt,
      NULL,'','','','','','',
      '','','','','Total',
      '','T','Y','',null

      close CRS
      deallocate CRS

      -- 群組條件下單一記錄填入 S
      UPDATE A SET FooterFlag = 'S'
      from #SalesOrder_1 A
      INNER JOIN (
        select TH001,TH002,COUNT(*) CNT from #SalesOrder_1
        where 1=1
        AND FooterFlag <> 'Y'
        group by TH001,TH002 having COUNT(*) =1
        ) B ON B.TH001 = A.TH001 and B.TH002 = A.TH002

      select * from #SalesOrder_1 order by ID

      DROP TABLE #tmpCSO_1
      DROP TABLE #SalesOrder_1

      COMMIT

  END TRY

  BEGIN CATCH

    ROLLBACK;

    PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR(MAX));
    PRINT 'Error Message: ' + ERROR_MESSAGE();

  END CATCH

END

GO
