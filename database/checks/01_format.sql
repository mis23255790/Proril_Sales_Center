/*
    格式檢查：補零與前後空白。

    為什麼重要
    ----------
    1. WPNo 是 6 碼左補零字串、SNo 是 4 碼。後端多數 API 會自己補
       （transferWpNoToPadding / $"{nSno:0000}"），但 **GetEditorText 不會**
       —— 它直接 `o.Sno == SNo` 比對。格式一跑掉，那筆進度就再也讀不到內文。
    2. ERP / 舊系統同步進來的字串常帶尾端空白。C# 端把資料撈成 List 之後是
       LINQ to Objects，`==` 不會像 SQL 那樣忽略尾端空白，會整批配對不到。

    T-SQL 陷阱
    ----------
    SQL 的 `=` 與 `<>` 會忽略尾端空白：`'abc ' = 'abc'` 是 TRUE。
    所以 **不能** 用 `col <> LTRIM(RTRIM(col))` 抓尾端空白，永遠抓不到。
    要用 DATALENGTH 比長度，或用 LIKE '%[^0-9]%' 抓非數字字元。

    輸出契約：chk / severity / ident / detail 四欄，回 0 列代表通過。
*/
SET NOCOUNT ON;

SELECT chk, severity, ident, detail FROM (

    -- WPNo 必須剛好 6 個字元且全為數字
    SELECT 'wpno_format' AS chk, 'ERROR' AS severity,
           'D_WorkProcess.ID=' + CAST(ID AS varchar(20)) AS ident,
           'WPNo=[' + WPNo + '] len=' + CAST(DATALENGTH(WPNo) AS varchar(10)) AS detail
    FROM dbo.D_WorkProcess
    WHERE aStatus = 'Y' AND (DATALENGTH(WPNo) <> 6 OR WPNo LIKE '%[^0-9]%')

    UNION ALL
    SELECT 'wpno_format', 'ERROR',
           'D_WorkProcessDetail.ID=' + CAST(ID AS varchar(20)),
           'WPNo=[' + WPNo + ']'
    FROM dbo.D_WorkProcessDetail
    WHERE aStatus = 'Y' AND (DATALENGTH(WPNo) <> 6 OR WPNo LIKE '%[^0-9]%')

    UNION ALL
    SELECT 'wpno_format', 'ERROR',
           'D_WorkProcessSearch.ID=' + CAST(ID AS varchar(20)),
           'WPNo=[' + WPNo + ']'
    FROM dbo.D_WorkProcessSearch
    WHERE aStatus = 'Y' AND (DATALENGTH(WPNo) <> 6 OR WPNo LIKE '%[^0-9]%')

    UNION ALL
    SELECT 'wpno_format', 'ERROR',
           'D_WorkProcessCustomer.ID=' + CAST(ID AS varchar(20)),
           'WPNo=[' + WPNo + ']'
    FROM dbo.D_WorkProcessCustomer
    WHERE aStatus = 'Y' AND (DATALENGTH(WPNo) <> 6 OR WPNo LIKE '%[^0-9]%')

    -- SNo 必須剛好 4 個字元且全為數字。GetEditorText 不補零，這裡壞掉就讀不到內文
    UNION ALL
    SELECT 'sno_format', 'ERROR',
           'D_WorkProcessDetail.ID=' + CAST(ID AS varchar(20)),
           'WPNo=' + WPNo + ' SNo=[' + SNo + '] len=' + CAST(DATALENGTH(SNo) AS varchar(10))
    FROM dbo.D_WorkProcessDetail
    WHERE aStatus = 'Y' AND (DATALENGTH(SNo) <> 4 OR SNo LIKE '%[^0-9]%')

    -- 帳號 / 客戶編號 / 關鍵字代碼帶前後空白：C# 端 LINQ to Objects 會配對不到
    UNION ALL
    SELECT 'trailing_space', 'ERROR',
           'D_WorkProcess.ID=' + CAST(ID AS varchar(20)),
           'Creator=[' + ISNULL(Creator, '') + ']'
    FROM dbo.D_WorkProcess
    WHERE aStatus = 'Y' AND Creator IS NOT NULL
      AND DATALENGTH(Creator) <> DATALENGTH(LTRIM(RTRIM(Creator)))

    UNION ALL
    SELECT 'trailing_space', 'ERROR',
           'D_WorkProcessCustomer.ID=' + CAST(ID AS varchar(20)),
           'CustomerNo=[' + ISNULL(CustomerNo, '') + ']'
    FROM dbo.D_WorkProcessCustomer
    WHERE aStatus = 'Y' AND CustomerNo IS NOT NULL
      AND DATALENGTH(CustomerNo) <> DATALENGTH(LTRIM(RTRIM(CustomerNo)))

    UNION ALL
    SELECT 'trailing_space', 'ERROR',
           'M_WorkProcessPhrase.ID=' + CAST(ID AS varchar(20)),
           'PhraseType=[' + ISNULL(PhraseType, '') + '] PhraseCode=[' + ISNULL(PhraseCode, '') + ']'
    FROM dbo.M_WorkProcessPhrase
    WHERE aStatus = 'Y'
      AND (DATALENGTH(ISNULL(PhraseCode, '')) <> DATALENGTH(LTRIM(RTRIM(ISNULL(PhraseCode, ''))))
        OR DATALENGTH(ISNULL(PhraseType, '')) <> DATALENGTH(LTRIM(RTRIM(ISNULL(PhraseType, '')))))

    UNION ALL
    SELECT 'trailing_space', 'ERROR',
           'D_WorkProcessSearch.ID=' + CAST(ID AS varchar(20)),
           'PhraseType=[' + ISNULL(PhraseType, '') + '] PhraseCode=[' + ISNULL(PhraseCode, '') + ']'
    FROM dbo.D_WorkProcessSearch
    WHERE aStatus = 'Y'
      AND (DATALENGTH(ISNULL(PhraseCode, '')) <> DATALENGTH(LTRIM(RTRIM(ISNULL(PhraseCode, ''))))
        OR DATALENGTH(ISNULL(PhraseType, '')) <> DATALENGTH(LTRIM(RTRIM(ISNULL(PhraseType, '')))))

    -- aStatus 只允許 Y / N。DB 是 case-sensitive collation，小寫 y 不等於 Y
    UNION ALL
    SELECT 'astatus_domain', 'ERROR',
           'D_WorkProcess.ID=' + CAST(ID AS varchar(20)),
           'aStatus=[' + ISNULL(aStatus, '(null)') + ']'
    FROM dbo.D_WorkProcess
    WHERE aStatus IS NULL OR aStatus NOT IN ('Y', 'N')

    UNION ALL
    SELECT 'astatus_domain', 'ERROR',
           'D_WorkProcessDetail.ID=' + CAST(ID AS varchar(20)),
           'aStatus=[' + ISNULL(aStatus, '(null)') + ']'
    FROM dbo.D_WorkProcessDetail
    WHERE aStatus IS NULL OR aStatus NOT IN ('Y', 'N')

) x
ORDER BY chk, ident;
