/*
 * 稽核紀錄：SYS_AuditLog，建在 Proril_Sales_Center（2026-10-06）。
 *
 * 跟檔案 log（api/Helpers/LogHelper.cs，保留 30 天、每個 request 都記）分工：
 *   - 檔案 log：除錯用，記所有 request／例外／步驟，不好查、一個月就清掉。
 *   - SYS_AuditLog：「誰、什麼時候、做了什麼」，只記有意義的事件，保留一年，給人查。
 *
 * 目前寫入的事件（api/Services/AuditLogService.cs，Action 常數見 AuditActions）：
 *   - 登入：LOGIN / LOGIN_FAIL（MainApi/LoginSso、MainApi/Login）
 *   - 人員管理：CREATE / UPDATE / DELETE / RESET_PASSWORD / UNLOCK，SetUserRoles 的角色增減
 *   - 權限管理：角色 CREATE / UPDATE / DELETE（含權限增減），SetRoleMembers 的成員增減
 * 不記「進入頁面」（2026-10-06 決定）。
 *
 * 欄位：
 *   - LogTime：UTC（SYSUTCDATETIME），顯示時再轉台灣時間；跟各表 CreateTime（容器 DateTime.Now）不同，刻意的。
 *   - Target：功能的頁面權限 key（例如 system.userManager），登入是 auth。
 *   - TargetId：被操作的對象（帳號、角色代碼…）。
 *   - Detail：JSON，改前／改後或增減清單。**不得寫入密碼、token、金鑰**。
 *   - ClientIp：Nuxt 轉發層帶來的 X-Forwarded-For 第一段，沒有就是連線來源。
 *
 * 保留一年：api/Services/LogTimedHostedService.cs 每天凌晨刪 LogTime 超過一年的列。
 *
 * 跟 RBAC_*、CMN_XlsFileFormat 一樣是新庫專屬的表，**不放進 database/Tables/ 與 TABLES.txt**。
 *
 * 怎麼執行：走 database/scripts/run-objects-migration.ps1，不要直接丟進 SSMS。
 *
 *   .\scripts\run-objects-migration.ps1 -Script AuditLogObjectsMigration.sql -Environment snapshot
 *   .\scripts\run-objects-migration.ps1 -Script AuditLogObjectsMigration.sql -Environment snapshot -Execute
 *
 * 不需要 linked server，報「不存在」不影響這支。可重複執行。
 */

USE Proril_Sales_Center;
GO

IF OBJECT_ID('dbo.SYS_AuditLog') IS NULL
BEGIN
    CREATE TABLE [dbo].[SYS_AuditLog] (
        [ID]        BIGINT         IDENTITY (1, 1) NOT NULL,
        [LogTime]   DATETIME2 (3)  NOT NULL CONSTRAINT [DF_SYS_AuditLog_LogTime] DEFAULT (SYSUTCDATETIME()),
        [Account]   VARCHAR (20)   NULL,
        [Action]    VARCHAR (20)   NOT NULL,
        [Target]    VARCHAR (100)  NOT NULL,
        [TargetId]  NVARCHAR (100) NULL,
        [Detail]    NVARCHAR (MAX) NULL,
        [ClientIp]  VARCHAR (45)   NULL,
        CONSTRAINT [PK_SYS_AuditLog] PRIMARY KEY CLUSTERED ([ID] ASC)
    );
    CREATE NONCLUSTERED INDEX [IX_SYS_AuditLog_LogTime] ON [dbo].[SYS_AuditLog] ([LogTime]);
    CREATE NONCLUSTERED INDEX [IX_SYS_AuditLog_Account] ON [dbo].[SYS_AuditLog] ([Account], [LogTime]);
    CREATE NONCLUSTERED INDEX [IX_SYS_AuditLog_Target] ON [dbo].[SYS_AuditLog] ([Target], [TargetId], [LogTime]);
    PRINT '已建立 dbo.SYS_AuditLog';
END
GO
