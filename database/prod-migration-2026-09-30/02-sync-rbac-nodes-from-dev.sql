/*
================================================================================
 51002 Proril_Sales_Center：RBAC_Permission 權限樹節點對齊 50002（Dev）
================================================================================

 前置：RbacObjectsMigration.sql 已在 51002 跑完（RBAC_Permission 已有 NodeType / ParentKey）。

 RbacObjectsMigration.sql 第 4b.4 段灌的是預設值（全部 aStatus = 'Y'），
 但 50002 之後在 DB 手動調過：
   - salesIssue 模組與底下 salesIssue.grpIssue / salesIssue.grpBasic 設成 'N'
     （aStatus = 'N' 會連同整棵子樹失效，業務議題的頁面因此在側欄消失）
   - system.groupPermission 維持 'N'
 下面的 VALUES 是 2026-09-30 從 50002 RBAC_Permission 逐列產生的（不是手打），
 MERGE 把 NodeType / ParentKey / Label / LabelEn / Path / Icon / Description / Sort / aStatus
 全部蓋成 Dev 的值。可重跑。

 不刪 51002 多出來的節點（正常不會有）；只列出來讓人工確認。

 執行：
   sqlcmd -S 192.168.1.142,51002 -U proril_sales_center -d Proril_Sales_Center -C -f 65001 -i 02-sync-rbac-nodes-from-dev.sql
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

IF COL_LENGTH('dbo.RBAC_Permission', 'NodeType') IS NULL
BEGIN
    RAISERROR('RBAC_Permission 還沒有 NodeType，請先跑 RbacObjectsMigration.sql。', 16, 1);
    SET NOEXEC ON;
END
GO

IF OBJECT_ID('tempdb..#Dev') IS NOT NULL DROP TABLE #Dev;
-- 暫存表建在 tempdb，字串欄位要 COLLATE DATABASE_DEFAULT，否則跟本庫比對會噴 collation conflict
CREATE TABLE #Dev (
    PermissionKey VARCHAR(100)  COLLATE DATABASE_DEFAULT PRIMARY KEY,
    NodeType      VARCHAR(10)   COLLATE DATABASE_DEFAULT NOT NULL,
    ParentKey     VARCHAR(100)  COLLATE DATABASE_DEFAULT NULL,
    Label         NVARCHAR(100) COLLATE DATABASE_DEFAULT NOT NULL,
    LabelEn       VARCHAR(50)   COLLATE DATABASE_DEFAULT NULL,
    Path          VARCHAR(200)  COLLATE DATABASE_DEFAULT NULL,
    Icon          VARCHAR(100)  COLLATE DATABASE_DEFAULT NULL,
    Description   NVARCHAR(200) COLLATE DATABASE_DEFAULT NULL,
    Sort INT NOT NULL,
    aStatus       VARCHAR(1)    COLLATE DATABASE_DEFAULT NOT NULL,
    Lvl INT NOT NULL
);

INSERT INTO #Dev (PermissionKey, NodeType, ParentKey, Label, LabelEn, Path, Icon, Description, Sort, aStatus, Lvl)
SELECT v.*, CASE v.NodeType WHEN 'MODULE' THEN 1 WHEN 'GROUP' THEN 2 WHEN 'PAGE' THEN 3 ELSE 4 END
FROM (VALUES
        ('salesIssue', 'MODULE', NULL, N'業務議題', 'Sales Issue', 'sales-issue', 'i-lucide-messages-square', NULL, 10, 'N'),
        ('salesSearch', 'MODULE', NULL, N'業務檢索', 'Sales Search', 'sales-search', 'i-lucide-search', NULL, 20, 'Y'),
        ('system', 'MODULE', NULL, N'系統管理', 'System', 'system', 'i-lucide-settings', NULL, 30, 'Y'),
        ('salesIssue.grpIssue', 'GROUP', 'salesIssue', N'議題管理', NULL, NULL, NULL, NULL, 10, 'N'),
        ('salesIssue.grpBasic', 'GROUP', 'salesIssue', N'基本資料', NULL, NULL, NULL, NULL, 20, 'N'),
        ('salesSearch.grpCustomer', 'GROUP', 'salesSearch', N'客戶', NULL, NULL, NULL, NULL, 10, 'Y'),
        ('salesSearch.grpSales', 'GROUP', 'salesSearch', N'銷貨', NULL, NULL, NULL, NULL, 20, 'Y'),
        ('salesSearch.grpOrder', 'GROUP', 'salesSearch', N'訂單', NULL, NULL, NULL, NULL, 30, 'Y'),
        ('system.grpAccess', 'GROUP', 'system', N'權限控管', NULL, NULL, NULL, NULL, 10, 'Y'),
        ('salesIssue.kindMaintain', 'PAGE', 'salesIssue.grpBasic', N'類別維護', NULL, 'sales-issue/kind-maintain', 'i-lucide-tags', N'維護議題的類別與職能主題關鍵字', 10, 'Y'),
        ('salesIssue.processMaintain', 'PAGE', 'salesIssue.grpIssue', N'議題維護', NULL, 'sales-issue/issues', 'i-lucide-clipboard-list', N'依客戶別追蹤議題進度、附件與結案狀態', 10, 'Y'),
        ('salesSearch.customQuery', 'PAGE', 'salesSearch.grpCustomer', N'客戶檢索', NULL, 'sales-search/customer', 'i-lucide-users', N'查詢內網／ERP客戶，新增或編輯內網客戶資料與 ERP 對應', 10, 'Y'),
        ('salesSearch.queryUnFinish', 'PAGE', 'salesSearch.grpOrder', N'未完成訂單', NULL, 'sales-search/unfinished-orders', 'i-lucide-package-search', N'依客戶別、訂單日期、預交日期、品號查詢尚未出貨的訂單，含品號/訂單細項與統計', 10, 'Y'),
        ('salesSearch.orderInfoVerify', 'PAGE', 'salesSearch.grpOrder', N'訂單資料檢核', NULL, 'sales-search/order-info-verify', 'i-lucide-shield-check', N'對訂單金額、信用額度等項目執行檢核，支援特規覆核與 Excel 匯出', 20, 'Y'),
        ('salesSearch.mixSalesShipping', 'PAGE', 'salesSearch.grpSales', N'銷貨檢索', NULL, 'sales-search/shipping-inquiry', 'i-lucide-truck', N'依客戶別、期間、品號查詢銷貨單，含品號/銷貨單細項與統計', 10, 'Y'),
        ('system.userManager', 'PAGE', 'system.grpAccess', N'人員管理', NULL, 'system/user-manager', 'i-lucide-user-cog', N'新增／停用帳號、指派角色、重置密碼與解除鎖定', 10, 'Y'),
        ('system.permissionManager', 'PAGE', 'system.grpAccess', N'權限管理', NULL, 'system/permission-manager', 'i-lucide-shield-check', N'維護角色：每個角色可用的功能與細項權限，以及角色成員', 20, 'Y'),
        ('system.groupPermission', 'PAGE', 'system.grpAccess', N'群組權限', NULL, NULL, NULL, NULL, 30, 'N'),
        ('salesIssue.processMaintain.createSop', 'ACTION', 'salesIssue.processMaintain', N'SOP-新增', NULL, NULL, NULL, NULL, 10, 'Y'),
        ('salesIssue.processMaintain.publishSop', 'ACTION', 'salesIssue.processMaintain', N'SOP-公開', NULL, NULL, NULL, NULL, 20, 'Y'),
        ('salesSearch.mixSalesShipping.viewAmount', 'ACTION', 'salesSearch.mixSalesShipping', N'顯示金額欄位', NULL, NULL, NULL, NULL, 10, 'Y'),
        ('salesSearch.orderInfoVerify.viewAmount', 'ACTION', 'salesSearch.orderInfoVerify', N'顯示金額欄位', NULL, NULL, NULL, NULL, 10, 'Y'),
        ('salesSearch.queryUnFinish.viewAmount', 'ACTION', 'salesSearch.queryUnFinish', N'顯示金額欄位', NULL, NULL, NULL, NULL, 10, 'Y')
) AS v (PermissionKey, NodeType, ParentKey, Label, LabelEn, Path, Icon, Description, Sort, aStatus);
GO

BEGIN TRANSACTION;

-- 由上往下處理（MODULE → GROUP → PAGE → ACTION），新增節點時父節點一定已存在，自我參照外鍵才過得了
DECLARE @lvl INT = 1;
WHILE @lvl <= 4
BEGIN
    MERGE dbo.RBAC_Permission AS t
    USING (SELECT * FROM #Dev WHERE Lvl = @lvl) AS s
    ON t.PermissionKey = s.PermissionKey
    WHEN MATCHED AND (
            t.NodeType <> s.NodeType
         OR ISNULL(t.ParentKey, '') <> ISNULL(s.ParentKey, '')
         OR t.Label <> s.Label
         OR ISNULL(t.LabelEn, '') <> ISNULL(s.LabelEn, '')
         OR ISNULL(t.Path, '') <> ISNULL(s.Path, '')
         OR ISNULL(t.Icon, '') <> ISNULL(s.Icon, '')
         OR ISNULL(t.Description, N'') <> ISNULL(s.Description, N'')
         OR t.Sort <> s.Sort
         OR t.aStatus <> s.aStatus) THEN
        UPDATE SET NodeType = s.NodeType, ParentKey = s.ParentKey, Label = s.Label, LabelEn = s.LabelEn,
                   Path = s.Path, Icon = s.Icon, Description = s.Description, Sort = s.Sort,
                   aStatus = s.aStatus, Modifier = 'migration', ModiTime = GETDATE()
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (PermissionKey, NodeType, ParentKey, Label, LabelEn, Path, Icon, Description, Sort, aStatus, Creator, CreateTime)
        VALUES (s.PermissionKey, s.NodeType, s.ParentKey, s.Label, s.LabelEn, s.Path, s.Icon, s.Description, s.Sort,
                s.aStatus, 'migration', GETDATE());
    PRINT CONCAT('第 ', @lvl, ' 層節點異動：', @@ROWCOUNT, ' 列');
    SET @lvl += 1;
END

COMMIT TRANSACTION;
GO

PRINT '--- 51002 有、Dev 沒有的節點（應為 0 筆，有的話人工確認）---';
SELECT p.PermissionKey, p.NodeType, p.aStatus
FROM dbo.RBAC_Permission p
WHERE NOT EXISTS (SELECT 1 FROM #Dev d WHERE d.PermissionKey = p.PermissionKey);

PRINT '--- 與 Dev 仍不一致的節點（應為 0 筆）---';
SELECT d.PermissionKey
FROM #Dev d
LEFT JOIN dbo.RBAC_Permission p ON p.PermissionKey = d.PermissionKey
WHERE p.ID IS NULL
   OR p.NodeType <> d.NodeType OR ISNULL(p.ParentKey, '') <> ISNULL(d.ParentKey, '')
   OR p.Label <> d.Label OR ISNULL(p.Path, '') <> ISNULL(d.Path, '')
   OR ISNULL(p.Icon, '') <> ISNULL(d.Icon, '') OR p.Sort <> d.Sort OR p.aStatus <> d.aStatus;
GO

SET NOEXEC OFF;
GO
