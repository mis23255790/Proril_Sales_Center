/*
 * 格式匯入（1.0 系統設定 / 格式匯入，Views/System/ImportXlsFormat.cshtml）：
 * Excel 匯出版型表 CMN_XlsFileFormat + 權限樹節點，建在 Proril_Sales_Center。
 *
 * 背景：
 *   - 1.0 有兩張版型表 PUR_XlsFileFormat / CMN_XlsFileFormat，由「格式匯入」頁上傳 Excel 範本
 *     逐列／逐欄／逐格寫入，各模組匯出時再讀出來組表頭、欄寬、樣式（XlsFormatterApis(_Cmn)）。
 *   - 2.0 只保留一張 CMN_XlsFileFormat（2026-09-30 決定，PUR 那張不搬），
 *     匯入解析沿用 1.0 PUR 版比較完整的那套（數字帶格式、ARGB 底色、NumberFormatId、隱藏欄）。
 *   - 2.0 三支匯出（銷貨檢索／未完成訂單／訂單資料檢核）有版型就套版型，
 *     **沒有版型就退回原本寫死在 C# 的版面**，所以這張表是空的也不影響匯出。
 *
 * **跟 1.0 同名但不同表**：
 *   - 1.0 用 FunctionNo（int 流水號，410/420/425）當 key，這裡改成 PermissionKey
 *     （頁面權限 key，例如 salesSearch.mixSalesShipping），與 2.0 其他地方一致。
 *   - Caption / WSName 改 nvarchar；XLSettings 放大到 nvarchar(300)
 *     （會計格式字串很長，1.0 的 varchar(150) 放不下完整的四段格式）。
 *   - **不從 PRORIL_WEB 複製資料**（2026-09-30 決定）：key 不同，而且 1.0 那份還有很多
 *     還沒搬的模組在用，兩邊各自維護。要套版型就用 2.0 的格式匯入頁重新匯入範本。
 *   - 跟 RBAC_* 一樣是新庫專屬的表，**不放進 database/Tables/ 與 TABLES.txt**
 *     （那邊對照的是 PRORIL_WEB 的 schema，也是 copy-snapshot-data.ps1 的複製白名單，
 *     放進去會把 1.0 的 int key 資料灌進來）。
 *
 * 權限樹：新增 GROUP system.grpSetting（系統設定）與 PAGE system.importXlsFormat（格式匯入），
 * 同時已補進 RbacObjectsMigration.sql 第 4b.4 段的清單（全新環境建庫用）。
 * 這裡用 MERGE 只補「不存在」的節點，已存在的不覆寫（名稱／位置之後直接在 DB 改）。
 *
 * 怎麼執行：走 database/scripts/run-objects-migration.ps1，不要直接丟進 SSMS。
 *
 *   .\scripts\run-objects-migration.ps1 -Script XlsFormatObjectsMigration.sql -Environment snapshot
 *   .\scripts\run-objects-migration.ps1 -Script XlsFormatObjectsMigration.sql -Environment snapshot -Execute
 *
 * 不需要 linked server，報「不存在」不影響這支。可重複執行。
 */

USE Proril_Sales_Center;
GO

-- ============================================================
-- 1. 資料表：CMN_XlsFileFormat
--    一列 = 一個版型元素，靠欄位組合區分種類（與 1.0 相同）：
--      Height 有值                 → 列（列高）
--      Width 有值                  → 欄（欄寬、欄樣式、數字格式、隱藏）
--      SplitRow / SplitColumn 有值 → 分頁層級（凍結窗格）
--      其他                        → 儲存格（文字、樣式、數字格式）
-- ============================================================

IF OBJECT_ID('dbo.CMN_XlsFileFormat') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMN_XlsFileFormat] (
        [ID]                INT            IDENTITY (1, 1) NOT NULL,
        [PermissionKey]     VARCHAR (100)  NOT NULL,
        [FunctionSubNo]     VARCHAR (40)   NOT NULL,
        [WSName]            NVARCHAR (40)  NOT NULL,
        [ColumnStartID]     VARCHAR (4)    NULL,
        [ColumnEndID]       VARCHAR (4)    NULL,
        [RowStartID]        INT            NULL,
        [RowEndID]          INT            NULL,
        [Caption]           NVARCHAR (400) NULL,
        [FormulaA1]         NVARCHAR (400) NULL,
        [StyleAlignmentH]   VARCHAR (20)   NULL,
        [StyleAlignmentV]   VARCHAR (20)   NULL,
        [StyleBorderLeft]   VARCHAR (20)   NULL,
        [StyleBorderTop]    VARCHAR (20)   NULL,
        [StyleBorderRight]  VARCHAR (20)   NULL,
        [StyleBorderBottom] VARCHAR (20)   NULL,
        [StyleFillColor]    VARCHAR (100)  NULL,
        [StyleFontSize]     FLOAT (53)     NULL,
        [StyleFontBold]     BIT            NULL,
        [StyleFontColor]    VARCHAR (100)  NULL,
        [StyleWrapText]     BIT            NULL,
        [Width]             FLOAT (53)     NULL,
        [Height]            FLOAT (53)     NULL,
        [SplitRow]          INT            NULL,
        [SplitColumn]       INT            NULL,
        [XLSettings]        NVARCHAR (300) NULL,
        [IsHidden]          BIT            NULL,
        [Creator]           VARCHAR (40)   NULL,
        [CreateTime]        DATETIME       NULL,
        [Modifier]          VARCHAR (40)   NULL,
        [ModiTime]          DATETIME       NULL,
        CONSTRAINT [PK_CMN_XlsFileFormat] PRIMARY KEY CLUSTERED ([ID] ASC)
    );
    CREATE NONCLUSTERED INDEX [IX_CMN_XlsFileFormat_Key]
        ON [dbo].[CMN_XlsFileFormat] ([PermissionKey], [FunctionSubNo], [WSName]);
    PRINT '已建立 dbo.CMN_XlsFileFormat';
END
GO

-- ============================================================
-- 2. 權限樹節點：系統管理 / 系統設定 / 格式匯入
--    父節點（system 模組）必須已存在（RbacObjectsMigration.sql 跑過）。
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_Permission WHERE PermissionKey = 'system')
BEGIN
    RAISERROR('RBAC_Permission 沒有 system 模組節點，請先跑 RbacObjectsMigration.sql。', 16, 1);
END
ELSE
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_Permission WHERE PermissionKey = 'system.grpSetting')
    BEGIN
        INSERT INTO dbo.RBAC_Permission (PermissionKey, NodeType, ParentKey, Label, LabelEn, Path, Icon, Description, Sort, aStatus, Creator, CreateTime)
        VALUES ('system.grpSetting', 'GROUP', 'system', N'系統設定', NULL, NULL, NULL, NULL, 20, 'Y', 'migration', GETDATE());
        PRINT '已新增權限節點 system.grpSetting';
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_Permission WHERE PermissionKey = 'system.importXlsFormat')
    BEGIN
        INSERT INTO dbo.RBAC_Permission (PermissionKey, NodeType, ParentKey, Label, LabelEn, Path, Icon, Description, Sort, aStatus, Creator, CreateTime)
        VALUES ('system.importXlsFormat', 'PAGE', 'system.grpSetting', N'格式匯入', NULL, 'system/import-xls-format',
                'i-lucide-file-spreadsheet', N'上傳 Excel 範本，設定各功能匯出檔的表頭、欄寬與樣式', 10, 'Y', 'migration', GETDATE());
        PRINT '已新增權限節點 system.importXlsFormat';
    END
END
GO
