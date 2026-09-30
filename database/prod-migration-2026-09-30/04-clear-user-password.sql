/*
================================================================================
 51002 Proril_Sales_Center：清空 M_User.Password（比照 50002 2026-09-14 的做法）
================================================================================

 2.0 的登入只走 SSO（LoginSso 不看密碼），50002 已經把 M_User.Password 全部清成 NULL、
 備份在 dbo.M_User_bak_Password（ID / Account / Password），見 PortingNotes.md
 「M_User.Password 清空（2026-09-14）」。51002 的 46 列還都有密碼。

 做的事：
   1. 建 dbo.M_User_bak_Password（結構同 50002），把目前有密碼的列備份進去。
      備份表已存在時只補「還沒備份過的帳號」，不覆蓋既有備份。
   2. M_User.Password 全部設成 NULL。

 注意：AddUser / ResetPassword 仍會寫 AES(帳號) 當密碼（CLAUDE.md 記載的已知不一致），
 之後新建的帳號會是唯一有密碼的那個，這支不處理。

 執行：
   sqlcmd -S 192.168.1.142,51002 -U proril_sales_center -d Proril_Sales_Center -C -f 65001 -i 04-clear-user-password.sql
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

IF OBJECT_ID('dbo.M_User_bak_Password', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.M_User_bak_Password (
        [ID]       INT          NOT NULL,
        [Account]  VARCHAR (10) NULL,
        [Password] VARCHAR (50) NULL
    );
    PRINT '已建立 dbo.M_User_bak_Password';
END
GO

BEGIN TRANSACTION;

INSERT INTO dbo.M_User_bak_Password (ID, Account, Password)
SELECT u.ID, u.Account, u.Password
FROM dbo.M_User u
WHERE u.Password IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.M_User_bak_Password b WHERE b.ID = u.ID);
PRINT CONCAT('備份密碼：', @@ROWCOUNT, ' 列');

UPDATE dbo.M_User SET Password = NULL WHERE Password IS NOT NULL;
PRINT CONCAT('清空密碼：', @@ROWCOUNT, ' 列');

COMMIT TRANSACTION;
GO

PRINT '--- 結果（HasPassword 應為 0）---';
SELECT COUNT(*) AS Users, SUM(CASE WHEN Password IS NULL THEN 0 ELSE 1 END) AS HasPassword FROM dbo.M_User;
SELECT COUNT(*) AS BackupRows FROM dbo.M_User_bak_Password;
GO

SET NOEXEC OFF;
GO
