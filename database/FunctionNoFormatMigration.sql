/*
================================================================================
 FunctionNo 改成 AAABBCC 格式（varchar(8)）
================================================================================

 在 **Proril_Sales_Center** 上執行（不是 PRORIL_WEB）。
 來源 PRORIL_WEB 必須跟它在同一個 SQL Server instance（要用三段式命名撈
 M_PermissionLinkType）。

 --------------------------------------------------------------------------
 改什麼
 --------------------------------------------------------------------------
 FunctionNo 從「流水號 int」改成「看得出歸屬的定長字串」：

     AAABBCC   AAA = SystemNo（補零 3 位）
               BB  = GroupNo （補零 2 位）
               CC  = 同一個 SystemNo+GroupNo 底下的序號（補零 2 位）

 定長的用意是字串排序等於「系統別 → 群組 → 序號」的正確順序。
 欄位開 varchar(8) 而不是剛好 7，留一位餘裕。

 | 舊  | 新        | 功能         | SystemNo | GroupNo |
 |-----|-----------|--------------|----------|---------|
 | 1   | 0000101   | 權限管理     | 0        | 1       |
 | 8   | 0000102   | 人員管理     | 0        | 1       |
 | 16  | 0070101   | 類別維護     | 7        | 1       |
 | 17  | 0070102   | 議題維護     | 7        | 1       |
 | 410 | 0320101   | 銷貨檢索     | 32       | 1       |
 | 420 | 0320102   | 未完成訂單   | 32       | 1       |
 | 440 | 0320103   | 客戶檢索     | 32       | 1       |
 | 425 | 0320201   | 訂單資料檢核 | 32       | 2       |

 序號是依「原本的 FunctionNo 由小到大」排的。對照表**刻意寫死在腳本裡**，
 不用 ROW_NUMBER() 自動算——自動算的結果會隨資料變動，這種一次性改號要能
 逐列審閱、重跑結果一致。

 --------------------------------------------------------------------------
 動到哪幾張表
 --------------------------------------------------------------------------
 1. M_Function           FunctionNo     int -> varchar(8)，換新號
 2. M_Permission         FunctionNo     int -> varchar(8)，8 個換新號，其餘轉舊數字字串
 3. M_PermissionGroup    FunctionNo     int -> varchar(8)，同上
 4. M_PermissionLinkType **這張原本不在這個庫**，從 PRORIL_WEB 建過來（只收
                         2.0 這 8 個功能的細項），FunctionNo 直接建成 varchar(8)
 5. H_FileLink           LinkFunctionNo int -> varchar(8)，17 換成 0070102，
                         其餘（其他模組寫的）轉舊數字字串

 「其餘轉舊數字字串」是刻意保留的：那些 FunctionNo 屬於 2.0 還沒搬的模組，
 沒有新號可對。它們在 M_Function 裡沒有對應列，權限樹與側欄本來就會忽略。

 --------------------------------------------------------------------------
 與 PRORIL_WEB 的 schema 分岔（重要）
 --------------------------------------------------------------------------
 **PRORIL_WEB 完全不動**——1.0 站台還在用 int 的 FunctionNo，改下去會整個炸。
 所以這 5 張表的 FunctionNo 型別在兩個庫**永久不同**：

     PRORIL_WEB           int
     Proril_Sales_Center  varchar(8)

 後果是 database/Tables 底下的 .sql（DACPAC 正本，對齊的是 PRORIL_WEB）跟這個庫對不起來：

 （順帶一個踩過的坑：**不要在區塊註解裡寫出 `/` 加 `*` 的組合**，例如 Tables/(星號).sql。
 T-SQL 的區塊註解可以巢狀，那會多開一層註解、把後面的程式碼連同環境防呆一起吃掉，
 而且不會報錯到讓人警覺，只會冒一句 Missing end comment mark。）
   - `publish.ps1 -Environment snapshot` 會想把 varchar(8) 改回 int —— **不要套用**
   - `drift.ps1` 對 snapshot 會一直報這幾個欄位的差異 —— 屬預期，不是漏同步

 同樣的狀況先前已經有一次（中文欄位的 varchar/nvarchar 覆寫），
 見 PortingNotes.md「為什麼有 9 個欄位型別跟來源不一樣」。

 --------------------------------------------------------------------------
 執行方式
 --------------------------------------------------------------------------
   sqlcmd -S <host>,<port> -d Proril_Sales_Center -U <user> -P <pw> -C -f 65001 \
          -i FunctionNoFormatMigration.sql

 **這支不是冪等的**（型別轉換只能做一次），重跑會在第 1 段就偵測到已經是
 varchar 而直接跳出。要重來請先從 _bak_FunctionNo 那幾張備份表還原。
 腳本開頭會自動建備份表。
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
    RAISERROR('同一個 instance 上找不到 PRORIL_WEB，撈不到 M_PermissionLinkType。', 16, 1);
    SET NOEXEC ON;
END
GO

-- 已經轉過就不要再跑一次（型別轉換不可重入）
IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID('dbo.M_Function')
             AND name = 'FunctionNo'
             AND system_type_id = TYPE_ID('varchar'))
BEGIN
    RAISERROR('M_Function.FunctionNo 已經是 varchar，這支腳本已執行過。要重來請先從 _bak_FunctionNo 備份表還原。', 16, 1);
    SET NOEXEC ON;
END
GO

-- ---------------------------------------------------------------- 0. 備份

IF OBJECT_ID('dbo.M_Function_bak_FunctionNo', 'U') IS NOT NULL DROP TABLE dbo.M_Function_bak_FunctionNo;
IF OBJECT_ID('dbo.M_Permission_bak_FunctionNo', 'U') IS NOT NULL DROP TABLE dbo.M_Permission_bak_FunctionNo;
IF OBJECT_ID('dbo.M_PermissionGroup_bak_FunctionNo', 'U') IS NOT NULL DROP TABLE dbo.M_PermissionGroup_bak_FunctionNo;
IF OBJECT_ID('dbo.H_FileLink_bak_FunctionNo', 'U') IS NOT NULL DROP TABLE dbo.H_FileLink_bak_FunctionNo;

SELECT * INTO dbo.M_Function_bak_FunctionNo        FROM dbo.M_Function;
SELECT * INTO dbo.M_Permission_bak_FunctionNo      FROM dbo.M_Permission;
SELECT * INTO dbo.M_PermissionGroup_bak_FunctionNo FROM dbo.M_PermissionGroup;
SELECT * INTO dbo.H_FileLink_bak_FunctionNo        FROM dbo.H_FileLink;
PRINT '備份完成（_bak_FunctionNo）';
GO

-- ---------------------------------------------------------------- 1. 對照表

IF OBJECT_ID('tempdb..#Map') IS NOT NULL DROP TABLE #Map;
CREATE TABLE #Map (OldNo INT PRIMARY KEY, NewNo VARCHAR(8) NOT NULL, FunctionName NVARCHAR(20));

INSERT INTO #Map (OldNo, NewNo, FunctionName) VALUES
    (  1, '0000101', N'權限管理'),
    (  8, '0000102', N'人員管理'),
    ( 16, '0070101', N'類別維護'),
    ( 17, '0070102', N'議題維護'),
    (410, '0320101', N'銷貨檢索'),
    (420, '0320102', N'未完成訂單'),
    (440, '0320103', N'客戶檢索'),
    (425, '0320201', N'訂單資料檢核');

-- 對照表必須剛好蓋住 M_Function 現有的每一列，否則就是資料跟腳本對不上，直接停
IF EXISTS (SELECT 1 FROM dbo.M_Function f WHERE NOT EXISTS (SELECT 1 FROM #Map m WHERE m.OldNo = f.FunctionNo))
BEGIN
    RAISERROR('M_Function 裡有對照表沒涵蓋的 FunctionNo，請先確認資料與腳本的對照表一致。', 16, 1);
    SET NOEXEC ON;
END
GO

-- ---------------------------------------------------------------- 2. M_Function

ALTER TABLE dbo.M_Function ALTER COLUMN FunctionNo VARCHAR(8) NOT NULL;
GO

UPDATE f SET f.FunctionNo = m.NewNo
FROM dbo.M_Function f JOIN #Map m ON CONVERT(VARCHAR(8), m.OldNo) = f.FunctionNo;
PRINT 'M_Function 換號完成';
GO

-- ---------------------------------------------------------------- 3. M_Permission

ALTER TABLE dbo.M_Permission ALTER COLUMN FunctionNo VARCHAR(8) NOT NULL;
GO

UPDATE p SET p.FunctionNo = m.NewNo
FROM dbo.M_Permission p JOIN #Map m ON CONVERT(VARCHAR(8), m.OldNo) = p.FunctionNo;
PRINT 'M_Permission 換號完成（其餘列保留舊數字字串）';
GO

-- ---------------------------------------------------------------- 4. M_PermissionGroup

ALTER TABLE dbo.M_PermissionGroup ALTER COLUMN FunctionNo VARCHAR(8) NULL;
GO

UPDATE g SET g.FunctionNo = m.NewNo
FROM dbo.M_PermissionGroup g JOIN #Map m ON CONVERT(VARCHAR(8), m.OldNo) = g.FunctionNo;
PRINT 'M_PermissionGroup 換號完成（其餘列保留舊數字字串）';
GO

-- ---------------------------------------------------------------- 5. M_PermissionLinkType

/*
  這張表原本只在 PRORIL_WEB（1.0 的 FileQueryApiController 還會 Add，所以 2.0 一直唯讀）。
  但 FunctionNo 改號之後，跨庫已經對不起來了——舊庫是 int 17，新庫是 '0070102'，
  權限樹第三層與欄位級權限會整個斷掉。所以這裡把 **2.0 這 8 個功能的細項**搬進來。

  1.0 之後在舊庫新增的細項不會自動同步過來，這點跟 M_Function 一樣，
  要靠人重跑這一段（或之後把檔案檢索也搬過來）。
*/
IF OBJECT_ID('dbo.M_PermissionLinkType', 'U') IS NOT NULL DROP TABLE dbo.M_PermissionLinkType;

CREATE TABLE [dbo].[M_PermissionLinkType] (
    [ID]               INT          IDENTITY (1, 1) NOT NULL,
    [FunctionNo]       VARCHAR (8)  NOT NULL,
    [LinkType]         TINYINT      NOT NULL,
    [LinkTypeName]     VARCHAR (50) NOT NULL,
    [ParentLinkTypeID] INT          NULL,
    [Creator]          VARCHAR (10) NULL,
    [CreateTime]       DATETIME     NULL,
    [Modifier]         VARCHAR (10) NULL,
    [ModifyTime]       DATETIME     NULL,
    CONSTRAINT [PK_M_PermissionLinkType] PRIMARY KEY CLUSTERED ([ID] ASC)
);

SET IDENTITY_INSERT dbo.M_PermissionLinkType ON;

INSERT INTO dbo.M_PermissionLinkType
    (ID, FunctionNo, LinkType, LinkTypeName, ParentLinkTypeID, Creator, CreateTime, Modifier, ModifyTime)
SELECT t.ID, m.NewNo, t.LinkType, t.LinkTypeName, t.ParentLinkTypeID,
       t.Creator, t.CreateTime, t.Modifier, t.ModifyTime
FROM [PRORIL_WEB].[dbo].[M_PermissionLinkType] t
JOIN #Map m ON m.OldNo = t.FunctionNo;

SET IDENTITY_INSERT dbo.M_PermissionLinkType OFF;

CREATE UNIQUE NONCLUSTERED INDEX [NonClusteredIndex-20231116-083304]
    ON [dbo].[M_PermissionLinkType]([FunctionNo] ASC, [LinkType] ASC, [ParentLinkTypeID] ASC);

PRINT 'M_PermissionLinkType 已建立並換號';
GO

-- ---------------------------------------------------------------- 6. H_FileLink

/*
  LinkFunctionNo 有 DEFAULT 約束，ALTER COLUMN 前要先拆掉，換完型別再建回去。
  預設值原本是 0（代表「沒有指定模組」），轉成字串後維持 '0' 這個語意，
  不要補成 '0000000'——那會看起來像一個合法的 SystemNo=0/GroupNo=0 功能。
*/
DECLARE @df SYSNAME;
SELECT @df = dc.name
FROM sys.default_constraints dc
JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id
WHERE dc.parent_object_id = OBJECT_ID('dbo.H_FileLink') AND c.name = 'LinkFunctionNo';

IF @df IS NOT NULL EXEC('ALTER TABLE dbo.H_FileLink DROP CONSTRAINT [' + @df + ']');
GO

ALTER TABLE dbo.H_FileLink ALTER COLUMN LinkFunctionNo VARCHAR(8) NOT NULL;
GO

UPDATE h SET h.LinkFunctionNo = m.NewNo
FROM dbo.H_FileLink h JOIN #Map m ON CONVERT(VARCHAR(8), m.OldNo) = h.LinkFunctionNo;

ALTER TABLE dbo.H_FileLink
    ADD CONSTRAINT DF_H_FileLink_LinkFunctionNo DEFAULT ('0') FOR LinkFunctionNo;
PRINT 'H_FileLink 換號完成（其他模組的列保留舊數字字串）';
GO

-- ---------------------------------------------------------------- 7. 驗證

PRINT '--- M_Function ---';
SELECT FunctionNo, FunctionName, SystemNo, GroupNo, GroupName, aStatus
FROM dbo.M_Function ORDER BY FunctionNo;

PRINT '--- M_Permission 依 FunctionNo（新號在前）---';
SELECT FunctionNo, COUNT(*) AS c FROM dbo.M_Permission
GROUP BY FunctionNo ORDER BY CASE WHEN LEN(FunctionNo) = 7 THEN 0 ELSE 1 END, FunctionNo;

PRINT '--- M_PermissionLinkType ---';
SELECT FunctionNo, LinkType, LinkTypeName FROM dbo.M_PermissionLinkType ORDER BY FunctionNo, LinkType;

PRINT '--- H_FileLink 依 LinkFunctionNo ---';
SELECT LinkFunctionNo, COUNT(*) AS c FROM dbo.H_FileLink GROUP BY LinkFunctionNo ORDER BY LinkFunctionNo;

/*
  漏改檢查：M_Permission / M_PermissionGroup / H_FileLink 裡不該再出現任何
  「對照表涵蓋得到的舊號」。有列出來就是哪一段 UPDATE 沒跑到。
*/
PRINT '--- 漏改檢查（應該沒有任何列）---';
SELECT 'M_Permission' AS t, p.FunctionNo FROM dbo.M_Permission p
JOIN #Map m ON CONVERT(VARCHAR(8), m.OldNo) = p.FunctionNo
UNION ALL
SELECT 'M_PermissionGroup', g.FunctionNo FROM dbo.M_PermissionGroup g
JOIN #Map m ON CONVERT(VARCHAR(8), m.OldNo) = g.FunctionNo
UNION ALL
SELECT 'H_FileLink', h.LinkFunctionNo FROM dbo.H_FileLink h
JOIN #Map m ON CONVERT(VARCHAR(8), m.OldNo) = h.LinkFunctionNo;
GO

SET NOEXEC OFF;
GO
