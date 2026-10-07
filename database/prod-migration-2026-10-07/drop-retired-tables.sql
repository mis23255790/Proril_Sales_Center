-- 2026-10-07：刪除 Proril_Sales_Center 已停用的表
--   _bak_FunctionNo 備份：M_Function / M_Permission / M_PermissionGroup / H_FileLink
--   M_PermissionGroup 本身：2026-09-23 改角色制（RBAC_*）後應用層不讀不寫，部門範本也沒轉進 RBAC
--
-- 這幾張是 FunctionNoFormatMigration.sql 第 0 段建的備份（FunctionNo 改 varchar(8) 之前的原表）。
-- 2026-09-24 起權限樹與側欄改由 RBAC_Permission 驅動，2026-09-23 起權限改角色制，
-- M_Function 已沒有人讀，M_Permission / M_PermissionGroup 本身也只剩備份用途，這層備份不再需要。
-- 刪掉之後 FunctionNoFormatMigration.sql 就沒有還原來源了。
-- 1.0 PRORIL_WEB 的 M_PermissionGroup 還在用，這支只能對 Proril_Sales_Center 跑。
--
-- 只能對 Proril_Sales_Center 跑，不要對 PRORIL_WEB 跑。

USE Proril_Sales_Center;
GO

IF OBJECT_ID('dbo.M_Function_bak_FunctionNo', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.M_Function_bak_FunctionNo;
    PRINT '已刪除 dbo.M_Function_bak_FunctionNo';
END
ELSE
    PRINT 'dbo.M_Function_bak_FunctionNo 不存在，略過';
GO

IF OBJECT_ID('dbo.M_Permission_bak_FunctionNo', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.M_Permission_bak_FunctionNo;
    PRINT '已刪除 dbo.M_Permission_bak_FunctionNo';
END
ELSE
    PRINT 'dbo.M_Permission_bak_FunctionNo 不存在，略過';
GO

IF OBJECT_ID('dbo.M_PermissionGroup_bak_FunctionNo', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.M_PermissionGroup_bak_FunctionNo;
    PRINT '已刪除 dbo.M_PermissionGroup_bak_FunctionNo';
END
ELSE
    PRINT 'dbo.M_PermissionGroup_bak_FunctionNo 不存在，略過';
GO

IF OBJECT_ID('dbo.H_FileLink_bak_FunctionNo', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.H_FileLink_bak_FunctionNo;
    PRINT '已刪除 dbo.H_FileLink_bak_FunctionNo';
END
ELSE
    PRINT 'dbo.H_FileLink_bak_FunctionNo 不存在，略過';
GO

IF OBJECT_ID('dbo.M_PermissionGroup', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.M_PermissionGroup;
    PRINT '已刪除 dbo.M_PermissionGroup';
END
ELSE
    PRINT 'dbo.M_PermissionGroup 不存在，略過';
GO
