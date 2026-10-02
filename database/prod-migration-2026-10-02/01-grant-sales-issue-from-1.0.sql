/*
  2026-10-02：把 1.0（PRORIL_WEB）有業務議題權限的人，在 2.0（Proril_Sales_Center）也開通

  對照（1.0 M_Permission 的 FunctionNo / LinkType → 2.0 PermissionKey）：
    16, LinkType <= 1  -> salesIssue.kindMaintain               類別維護
    17, LinkType <= 1  -> salesIssue.processMaintain            議題維護
    17, LinkType = 10  -> salesIssue.processMaintain.createSop  SOP-新增
    17, LinkType = 20  -> salesIssue.processMaintain.publishSop SOP-公開
  1.0 的有效權限 = 本人 ∪ LinkNumber '000000'（MainApiController_SystemSetting.cs），這裡照算。

  做的事：
    1. （@EnableModule = 1）salesIssue 模組與 grpIssue / grpBasic 分組改回 aStatus = 'Y'。
       2026-09-30 對齊 Dev 時被設成 'N'，整棵子樹失效，不改回來勾了 key 也進不去。
    2. 每個帳號算出「1.0 有、2.0 目前還沒有效擁有」的業務議題 key
       （2.0 已有 = 所屬角色 ∪ everyone；superAdmin 成員略過），
       依 key 組合分群，一組建一個角色「業務議題-NN」（RoleCode salesIssueNN），再掛成員。
       比照 RbacObjectsMigration.sql 第 4.3 段的簽章分群，只是範圍限業務議題。
    3. 只加不刪：2.0 已有、1.0 沒有的權限不動。

  可重跑：第二次跑時大家都已經有效擁有那些 key，不會再建角色；編號接在既有 salesIssueNN 後面。

  前提 / 跑法：
    - 要同時讀 PRORIL_WEB、寫 Proril_Sales_Center。proril_sales_center 帳號對 PRORIL_WEB
      沒有 SELECT（見 prod-migration-2026-09-21/README.md），要用兩邊都有權限的帳號跑。
    - 預設 @Execute = 0：整段跑完印出結果後 ROLLBACK（dry-run）。確認無誤改成 1 再跑。
      sqlcmd -S 192.168.1.142,51002 -U <帳號> -d Proril_Sales_Center -C -f 65001 -i 01-grant-sales-issue-from-1.0.sql
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Execute      BIT = 0;   -- 0 = dry-run（最後 ROLLBACK），1 = 實際寫入
DECLARE @EnableModule BIT = 1;   -- 1 = 一併把 salesIssue 模組與分組改回 'Y'
DECLARE @Operator     VARCHAR(10) = 'migration';

IF DB_NAME() <> 'Proril_Sales_Center'
BEGIN
    RAISERROR('這支腳本要在 Proril_Sales_Center 上執行，目前連到的是別的資料庫。', 16, 1);
    RETURN;
END

BEGIN TRANSACTION;

-- ---------------------------------------------------------------- 0. 1.0 權限（本人 ∪ 000000）

CREATE TABLE #Map (FunctionNo INT NOT NULL, LinkType INT NOT NULL,
                   PermissionKey VARCHAR(100) COLLATE DATABASE_DEFAULT NOT NULL);
INSERT INTO #Map (FunctionNo, LinkType, PermissionKey) VALUES
    (16,  1, 'salesIssue.kindMaintain'),
    (17,  1, 'salesIssue.processMaintain'),
    (17, 10, 'salesIssue.processMaintain.createSop'),
    (17, 20, 'salesIssue.processMaintain.publishSop');

CREATE TABLE #Src (LinkNumber VARCHAR(20) COLLATE DATABASE_DEFAULT NOT NULL,
                   FunctionNo INT NOT NULL, LinkType INT NOT NULL);
INSERT INTO #Src (LinkNumber, FunctionNo, LinkType)
SELECT DISTINCT LTRIM(RTRIM(p.LinkNumber)), p.FunctionNo,
       CASE WHEN ISNULL(p.LinkType, 1) <= 1 THEN 1 ELSE p.LinkType END
FROM PRORIL_WEB.dbo.M_Permission p
WHERE p.FunctionNo IN (16, 17);

PRINT '--- 1.0 業務議題權限列中對不到 2.0 key 的（應為 0 筆，不是 0 筆要先補 #Map）---';
SELECT s.* FROM #Src s
WHERE NOT EXISTS (SELECT 1 FROM #Map m WHERE m.FunctionNo = s.FunctionNo AND m.LinkType = s.LinkType);

-- 2.0 帳號（M_User）× 1.0 key（本人 ∪ 000000）
CREATE TABLE #Want (Account VARCHAR(10) COLLATE DATABASE_DEFAULT NOT NULL,
                    PermissionKey VARCHAR(100) COLLATE DATABASE_DEFAULT NOT NULL,
                    PRIMARY KEY (Account, PermissionKey));
INSERT INTO #Want (Account, PermissionKey)
SELECT DISTINCT LTRIM(RTRIM(u.Account)), m.PermissionKey
FROM dbo.M_User u
JOIN #Src s ON s.LinkNumber IN (LTRIM(RTRIM(u.Account)), '000000')
JOIN #Map m ON m.FunctionNo = s.FunctionNo AND m.LinkType = s.LinkType;

PRINT '--- 1.0 有業務議題權限、但 2.0 M_User 沒有這個帳號（不會開通）---';
SELECT s.LinkNumber, COUNT(*) AS Rows1_0
FROM #Src s
WHERE s.LinkNumber <> '000000'
  AND NOT EXISTS (SELECT 1 FROM dbo.M_User u WHERE LTRIM(RTRIM(u.Account)) = s.LinkNumber)
GROUP BY s.LinkNumber;

-- ---------------------------------------------------------------- 1. 模組與分組改回 'Y'

IF @EnableModule = 1
BEGIN
    UPDATE dbo.RBAC_Permission
    SET aStatus = 'Y', Modifier = @Operator, ModiTime = GETDATE()
    WHERE PermissionKey IN ('salesIssue', 'salesIssue.grpIssue', 'salesIssue.grpBasic')
      AND aStatus <> 'Y';
    PRINT CONCAT('salesIssue 模組／分組改回 Y：', @@ROWCOUNT, ' 列');
END

PRINT '--- 業務議題節點狀態（PAGE / ACTION 停用的話角色勾了也不算）---';
SELECT PermissionKey, NodeType, ParentKey, Label, aStatus
FROM dbo.RBAC_Permission
WHERE PermissionKey = 'salesIssue' OR PermissionKey LIKE 'salesIssue.%'
ORDER BY PermissionKey;

-- ---------------------------------------------------------------- 2. 扣掉 2.0 已有效擁有的，分群建角色

-- 2.0 目前已擁有（所屬角色 ∪ everyone），superAdmin 成員整個略過
CREATE TABLE #Have (Account VARCHAR(10) COLLATE DATABASE_DEFAULT NOT NULL,
                    PermissionKey VARCHAR(100) COLLATE DATABASE_DEFAULT NOT NULL);
INSERT INTO #Have (Account, PermissionKey)
SELECT LTRIM(RTRIM(ru.Account)), rp.PermissionKey
FROM dbo.RBAC_RoleUser ru
JOIN dbo.RBAC_Role r ON r.ID = ru.RoleID AND r.aStatus = 'Y'
JOIN dbo.RBAC_RolePermission rp ON rp.RoleID = r.ID AND rp.aStatus = 'Y'
WHERE ru.aStatus = 'Y'
UNION
SELECT w.Account, rp.PermissionKey
FROM (SELECT DISTINCT Account FROM #Want) w
CROSS JOIN dbo.RBAC_Role r
JOIN dbo.RBAC_RolePermission rp ON rp.RoleID = r.ID AND rp.aStatus = 'Y'
WHERE r.IsDefault = 1 AND r.aStatus = 'Y';

CREATE TABLE #Need (Account VARCHAR(10) COLLATE DATABASE_DEFAULT NOT NULL,
                    PermissionKey VARCHAR(100) COLLATE DATABASE_DEFAULT NOT NULL,
                    PRIMARY KEY (Account, PermissionKey));
INSERT INTO #Need (Account, PermissionKey)
SELECT w.Account, w.PermissionKey
FROM #Want w
WHERE NOT EXISTS (SELECT 1 FROM #Have h WHERE h.Account = w.Account AND h.PermissionKey = w.PermissionKey)
  AND NOT EXISTS (SELECT 1 FROM dbo.RBAC_RoleUser ru
                  JOIN dbo.RBAC_Role r ON r.ID = ru.RoleID AND r.aStatus = 'Y' AND r.IsSuperAdmin = 1
                  WHERE ru.aStatus = 'Y' AND LTRIM(RTRIM(ru.Account)) = w.Account);

CREATE TABLE #Sig (Account VARCHAR(10) COLLATE DATABASE_DEFAULT PRIMARY KEY,
                   Signature VARCHAR(MAX) COLLATE DATABASE_DEFAULT NOT NULL);
INSERT INTO #Sig (Account, Signature)
SELECT Account, STRING_AGG(CONVERT(VARCHAR(MAX), PermissionKey), ',') WITHIN GROUP (ORDER BY PermissionKey)
FROM #Need
GROUP BY Account;

-- 編號接在既有 salesIssueNN 之後；同一批內依簽章裡字典序最小的帳號排
DECLARE @BaseNo INT = ISNULL((SELECT MAX(TRY_CAST(SUBSTRING(RoleCode, 11, 10) AS INT))
                              FROM dbo.RBAC_Role WHERE RoleCode LIKE 'salesIssue[0-9]%'), 0);

CREATE TABLE #Grp (GroupNo INT PRIMARY KEY,
                   Signature VARCHAR(MAX) COLLATE DATABASE_DEFAULT NOT NULL,
                   RoleCode VARCHAR(50) COLLATE DATABASE_DEFAULT NOT NULL,
                   RoleID INT NULL);
INSERT INTO #Grp (GroupNo, Signature, RoleCode)
SELECT @BaseNo + ROW_NUMBER() OVER (ORDER BY MIN(Account)), Signature, ''
FROM #Sig
GROUP BY Signature;
UPDATE #Grp SET RoleCode = 'salesIssue' + RIGHT('00' + CAST(GroupNo AS VARCHAR(10)), 2);

INSERT INTO dbo.RBAC_Role (RoleCode, RoleName, Description, IsSystem, IsSuperAdmin, IsDefault, Sort, aStatus, Creator, CreateTime)
SELECT g.RoleCode,
       N'業務議題-' + RIGHT('00' + CAST(g.GroupNo AS VARCHAR(10)), 2),
       N'由 1.0 業務議題權限依權限組合自動產生（2026-10-02），請改名或合併',
       0, 0, 0, 200 + g.GroupNo, 'Y', @Operator, GETDATE()
FROM #Grp g;
PRINT CONCAT('新增角色：', @@ROWCOUNT, ' 個');

UPDATE g SET g.RoleID = r.ID
FROM #Grp g JOIN dbo.RBAC_Role r ON r.RoleCode = g.RoleCode;

INSERT INTO dbo.RBAC_RolePermission (RoleID, PermissionKey, Creator, CreateTime)
SELECT DISTINCT g.RoleID, n.PermissionKey, @Operator, GETDATE()
FROM #Grp g
JOIN #Sig s ON s.Signature = g.Signature
JOIN #Need n ON n.Account = s.Account;
PRINT CONCAT('新增角色權限：', @@ROWCOUNT, ' 筆');

INSERT INTO dbo.RBAC_RoleUser (Account, RoleID, Creator, CreateTime)
SELECT s.Account, g.RoleID, @Operator, GETDATE()
FROM #Sig s
JOIN #Grp g ON g.Signature = s.Signature;
PRINT CONCAT('新增角色成員：', @@ROWCOUNT, ' 筆');

-- ---------------------------------------------------------------- 3. 結果與驗證

PRINT '--- 新建的角色與成員 ---';
SELECT g.RoleCode, s.Account, u.UserName, u.IsEnable, u.IsLocked, g.Signature
FROM #Grp g
JOIN #Sig s ON s.Signature = g.Signature
LEFT JOIN dbo.M_User u ON LTRIM(RTRIM(u.Account)) = s.Account
ORDER BY g.RoleCode, s.Account;

PRINT '--- 驗證：1.0 有、2.0 開通後仍沒有的（應為 0 筆；superAdmin 全放行不列）---';
SELECT w.Account, w.PermissionKey
FROM #Want w
WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.RBAC_RoleUser ru
        JOIN dbo.RBAC_Role r ON r.ID = ru.RoleID AND r.aStatus = 'Y'
        JOIN dbo.RBAC_RolePermission rp ON rp.RoleID = r.ID AND rp.aStatus = 'Y'
        WHERE ru.aStatus = 'Y' AND LTRIM(RTRIM(ru.Account)) = w.Account AND rp.PermissionKey = w.PermissionKey)
  AND NOT EXISTS (
        SELECT 1 FROM dbo.RBAC_Role r
        JOIN dbo.RBAC_RolePermission rp ON rp.RoleID = r.ID AND rp.aStatus = 'Y'
        WHERE r.IsDefault = 1 AND r.aStatus = 'Y' AND rp.PermissionKey = w.PermissionKey)
  AND NOT EXISTS (
        SELECT 1 FROM dbo.RBAC_RoleUser ru
        JOIN dbo.RBAC_Role r ON r.ID = ru.RoleID AND r.aStatus = 'Y' AND r.IsSuperAdmin = 1
        WHERE ru.aStatus = 'Y' AND LTRIM(RTRIM(ru.Account)) = w.Account);

IF @Execute = 1
BEGIN
    COMMIT TRANSACTION;
    PRINT '已寫入。';
END
ELSE
BEGIN
    ROLLBACK TRANSACTION;
    PRINT 'dry-run：已 ROLLBACK，資料沒動。確認無誤把 @Execute 改成 1 再跑。';
END
