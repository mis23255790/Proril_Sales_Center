/*
================================================================================
 角色制（RBAC）：RBAC_Permission（原 M_PermissionDef）/ RBAC_Role / RBAC_RolePermission / RBAC_RoleUser，並把既有個人權限轉成角色
================================================================================

 在 **Proril_Sales_Center** 上執行（不是 PRORIL_WEB）。三張表都是 2.0 新表，
 PRORIL_WEB 沒有，也不在 TABLES.txt（copy-snapshot-data.ps1 不歸它管）。
 前置條件：PermissionDefObjectsMigration.sql 已跑過（M_PermissionDef 存在、
 M_Permission.PermissionKey 已回填）。這支會把 M_PermissionDef 改名成 RBAC_Permission
 並拿掉過渡期的 PermissionLinkTypeID 欄位（角色制之後沒有地方讀它），
 四張權限表因此都是 RBAC_ 開頭。

 權限模型改成：
   角色（RBAC_Role）綁一組 PermissionKey（RBAC_RolePermission），使用者掛多個角色（RBAC_RoleUser）。
   不做個人例外授權。
   系統角色兩個（IsSystem = 1，不可刪）：
     superAdmin  系統管理員，IsSuperAdmin = 1，全放行（取代 M_User.IsAdmin）
     everyone    全體使用者，IsDefault = 1，所有啟用帳號自動擁有（取代 LinkNumber = '000000'）

 做五件事：
   1. 建三張表（若不存在）。三張都有 aStatus（預設 'Y'）與 Creator/CreateTime/Modifier/ModiTime；
      aStatus 手動改成 'N' 即視為該筆失效（角色、角色的某個權限、某人的某個角色），api/ 只認 'Y'。
   2. 停用群組權限功能（M_Function 0000103、system.groupPermission.view 設 aStatus = 'N'）。
      key 不刪，照「key 一旦寫進資料就不改名」的規則保留。
   3. 建系統角色；everyone 的權限 = M_Permission 裡 LinkNumber = '000000' 的 key。
   4. 既有個人權限轉換（只在 RBAC_RoleUser 還是空的時候做，重跑不會重複）：
      - M_User.IsAdmin = 1 的帳號 → 指派 superAdmin（全放行，個人 key 不另外轉）。
      - 其餘帳號：個人 key 扣掉 everyone 已有的（有效權限 = 聯集，扣掉不失真），
        以排序後的 key 串當簽章分群，一個簽章建一個「移轉角色-NN」（RoleCode migratedNN），
        成員就是簽章相同的那些人。扣完是空集合的不建角色。
      - PermissionKey IS NULL 的 1.0 遺留列不轉；M_PermissionGroup 的部門範本不轉。
      - 只轉 M_User 裡還存在的帳號（已刪帳號的孤兒權限列不轉）。
   4b. 權限樹改成 RBAC_Permission 單一表自我參照（NodeType / ParentKey / Label / Path / Icon），
       頁面 key 拿掉 .view，拿掉 FunctionNo / LinkType，角色補上祖先節點（2026-09-24）。
   5. 驗證：每個帳號轉換前後的有效權限對稱差、IsAdmin 與 superAdmin 成員的對稱差，都應為 0 筆；
      最後列出整棵權限樹。

 M_Permission / M_PermissionGroup **不刪、不改**，留作備份；api/ 之後不再讀寫它們。

 **不要**用 scripts/publish.ps1 建這幾張表，理由見 CLAUDE.md
 「Proril_Sales_Center 的建表一律走 ObjectsMigration 腳本」。

 執行方式（UTF-8 無 BOM，中文角色名稱要靠 -f 65001）：
   .\scripts\run-objects-migration.ps1 -Script RbacObjectsMigration.sql -Environment snapshot [-Execute]
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

IF (OBJECT_ID('dbo.M_PermissionDef', 'U') IS NULL AND OBJECT_ID('dbo.RBAC_Permission', 'U') IS NULL)
   OR COL_LENGTH('dbo.M_Permission', 'PermissionKey') IS NULL
BEGIN
    RAISERROR('請先執行 PermissionDefObjectsMigration.sql（M_PermissionDef / M_Permission.PermissionKey 不存在）。', 16, 1);
    SET NOEXEC ON;
END
GO

-- ---------------------------------------------------------------- 1. 建表

-- 三張表原本叫 M_Role / M_RolePermission / M_RoleUser（更早是 M_UserRole），2026-09-23 統一改成 RBAC_ 開頭（全大寫、不加 M_），
-- 在 SSMS 會排在一起、一眼看出是同一組權限表。測試區已用舊名建過：原地改名，資料不動；
-- constraint / index 名稱一併改，跟 SalesCenterDbContext 的對映一致。
IF OBJECT_ID('dbo.M_UserRole', 'U') IS NOT NULL AND OBJECT_ID('dbo.M_RoleUser', 'U') IS NULL
BEGIN
    EXEC sp_rename 'dbo.M_UserRole', 'M_RoleUser';
    EXEC sp_rename 'dbo.PK_M_UserRole', 'PK_M_RoleUser', 'OBJECT';
    EXEC sp_rename 'dbo.UQ_M_UserRole_Account_Role', 'UQ_M_RoleUser_Account_Role', 'OBJECT';
    EXEC sp_rename 'dbo.FK_M_UserRole_M_Role', 'FK_M_RoleUser_M_Role', 'OBJECT';
    IF OBJECT_ID('dbo.DF_M_UserRole_aStatus', 'D') IS NOT NULL
        EXEC sp_rename 'dbo.DF_M_UserRole_aStatus', 'DF_M_RoleUser_aStatus', 'OBJECT';
    EXEC sp_rename 'dbo.M_RoleUser.IX_M_UserRole_RoleID', 'IX_M_RoleUser_RoleID', 'INDEX';
END
GO

-- 還有一版叫 RBACRole / RBACRolePermission / RBACRoleUser（沒有底線，測試區建過），一樣原地改名。
IF OBJECT_ID('dbo.RBACRole', 'U') IS NOT NULL AND OBJECT_ID('dbo.RBAC_Role', 'U') IS NULL
BEGIN
    EXEC sp_rename 'dbo.RBACRole', 'RBAC_Role';
    EXEC sp_rename 'dbo.PK_RBACRole', 'PK_RBAC_Role', 'OBJECT';
    EXEC sp_rename 'dbo.UQ_RBACRole_RoleCode', 'UQ_RBAC_Role_RoleCode', 'OBJECT';
    EXEC sp_rename 'dbo.DF_RBACRole_IsSystem', 'DF_RBAC_Role_IsSystem', 'OBJECT';
    EXEC sp_rename 'dbo.DF_RBACRole_IsSuperAdmin', 'DF_RBAC_Role_IsSuperAdmin', 'OBJECT';
    EXEC sp_rename 'dbo.DF_RBACRole_IsDefault', 'DF_RBAC_Role_IsDefault', 'OBJECT';
    EXEC sp_rename 'dbo.DF_RBACRole_Sort', 'DF_RBAC_Role_Sort', 'OBJECT';
    EXEC sp_rename 'dbo.DF_RBACRole_aStatus', 'DF_RBAC_Role_aStatus', 'OBJECT';
    PRINT '已把 dbo.RBACRole 改名為 dbo.RBAC_Role';
END
GO

IF OBJECT_ID('dbo.RBACRolePermission', 'U') IS NOT NULL AND OBJECT_ID('dbo.RBAC_RolePermission', 'U') IS NULL
BEGIN
    EXEC sp_rename 'dbo.RBACRolePermission', 'RBAC_RolePermission';
    EXEC sp_rename 'dbo.PK_RBACRolePermission', 'PK_RBAC_RolePermission', 'OBJECT';
    EXEC sp_rename 'dbo.UQ_RBACRolePermission_Role_Key', 'UQ_RBAC_RolePermission_Role_Key', 'OBJECT';
    EXEC sp_rename 'dbo.FK_RBACRolePermission_RBACRole', 'FK_RBAC_RolePermission_RBAC_Role', 'OBJECT';
    EXEC sp_rename 'dbo.FK_RBACRolePermission_M_PermissionDef', 'FK_RBAC_RolePermission_M_PermissionDef', 'OBJECT';
    EXEC sp_rename 'dbo.DF_RBACRolePermission_aStatus', 'DF_RBAC_RolePermission_aStatus', 'OBJECT';
    PRINT '已把 dbo.RBACRolePermission 改名為 dbo.RBAC_RolePermission';
END
GO

IF OBJECT_ID('dbo.RBACRoleUser', 'U') IS NOT NULL AND OBJECT_ID('dbo.RBAC_RoleUser', 'U') IS NULL
BEGIN
    EXEC sp_rename 'dbo.RBACRoleUser', 'RBAC_RoleUser';
    EXEC sp_rename 'dbo.PK_RBACRoleUser', 'PK_RBAC_RoleUser', 'OBJECT';
    EXEC sp_rename 'dbo.UQ_RBACRoleUser_Account_Role', 'UQ_RBAC_RoleUser_Account_Role', 'OBJECT';
    EXEC sp_rename 'dbo.FK_RBACRoleUser_RBACRole', 'FK_RBAC_RoleUser_RBAC_Role', 'OBJECT';
    EXEC sp_rename 'dbo.DF_RBACRoleUser_aStatus', 'DF_RBAC_RoleUser_aStatus', 'OBJECT';
    EXEC sp_rename 'dbo.RBAC_RoleUser.IX_RBACRoleUser_RoleID', 'IX_RBAC_RoleUser_RoleID', 'INDEX';
    PRINT '已把 dbo.RBACRoleUser 改名為 dbo.RBAC_RoleUser';
END
GO

-- 也有一版叫 RbacRole / RbacRolePermission / RbacRoleUser（測試區建過）。資料庫定序是 _BIN，
-- 物件名稱區分大小寫，RbacRole 與 RBAC_Role 是不同名字，一樣原地改名。
IF OBJECT_ID('dbo.RbacRole', 'U') IS NOT NULL AND OBJECT_ID('dbo.RBAC_Role', 'U') IS NULL
BEGIN
    EXEC sp_rename 'dbo.RbacRole', 'RBAC_Role';
    EXEC sp_rename 'dbo.PK_RbacRole', 'PK_RBAC_Role', 'OBJECT';
    EXEC sp_rename 'dbo.UQ_RbacRole_RoleCode', 'UQ_RBAC_Role_RoleCode', 'OBJECT';
    EXEC sp_rename 'dbo.DF_RbacRole_IsSystem', 'DF_RBAC_Role_IsSystem', 'OBJECT';
    EXEC sp_rename 'dbo.DF_RbacRole_IsSuperAdmin', 'DF_RBAC_Role_IsSuperAdmin', 'OBJECT';
    EXEC sp_rename 'dbo.DF_RbacRole_IsDefault', 'DF_RBAC_Role_IsDefault', 'OBJECT';
    EXEC sp_rename 'dbo.DF_RbacRole_Sort', 'DF_RBAC_Role_Sort', 'OBJECT';
    EXEC sp_rename 'dbo.DF_RbacRole_aStatus', 'DF_RBAC_Role_aStatus', 'OBJECT';
    PRINT '已把 dbo.RbacRole 改名為 dbo.RBAC_Role';
END
GO

IF OBJECT_ID('dbo.RbacRolePermission', 'U') IS NOT NULL AND OBJECT_ID('dbo.RBAC_RolePermission', 'U') IS NULL
BEGIN
    EXEC sp_rename 'dbo.RbacRolePermission', 'RBAC_RolePermission';
    EXEC sp_rename 'dbo.PK_RbacRolePermission', 'PK_RBAC_RolePermission', 'OBJECT';
    EXEC sp_rename 'dbo.UQ_RbacRolePermission_Role_Key', 'UQ_RBAC_RolePermission_Role_Key', 'OBJECT';
    EXEC sp_rename 'dbo.FK_RbacRolePermission_RbacRole', 'FK_RBAC_RolePermission_RBAC_Role', 'OBJECT';
    EXEC sp_rename 'dbo.FK_RbacRolePermission_M_PermissionDef', 'FK_RBAC_RolePermission_M_PermissionDef', 'OBJECT';
    EXEC sp_rename 'dbo.DF_RbacRolePermission_aStatus', 'DF_RBAC_RolePermission_aStatus', 'OBJECT';
    PRINT '已把 dbo.RbacRolePermission 改名為 dbo.RBAC_RolePermission';
END
GO

IF OBJECT_ID('dbo.RbacRoleUser', 'U') IS NOT NULL AND OBJECT_ID('dbo.RBAC_RoleUser', 'U') IS NULL
BEGIN
    EXEC sp_rename 'dbo.RbacRoleUser', 'RBAC_RoleUser';
    EXEC sp_rename 'dbo.PK_RbacRoleUser', 'PK_RBAC_RoleUser', 'OBJECT';
    EXEC sp_rename 'dbo.UQ_RbacRoleUser_Account_Role', 'UQ_RBAC_RoleUser_Account_Role', 'OBJECT';
    EXEC sp_rename 'dbo.FK_RbacRoleUser_RbacRole', 'FK_RBAC_RoleUser_RBAC_Role', 'OBJECT';
    EXEC sp_rename 'dbo.DF_RbacRoleUser_aStatus', 'DF_RBAC_RoleUser_aStatus', 'OBJECT';
    EXEC sp_rename 'dbo.RBAC_RoleUser.IX_RbacRoleUser_RoleID', 'IX_RBAC_RoleUser_RoleID', 'INDEX';
    PRINT '已把 dbo.RbacRoleUser 改名為 dbo.RBAC_RoleUser';
END
GO

-- 中間還有一版叫 M_RbacRole / M_RbacRolePermission / M_RbacRoleUser（測試區建過），一樣原地改名。
IF OBJECT_ID('dbo.M_RbacRole', 'U') IS NOT NULL AND OBJECT_ID('dbo.RBAC_Role', 'U') IS NULL
BEGIN
    EXEC sp_rename 'dbo.M_RbacRole', 'RBAC_Role';
    EXEC sp_rename 'dbo.PK_M_RbacRole', 'PK_RBAC_Role', 'OBJECT';
    EXEC sp_rename 'dbo.UQ_M_RbacRole_RoleCode', 'UQ_RBAC_Role_RoleCode', 'OBJECT';
    EXEC sp_rename 'dbo.DF_M_RbacRole_IsSystem', 'DF_RBAC_Role_IsSystem', 'OBJECT';
    EXEC sp_rename 'dbo.DF_M_RbacRole_IsSuperAdmin', 'DF_RBAC_Role_IsSuperAdmin', 'OBJECT';
    EXEC sp_rename 'dbo.DF_M_RbacRole_IsDefault', 'DF_RBAC_Role_IsDefault', 'OBJECT';
    EXEC sp_rename 'dbo.DF_M_RbacRole_Sort', 'DF_RBAC_Role_Sort', 'OBJECT';
    EXEC sp_rename 'dbo.DF_M_RbacRole_aStatus', 'DF_RBAC_Role_aStatus', 'OBJECT';
    PRINT '已把 dbo.M_RbacRole 改名為 dbo.RBAC_Role';
END
GO

IF OBJECT_ID('dbo.M_RbacRolePermission', 'U') IS NOT NULL AND OBJECT_ID('dbo.RBAC_RolePermission', 'U') IS NULL
BEGIN
    EXEC sp_rename 'dbo.M_RbacRolePermission', 'RBAC_RolePermission';
    EXEC sp_rename 'dbo.PK_M_RbacRolePermission', 'PK_RBAC_RolePermission', 'OBJECT';
    EXEC sp_rename 'dbo.UQ_M_RbacRolePermission_Role_Key', 'UQ_RBAC_RolePermission_Role_Key', 'OBJECT';
    EXEC sp_rename 'dbo.FK_M_RbacRolePermission_M_RbacRole', 'FK_RBAC_RolePermission_RBAC_Role', 'OBJECT';
    EXEC sp_rename 'dbo.FK_M_RbacRolePermission_M_PermissionDef', 'FK_RBAC_RolePermission_M_PermissionDef', 'OBJECT';
    EXEC sp_rename 'dbo.DF_M_RbacRolePermission_aStatus', 'DF_RBAC_RolePermission_aStatus', 'OBJECT';
    PRINT '已把 dbo.M_RbacRolePermission 改名為 dbo.RBAC_RolePermission';
END
GO

IF OBJECT_ID('dbo.M_RbacRoleUser', 'U') IS NOT NULL AND OBJECT_ID('dbo.RBAC_RoleUser', 'U') IS NULL
BEGIN
    EXEC sp_rename 'dbo.M_RbacRoleUser', 'RBAC_RoleUser';
    EXEC sp_rename 'dbo.PK_M_RbacRoleUser', 'PK_RBAC_RoleUser', 'OBJECT';
    EXEC sp_rename 'dbo.UQ_M_RbacRoleUser_Account_Role', 'UQ_RBAC_RoleUser_Account_Role', 'OBJECT';
    EXEC sp_rename 'dbo.FK_M_RbacRoleUser_M_RbacRole', 'FK_RBAC_RoleUser_RBAC_Role', 'OBJECT';
    EXEC sp_rename 'dbo.DF_M_RbacRoleUser_aStatus', 'DF_RBAC_RoleUser_aStatus', 'OBJECT';
    EXEC sp_rename 'dbo.RBAC_RoleUser.IX_M_RbacRoleUser_RoleID', 'IX_RBAC_RoleUser_RoleID', 'INDEX';
    PRINT '已把 dbo.M_RbacRoleUser 改名為 dbo.RBAC_RoleUser';
END
GO

IF OBJECT_ID('dbo.M_Role', 'U') IS NOT NULL AND OBJECT_ID('dbo.RBAC_Role', 'U') IS NULL
BEGIN
    EXEC sp_rename 'dbo.M_Role', 'RBAC_Role';
    EXEC sp_rename 'dbo.PK_M_Role', 'PK_RBAC_Role', 'OBJECT';
    EXEC sp_rename 'dbo.UQ_M_Role_RoleCode', 'UQ_RBAC_Role_RoleCode', 'OBJECT';
    EXEC sp_rename 'dbo.DF_M_Role_IsSystem', 'DF_RBAC_Role_IsSystem', 'OBJECT';
    EXEC sp_rename 'dbo.DF_M_Role_IsSuperAdmin', 'DF_RBAC_Role_IsSuperAdmin', 'OBJECT';
    EXEC sp_rename 'dbo.DF_M_Role_IsDefault', 'DF_RBAC_Role_IsDefault', 'OBJECT';
    EXEC sp_rename 'dbo.DF_M_Role_Sort', 'DF_RBAC_Role_Sort', 'OBJECT';
    EXEC sp_rename 'dbo.DF_M_Role_aStatus', 'DF_RBAC_Role_aStatus', 'OBJECT';
    PRINT '已把 dbo.M_Role 改名為 dbo.RBAC_Role';
END
GO

IF OBJECT_ID('dbo.M_RolePermission', 'U') IS NOT NULL AND OBJECT_ID('dbo.RBAC_RolePermission', 'U') IS NULL
BEGIN
    EXEC sp_rename 'dbo.M_RolePermission', 'RBAC_RolePermission';
    EXEC sp_rename 'dbo.PK_M_RolePermission', 'PK_RBAC_RolePermission', 'OBJECT';
    EXEC sp_rename 'dbo.UQ_M_RolePermission_Role_Key', 'UQ_RBAC_RolePermission_Role_Key', 'OBJECT';
    EXEC sp_rename 'dbo.FK_M_RolePermission_M_Role', 'FK_RBAC_RolePermission_RBAC_Role', 'OBJECT';
    EXEC sp_rename 'dbo.FK_M_RolePermission_M_PermissionDef', 'FK_RBAC_RolePermission_M_PermissionDef', 'OBJECT';
    IF OBJECT_ID('dbo.DF_M_RolePermission_aStatus', 'D') IS NOT NULL
        EXEC sp_rename 'dbo.DF_M_RolePermission_aStatus', 'DF_RBAC_RolePermission_aStatus', 'OBJECT';
    PRINT '已把 dbo.M_RolePermission 改名為 dbo.RBAC_RolePermission';
END
GO

IF OBJECT_ID('dbo.M_RoleUser', 'U') IS NOT NULL AND OBJECT_ID('dbo.RBAC_RoleUser', 'U') IS NULL
BEGIN
    EXEC sp_rename 'dbo.M_RoleUser', 'RBAC_RoleUser';
    EXEC sp_rename 'dbo.PK_M_RoleUser', 'PK_RBAC_RoleUser', 'OBJECT';
    EXEC sp_rename 'dbo.UQ_M_RoleUser_Account_Role', 'UQ_RBAC_RoleUser_Account_Role', 'OBJECT';
    EXEC sp_rename 'dbo.FK_M_RoleUser_M_Role', 'FK_RBAC_RoleUser_RBAC_Role', 'OBJECT';
    IF OBJECT_ID('dbo.DF_M_RoleUser_aStatus', 'D') IS NOT NULL
        EXEC sp_rename 'dbo.DF_M_RoleUser_aStatus', 'DF_RBAC_RoleUser_aStatus', 'OBJECT';
    EXEC sp_rename 'dbo.RBAC_RoleUser.IX_M_RoleUser_RoleID', 'IX_RBAC_RoleUser_RoleID', 'INDEX';
    PRINT '已把 dbo.M_RoleUser 改名為 dbo.RBAC_RoleUser';
END
GO

-- 權限主檔 M_PermissionDef → RBAC_Permission（2026-09-23，跟角色三張表同一組前綴）。原地改名，資料不動。
-- 順便拿掉 PermissionLinkTypeID：那是過渡期對回 1.0 M_PermissionLinkType 的欄位，角色制之後沒有地方讀。
IF OBJECT_ID('dbo.M_PermissionDef', 'U') IS NOT NULL AND OBJECT_ID('dbo.RBAC_Permission', 'U') IS NULL
BEGIN
    EXEC sp_rename 'dbo.M_PermissionDef', 'RBAC_Permission';
    EXEC sp_rename 'dbo.PK_M_PermissionDef', 'PK_RBAC_Permission', 'OBJECT';
    EXEC sp_rename 'dbo.UQ_M_PermissionDef_PermissionKey', 'UQ_RBAC_Permission_PermissionKey', 'OBJECT';
    EXEC sp_rename 'dbo.UQ_M_PermissionDef_FunctionNo_LinkType', 'UQ_RBAC_Permission_FunctionNo_LinkType', 'OBJECT';
    EXEC sp_rename 'dbo.DF_M_PermissionDef_Sort', 'DF_RBAC_Permission_Sort', 'OBJECT';
    EXEC sp_rename 'dbo.DF_M_PermissionDef_aStatus', 'DF_RBAC_Permission_aStatus', 'OBJECT';
    PRINT '已把 dbo.M_PermissionDef 改名為 dbo.RBAC_Permission';
END
GO

IF COL_LENGTH('dbo.RBAC_Permission', 'PermissionLinkTypeID') IS NOT NULL
BEGIN
    ALTER TABLE dbo.RBAC_Permission DROP COLUMN [PermissionLinkTypeID];
    PRINT '已拿掉 dbo.RBAC_Permission.PermissionLinkTypeID';
END
GO

IF OBJECT_ID('dbo.FK_RBAC_RolePermission_M_PermissionDef', 'F') IS NOT NULL
    EXEC sp_rename 'dbo.FK_RBAC_RolePermission_M_PermissionDef', 'FK_RBAC_RolePermission_RBAC_Permission', 'OBJECT';
GO

IF OBJECT_ID('dbo.RBAC_Role', 'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[RBAC_Role] (
        [ID]           INT            IDENTITY (1, 1) NOT NULL,
        [RoleCode]     VARCHAR (50)   NOT NULL,
        [RoleName]     NVARCHAR (50)  NOT NULL,
        [Description]  NVARCHAR (200) NULL,
        [IsSystem]     BIT            CONSTRAINT [DF_RBAC_Role_IsSystem] DEFAULT (0) NOT NULL,      -- 系統角色：不可刪、不可改代碼
        [IsSuperAdmin] BIT            CONSTRAINT [DF_RBAC_Role_IsSuperAdmin] DEFAULT (0) NOT NULL,  -- 全放行
        [IsDefault]    BIT            CONSTRAINT [DF_RBAC_Role_IsDefault] DEFAULT (0) NOT NULL,     -- 所有啟用帳號自動擁有
        [Sort]         INT            CONSTRAINT [DF_RBAC_Role_Sort] DEFAULT (0) NOT NULL,
        [aStatus]      VARCHAR (1)    CONSTRAINT [DF_RBAC_Role_aStatus] DEFAULT ('Y') NOT NULL,
        [Creator]      VARCHAR (10)   NULL,
        [CreateTime]   DATETIME       NULL,
        [Modifier]     VARCHAR (10)   NULL,
        [ModiTime]     DATETIME       NULL,
        CONSTRAINT [PK_RBAC_Role] PRIMARY KEY CLUSTERED ([ID] ASC),
        CONSTRAINT [UQ_RBAC_Role_RoleCode] UNIQUE ([RoleCode])
    );
    PRINT '已建立 dbo.RBAC_Role';
END
GO

IF OBJECT_ID('dbo.RBAC_RolePermission', 'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[RBAC_RolePermission] (
        [ID]            INT           IDENTITY (1, 1) NOT NULL,
        [RoleID]        INT           NOT NULL,
        [PermissionKey] VARCHAR (100) NOT NULL,
        [aStatus]       VARCHAR (1)   CONSTRAINT [DF_RBAC_RolePermission_aStatus] DEFAULT ('Y') NOT NULL,
        [Creator]       VARCHAR (10)  NULL,
        [CreateTime]    DATETIME      NULL,
        [Modifier]      VARCHAR (10)  NULL,
        [ModiTime]      DATETIME      NULL,
        CONSTRAINT [PK_RBAC_RolePermission] PRIMARY KEY CLUSTERED ([ID] ASC),
        CONSTRAINT [UQ_RBAC_RolePermission_Role_Key] UNIQUE ([RoleID], [PermissionKey]),
        CONSTRAINT [FK_RBAC_RolePermission_RBAC_Role] FOREIGN KEY ([RoleID]) REFERENCES [dbo].[RBAC_Role] ([ID]),
        CONSTRAINT [FK_RBAC_RolePermission_RBAC_Permission] FOREIGN KEY ([PermissionKey])
            REFERENCES [dbo].[RBAC_Permission] ([PermissionKey])
    );
    PRINT '已建立 dbo.RBAC_RolePermission';
END
GO

IF OBJECT_ID('dbo.RBAC_RoleUser', 'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[RBAC_RoleUser] (
        [ID]         INT          IDENTITY (1, 1) NOT NULL,
        [Account]    VARCHAR (10) NOT NULL,
        [RoleID]     INT          NOT NULL,
        [aStatus]    VARCHAR (1)  CONSTRAINT [DF_RBAC_RoleUser_aStatus] DEFAULT ('Y') NOT NULL,
        [Creator]    VARCHAR (10) NULL,
        [CreateTime] DATETIME     NULL,
        [Modifier]   VARCHAR (10) NULL,
        [ModiTime]   DATETIME     NULL,
        CONSTRAINT [PK_RBAC_RoleUser] PRIMARY KEY CLUSTERED ([ID] ASC),
        CONSTRAINT [UQ_RBAC_RoleUser_Account_Role] UNIQUE ([Account], [RoleID]),
        CONSTRAINT [FK_RBAC_RoleUser_RBAC_Role] FOREIGN KEY ([RoleID]) REFERENCES [dbo].[RBAC_Role] ([ID])
    );
    CREATE NONCLUSTERED INDEX [IX_RBAC_RoleUser_RoleID] ON dbo.RBAC_RoleUser ([RoleID]);
    PRINT '已建立 dbo.RBAC_RoleUser';
END
GO

-- 早期版本的 RBAC_RolePermission / RBAC_RoleUser 沒有 aStatus / Modifier / ModiTime（測試區 2026-09-23 建過一次），補欄位。
-- aStatus 手動改成 'N' = 這筆指派失效（api/ 只認 'Y'）。
IF COL_LENGTH('dbo.RBAC_RolePermission', 'aStatus') IS NULL
BEGIN
    ALTER TABLE dbo.RBAC_RolePermission ADD [aStatus] VARCHAR (1) CONSTRAINT [DF_RBAC_RolePermission_aStatus] DEFAULT ('Y') NOT NULL;
    PRINT '已加 dbo.RBAC_RolePermission.aStatus';
END
IF COL_LENGTH('dbo.RBAC_RolePermission', 'Modifier') IS NULL
    ALTER TABLE dbo.RBAC_RolePermission ADD [Modifier] VARCHAR (10) NULL;
IF COL_LENGTH('dbo.RBAC_RolePermission', 'ModiTime') IS NULL
    ALTER TABLE dbo.RBAC_RolePermission ADD [ModiTime] DATETIME NULL;
IF COL_LENGTH('dbo.RBAC_RoleUser', 'aStatus') IS NULL
BEGIN
    ALTER TABLE dbo.RBAC_RoleUser ADD [aStatus] VARCHAR (1) CONSTRAINT [DF_RBAC_RoleUser_aStatus] DEFAULT ('Y') NOT NULL;
    PRINT '已加 dbo.RBAC_RoleUser.aStatus';
END
IF COL_LENGTH('dbo.RBAC_RoleUser', 'Modifier') IS NULL
    ALTER TABLE dbo.RBAC_RoleUser ADD [Modifier] VARCHAR (10) NULL;
IF COL_LENGTH('dbo.RBAC_RoleUser', 'ModiTime') IS NULL
    ALTER TABLE dbo.RBAC_RoleUser ADD [ModiTime] DATETIME NULL;
GO

-- ---------------------------------------------------------------- 2. 停用群組權限功能

UPDATE dbo.M_Function SET aStatus = 'N' WHERE FunctionNo = '0000103' AND aStatus <> 'N';
UPDATE dbo.RBAC_Permission
SET aStatus = 'N', Modifier = 'migration', ModiTime = GETDATE()
WHERE PermissionKey = 'system.groupPermission.view' AND aStatus <> 'N';
GO

-- ---------------------------------------------------------------- 3. 系統角色

MERGE dbo.RBAC_Role AS t
USING (VALUES
    ('superAdmin', N'系統管理員', N'全部功能放行，不需另外勾權限', 1, 0, 0),
    ('everyone',   N'全體使用者', N'所有啟用帳號自動擁有，不需指派成員', 0, 1, 1)
) AS s (RoleCode, RoleName, Description, IsSuperAdmin, IsDefault, Sort)
ON t.RoleCode = s.RoleCode
-- 重跑時不動 aStatus：手動改成 'N' 的就維持失效
WHEN MATCHED THEN
    UPDATE SET IsSystem = 1, IsSuperAdmin = s.IsSuperAdmin, IsDefault = s.IsDefault
WHEN NOT MATCHED BY TARGET THEN
    INSERT (RoleCode, RoleName, Description, IsSystem, IsSuperAdmin, IsDefault, Sort, aStatus, Creator, CreateTime)
    VALUES (s.RoleCode, s.RoleName, s.Description, 1, s.IsSuperAdmin, s.IsDefault, s.Sort, 'Y', 'migration', GETDATE());
GO

-- ---------------------------------------------------------------- 4. 轉換既有個人權限

IF EXISTS (SELECT 1 FROM dbo.RBAC_RoleUser)
BEGIN
    PRINT 'RBAC_RoleUser 已有資料，略過轉換（避免重跑重複建角色）。';
END
ELSE
BEGIN
    BEGIN TRANSACTION;

    DECLARE @SuperAdminId INT = (SELECT ID FROM dbo.RBAC_Role WHERE RoleCode = 'superAdmin');
    DECLARE @EveryoneId   INT = (SELECT ID FROM dbo.RBAC_Role WHERE RoleCode = 'everyone');

    -- 4.1 everyone 的權限 = 000000 的 key（只收仍啟用的 key）
    INSERT INTO dbo.RBAC_RolePermission (RoleID, PermissionKey, Creator, CreateTime)
    SELECT DISTINCT @EveryoneId, d.PermissionKey, 'migration', GETDATE()
    FROM dbo.M_Permission p
    JOIN dbo.RBAC_Permission d ON d.PermissionKey = p.PermissionKey AND d.aStatus = 'Y'
    WHERE LTRIM(RTRIM(p.LinkNumber)) = '000000'
      AND NOT EXISTS (SELECT 1 FROM dbo.RBAC_RolePermission rp
                      WHERE rp.RoleID = @EveryoneId AND rp.PermissionKey = d.PermissionKey);

    -- 4.2 IsAdmin → superAdmin
    INSERT INTO dbo.RBAC_RoleUser (Account, RoleID, Creator, CreateTime)
    SELECT DISTINCT LTRIM(RTRIM(u.Account)), @SuperAdminId, 'migration', GETDATE()
    FROM dbo.M_User u
    WHERE u.IsAdmin = 1;

    -- 4.3 其餘帳號：個人 key 扣掉 everyone 已有的，依簽章分群
    DECLARE @UserKeys TABLE (Account VARCHAR(10) NOT NULL, PermissionKey VARCHAR(100) NOT NULL,
                             PRIMARY KEY (Account, PermissionKey));

    INSERT INTO @UserKeys (Account, PermissionKey)
    SELECT DISTINCT LTRIM(RTRIM(p.LinkNumber)), d.PermissionKey
    FROM dbo.M_Permission p
    JOIN dbo.RBAC_Permission d ON d.PermissionKey = p.PermissionKey AND d.aStatus = 'Y'
    JOIN dbo.M_User u ON LTRIM(RTRIM(u.Account)) = LTRIM(RTRIM(p.LinkNumber))
    WHERE LTRIM(RTRIM(p.LinkNumber)) <> '000000'
      AND ISNULL(u.IsAdmin, 0) = 0
      AND NOT EXISTS (SELECT 1 FROM dbo.RBAC_RolePermission rp
                      WHERE rp.RoleID = @EveryoneId AND rp.PermissionKey = d.PermissionKey);

    DECLARE @Signatures TABLE (Account VARCHAR(10) PRIMARY KEY, Signature VARCHAR(MAX) NOT NULL);

    INSERT INTO @Signatures (Account, Signature)
    SELECT Account, STRING_AGG(CONVERT(VARCHAR(MAX), PermissionKey), ',') WITHIN GROUP (ORDER BY PermissionKey)
    FROM @UserKeys
    GROUP BY Account;

    -- 簽章編號：依簽章裡字典序最小的成員帳號排序，編號才穩定好對照
    DECLARE @Groups TABLE (GroupNo INT PRIMARY KEY, Signature VARCHAR(MAX) NOT NULL, RoleID INT NULL);

    INSERT INTO @Groups (GroupNo, Signature)
    SELECT ROW_NUMBER() OVER (ORDER BY MIN(Account)), Signature
    FROM @Signatures
    GROUP BY Signature;

    INSERT INTO dbo.RBAC_Role (RoleCode, RoleName, Description, IsSystem, IsSuperAdmin, IsDefault, Sort, aStatus, Creator, CreateTime)
    SELECT 'migrated' + RIGHT('00' + CAST(g.GroupNo AS VARCHAR(10)), 2),
           N'移轉角色-' + RIGHT('00' + CAST(g.GroupNo AS VARCHAR(10)), 2),
           N'由舊個人權限依權限組合自動產生，請改名或合併',
           0, 0, 0, 100 + g.GroupNo, 'Y', 'migration', GETDATE()
    FROM @Groups g;

    UPDATE g
    SET g.RoleID = r.ID
    FROM @Groups g
    JOIN dbo.RBAC_Role r ON r.RoleCode = 'migrated' + RIGHT('00' + CAST(g.GroupNo AS VARCHAR(10)), 2);

    INSERT INTO dbo.RBAC_RolePermission (RoleID, PermissionKey, Creator, CreateTime)
    SELECT DISTINCT g.RoleID, k.PermissionKey, 'migration', GETDATE()
    FROM @Groups g
    JOIN @Signatures s ON s.Signature = g.Signature
    JOIN @UserKeys k ON k.Account = s.Account;

    INSERT INTO dbo.RBAC_RoleUser (Account, RoleID, Creator, CreateTime)
    SELECT s.Account, g.RoleID, 'migration', GETDATE()
    FROM @Signatures s
    JOIN @Groups g ON g.Signature = s.Signature;

    COMMIT TRANSACTION;
    PRINT '已完成個人權限轉換。';
END
GO

-- ---------------------------------------------------------------- 4b. 權限樹改成單一樹（自我參照）

-- 2026-09-24：權限樹與側欄原本由 M_System（系統）→ M_Function（功能，位置編在 FunctionNo）
-- → RBAC_Permission（細項）三張表拼起來，路由／icon 還寫死在前端 NAV_MODULES，
-- 功能要換位置就得改 FunctionNo。改成 RBAC_Permission 一張表自我參照：
--   NodeType  MODULE（模組，側欄第一層）/ GROUP（模組內分組，不是頁面）/ PAGE（頁面）/ ACTION（頁面內細項）
--   ParentKey 父節點的 PermissionKey，NULL = 最上層；改它就是搬位置，改 Sort 就是換順序
--   Label / LabelEn / Path / Icon / Description  側欄與權限樹顯示用，Path 是 PAGE / MODULE 的前端路由（不含 /sales-center）
-- 頁面節點的 key 拿掉 .view（salesSearch.mixSalesShipping.view → salesSearch.mixSalesShipping），
-- 勾頁面 = 進得去；RBAC_RolePermission 靠 ON UPDATE CASCADE 一起改。
-- FunctionNo / LinkType 不再用來組樹，整欄拿掉；M_System / M_Function 只剩 topbar 環境圖示在讀。

-- 4b.1 欄位
IF COL_LENGTH('dbo.RBAC_Permission', 'ActionName') IS NOT NULL AND COL_LENGTH('dbo.RBAC_Permission', 'Label') IS NULL
    EXEC sp_rename 'dbo.RBAC_Permission.ActionName', 'Label', 'COLUMN';
IF COL_LENGTH('dbo.RBAC_Permission', 'ParentPermissionKey') IS NOT NULL AND COL_LENGTH('dbo.RBAC_Permission', 'ParentKey') IS NULL
    EXEC sp_rename 'dbo.RBAC_Permission.ParentPermissionKey', 'ParentKey', 'COLUMN';
IF COL_LENGTH('dbo.RBAC_Permission', 'NodeType') IS NULL
    ALTER TABLE dbo.RBAC_Permission ADD [NodeType] VARCHAR (10) NULL;
IF COL_LENGTH('dbo.RBAC_Permission', 'LabelEn') IS NULL
    ALTER TABLE dbo.RBAC_Permission ADD [LabelEn] VARCHAR (50) NULL;
IF COL_LENGTH('dbo.RBAC_Permission', 'Path') IS NULL
    ALTER TABLE dbo.RBAC_Permission ADD [Path] VARCHAR (200) NULL;
IF COL_LENGTH('dbo.RBAC_Permission', 'Icon') IS NULL
    ALTER TABLE dbo.RBAC_Permission ADD [Icon] VARCHAR (100) NULL;
IF COL_LENGTH('dbo.RBAC_Permission', 'Description') IS NULL
    ALTER TABLE dbo.RBAC_Permission ADD [Description] NVARCHAR (200) NULL;
GO

-- 4b.2 角色權限的外鍵改成 ON UPDATE CASCADE，改 key 時 RBAC_RolePermission 跟著改
IF EXISTS (SELECT 1 FROM sys.foreign_keys
           WHERE name = 'FK_RBAC_RolePermission_RBAC_Permission' AND update_referential_action = 0)
BEGIN
    ALTER TABLE dbo.RBAC_RolePermission DROP CONSTRAINT [FK_RBAC_RolePermission_RBAC_Permission];
    ALTER TABLE dbo.RBAC_RolePermission ADD CONSTRAINT [FK_RBAC_RolePermission_RBAC_Permission]
        FOREIGN KEY ([PermissionKey]) REFERENCES dbo.RBAC_Permission ([PermissionKey]) ON UPDATE CASCADE;
    PRINT '已把 FK_RBAC_RolePermission_RBAC_Permission 改成 ON UPDATE CASCADE';
END
GO

-- 4b.3 還有 LinkType 欄位的庫：先依 LinkType 標 NodeType，頁面 key 拿掉 .view，再把 FunctionNo / LinkType 拿掉。
-- 欄位拿掉之後這段整個略過（用動態 SQL，免得欄位不存在時整批編譯失敗）。
IF COL_LENGTH('dbo.RBAC_Permission', 'LinkType') IS NOT NULL
BEGIN
    EXEC (N'
        UPDATE dbo.RBAC_Permission
        SET NodeType = CASE WHEN LinkType = 1 THEN ''PAGE'' ELSE ''ACTION'' END
        WHERE NodeType IS NULL;

        UPDATE dbo.RBAC_Permission
        SET PermissionKey = LEFT(PermissionKey, LEN(PermissionKey) - 5), Modifier = ''migration'', ModiTime = GETDATE()
        WHERE LinkType = 1 AND PermissionKey LIKE ''%.view'';');
    PRINT '已把頁面節點的 key 拿掉 .view';

    IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = 'UQ_RBAC_Permission_FunctionNo_LinkType')
        ALTER TABLE dbo.RBAC_Permission DROP CONSTRAINT [UQ_RBAC_Permission_FunctionNo_LinkType];
    ALTER TABLE dbo.RBAC_Permission DROP COLUMN [LinkType];
    IF COL_LENGTH('dbo.RBAC_Permission', 'FunctionNo') IS NOT NULL
        ALTER TABLE dbo.RBAC_Permission DROP COLUMN [FunctionNo];
    PRINT '已拿掉 dbo.RBAC_Permission.FunctionNo / LinkType';
END
GO

-- 4b.4 節點資料。只在還沒有 MODULE 節點時灌一次——之後位置／名稱／icon 直接在 DB 改，
-- 重跑這支**不會**把手動調整蓋回去。群組權限（system.groupPermission，aStatus = 'N'）不在清單裡，維持原樣。
IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_Permission WHERE NodeType = 'MODULE')
BEGIN
    MERGE dbo.RBAC_Permission AS t
    USING (VALUES
        -- 模組
        ('salesIssue',  'MODULE', NULL, N'業務議題', 'Sales Issue',  'sales-issue',  'i-lucide-messages-square', NULL, 10),
        ('salesSearch', 'MODULE', NULL, N'業務檢索', 'Sales Search', 'sales-search', 'i-lucide-search',          NULL, 20),
        ('system',      'MODULE', NULL, N'系統管理', 'System',       'system',       'i-lucide-settings',        NULL, 30),
        -- 分組
        ('salesIssue.grpIssue',     'GROUP', 'salesIssue',  N'議題管理', NULL, NULL, NULL, NULL, 10),
        ('salesIssue.grpBasic',     'GROUP', 'salesIssue',  N'基本資料', NULL, NULL, NULL, NULL, 20),
        ('salesSearch.grpCustomer', 'GROUP', 'salesSearch', N'客戶',     NULL, NULL, NULL, NULL, 10),
        ('salesSearch.grpSales',    'GROUP', 'salesSearch', N'銷貨',     NULL, NULL, NULL, NULL, 20),
        ('salesSearch.grpOrder',    'GROUP', 'salesSearch', N'訂單',     NULL, NULL, NULL, NULL, 30),
        ('system.grpAccess',        'GROUP', 'system',      N'權限控管', NULL, NULL, NULL, NULL, 10),
        -- 頁面
        ('salesIssue.processMaintain',   'PAGE', 'salesIssue.grpIssue',     N'議題維護',     NULL, 'sales-issue/issues',             'i-lucide-clipboard-list', N'依客戶別追蹤議題進度、附件與結案狀態', 10),
        ('salesIssue.kindMaintain',      'PAGE', 'salesIssue.grpBasic',     N'類別維護',     NULL, 'sales-issue/kind-maintain',      'i-lucide-tags',           N'維護議題的類別與職能主題關鍵字', 10),
        ('salesSearch.customQuery',      'PAGE', 'salesSearch.grpCustomer', N'客戶檢索',     NULL, 'sales-search/customer',          'i-lucide-users',          N'查詢內網／ERP客戶，新增或編輯內網客戶資料與 ERP 對應', 10),
        ('salesSearch.mixSalesShipping', 'PAGE', 'salesSearch.grpSales',    N'銷貨檢索',     NULL, 'sales-search/shipping-inquiry',  'i-lucide-truck',          N'依客戶別、期間、品號查詢銷貨單，含品號/銷貨單細項與統計', 10),
        ('salesSearch.queryUnFinish',    'PAGE', 'salesSearch.grpOrder',    N'未完成訂單',   NULL, 'sales-search/unfinished-orders', 'i-lucide-package-search', N'依客戶別、訂單日期、預交日期、品號查詢尚未出貨的訂單，含品號/訂單細項與統計', 10),
        ('salesSearch.orderInfoVerify',  'PAGE', 'salesSearch.grpOrder',    N'訂單資料檢核', NULL, 'sales-search/order-info-verify', 'i-lucide-shield-check',   N'對訂單金額、信用額度等項目執行檢核，支援特規覆核與 Excel 匯出', 20),
        ('system.userManager',           'PAGE', 'system.grpAccess',        N'人員管理',     NULL, 'system/user-manager',            'i-lucide-user-cog',       N'新增／停用帳號、指派角色、重置密碼與解除鎖定', 10),
        ('system.permissionManager',     'PAGE', 'system.grpAccess',        N'權限管理',     NULL, 'system/permission-manager',      'i-lucide-shield-check',   N'維護角色：每個角色可用的功能與細項權限，以及角色成員', 20),
        -- 細項
        ('salesIssue.processMaintain.createSop',   'ACTION', 'salesIssue.processMaintain',   N'SOP-新增',     NULL, NULL, NULL, NULL, 10),
        ('salesIssue.processMaintain.publishSop',  'ACTION', 'salesIssue.processMaintain',   N'SOP-公開',     NULL, NULL, NULL, NULL, 20),
        ('salesSearch.mixSalesShipping.viewAmount','ACTION', 'salesSearch.mixSalesShipping', N'顯示金額欄位', NULL, NULL, NULL, NULL, 10),
        ('salesSearch.queryUnFinish.viewAmount',   'ACTION', 'salesSearch.queryUnFinish',    N'顯示金額欄位', NULL, NULL, NULL, NULL, 10),
        ('salesSearch.orderInfoVerify.viewAmount', 'ACTION', 'salesSearch.orderInfoVerify',  N'顯示金額欄位', NULL, NULL, NULL, NULL, 10)
    ) AS s (PermissionKey, NodeType, ParentKey, Label, LabelEn, Path, Icon, Description, Sort)
    ON t.PermissionKey = s.PermissionKey
    WHEN MATCHED THEN
        UPDATE SET NodeType = s.NodeType, ParentKey = s.ParentKey, Label = s.Label, LabelEn = s.LabelEn,
                   Path = s.Path, Icon = s.Icon, Description = s.Description, Sort = s.Sort,
                   Modifier = 'migration', ModiTime = GETDATE()
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (PermissionKey, NodeType, ParentKey, Label, LabelEn, Path, Icon, Description, Sort, aStatus, Creator, CreateTime)
        VALUES (s.PermissionKey, s.NodeType, s.ParentKey, s.Label, s.LabelEn, s.Path, s.Icon, s.Description, s.Sort,
                'Y', 'migration', GETDATE());

    -- 清單外的節點（停用的群組權限）ParentKey 可能指向不存在的 key，清掉才建得了自我參照外鍵
    UPDATE p SET p.ParentKey = NULL
    FROM dbo.RBAC_Permission p
    WHERE p.ParentKey IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM dbo.RBAC_Permission x WHERE x.PermissionKey = p.ParentKey);
    PRINT '已灌入權限樹節點（模組／分組／頁面／細項）';
END
GO

-- 4b.5 約束：NodeType 必填且只能四種值；ParentKey 必須指到存在的節點
-- 停用的群組權限原本 ParentKey 指向自己（手動改資料時填的 module.function），接回權限控管底下；
-- 其他指向自己的節點一律清成 NULL，免得變成樹上接不到的孤兒。
UPDATE dbo.RBAC_Permission SET ParentKey = 'system.grpAccess'
WHERE PermissionKey = 'system.groupPermission' AND (ParentKey IS NULL OR ParentKey = PermissionKey)
  AND EXISTS (SELECT 1 FROM dbo.RBAC_Permission WHERE PermissionKey = 'system.grpAccess');
UPDATE dbo.RBAC_Permission SET ParentKey = NULL WHERE ParentKey = PermissionKey;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.RBAC_Permission') AND name = 'NodeType' AND is_nullable = 1)
    ALTER TABLE dbo.RBAC_Permission ALTER COLUMN [NodeType] VARCHAR (10) NOT NULL;
IF OBJECT_ID('dbo.CK_RBAC_Permission_NodeType', 'C') IS NULL
    ALTER TABLE dbo.RBAC_Permission ADD CONSTRAINT [CK_RBAC_Permission_NodeType]
        CHECK ([NodeType] IN ('MODULE', 'GROUP', 'PAGE', 'ACTION'));
IF OBJECT_ID('dbo.FK_RBAC_Permission_Parent', 'F') IS NULL
    ALTER TABLE dbo.RBAC_Permission ADD CONSTRAINT [FK_RBAC_Permission_Parent]
        FOREIGN KEY ([ParentKey]) REFERENCES dbo.RBAC_Permission ([PermissionKey]);
GO

-- 4b.6 角色補上祖先節點（勾頁面／細項就連帶擁有所屬分組與模組，側欄才長得出上層）。
-- 後端 SaveRole 存檔時也會補；已手動設成 'N' 的列不動。
;WITH Anc AS (
    SELECT rp.RoleID, p.ParentKey AS AncKey
    FROM dbo.RBAC_RolePermission rp
    JOIN dbo.RBAC_Permission p ON p.PermissionKey = rp.PermissionKey
    WHERE rp.aStatus = 'Y' AND p.ParentKey IS NOT NULL
    UNION ALL
    SELECT a.RoleID, p.ParentKey
    FROM Anc a
    JOIN dbo.RBAC_Permission p ON p.PermissionKey = a.AncKey
    WHERE p.ParentKey IS NOT NULL
)
INSERT INTO dbo.RBAC_RolePermission (RoleID, PermissionKey, aStatus, Creator, CreateTime)
SELECT DISTINCT a.RoleID, a.AncKey, 'Y', 'migration', GETDATE()
FROM Anc a
WHERE NOT EXISTS (SELECT 1 FROM dbo.RBAC_RolePermission x WHERE x.RoleID = a.RoleID AND x.PermissionKey = a.AncKey);
GO

-- ---------------------------------------------------------------- 5. 驗證

PRINT '--- RBAC_Role ---';
SELECT r.ID, r.RoleCode, r.RoleName, r.IsSystem, r.IsSuperAdmin, r.IsDefault, r.Sort,
       (SELECT COUNT(*) FROM dbo.RBAC_RolePermission rp WHERE rp.RoleID = r.ID AND rp.aStatus = 'Y') AS KeyCnt,
       (SELECT COUNT(*) FROM dbo.RBAC_RoleUser ur WHERE ur.RoleID = r.ID AND ur.aStatus = 'Y') AS MemberCnt
FROM dbo.RBAC_Role r
ORDER BY r.Sort, r.ID;

-- 舊有效權限（本人 ∪ 000000）vs 新有效權限（所屬角色 ∪ IsDefault 角色），只比非管理員帳號。
-- 舊 key 的頁面權限是 xxx.view，新樹拿掉了 .view，比對前先換算；
-- 新樹多出來的 MODULE / GROUP 節點（4b.6 補的祖先）舊資料本來就沒有，不列入比對。
PRINT '--- 轉換前後有效權限不一致的帳號（應為 0 筆）---';
WITH Accounts AS (
    SELECT DISTINCT LTRIM(RTRIM(Account)) AS Account
    FROM dbo.M_User WHERE ISNULL(IsAdmin, 0) = 0
),
OldRaw AS (
    SELECT DISTINCT a.Account,
           CASE WHEN p.PermissionKey LIKE '%.view' THEN LEFT(p.PermissionKey, LEN(p.PermissionKey) - 5)
                ELSE p.PermissionKey END AS PermissionKey
    FROM Accounts a
    JOIN dbo.M_Permission p ON LTRIM(RTRIM(p.LinkNumber)) IN (a.Account, '000000')
    WHERE p.PermissionKey IS NOT NULL
),
OldKeys AS (
    SELECT o.Account, o.PermissionKey
    FROM OldRaw o
    JOIN dbo.RBAC_Permission d ON d.PermissionKey = o.PermissionKey AND d.aStatus = 'Y'
),
NewKeys AS (
    SELECT DISTINCT a.Account, rp.PermissionKey
    FROM Accounts a
    JOIN dbo.RBAC_Role r ON r.aStatus = 'Y'
     AND (r.IsDefault = 1 OR EXISTS (SELECT 1 FROM dbo.RBAC_RoleUser ur
                                     WHERE ur.RoleID = r.ID AND ur.Account = a.Account AND ur.aStatus = 'Y'))
    JOIN dbo.RBAC_RolePermission rp ON rp.RoleID = r.ID AND rp.aStatus = 'Y'
    JOIN dbo.RBAC_Permission d ON d.PermissionKey = rp.PermissionKey AND d.aStatus = 'Y'
    WHERE d.NodeType IN ('PAGE', 'ACTION')
)
SELECT 'only_old' AS Diff, Account, PermissionKey FROM (SELECT * FROM OldKeys EXCEPT SELECT * FROM NewKeys) x
UNION ALL
SELECT 'only_new', Account, PermissionKey FROM (SELECT * FROM NewKeys EXCEPT SELECT * FROM OldKeys) y
ORDER BY Account, PermissionKey;

PRINT '--- IsAdmin 與 superAdmin 成員不一致的帳號（應為 0 筆）---';
SELECT 'only_isAdmin' AS Diff, Account
FROM (SELECT LTRIM(RTRIM(Account)) AS Account FROM dbo.M_User WHERE IsAdmin = 1
      EXCEPT
      SELECT ur.Account FROM dbo.RBAC_RoleUser ur JOIN dbo.RBAC_Role r ON r.ID = ur.RoleID WHERE r.IsSuperAdmin = 1 AND ur.aStatus = 'Y') x
UNION ALL
SELECT 'only_superAdmin', Account
FROM (SELECT ur.Account FROM dbo.RBAC_RoleUser ur JOIN dbo.RBAC_Role r ON r.ID = ur.RoleID WHERE r.IsSuperAdmin = 1 AND ur.aStatus = 'Y'
      EXCEPT
      SELECT LTRIM(RTRIM(Account)) FROM dbo.M_User WHERE IsAdmin = 1) y;
GO

PRINT '--- 權限樹（RBAC_Permission，依 ParentKey 展開）---';
;WITH T AS (
    SELECT PermissionKey, ParentKey, NodeType, Label, Path, Sort, aStatus, 0 AS Lvl,
           CAST(RIGHT('0000' + CAST(Sort AS VARCHAR(10)), 4) AS VARCHAR(400)) AS SortPath
    FROM dbo.RBAC_Permission WHERE ParentKey IS NULL
    UNION ALL
    SELECT c.PermissionKey, c.ParentKey, c.NodeType, c.Label, c.Path, c.Sort, c.aStatus, t.Lvl + 1,
           CAST(t.SortPath + '/' + RIGHT('0000' + CAST(c.Sort AS VARCHAR(10)), 4) AS VARCHAR(400))
    FROM dbo.RBAC_Permission c JOIN T t ON c.ParentKey = t.PermissionKey
)
SELECT REPLICATE('    ', Lvl) + Label AS Tree, NodeType, PermissionKey, Path, aStatus
FROM T ORDER BY SortPath;
GO

SET NOEXEC OFF;
GO
