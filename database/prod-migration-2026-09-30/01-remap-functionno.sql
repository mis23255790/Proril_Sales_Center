/*
================================================================================
 51002 Proril_Sales_Center：M_Permission 等表的 FunctionNo 補換號（AAABBCC）
================================================================================

 背景（2026-09-30 比對 50002／51002 發現）：
   51002 有 *_bak_FunctionNo 備份表、M_Function 也已經是 AAABBCC，代表
   FunctionNoFormatMigration.sql 當初跑過；但之後 M_Permission／M_PermissionLinkType／
   H_FileLink 又被 PRORIL_WEB 的資料重灌過，裡面的 FunctionNo 回到舊的 int 流水號
   （欄位型別仍是 varchar(8)）。結果 PermissionDefObjectsMigration.sql 回填不到任何
   PermissionKey（801 列全是 NULL），RbacObjectsMigration.sql 只會轉出 superAdmin。

 FunctionNoFormatMigration.sql 不能直接重跑：它偵測到 M_Function 已是 varchar 就停，
 M_PermissionLinkType 那段還要讀 PRORIL_WEB（proril_sales_center 帳號沒有 SELECT）。
 所以這裡只做「資料換號」那幾段，對照表與原腳本一字不差，**可重跑**
 （只動還是舊號的列，換過的列不會再被對到）。

 做的事：
   1. M_Permission / M_PermissionGroup / H_FileLink：8 個舊號換成新號，其餘舊號保留
   2. M_PermissionLinkType：只留 2.0 這 8 個功能的細項並換號
      （與 FunctionNoFormatMigration.sql 從 PRORIL_WEB 重建的結果相同；原本 14 列 → 4 列）
   3. 驗證：不應再有任何對照表涵蓋得到的舊號

 執行：
   sqlcmd -S 192.168.1.142,51002 -U proril_sales_center -d Proril_Sales_Center -C -f 65001 -i 01-remap-functionno.sql
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

-- M_Function 必須已經是新格式，否則代表 FunctionNoFormatMigration.sql 沒跑過，應該跑那支
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID('dbo.M_Function') AND name = 'FunctionNo'
                 AND system_type_id = TYPE_ID('varchar'))
   OR EXISTS (SELECT 1 FROM dbo.M_Function WHERE LEN(FunctionNo) <> 7)
BEGIN
    RAISERROR('M_Function 還不是 AAABBCC 格式，請改跑 FunctionNoFormatMigration.sql。', 16, 1);
    SET NOEXEC ON;
END
GO

IF OBJECT_ID('tempdb..#Map') IS NOT NULL DROP TABLE #Map;
-- 暫存表建在 tempdb，不指定 COLLATE 會用 instance 預設定序（51002 是 SQL_Latin1_General_CP1_CI_AS），
-- 跟本庫的 Chinese_Taiwan_Stroke_BIN 比對會噴 collation conflict
CREATE TABLE #Map (OldNo VARCHAR(8) COLLATE DATABASE_DEFAULT PRIMARY KEY,
                   NewNo VARCHAR(8) COLLATE DATABASE_DEFAULT NOT NULL);
INSERT INTO #Map (OldNo, NewNo) VALUES
    ('1',   '0000101'),   -- 權限管理
    ('8',   '0000102'),   -- 人員管理
    ('16',  '0070101'),   -- 類別維護
    ('17',  '0070102'),   -- 議題維護
    ('410', '0320101'),   -- 銷貨檢索
    ('420', '0320102'),   -- 未完成訂單
    ('440', '0320103'),   -- 客戶檢索
    ('425', '0320201');   -- 訂單資料檢核

BEGIN TRANSACTION;

UPDATE p SET p.FunctionNo = m.NewNo
FROM dbo.M_Permission p JOIN #Map m ON m.OldNo = p.FunctionNo;
PRINT CONCAT('M_Permission 換號：', @@ROWCOUNT, ' 列');

UPDATE g SET g.FunctionNo = m.NewNo
FROM dbo.M_PermissionGroup g JOIN #Map m ON m.OldNo = g.FunctionNo;
PRINT CONCAT('M_PermissionGroup 換號：', @@ROWCOUNT, ' 列');

UPDATE h SET h.LinkFunctionNo = m.NewNo
FROM dbo.H_FileLink h JOIN #Map m ON m.OldNo = h.LinkFunctionNo;
PRINT CONCAT('H_FileLink 換號：', @@ROWCOUNT, ' 列');

-- M_PermissionLinkType：非 2.0 功能的細項刪掉（新舊號都對不到的），2.0 的換號
DELETE lt FROM dbo.M_PermissionLinkType lt
WHERE NOT EXISTS (SELECT 1 FROM #Map m WHERE m.OldNo = lt.FunctionNo OR m.NewNo = lt.FunctionNo);
PRINT CONCAT('M_PermissionLinkType 刪除非 2.0 功能細項：', @@ROWCOUNT, ' 列');

UPDATE lt SET lt.FunctionNo = m.NewNo
FROM dbo.M_PermissionLinkType lt JOIN #Map m ON m.OldNo = lt.FunctionNo;
PRINT CONCAT('M_PermissionLinkType 換號：', @@ROWCOUNT, ' 列');

COMMIT TRANSACTION;
GO

PRINT '--- 漏改檢查（應該沒有任何列）---';
SELECT 'M_Permission' AS t, p.FunctionNo FROM dbo.M_Permission p JOIN #Map m ON m.OldNo = p.FunctionNo
UNION ALL
SELECT 'M_PermissionGroup', g.FunctionNo FROM dbo.M_PermissionGroup g JOIN #Map m ON m.OldNo = g.FunctionNo
UNION ALL
SELECT 'H_FileLink', h.LinkFunctionNo FROM dbo.H_FileLink h JOIN #Map m ON m.OldNo = h.LinkFunctionNo
UNION ALL
SELECT 'M_PermissionLinkType', lt.FunctionNo FROM dbo.M_PermissionLinkType lt JOIN #Map m ON m.OldNo = lt.FunctionNo;

PRINT '--- M_PermissionLinkType ---';
SELECT ID, FunctionNo, LinkType, LinkTypeName FROM dbo.M_PermissionLinkType ORDER BY FunctionNo, LinkType;
GO

SET NOEXEC OFF;
GO
