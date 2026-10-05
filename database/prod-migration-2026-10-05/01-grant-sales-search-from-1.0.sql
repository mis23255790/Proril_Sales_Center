/*
  2026-10-05：把 1.0（PRORIL_WEB）有業務檢索權限的人，在 2.0（Proril_Sales_Center）也開通

  對照（1.0 M_Permission 的 FunctionNo / LinkType → 2.0 PermissionKey）：
    410, LinkType <= 1  -> salesSearch.mixSalesShipping              銷貨檢索
    410, LinkType = 100 -> salesSearch.mixSalesShipping.viewAmount   銷貨檢索-顯示金額
    420, LinkType <= 1  -> salesSearch.queryUnFinish                 未完成訂單
    420, LinkType = 100 -> salesSearch.queryUnFinish.viewAmount      未完成訂單-顯示金額
    425, LinkType <= 1  -> salesSearch.orderInfoVerify               訂單資料檢核
    425, LinkType = 100 -> salesSearch.orderInfoVerify.viewAmount    訂單資料檢核-顯示金額
    440, LinkType <= 1  -> salesSearch.customQuery                   客戶檢索
  LinkType 100 = 1.0 的 _permission_amount_LinkType（1.0 Controllers/MixSalesShip 底下各支 _XlsOut.cs）。
  1.0 的有效權限 = 本人 ∪ LinkNumber '000000'（MainApiController_SystemSetting.cs），這裡照算。

  刻意不轉：
    441 客戶相關資訊：2.0 沒有自己的 key（頁面靠 customQuery／mixSalesShipping 進去），
        而且正式區 1.0 的 000000 有 441，照算會讓所有帳號都拿到客戶檢索（含編輯內網客戶）。
        2026-10-05 決定不轉，腳本只列出筆數供參考。

  做的事：
    1. 每個帳號算出「1.0 有、2.0 目前還沒有效擁有」的業務檢索 PAGE / ACTION key
       （2.0 已有 = 所屬角色 ∪ everyone；superAdmin 成員略過）。
       細項（顯示金額）一律連帶所屬頁面——2.0 規則是細項一定帶祖先，
       1.0 只有金額權限、沒有頁面權限的人也照開頁面（2026-10-05 決定）。
    2. 依 key 組合分群，一組建一個角色「業務檢索-NN」（RoleCode salesSearchNN，Sort 300+NN），
       角色權限 = 該組 key + 沿 ParentKey 往上的所有祖先（分組、模組），比照
       RbacObjectsMigration.sql 第 4b.6 段與後端 SaveRole 的補祖先規則，側欄才長得出上層。
    3. 只加不刪：2.0 已有、1.0 沒有的權限不動。
    4. （@EnableModule = 1）salesSearch 模組與 grpCustomer / grpSales / grpOrder 分組改回 'Y'。
       預設 0：只列出節點狀態，停用的節點角色勾了也進不去，看到 'N' 再決定要不要開。

  可重跑：第二次跑時大家都已經有效擁有那些 key，不會再建角色；編號接在既有 salesSearchNN 後面。

  前提 / 跑法：
    - 要同時讀 PRORIL_WEB、寫 Proril_Sales_Center。proril_sales_center 帳號對 PRORIL_WEB
      沒有 SELECT（見 prod-migration-2026-09-21/README.md），要用兩邊都有權限的帳號跑。
    - 預設 @Execute = 0：整段跑完印出結果後 ROLLBACK（dry-run）。確認無誤改成 1 再跑。
      sqlcmd -S 192.168.1.142,51002 -U <帳號> -d Proril_Sales_Center -C -f 65001 -i 01-grant-sales-search-from-1.0.sql
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Execute      BIT = 0;   -- 0 = dry-run（最後 ROLLBACK），1 = 實際寫入
DECLARE @EnableModule BIT = 0;   -- 1 = 一併把 salesSearch 模組與分組改回 'Y'
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
    (410,   1, 'salesSearch.mixSalesShipping'),
    (410, 100, 'salesSearch.mixSalesShipping.viewAmount'),
    (420,   1, 'salesSearch.queryUnFinish'),
    (420, 100, 'salesSearch.queryUnFinish.viewAmount'),
    (425,   1, 'salesSearch.orderInfoVerify'),
    (425, 100, 'salesSearch.orderInfoVerify.viewAmount'),
    (440,   1, 'salesSearch.customQuery');

PRINT '--- 1.0 業務檢索權限分布（參考；441 不轉）---';
SELECT p.FunctionNo, ISNULL(p.LinkType, 1) AS LinkType,
       SUM(CASE WHEN LTRIM(RTRIM(p.LinkNumber)) = '000000' THEN 1 ELSE 0 END) AS EveryoneRows,
       COUNT(DISTINCT LTRIM(RTRIM(p.LinkNumber))) AS Accounts
FROM PRORIL_WEB.dbo.M_Permission p
WHERE p.FunctionNo IN (410, 420, 425, 440, 441)
GROUP BY p.FunctionNo, ISNULL(p.LinkType, 1)
ORDER BY p.FunctionNo, ISNULL(p.LinkType, 1);

CREATE TABLE #Src (LinkNumber VARCHAR(20) COLLATE DATABASE_DEFAULT NOT NULL,
                   FunctionNo INT NOT NULL, LinkType INT NOT NULL);
INSERT INTO #Src (LinkNumber, FunctionNo, LinkType)
SELECT DISTINCT LTRIM(RTRIM(p.LinkNumber)), p.FunctionNo,
       CASE WHEN ISNULL(p.LinkType, 1) <= 1 THEN 1 ELSE p.LinkType END
FROM PRORIL_WEB.dbo.M_Permission p
WHERE p.FunctionNo IN (410, 420, 425, 440);

PRINT '--- 1.0 業務檢索權限列中對不到 2.0 key 的（應為 0 筆，不是 0 筆要先補 #Map）---';
SELECT s.* FROM #Src s
WHERE NOT EXISTS (SELECT 1 FROM #Map m WHERE m.FunctionNo = s.FunctionNo AND m.LinkType = s.LinkType);

PRINT '--- 2.0 權限樹找不到（或節點本身停用）的對照 key（應為 0 筆）---';
SELECT m.PermissionKey, p.NodeType, p.aStatus
FROM #Map m
LEFT JOIN dbo.RBAC_Permission p ON p.PermissionKey = m.PermissionKey
WHERE p.PermissionKey IS NULL OR p.aStatus <> 'Y';

-- 2.0 帳號（M_User）× 1.0 key（本人 ∪ 000000）
CREATE TABLE #Want (Account VARCHAR(10) COLLATE DATABASE_DEFAULT NOT NULL,
                    PermissionKey VARCHAR(100) COLLATE DATABASE_DEFAULT NOT NULL,
                    PRIMARY KEY (Account, PermissionKey));
INSERT INTO #Want (Account, PermissionKey)
SELECT DISTINCT LTRIM(RTRIM(u.Account)), m.PermissionKey
FROM dbo.M_User u
JOIN #Src s ON s.LinkNumber IN (LTRIM(RTRIM(u.Account)), '000000')
JOIN #Map m ON m.FunctionNo = s.FunctionNo AND m.LinkType = s.LinkType;

PRINT '--- 1.0 只有顯示金額、沒有頁面權限的（照開頁面，列出供確認）---';
SELECT w.Account, w.PermissionKey AS ActionKey, p.ParentKey AS PageKeyAdded
FROM #Want w
JOIN dbo.RBAC_Permission p ON p.PermissionKey = w.PermissionKey AND p.NodeType = 'ACTION'
WHERE NOT EXISTS (SELECT 1 FROM #Want x WHERE x.Account = w.Account AND x.PermissionKey = p.ParentKey)
ORDER BY w.Account, w.PermissionKey;

-- 細項連帶所屬頁面
INSERT INTO #Want (Account, PermissionKey)
SELECT DISTINCT w.Account, p.ParentKey
FROM #Want w
JOIN dbo.RBAC_Permission p ON p.PermissionKey = w.PermissionKey AND p.NodeType = 'ACTION'
WHERE NOT EXISTS (SELECT 1 FROM #Want x WHERE x.Account = w.Account AND x.PermissionKey = p.ParentKey);

PRINT '--- 1.0 有業務檢索權限、但 2.0 M_User 沒有這個帳號（不會開通）---';
SELECT s.LinkNumber, COUNT(*) AS Rows1_0
FROM #Src s
WHERE s.LinkNumber <> '000000'
  AND NOT EXISTS (SELECT 1 FROM dbo.M_User u WHERE LTRIM(RTRIM(u.Account)) = s.LinkNumber)
GROUP BY s.LinkNumber;

-- ---------------------------------------------------------------- 1. 模組與分組狀態

IF @EnableModule = 1
BEGIN
    UPDATE dbo.RBAC_Permission
    SET aStatus = 'Y', Modifier = @Operator, ModiTime = GETDATE()
    WHERE PermissionKey IN ('salesSearch', 'salesSearch.grpCustomer', 'salesSearch.grpSales', 'salesSearch.grpOrder')
      AND aStatus <> 'Y';
    PRINT CONCAT('salesSearch 模組／分組改回 Y：', @@ROWCOUNT, ' 列');
END

PRINT '--- 業務檢索節點狀態（任一層是 N，底下角色勾了也不算）---';
SELECT PermissionKey, NodeType, ParentKey, Label, aStatus
FROM dbo.RBAC_Permission
WHERE PermissionKey = 'salesSearch' OR PermissionKey LIKE 'salesSearch.%'
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

-- 編號接在既有 salesSearchNN 之後；同一批內依簽章裡字典序最小的帳號排
DECLARE @BaseNo INT = ISNULL((SELECT MAX(TRY_CAST(SUBSTRING(RoleCode, 12, 10) AS INT))
                              FROM dbo.RBAC_Role WHERE RoleCode LIKE 'salesSearch[0-9]%'), 0);

CREATE TABLE #Grp (GroupNo INT PRIMARY KEY,
                   Signature VARCHAR(MAX) COLLATE DATABASE_DEFAULT NOT NULL,
                   RoleCode VARCHAR(50) COLLATE DATABASE_DEFAULT NOT NULL,
                   RoleID INT NULL);
INSERT INTO #Grp (GroupNo, Signature, RoleCode)
SELECT @BaseNo + ROW_NUMBER() OVER (ORDER BY MIN(Account)), Signature, ''
FROM #Sig
GROUP BY Signature;
UPDATE #Grp SET RoleCode = 'salesSearch' + RIGHT('00' + CAST(GroupNo AS VARCHAR(10)), 2);

INSERT INTO dbo.RBAC_Role (RoleCode, RoleName, Description, IsSystem, IsSuperAdmin, IsDefault, Sort, aStatus, Creator, CreateTime)
SELECT g.RoleCode,
       N'業務檢索-' + RIGHT('00' + CAST(g.GroupNo AS VARCHAR(10)), 2),
       N'由 1.0 業務檢索權限依權限組合自動產生（2026-10-05），請改名或合併',
       0, 0, 0, 300 + g.GroupNo, 'Y', @Operator, GETDATE()
FROM #Grp g;
PRINT CONCAT('新增角色：', @@ROWCOUNT, ' 個');

UPDATE g SET g.RoleID = r.ID
FROM #Grp g JOIN dbo.RBAC_Role r ON r.RoleCode = g.RoleCode;

INSERT INTO dbo.RBAC_RolePermission (RoleID, PermissionKey, Creator, CreateTime)
SELECT DISTINCT g.RoleID, n.PermissionKey, @Operator, GETDATE()
FROM #Grp g
JOIN #Sig s ON s.Signature = g.Signature
JOIN #Need n ON n.Account = s.Account;
PRINT CONCAT('新增角色權限（頁面／細項）：', @@ROWCOUNT, ' 筆');

-- 補祖先（分組、模組），只補這次新建的角色
;WITH Anc AS (
    SELECT rp.RoleID, p.ParentKey AS AncKey
    FROM dbo.RBAC_RolePermission rp
    JOIN #Grp g ON g.RoleID = rp.RoleID
    JOIN dbo.RBAC_Permission p ON p.PermissionKey = rp.PermissionKey
    WHERE rp.aStatus = 'Y' AND p.ParentKey IS NOT NULL
    UNION ALL
    SELECT a.RoleID, p.ParentKey
    FROM Anc a
    JOIN dbo.RBAC_Permission p ON p.PermissionKey = a.AncKey
    WHERE p.ParentKey IS NOT NULL
)
INSERT INTO dbo.RBAC_RolePermission (RoleID, PermissionKey, Creator, CreateTime)
SELECT DISTINCT a.RoleID, a.AncKey, @Operator, GETDATE()
FROM Anc a
WHERE NOT EXISTS (SELECT 1 FROM dbo.RBAC_RolePermission x WHERE x.RoleID = a.RoleID AND x.PermissionKey = a.AncKey);
PRINT CONCAT('新增角色權限（祖先節點）：', @@ROWCOUNT, ' 筆');

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

PRINT '--- 新建角色的完整權限（含祖先）---';
SELECT g.RoleCode, rp.PermissionKey, p.NodeType
FROM #Grp g
JOIN dbo.RBAC_RolePermission rp ON rp.RoleID = g.RoleID AND rp.aStatus = 'Y'
LEFT JOIN dbo.RBAC_Permission p ON p.PermissionKey = rp.PermissionKey
ORDER BY g.RoleCode, rp.PermissionKey;

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
