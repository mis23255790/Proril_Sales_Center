-- M_Department：方向與其他腳本相反 —— 這次是把 51002 已存在的表搭一份回 50002，
-- 讓兩邊 Proril_Sales_Center 的 table 清單一致（不是 PRORIL_WEB -> Proril_Sales_Center）。
-- 背景見 database/PortingNotes.md「M_Department：兩邊 Proril_Sales_Center 快照對齊」。
-- schema 與 database/Tables/M_Department.sql 一致（含 PK 名稱）。

IF OBJECT_ID('dbo.M_Department') IS NULL
BEGIN
    CREATE TABLE dbo.[M_Department] (
        [ID] int IDENTITY(1,1) NOT NULL,
        [DepCode] varchar(10) NOT NULL,
        [DepName] varchar(40) NOT NULL,
        [DepLeader] varchar(10) NULL,
        [Directions] varchar(MAX) NULL,
        [DepLevel] int NULL,
        [ParentsDep] varchar(10) NULL,
        [OrgChartFlag] bit NULL DEFAULT ((1)),
        [Horqueue] int NULL,
        [IsEnable] bit NOT NULL DEFAULT ((1)),
        [DepGroup] int NOT NULL
    );
    ALTER TABLE dbo.[M_Department] ADD CONSTRAINT [PK__M_Depart__3214EC2799095914] PRIMARY KEY CLUSTERED ([ID]);
END
GO
