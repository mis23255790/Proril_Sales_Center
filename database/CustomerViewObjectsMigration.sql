/*
 * V_COP_Customer（1.0 客戶查詢 CustomQueryApi/GetCustom 用的 ERP 客戶清單 View），
 * 從 PRORIL_WEB 搬一份到 Proril_Sales_Center。
 *
 * 依賴關係（OBJECT_DEFINITION 逐行讀過）：
 *   - 0 個本地表，只讀 ERP linked server 的 COPMA（[192.168.1.200].PRORIL.dbo.COPMA
 *     與 [192.168.1.200].TWPR.dbo.COPMA 各一次 UNION），跟已經在這個庫可用的
 *     V_ERPCustomer 依賴同一台 linked server，不用另外處理。
 *   - 0 個預存程序、0 個函式，不用複製任何資料列。
 *
 * CREATE VIEW 改成 CREATE OR ALTER，可重複執行。除此之外與來源
 * （PRORIL_WEB 目前的定義，2026-09-21 用 OBJECT_DEFINITION 直接從資料庫撈出來）
 * 一字不差，連註解掉的欄位都保留。
 *
 * 怎麼執行：走 database/scripts/run-objects-migration.ps1，不要直接丟進 SSMS。
 *
 *   .\scripts\run-objects-migration.ps1 -Script CustomerViewObjectsMigration.sql -Environment snapshot
 *   .\scripts\run-objects-migration.ps1 -Script CustomerViewObjectsMigration.sql -Environment snapshot -Execute
 */

USE Proril_Sales_Center;
GO

-- ============================================================
-- View：V_COP_Customer
-- ============================================================

-- 20241118 建立一份浦瑞及芳晟客戶資料集合的 VIEW 供銷貨單資料查詢功能使用

CREATE OR ALTER view [dbo].[V_COP_Customer]
as

SELECT DISTINCT TOP 100000 * FROM
(
SELECT LTRIM(RTRIM(MA001)) as [CustomerNo],LTRIM(RTRIM(MA003)) as [LongName],LTRIM(RTRIM(MA002)) as [ShortName],LTRIM(RTRIM(MA054)) as [Ship],
 CASE MA048 WHEN '1' THEN '空運'
        WHEN '2' THEN '海運'
        WHEN '3' THEN '海空聯運'
        WHEN '4' THEN '郵寄'
        WHEN '5' THEN '陸運'
        WHEN '6' THEN '自取'
        WHEN '7' THEN '自送'
        WHEN '8' THEN '快遞'
        ELSE MA048 END as [Transport],
LTRIM(RTRIM(MA005)) as [ContactName],LTRIM(RTRIM(MA006)) as [ContactPhone],LTRIM(RTRIM(MA009)) as [ContactEMail]--,CREATE_DATE,CREATE_TIME,MODI_DATE,MODI_TIME
FROM [192.168.1.200].PRORIL.dbo.COPMA MA
WHERE 1=1
UNION
SELECT LTRIM(RTRIM(MA001)) as [CustomerNo],LTRIM(RTRIM(MA003)) as [LongName],LTRIM(RTRIM(MA002)) as [ShortName],LTRIM(RTRIM(MA054)) as [Ship],
 CASE MA048 WHEN '1' THEN '空運'
        WHEN '2' THEN '海運'
        WHEN '3' THEN '海空聯運'
        WHEN '4' THEN '郵寄'
        WHEN '5' THEN '陸運'
        WHEN '6' THEN '自取'
        WHEN '7' THEN '自送'
        WHEN '8' THEN '快遞'
        ELSE MA048 END as [Transport],
LTRIM(RTRIM(MA005)) as [ContactName],LTRIM(RTRIM(MA006)) as [ContactPhone],LTRIM(RTRIM(MA009)) as [ContactEMail]--,CREATE_DATE,CREATE_TIME,MODI_DATE,MODI_TIME
FROM [192.168.1.200].TWPR.dbo.COPMA MA
WHERE 1=1
) X
ORDER BY CustomerNo
GO
