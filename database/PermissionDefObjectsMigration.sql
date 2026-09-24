/*
================================================================================
 字串權限（PermissionKey）：新增 M_PermissionDef，M_Permission / M_PermissionGroup 加欄位
================================================================================

 在 **Proril_Sales_Center** 上執行（不是 PRORIL_WEB）。M_PermissionDef 是 2.0 新表，
 PRORIL_WEB 沒有，也不在 TABLES.txt（copy-snapshot-data.ps1 是從 PRORIL_WEB 複製，這張表不歸它管）。

 權限改成 Google IAM 式的三段字串 `module.function.action`，例如
   salesSearch.mixSalesShipping.view         → 進得去銷貨檢索
   salesSearch.mixSalesShipping.viewAmount   → 銷貨檢索顯示金額欄位
 取代原本「FunctionNo + 各功能自訂的 LinkType 數字（100 = 顯示金額）」的魔術數字。

 做四件事：
   1. 建 M_PermissionDef（若不存在），灌 14 個權限（MERGE，可重跑）。
      FunctionNo / LinkType / PermissionLinkTypeID 是對回舊模型的欄位，過渡期寫入
      M_Permission 時一併填，側欄（GetUserFunctions）仍靠 FunctionNo。
   2. M_Permission / M_PermissionGroup 加 PermissionKey 欄位與索引（若不存在）。
   3. 以 (FunctionNo, LinkType) 回填既有列的 PermissionKey。
   4. 驗證：列出回填不到的列。這些**不是錯誤**——FunctionNoFormatMigration.sql 刻意保留了
      2.0 沒有頁面的 1.0 功能（FunctionNo 還是舊數字，例如 '13'、'441'），它們本來就
      不在 M_PermissionDef 裡。api/ 存檔時只動有 PermissionKey 的列，這些會原封不動。
      要注意的只有 FunctionNo 是 7 碼 AAABBCC 格式卻回填不到的列（代表主檔漏了細項）。

 **不要**用 scripts/publish.ps1 建這張表 / 加這個欄位，理由見 CLAUDE.md
 「Proril_Sales_Center 的建表一律走 *ObjectsMigration.sql」。

 執行方式：
   sqlcmd -S <host>,<port> -d Proril_Sales_Center -U <user> -P <pw> -C -i PermissionDefObjectsMigration.sql
 之後請再跑一次 PermissionMasterSeed.sql，才會有 0000103 群組權限這個功能。

 **已被取代**：2026-09-23 改成角色制之後，RbacObjectsMigration.sql 會把 M_PermissionDef
 改名成 RBAC_Permission（並拿掉 PermissionLinkTypeID）。新環境仍是先跑這支、再跑那支；
 已經改名過的庫再跑這支會自動略過。
================================================================================
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF DB_NAME() <> 'Proril_Sales_Center'
BEGIN
    RAISERROR('這支腳本要在 Proril_Sales_Center 上執行，目前連到的是別的資料庫。', 16, 1);
    SET NOEXEC ON;
END
GO

-- 2026-09-23 起 M_PermissionDef 已由 RbacObjectsMigration.sql 改名成 RBAC_Permission。
-- 改名之後再跑這支會重建一張空的 M_PermissionDef、回填也會失準，直接跳過。
IF OBJECT_ID('dbo.RBAC_Permission', 'U') IS NOT NULL
BEGIN
    PRINT 'RBAC_Permission 已存在（M_PermissionDef 已改名），這支不需要再跑，略過。';
    SET NOEXEC ON;
END
GO

-- ---------------------------------------------------------------- 1. M_PermissionDef

-- 這張表原本叫 M_PermissionAction（2026-09-23 改名，測試區已用舊名建過一次）。
-- 還是舊名的庫就原地改名，資料不動；constraint 名稱一併改，跟 SalesCenterDbContext 的對映一致。
IF OBJECT_ID('dbo.M_PermissionAction', 'U') IS NOT NULL AND OBJECT_ID('dbo.M_PermissionDef', 'U') IS NULL
BEGIN
    EXEC sp_rename 'dbo.M_PermissionAction', 'M_PermissionDef';
    EXEC sp_rename 'dbo.PK_M_PermissionAction', 'PK_M_PermissionDef', 'OBJECT';
    EXEC sp_rename 'dbo.UQ_M_PermissionAction_PermissionKey', 'UQ_M_PermissionDef_PermissionKey', 'OBJECT';
    EXEC sp_rename 'dbo.UQ_M_PermissionAction_FunctionNo_LinkType', 'UQ_M_PermissionDef_FunctionNo_LinkType', 'OBJECT';
    EXEC sp_rename 'dbo.DF_M_PermissionAction_Sort', 'DF_M_PermissionDef_Sort', 'OBJECT';
    EXEC sp_rename 'dbo.DF_M_PermissionAction_aStatus', 'DF_M_PermissionDef_aStatus', 'OBJECT';
    PRINT '已把 dbo.M_PermissionAction 改名為 dbo.M_PermissionDef';
END
GO

IF OBJECT_ID('dbo.M_PermissionDef', 'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[M_PermissionDef] (
        [ID]                   INT            IDENTITY (1, 1) NOT NULL,
        [PermissionKey]        VARCHAR (100)  NOT NULL,
        [FunctionNo]           VARCHAR (8)    NOT NULL,
        [LinkType]             TINYINT        NOT NULL,   -- 1 = view（功能本身），>1 = 細項
        [PermissionLinkTypeID] INT            NULL,       -- 對回 M_PermissionLinkType，過渡期用
        [ParentPermissionKey]  VARCHAR (100)  NULL,       -- 細項底下再掛細項時用，NULL = 直接掛在功能底下
        [ActionName]           NVARCHAR (50)  NOT NULL,
        [Sort]                 INT            CONSTRAINT [DF_M_PermissionDef_Sort] DEFAULT (0) NOT NULL,
        [aStatus]              VARCHAR (1)    CONSTRAINT [DF_M_PermissionDef_aStatus] DEFAULT ('Y') NOT NULL,
        [Creator]              VARCHAR (10)   NULL,
        [CreateTime]           DATETIME       NULL,
        [Modifier]             VARCHAR (10)   NULL,
        [ModiTime]             DATETIME       NULL,
        CONSTRAINT [PK_M_PermissionDef] PRIMARY KEY CLUSTERED ([ID] ASC),
        CONSTRAINT [UQ_M_PermissionDef_PermissionKey] UNIQUE ([PermissionKey]),
        CONSTRAINT [UQ_M_PermissionDef_FunctionNo_LinkType] UNIQUE ([FunctionNo], [LinkType])
    );
    PRINT '已建立 dbo.M_PermissionDef';
END
GO

MERGE dbo.M_PermissionDef AS t
USING (VALUES
    ('system.permissionManager.view',            '0000101',   1, N'權限管理',       10),
    ('system.userManager.view',                  '0000102',   1, N'人員管理',       20),
    ('system.groupPermission.view',              '0000103',   1, N'群組權限',       30),
    ('salesIssue.kindMaintain.view',             '0070101',   1, N'類別維護',       10),
    ('salesIssue.processMaintain.view',          '0070102',   1, N'議題維護',       20),
    ('salesIssue.processMaintain.createSop',     '0070102',  10, N'SOP-新增',       21),
    ('salesIssue.processMaintain.publishSop',    '0070102',  20, N'SOP-公開',       22),
    ('salesSearch.mixSalesShipping.view',        '0320101',   1, N'銷貨檢索',       10),
    ('salesSearch.mixSalesShipping.viewAmount',  '0320101', 100, N'顯示金額欄位',   11),
    ('salesSearch.queryUnFinish.view',           '0320102',   1, N'未完成訂單',     20),
    ('salesSearch.queryUnFinish.viewAmount',     '0320102', 100, N'顯示金額欄位',   21),
    ('salesSearch.customQuery.view',             '0320103',   1, N'客戶檢索',       30),
    ('salesSearch.orderInfoVerify.view',         '0320201',   1, N'訂單資料檢核',   40),
    -- 1.0 起就有檢查、但 M_PermissionLinkType 沒有這列，權限樹勾不到；這裡補上
    ('salesSearch.orderInfoVerify.viewAmount',   '0320201', 100, N'顯示金額欄位',   41)
) AS s (PermissionKey, FunctionNo, LinkType, ActionName, Sort)
ON t.PermissionKey = s.PermissionKey
WHEN MATCHED THEN
    UPDATE SET FunctionNo = s.FunctionNo, LinkType = s.LinkType, ActionName = s.ActionName,
               Sort = s.Sort, aStatus = 'Y', Modifier = 'migration', ModiTime = GETDATE()
WHEN NOT MATCHED BY TARGET THEN
    INSERT (PermissionKey, FunctionNo, LinkType, ActionName, Sort, aStatus, Creator, CreateTime)
    VALUES (s.PermissionKey, s.FunctionNo, s.LinkType, s.ActionName, s.Sort, 'Y', 'migration', GETDATE());
GO

-- 細項對回 M_PermissionLinkType 的 ID（orderInfoVerify.viewAmount 沒有對應列，維持 NULL）
UPDATE a
SET a.PermissionLinkTypeID = lt.ID
FROM dbo.M_PermissionDef a
JOIN dbo.M_PermissionLinkType lt ON lt.FunctionNo = a.FunctionNo AND lt.LinkType = a.LinkType
WHERE a.LinkType > 1;
GO

-- ---------------------------------------------------------------- 2. 加欄位

IF COL_LENGTH('dbo.M_Permission', 'PermissionKey') IS NULL
BEGIN
    ALTER TABLE dbo.M_Permission ADD [PermissionKey] VARCHAR (100) NULL;
    PRINT '已加 dbo.M_Permission.PermissionKey';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_M_Permission_LinkNumber_PermissionKey'
                                           AND object_id = OBJECT_ID('dbo.M_Permission'))
    CREATE NONCLUSTERED INDEX [IX_M_Permission_LinkNumber_PermissionKey]
        ON dbo.M_Permission ([LinkNumber], [PermissionKey]);
GO

IF COL_LENGTH('dbo.M_PermissionGroup', 'PermissionKey') IS NULL
BEGIN
    ALTER TABLE dbo.M_PermissionGroup ADD [PermissionKey] VARCHAR (100) NULL;
    PRINT '已加 dbo.M_PermissionGroup.PermissionKey';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_M_PermissionGroup_Group_PermissionKey'
                                           AND object_id = OBJECT_ID('dbo.M_PermissionGroup'))
    CREATE NONCLUSTERED INDEX [IX_M_PermissionGroup_Group_PermissionKey]
        ON dbo.M_PermissionGroup ([GroupType], [GroupNo], [PermissionKey]);
GO

-- ---------------------------------------------------------------- 3. 回填

BEGIN TRANSACTION;

-- LinkType 0 / NULL 的舊資料一律當成「功能本身」（同 permissionTree.ts 原本 linkType <= 1 的判斷）
UPDATE p
SET p.PermissionKey = a.PermissionKey
FROM dbo.M_Permission p
JOIN dbo.M_PermissionDef a
  ON a.FunctionNo = p.FunctionNo
 AND a.LinkType = CASE WHEN p.LinkType <= 1 THEN 1 ELSE p.LinkType END
WHERE p.PermissionKey IS NULL OR p.PermissionKey <> a.PermissionKey;

UPDATE g
SET g.PermissionKey = a.PermissionKey
FROM dbo.M_PermissionGroup g
JOIN dbo.M_PermissionDef a
  ON a.FunctionNo = g.FunctionNo
 AND a.LinkType = CASE WHEN ISNULL(g.LinkType, 1) <= 1 THEN 1 ELSE g.LinkType END
WHERE g.PermissionKey IS NULL OR g.PermissionKey <> a.PermissionKey;

COMMIT TRANSACTION;
GO

-- ---------------------------------------------------------------- 4. 驗證

PRINT '--- M_PermissionDef ---';
SELECT ID, PermissionKey, FunctionNo, LinkType, PermissionLinkTypeID, ActionName, Sort, aStatus
FROM dbo.M_PermissionDef
ORDER BY FunctionNo, LinkType;

-- 回填不到的列分兩種：
--   舊數字 FunctionNo（2.0 沒有頁面的 1.0 功能）→ 刻意保留，只列筆數
--   7 碼 AAABBCC 卻回填不到 → M_PermissionDef 漏了細項，**這種要處理，應為 0 筆**
PRINT '--- 回填不到 PermissionKey 的舊功能列（刻意保留，存檔不會動到）---';
SELECT 'M_Permission' AS TableName, COUNT(*) AS Cnt
FROM dbo.M_Permission WHERE PermissionKey IS NULL AND LEN(FunctionNo) <> 7
UNION ALL
SELECT 'M_PermissionGroup', COUNT(*)
FROM dbo.M_PermissionGroup WHERE PermissionKey IS NULL AND LEN(FunctionNo) <> 7;

PRINT '--- 2.0 功能卻回填不到 PermissionKey 的列（應為 0 筆）---';
SELECT 'M_Permission' AS TableName, ID, LinkNumber AS Owner, FunctionNo, LinkType
FROM dbo.M_Permission WHERE PermissionKey IS NULL AND LEN(FunctionNo) = 7
UNION ALL
SELECT 'M_PermissionGroup', ID, GroupNo, FunctionNo, LinkType
FROM dbo.M_PermissionGroup WHERE PermissionKey IS NULL AND LEN(FunctionNo) = 7;
GO

SET NOEXEC OFF;
GO
