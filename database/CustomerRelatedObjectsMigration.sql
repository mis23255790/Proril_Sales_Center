/*
 * 客戶相關資訊（1.0 Mix/CustomerRelated，FunctionNo 441）用到的 View，
 * 從 PRORIL_WEB 搬到 Proril_Sales_Center。
 *
 * 兩個物件：
 *   V_SalesTotal      「銷售」頁籤的年／月銷售數量金額（1.0 MixSalesShipApi/GetSalesTotal）
 *   CRM_CustomerMemo  「情報」頁籤的內容（1.0 CustomQueryApi/GetCustomMemo、SetCustomMemo）
 *
 * 為什麼一定要搬（PortingNotes.md 第 5 點的結案）：
 *   V_SalesTotal 的唯一資料來源是 COP_SalesOrder，而那張表已經在 Proril_Sales_Center
 *   （SalesShippingObjectsMigration.sql）。銷貨檢索的 prc_QuerySalesOrder(_1) 進來就
 *   EXEC prc_ImportSalesOrder，往新庫的 COP_SalesOrder 增量寫入，舊庫那份只有 1.0 在餵。
 *   View 不搬的話，「銷售」頁籤會讀到舊庫的快取，跟同一站台的銷貨檢索對不起來——
 *   兩邊都是從同一份 ERP 拉的，不影響正確性，但成長節奏不同步，使用者看到的數字會有落差。
 *   搬過來之後 COP_SalesOrder 在 PRORIL_WEB 就沒有 2.0 這側的讀者了，
 *   終於符合「單一擁有者」，PortingNotes.md 第 5 點可以結案。
 *
 * 依賴關係（OBJECT_DEFINITION 逐行讀過）：
 *   - V_SalesTotal 只讀 1 張表：COP_SalesOrder，**已經在目標資料庫**，
 *     不用另外搬、也不用複製資料。
 *   - CRM_CustomerMemo 不參照任何其他物件（CustomerNo 與 CRM_Customer 靠應用層對應，
 *     DB 端沒有 FK）。
 *   - 0 個 linked server：跟 V_UnfinOrder 不同，這支完全不碰鼎新 ERP，
 *     純粹對本地資料操作。所以 run-objects-migration.ps1 報 linked server 不存在時，
 *     這支腳本仍然可以正常執行。
 *   - 0 個預存程序、0 個函式。
 *
 * 特別注意：
 *   1. **YM 是從銷貨單號 TH002 推出來的，不是銷貨日期 TG003**：
 *      SUBSTRING(TH002,1,3) 取民國年 + 1911 換算西元，SUBSTRING(TH002,4,2) 取月份。
 *      看起來取巧，但這是 1.0 的既有語意（單號前綴就是年月），照抄不改——
 *      改成用 TG003 會讓歷史數字整批位移。
 *   2. **兩段 UNION 都有 TOP 10000 卻沒有 ORDER BY**：SQL Server 對這種寫法回哪 10000 筆
 *      不保證，等於資料量超過上限時會靜默漏資料。這是 1.0 的既有寫法，照抄不動——
 *      這次搬移的目標是行為一致，不是順手改邏輯。真的要修要另外評估。
 *   3. **只統計品號開頭是 5 或 x 的（成品/零件）**，其餘品號不計入銷售統計，同樣照抄。
 *   4. CREATE VIEW 改成 CREATE OR ALTER，可重複執行。
 *   5. 除了第 4 點，與來源（PRORIL_WEB 目前的定義，2026-09-16 用 OBJECT_DEFINITION
 *      直接從資料庫撈出來）一字不差，連註解掉的那幾行都保留。
 *
 * 另外還有一張表 CRM_CustomerMemo（「情報」頁籤），比照銷貨檢索的 COP_SalesOrder
 * 一併在這支腳本裡建表 + 複製資料（CREATE TABLE 包 IF OBJECT_ID(...) IS NULL、
 * 資料複製在表已有資料時自動跳過，所以整支可重複執行）。
 *
 * **為什麼不用 publish.ps1 建這張表**：Tables 底下那些 .sql 對照的是 PRORIL_WEB 的 schema，
 * 而 Proril_Sales_Center 已經在好幾處刻意分岔（FunctionNo 從 int 改成 varchar(8)、
 * 定序對齊後一批 nvarchar 欄位的實際型別、COP_CheckRule 少一個欄位…）。
 * 對這個庫跑 publish 會把那些分岔「修正」回去，等於把權限控管整組打爛——
 * 實際跑 dry-run 驗證過，部署預覽就是這些警告。
 * Tables/CRM_CustomerMemo.sql 與 TABLES.txt 照樣要加，那是 schema 版控與
 * copy-snapshot-data.ps1 的白名單，跟「這次怎麼把表建出來」是兩回事。
 *
 * 怎麼執行：走 database/scripts/run-objects-migration.ps1，不要直接丟進 SSMS。
 *
 *   .\scripts\run-objects-migration.ps1 -Script CustomerRelatedObjectsMigration.sql -Environment snapshot
 *   .\scripts\run-objects-migration.ps1 -Script CustomerRelatedObjectsMigration.sql -Environment snapshot -Execute
 *
 * 不加 -Execute 只做檢查：目標庫與這裡的 USE 對帳、linked server 在不在（這支不需要，
 * 報不存在也沒關係）、物件現況、SET PARSEONLY ON 驗語法。
 *
 * 執行前建議：
 *   - 確認連到的是 Proril_Sales_Center（192.168.1.142,50002），不是 PRORIL_WEB。
 *   - 確認目標庫的 COP_SalesOrder 已經有資料（SalesShippingObjectsMigration.sql 跑過，
 *     而且銷貨檢索查過幾次讓 prc_ImportSalesOrder 灌進來），否則「銷售」頁籤會是空的。
 */

USE Proril_Sales_Center;
GO

-- ============================================================
-- 1. View：V_SalesTotal
-- ============================================================

-- 20250408 Mars
-- 客戶銷貨統計[V_SalesTotal]

CREATE OR ALTER VIEW [dbo].[V_SalesTotal]
AS

select top 10000 CustomerNo,cast(CAST(SUBSTRING(TH002,1,3) as int) + 1911 as varchar) + SUBSTRING(TH002,4,2) as YM,SUM(TH008) TotalQty ,SUM(TH037) + SUM(TH038) TotalAmt
from COP_SalesOrder
where 1=1
AND substring(TH004,1,1) in ('5','x')
--and CustomerNo like '101%'
GROUP BY CustomerNo,cast(CAST(SUBSTRING(TH002,1,3) as int) + 1911 as varchar) + SUBSTRING(TH002,4,2)
--order BY CustomerNo,cast(CAST(SUBSTRING(TH002,1,3) as int) + 1911 as varchar) + SUBSTRING(TH002,4,2)

union

select top 10000 CustomerNo, cast(CAST(SUBSTRING(TH002,1,3) as int) + 1911 as varchar) as aYear ,SUM(TH008) TotalQty ,SUM(TH037) + SUM(TH038) TotalAmt
from COP_SalesOrder
where 1=1
AND substring(TH004,1,1) in ('5','x')
--and CustomerNo like '101%'
GROUP BY CustomerNo,cast(CAST(SUBSTRING(TH002,1,3) as int) + 1911 as varchar)
--order BY CustomerNo,cast(CAST(SUBSTRING(TH002,1,3) as int) + 1911 as varchar)
GO

-- ============================================================
-- 2. 資料表：CRM_CustomerMemo
--    欄位定義與 database/Tables/CRM_CustomerMemo.sql 一致（那份是 schema 版控）。
-- ============================================================

IF OBJECT_ID('dbo.CRM_CustomerMemo') IS NULL
BEGIN
    CREATE TABLE [dbo].[CRM_CustomerMemo] (
        [ID]         INT             IDENTITY (1, 1) NOT NULL,
        [CustomerNo] VARCHAR (20)    NULL,
        [MemoType]   NVARCHAR (40)   NULL,
        [MemoDesc]   NVARCHAR (1000) NULL,
        [FileName]   NVARCHAR (200)  NULL,
        [aStatus]    VARCHAR (1)     NULL,
        [Creator]    VARCHAR (40)    NULL,
        [CreateTime] DATETIME        NULL,
        [Modifier]   VARCHAR (40)    NULL,
        [ModiTime]   DATETIME        NULL,
        CONSTRAINT [PK_CRM_CustomerMemo] PRIMARY KEY CLUSTERED ([ID] ASC)
    );
    PRINT '已建立 dbo.CRM_CustomerMemo';
END
GO

-- ============================================================
-- 3. 資料複製（只在新表是空的時候跑）
--
-- 情報是使用者手打的內容，沒有任何來源可以重新產生，一定要把既有資料帶過來。
-- 保留原始 ID：CRM_CustomerMemo 沒有被別的表參照，但 SetCustomMemo 是拿 ID 當更新鍵，
-- 換號等於讓還開著舊畫面的人存到別筆。
-- ============================================================

IF OBJECT_ID('dbo.CRM_CustomerMemo') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.CRM_CustomerMemo)
BEGIN
    SET IDENTITY_INSERT dbo.CRM_CustomerMemo ON;

    INSERT INTO dbo.CRM_CustomerMemo (
        [ID], [CustomerNo], [MemoType], [MemoDesc], [FileName],
        [aStatus], [Creator], [CreateTime], [Modifier], [ModiTime])
    SELECT
        [ID], [CustomerNo], [MemoType], [MemoDesc], [FileName],
        [aStatus], [Creator], [CreateTime], [Modifier], [ModiTime]
    FROM PRORIL_WEB.dbo.CRM_CustomerMemo;

    SET IDENTITY_INSERT dbo.CRM_CustomerMemo OFF;
END
GO
