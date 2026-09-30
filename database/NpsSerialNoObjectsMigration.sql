/*
 * V_NPS_SerialNo：銘版序號（NPS_D_Order.SerialNosJson）的直連 View，建在 Proril_Sales_Center。
 *
 * 背景：
 *   - NPS_D_Order 業務上屬於 Proril_Manufacturing_Center（銘版系統），資料目前躺在 PRORIL_WEB，
 *     那邊還沒有獨立 API。
 *   - api/ 2026-09-29 起已不連 PRORIL_WEB（ProrilWebDbContext 已刪除），2.0 要讀序號只能
 *     從 Proril_Sales_Center 這邊跨庫讀，所以集中成這一個 View，應用層只認它。
 *   - 讀取端是 api/Services/SerialNoSource.cs 的 ViewSerialNoSource
 *     （SalesOrderUnFinishApi／ManufacturingApi／SerialNoSyncHostedService 共用）。
 *     哪天 Manufacturing_Center 有 API 了，把 Services:ManufacturingCenter:SerialNoSource
 *     改成 Api 就不再讀這個 View，這支腳本不用回收也不影響。
 *
 * 欄位：
 *   - SerialKey：OrderType + '-' + RTRIM(OrderNo) + OrderSno，
 *     與原本 prc_ImportSalesOrder／V_UnfinOrder 那段跨庫 LEFT JOIN 的比對規則一字不差，
 *     也就是 COP_SalesOrder 的 TH014-RTRIM(TH015)TH016、V_UnfinOrder 的 TD001-RTRIM(TD002)TD003。
 *   - SerialNosJson：只列有值的列（NULL 的列對誰都沒用）。
 *
 * **權限前提**：這是跨資料庫參照，執行查詢的登入帳號必須在 PRORIL_WEB 有 NPS_D_Order 的
 * SELECT 權限（SQL Server 預設不開 cross-database ownership chaining，View 本身的權限不夠）。
 * 51002 的 proril_sales_center 帳號目前沒有這個權限（見 prod-migration-2026-09-21/README.md），
 * 在那個環境要嘛補授權：
 *
 *   USE PRORIL_WEB;
 *   CREATE USER [proril_sales_center] FOR LOGIN [proril_sales_center];  -- 已存在就跳過
 *   GRANT SELECT ON dbo.NPS_D_Order TO [proril_sales_center];
 *
 * 要嘛把 SerialNoSource 設成 Api、等 Manufacturing_Center 的端點。
 *
 * 怎麼執行：走 database/scripts/run-objects-migration.ps1，不要直接丟進 SSMS。
 *
 *   .\scripts\run-objects-migration.ps1 -Script NpsSerialNoObjectsMigration.sql -Environment snapshot
 *   .\scripts\run-objects-migration.ps1 -Script NpsSerialNoObjectsMigration.sql -Environment snapshot -Execute
 */

USE Proril_Sales_Center;
GO

-- ============================================================
-- View：V_NPS_SerialNo
-- ============================================================

CREATE OR ALTER VIEW [dbo].[V_NPS_SerialNo]
AS
SELECT
    TB.OrderType + '-' + RTRIM(TB.OrderNo) + TB.OrderSno AS SerialKey,
    TB.SerialNosJson
FROM PRORIL_WEB.dbo.NPS_D_Order TB
WHERE TB.SerialNosJson IS NOT NULL;
GO
