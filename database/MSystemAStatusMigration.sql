/*
 * M_System 加 aStatus（Proril_Sales_Center 專用）。
 *
 * 背景：
 *   - M_System 在新庫只剩 topbar 環境圖示（MainApi/GetMSystemWNo）在讀，
 *     沒有維護畫面，直接在 DB 改。
 *   - 比照 RBAC_* 的慣例：aStatus = 'Y' 有效、'N' 失效，api/ 只認 'Y'。
 *
 * 注意：
 *   - 只對 Proril_Sales_Center 執行，**不要對 PRORIL_WEB 跑**（1.0 的表不動）。
 *     所以 database/Tables/M_System.sql（對照 PRORIL_WEB）不加這欄，新庫在此分岔。
 *   - database/PermissionMasterSeed.sql 會 DELETE 後從 PRORIL_WEB 重灌 M_System，
 *     重灌後 aStatus 一律回到預設 'Y'，手動設過 'N' 的要再設一次。
 *   - 可重複執行。
 */

IF COL_LENGTH('dbo.M_System', 'aStatus') IS NULL
BEGIN
    ALTER TABLE dbo.M_System ADD [aStatus] VARCHAR (1) CONSTRAINT [DF_M_System_aStatus] DEFAULT ('Y') NOT NULL;
    PRINT '已加入 dbo.M_System.aStatus';
END
ELSE
    PRINT 'dbo.M_System.aStatus 已存在，略過';
GO

SELECT ID, SystemNo, SystemName, aStatus FROM dbo.M_System ORDER BY SystemNo;
GO
