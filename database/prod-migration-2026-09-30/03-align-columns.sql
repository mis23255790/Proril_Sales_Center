/*
================================================================================
 51002 Proril_Sales_Center：業務議題表的欄位型別／預設值對齊 50002（Dev）
================================================================================

 2026-09-30 比對 50002／51002 的 sys.columns 發現，50002 有 PortingNotes.md
 「為什麼有 9 個欄位型別跟來源不一樣」那節的 varchar → nvarchar 覆寫與幾個預設值，
 51002 沒有（51002 的表是照 PRORIL_WEB 原型別建的）。

 真正有風險的是這兩個（其他是對齊用）：
   - D_WorkProcess.SopTitle：51002 是 NOT NULL，但 api/ 的 DWorkProcess.SopTitle 是 string?，
     送 NULL 進來會寫入失敗。改成 NULL + DEFAULT ('')。
   - D_WorkProcess.ProgressStatus：SalesCenterDbContext 設了 HasDefaultValue(10)，
     EF 在值為 null 時不送這個欄位、交給 DB 預設值；51002 沒有預設值就會存成 NULL。

 | 表 | 欄位 | 51002 現況 | 改成（= 50002） |
 |---|---|---|---|
 | D_WorkProcess         | Descript        | varchar(max) NULL      | nvarchar(max) NULL |
 | D_WorkProcess         | PhraseList      | varchar(500) NOT NULL  | nvarchar(500) NOT NULL |
 | D_WorkProcess         | SopTitle        | varchar(200) NOT NULL  | nvarchar(200) NULL DEFAULT ('') |
 | D_WorkProcess         | ProgressStatus  | 無預設值               | DEFAULT (10) |
 | D_WorkProcessCustomer | aStatus         | 無預設值               | DEFAULT ('Y') |
 | D_WorkProcessCustomer | CustomerType    | 無預設值               | DEFAULT ('1') |
 | D_WorkProcessDetail   | ProcessCaption2 | nvarchar(400) NULL     | nvarchar(max) NULL |
 | D_WorkProcessDetail   | RenameFile      | varchar(200) NULL      | nvarchar(200) NULL |
 | D_WorkProcessDetail   | UploadFile      | varchar(200) NULL      | nvarchar(200) NULL |
 | M_WorkProcessPhrase   | PhraseName      | varchar(40) NOT NULL   | nvarchar(40) NOT NULL |
 | M_WorkProcessPhrase   | Directions      | varchar(max) NULL      | nvarchar(max) NULL |
 | M_WorkProcessType     | TypeName        | varchar(40) NOT NULL   | nvarchar(40) NOT NULL |
 | M_WorkProcessType     | Descript        | varchar(max) NULL      | nvarchar(max) NULL |

 刻意不動的差異：
   - D_WorkProcess.FinFlag：51002 有 DEFAULT ((0))、50002 沒有。多一個預設值無害，保留。
   - H_FileLink.FilePath：51002 是 varchar(255)、50002 是 varchar(100)，51002 比較寬，保留。
   - COP_CheckRule.testDacPak：只有 50002 有，是 DACPAC 測試殘留欄位，不搬。
   - 各表 PK / DF 約束名稱不同：系統自動命名，不影響功能。

 這些欄位都不在任何索引裡（已查 51002 sys.index_columns），ALTER COLUMN 不用先拆索引。
 定序兩邊都是 Chinese_Taiwan_Stroke_BIN，varchar → nvarchar 不會讓中文變問號。
 可重跑：型別已經對的欄位、已經有預設值的欄位會略過。

 執行：
   sqlcmd -S 192.168.1.142,51002 -U proril_sales_center -d Proril_Sales_Center -C -f 65001 -i 03-align-columns.sql
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

IF OBJECT_ID('tempdb..#Cols') IS NOT NULL DROP TABLE #Cols;
CREATE TABLE #Cols (TableName SYSNAME, ColumnName SYSNAME, TargetType VARCHAR(50), MaxLen SMALLINT, NullSpec VARCHAR(10));
INSERT INTO #Cols VALUES
    ('D_WorkProcess',       'Descript',        'NVARCHAR(MAX)', -1,  'NULL'),
    ('D_WorkProcess',       'PhraseList',      'NVARCHAR(500)', 1000, 'NOT NULL'),
    ('D_WorkProcess',       'SopTitle',        'NVARCHAR(200)', 400, 'NULL'),
    ('D_WorkProcessDetail', 'ProcessCaption2', 'NVARCHAR(MAX)', -1,  'NULL'),
    ('D_WorkProcessDetail', 'RenameFile',      'NVARCHAR(200)', 400, 'NULL'),
    ('D_WorkProcessDetail', 'UploadFile',      'NVARCHAR(200)', 400, 'NULL'),
    ('M_WorkProcessPhrase', 'PhraseName',      'NVARCHAR(40)',  80,  'NOT NULL'),
    ('M_WorkProcessPhrase', 'Directions',      'NVARCHAR(MAX)', -1,  'NULL'),
    ('M_WorkProcessType',   'TypeName',        'NVARCHAR(40)',  80,  'NOT NULL'),
    ('M_WorkProcessType',   'Descript',        'NVARCHAR(MAX)', -1,  'NULL');

DECLARE @t SYSNAME, @c SYSNAME, @type VARCHAR(50), @len SMALLINT, @null VARCHAR(10), @sql NVARCHAR(MAX);
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT TableName, ColumnName, TargetType, MaxLen, NullSpec FROM #Cols;
OPEN cur;
FETCH NEXT FROM cur INTO @t, @c, @type, @len, @null;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID('dbo.' + @t) AND name = @c
                 AND (system_type_id <> TYPE_ID('nvarchar') OR max_length <> @len
                      OR is_nullable <> CASE @null WHEN 'NULL' THEN 1 ELSE 0 END))
    BEGIN
        SET @sql = N'ALTER TABLE dbo.' + QUOTENAME(@t) + N' ALTER COLUMN ' + QUOTENAME(@c) + N' ' + @type + N' ' + @null + N';';
        EXEC (@sql);
        PRINT CONCAT('已改 ', @t, '.', @c, ' → ', @type, ' ', @null);
    END
    FETCH NEXT FROM cur INTO @t, @c, @type, @len, @null;
END
CLOSE cur;
DEALLOCATE cur;
GO

-- 預設值：該欄位還沒有任何預設約束才加
IF OBJECT_ID('tempdb..#Defaults') IS NOT NULL DROP TABLE #Defaults;
CREATE TABLE #Defaults (TableName SYSNAME, ColumnName SYSNAME, DefaultExpr NVARCHAR(50));
INSERT INTO #Defaults VALUES
    ('D_WorkProcess',         'SopTitle',       N'('''')'),
    ('D_WorkProcess',         'ProgressStatus', N'((10))'),
    ('D_WorkProcessCustomer', 'aStatus',        N'(''Y'')'),
    ('D_WorkProcessCustomer', 'CustomerType',   N'(''1'')');

DECLARE @t SYSNAME, @c SYSNAME, @d NVARCHAR(50), @sql NVARCHAR(MAX);
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT TableName, ColumnName, DefaultExpr FROM #Defaults;
OPEN cur;
FETCH NEXT FROM cur INTO @t, @c, @d;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID('dbo.' + @t) AND name = @c AND default_object_id <> 0)
    BEGIN
        SET @sql = N'ALTER TABLE dbo.' + QUOTENAME(@t) + N' ADD CONSTRAINT ' + QUOTENAME('DF_' + @t + '_' + @c)
                 + N' DEFAULT ' + @d + N' FOR ' + QUOTENAME(@c) + N';';
        EXEC (@sql);
        PRINT CONCAT('已加預設值 ', @t, '.', @c, ' = ', @d);
    END
    FETCH NEXT FROM cur INTO @t, @c, @d;
END
CLOSE cur;
DEALLOCATE cur;
GO

PRINT '--- 結果 ---';
SELECT t.name AS TableName, c.name AS ColumnName, ty.name AS TypeName, c.max_length, c.is_nullable,
       dc.definition AS DefaultDef
FROM sys.columns c
JOIN sys.tables t ON t.object_id = c.object_id
JOIN sys.types ty ON ty.user_type_id = c.user_type_id
LEFT JOIN sys.default_constraints dc ON dc.object_id = c.default_object_id
WHERE (t.name = 'D_WorkProcess' AND c.name IN ('Descript', 'PhraseList', 'SopTitle', 'ProgressStatus'))
   OR (t.name = 'D_WorkProcessCustomer' AND c.name IN ('aStatus', 'CustomerType'))
   OR (t.name = 'D_WorkProcessDetail' AND c.name IN ('ProcessCaption2', 'RenameFile', 'UploadFile'))
   OR (t.name = 'M_WorkProcessPhrase' AND c.name IN ('PhraseName', 'Directions'))
   OR (t.name = 'M_WorkProcessType' AND c.name IN ('TypeName', 'Descript'))
ORDER BY t.name, c.name;
GO

SET NOEXEC OFF;
GO
