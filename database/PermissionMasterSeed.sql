/*
================================================================================
 功能主檔（M_System / M_Function）搬到 Proril_Sales_Center
================================================================================

 在 **Proril_Sales_Center** 上執行（不是 PRORIL_WEB）。
 來源 PRORIL_WEB 必須跟它在**同一個 SQL Server instance**——腳本用三段式命名
 [PRORIL_WEB].dbo.xxx 跨資料庫查，不需要 linked server，但登入帳號要對兩個庫都有權限。
 這跟 scripts/copy-snapshot-data.ps1 的前提一致。

 做兩件事：
   1. 建 M_System / M_Function（若不存在）。**中文欄位刻意開成 nvarchar**，
      見下面「為什麼不直接照抄 PRORIL_WEB 的型別」。
   2. 把 2.0 真的有頁面的那幾列從 PRORIL_WEB 複製過來（整批覆蓋，可重複執行）。

 --------------------------------------------------------------------------
 為什麼只複製幾列，不是整張表
 --------------------------------------------------------------------------
 PRORIL_WEB.M_Function 有 90+ 個功能，絕大多數是 2.0 還沒搬的模組（品異、託工、
 包裝、報價、庫存…）。整份複製的話 2.0 的權限管理樹會長出一堆點下去 404 的功能。
 所以只收 2.0 真的有對應頁面的 8 個功能 + 它們所屬的 3 個系統別。

 對應的 2.0 路由在 app/composables/useAppNavigation.ts 的 NAV_MODULES
 （M_Function.Href 存的是 1.0 的網址，2.0 不用它，但照原樣複製過來不動）。

 scripts/copy-snapshot-data.ps1 **會跳過這兩張表**（$script:PartialRowTables），
 否則它的整批覆蓋會把上面這件事推翻掉。要改這 8 列的範圍就改本檔的 @FunctionNos。

 --------------------------------------------------------------------------
 為什麼不直接照抄 PRORIL_WEB 的型別
 --------------------------------------------------------------------------
 兩個資料庫的 collation 不同：
   PRORIL_WEB           Chinese_Taiwan_Stroke_BIN     （支援繁中的 code page）
   Proril_Sales_Center  SQL_Latin1_General_CP1_CI_AS  （西歐語系，**不支援中文**）

 M_Function.FunctionName / GroupName 在來源是 varchar 卻存了中文，照原型別建表的話
 資料複製過去會經過 code page 轉換，中文變成 ?（不可逆）。所以這兩欄建成 nvarchar。
 M_System.SystemName / TypeName 在來源本來就是 nvarchar，不用覆寫。
 同樣的處理見 PortingNotes.md「為什麼有 9 個欄位型別跟來源不一樣」。

 這也是為什麼 **不要**用 scripts/publish.ps1 去建這兩張表：DACPAC 裡的
 Tables/M_Function.sql 是 PRORIL_WEB 的正本（varchar），publish 到這個庫會踩到上面
 這個坑。Tables/M_System.sql 已經是 nvarchar，沒這個問題。

 --------------------------------------------------------------------------
 執行方式
 --------------------------------------------------------------------------
 在 SSMS 開 Proril_Sales_Center 直接執行，或：
   sqlcmd -S <host>,<port> -d Proril_Sales_Center -U <user> -P <pw> -C -i PermissionMasterSeed.sql

 可重複執行：每次都是先刪這幾列再重灌，不會累積。
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

IF DB_ID('PRORIL_WEB') IS NULL
BEGIN
    RAISERROR('同一個 instance 上找不到 PRORIL_WEB，來源不在這台機器。', 16, 1);
    SET NOEXEC ON;
END
GO

-- ---------------------------------------------------------------- 1. 建表

IF OBJECT_ID('dbo.M_System', 'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[M_System] (
        [ID]           INT           IDENTITY (1, 1) NOT NULL,
        [SystemNo]     INT           NOT NULL,
        [SystemName]   NVARCHAR (20) NOT NULL,
        [SystemType]   INT           NOT NULL,
        [TypeName]     NVARCHAR (20) NULL,
        [Sort]         INT           NOT NULL,
        [ImagePath]    VARCHAR (50)  NULL,
        [Href]         NVARCHAR (50) CONSTRAINT [DF_M_System_Href] DEFAULT ('') NOT NULL,
        [RedirectHref] NVARCHAR (50) NULL,
        CONSTRAINT [PK__M_System__3214EC279302271C] PRIMARY KEY CLUSTERED ([ID] ASC)
    );
    PRINT '已建立 dbo.M_System';
END
GO

IF OBJECT_ID('dbo.M_Function', 'U') IS NULL
BEGIN
    -- FunctionNo 是 AAABBCC（SystemNo 3 + GroupNo 2 + 序號 2），跟來源 PRORIL_WEB 的
    -- int 流水號**不一樣**，見 database/FunctionNoFormatMigration.sql。
    -- FunctionName / GroupName 刻意用 nvarchar，來源是 varchar 但存了中文，見檔頭說明
    CREATE TABLE [dbo].[M_Function] (
        [ID]           INT           IDENTITY (1, 1) NOT NULL,
        [FunctionNo]   VARCHAR (8)   NOT NULL,
        [FunctionName] NVARCHAR (20) NULL,
        [SystemNo]     INT           NOT NULL,
        [GroupNo]      INT           NULL,
        [GroupName]    NVARCHAR (20) NULL,
        [ImagrePath]   VARCHAR (50)  NULL,
        [Href]         NVARCHAR (50) NULL,
        [aStatus]      VARCHAR (1)   CONSTRAINT [DF_M_Function_aStatus] DEFAULT ('Y') NULL,
        [RedirectHref] NVARCHAR (50) NULL,
        CONSTRAINT [PK__M_Functi__3214EC2746E5CF47] PRIMARY KEY CLUSTERED ([ID] ASC)
    );
    PRINT '已建立 dbo.M_Function';
END
GO

-- ---------------------------------------------------------------- 2. 複製資料

/*
  2.0 真的有頁面的 8 個功能。改這裡就等於改 2.0 權限樹勾得到的範圍——
  加一列之前請先確認 app/composables/useAppNavigation.ts 的 NAV_MODULES 有對應路由，
  否則側欄不會顯示它（側欄只列有對照路由的功能），權限樹卻勾得到，容易誤會。

    舊 1   -> 0000101  權限管理      -> system/permission-manager
    舊 8   -> 0000102  人員管理      -> system/user-manager
    舊 16  -> 0070101  類別維護      -> sales-issue/kind-maintain
    舊 17  -> 0070102  議題維護      -> sales-issue/issues
    舊 410 -> 0320101  銷貨檢索      -> sales-search/shipping-inquiry
    舊 420 -> 0320102  未完成訂單    -> sales-search/unfinished-orders
    舊 425 -> 0320201  訂單資料檢核  -> sales-search/order-info-verify
    舊 440 -> 0320103  客戶檢索      -> sales-search/customer
*/
DECLARE @FunctionNos TABLE (OldNo INT PRIMARY KEY, NewNo VARCHAR(8) NOT NULL);
INSERT INTO @FunctionNos (OldNo, NewNo) VALUES
    (  1, '0000101'),   -- 權限管理
    (  8, '0000102'),   -- 人員管理
    ( 16, '0070101'),   -- 類別維護
    ( 17, '0070102'),   -- 議題維護
    (410, '0320101'),   -- 銷貨檢索
    (420, '0320102'),   -- 未完成訂單
    (440, '0320103'),   -- 客戶檢索
    (425, '0320201');   -- 訂單資料檢核

-- 系統別直接由上面那幾個功能推出來，不另外寫死，加功能時不會忘了補系統別
DECLARE @SystemNos TABLE (SystemNo INT PRIMARY KEY);
INSERT INTO @SystemNos (SystemNo)
SELECT DISTINCT f.SystemNo
FROM [PRORIL_WEB].[dbo].[M_Function] f
JOIN @FunctionNos n ON n.OldNo = f.FunctionNo;

BEGIN TRANSACTION;

-- M_System -------------------------------------------------------
DELETE FROM dbo.M_System;

SET IDENTITY_INSERT dbo.M_System ON;

INSERT INTO dbo.M_System (ID, SystemNo, SystemName, SystemType, TypeName, Sort, ImagePath, Href, RedirectHref)
SELECT s.ID, s.SystemNo, s.SystemName, s.SystemType, s.TypeName, s.Sort, s.ImagePath, s.Href, s.RedirectHref
FROM [PRORIL_WEB].[dbo].[M_System] s
JOIN @SystemNos n ON n.SystemNo = s.SystemNo;

SET IDENTITY_INSERT dbo.M_System OFF;

-- M_Function -----------------------------------------------------
DELETE FROM dbo.M_Function;

SET IDENTITY_INSERT dbo.M_Function ON;

-- 來源是舊的 int 流水號，這裡換成 AAABBCC 再寫進去
INSERT INTO dbo.M_Function (ID, FunctionNo, FunctionName, SystemNo, GroupNo, GroupName, ImagrePath, Href, aStatus, RedirectHref)
SELECT f.ID, n.NewNo, f.FunctionName, f.SystemNo, f.GroupNo, f.GroupName, f.ImagrePath, f.Href, f.aStatus, f.RedirectHref
FROM [PRORIL_WEB].[dbo].[M_Function] f
JOIN @FunctionNos n ON n.OldNo = f.FunctionNo;

SET IDENTITY_INSERT dbo.M_Function OFF;

COMMIT TRANSACTION;
GO

-- ---------------------------------------------------------------- 3. 驗證

PRINT '--- M_System ---';
SELECT ID, SystemNo, SystemName, SystemType, TypeName, Sort, ImagePath FROM dbo.M_System ORDER BY SystemNo;

PRINT '--- M_Function ---';
SELECT ID, FunctionNo, FunctionName, SystemNo, GroupNo, GroupName, aStatus FROM dbo.M_Function ORDER BY SystemNo, GroupNo, FunctionNo;

/*
  中文有沒有被 code page 吃掉：兩邊用同一個 collation 轉出來比對，應該 0 筆不一致。
  有列出來就代表建表時漏了 nvarchar 覆寫，把表 drop 掉重跑這支腳本。
*/
PRINT '--- 中文欄位比對（應該沒有任何列） ---';
SELECT t.FunctionNo, t.FunctionName AS Target, s.FunctionName AS Source
FROM dbo.M_Function t
JOIN [PRORIL_WEB].[dbo].[M_Function] s ON s.ID = t.ID  -- FunctionNo 兩邊已不同，只能靠 ID 對
WHERE CAST(t.FunctionName AS NVARCHAR(20))
      <> CAST(s.FunctionName COLLATE Chinese_Taiwan_Stroke_BIN AS NVARCHAR(20))
   OR CAST(ISNULL(t.GroupName, N'') AS NVARCHAR(20))
      <> CAST(ISNULL(s.GroupName, '') COLLATE Chinese_Taiwan_Stroke_BIN AS NVARCHAR(20));

SELECT t.SystemNo, t.SystemName AS Target, s.SystemName AS Source
FROM dbo.M_System t
JOIN [PRORIL_WEB].[dbo].[M_System] s ON s.ID = t.ID
WHERE t.SystemName <> s.SystemName
   OR ISNULL(t.TypeName, N'') <> ISNULL(s.TypeName, N'');
GO

SET NOEXEC OFF;
GO
