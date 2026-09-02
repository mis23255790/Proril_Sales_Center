/*
    參照完整性檢查。

    為什麼要自己查而不是靠 FK
    --------------------------
    這些表目前沒有 FK，而且用的是「軟刪除」——  aStatus = 'N' 代表
    「這筆已失效／已不在集合裡」，不是「已完成」。所以光有 FK 也不夠，
    還要驗「參照到的那一列是不是還有效」。

    比對一律兩邊都 LTRIM(RTRIM())：這些欄位是 varchar 且常帶 ERP 來的尾端空白。

    輸出契約：chk / severity / ident / detail 四欄，回 0 列代表通過。
*/
SET NOCOUNT ON;

SELECT chk, severity, ident, detail FROM (

    -- 進度掛在不存在（或已失效）的議題底下
    SELECT 'orphan_detail' AS chk, 'ERROR' AS severity,
           'D_WorkProcessDetail.ID=' + CAST(d.ID AS varchar(20)) AS ident,
           'WPNo=' + d.WPNo + ' SNo=' + d.SNo AS detail
    FROM dbo.D_WorkProcessDetail d
    WHERE d.aStatus = 'Y'
      AND NOT EXISTS (SELECT 1 FROM dbo.D_WorkProcess w
                      WHERE LTRIM(RTRIM(w.WPNo)) = LTRIM(RTRIM(d.WPNo)) AND w.aStatus = 'Y')

    UNION ALL
    SELECT 'orphan_search', 'ERROR',
           'D_WorkProcessSearch.ID=' + CAST(s.ID AS varchar(20)),
           'WPNo=' + s.WPNo
    FROM dbo.D_WorkProcessSearch s
    WHERE s.aStatus = 'Y'
      AND NOT EXISTS (SELECT 1 FROM dbo.D_WorkProcess w
                      WHERE LTRIM(RTRIM(w.WPNo)) = LTRIM(RTRIM(s.WPNo)) AND w.aStatus = 'Y')

    UNION ALL
    SELECT 'orphan_customer', 'ERROR',
           'D_WorkProcessCustomer.ID=' + CAST(c.ID AS varchar(20)),
           'WPNo=' + c.WPNo
    FROM dbo.D_WorkProcessCustomer c
    WHERE c.aStatus = 'Y'
      AND NOT EXISTS (SELECT 1 FROM dbo.D_WorkProcess w
                      WHERE LTRIM(RTRIM(w.WPNo)) = LTRIM(RTRIM(c.WPNo)) AND w.aStatus = 'Y')

    -- 議題掛的客戶不在 CRM_Customer（或該客戶已失效）→ 列表的「客戶別」欄會空白
    UNION ALL
    SELECT 'customer_not_found', 'ERROR',
           'D_WorkProcessCustomer.ID=' + CAST(c.ID AS varchar(20)),
           'WPNo=' + c.WPNo + ' CustomerNo=[' + ISNULL(c.CustomerNo, '') + ']'
    FROM dbo.D_WorkProcessCustomer c
    WHERE c.aStatus = 'Y' AND ISNULL(c.CustomerNo, '') <> ''
      AND NOT EXISTS (SELECT 1 FROM dbo.CRM_Customer m
                      WHERE LTRIM(RTRIM(m.CustomerNo)) = LTRIM(RTRIM(c.CustomerNo)) AND m.aStatus = 'Y')

    -- 議題掛的關鍵字指到不存在／已失效的 phrase → 列表的「類別」欄會莫名空白
    UNION ALL
    SELECT 'phrase_not_found', 'ERROR',
           'D_WorkProcessSearch.ID=' + CAST(s.ID AS varchar(20)),
           'WPNo=' + s.WPNo + ' Type=' + ISNULL(s.PhraseType, '') + ' Code=' + ISNULL(s.PhraseCode, '')
    FROM dbo.D_WorkProcessSearch s
    WHERE s.aStatus = 'Y'
      AND NOT EXISTS (SELECT 1 FROM dbo.M_WorkProcessPhrase p
                      WHERE LTRIM(RTRIM(p.PhraseCode)) = LTRIM(RTRIM(s.PhraseCode))
                        AND LTRIM(RTRIM(p.PhraseType)) = LTRIM(RTRIM(s.PhraseType))
                        AND p.aStatus = 'Y')

    /*
        SaveKindData 是用 (PhraseType, PhraseCode) 判斷「新增還是更新」。
        撞號的話存檔會蓋掉別人的關鍵字，而且列表上會看到兩筆同號不同名。
    */
    UNION ALL
    SELECT 'dup_phrase_key', 'ERROR',
           'M_WorkProcessPhrase Type=' + LTRIM(RTRIM(ISNULL(PhraseType, ''))) + ' Code=' + LTRIM(RTRIM(ISNULL(PhraseCode, ''))),
           'count=' + CAST(COUNT(*) AS varchar(10))
    FROM dbo.M_WorkProcessPhrase
    WHERE aStatus = 'Y'
    GROUP BY LTRIM(RTRIM(ISNULL(PhraseType, ''))), LTRIM(RTRIM(ISNULL(PhraseCode, '')))
    HAVING COUNT(*) > 1

    /*
        GetSOPOrder 對同一個 WPNo 只取 FirstOrDefault()。
        重複的話另一筆會被無聲忽略，改了也存不進正確的那一列。
    */
    UNION ALL
    SELECT 'dup_wpno', 'ERROR',
           'D_WorkProcess WPNo=' + LTRIM(RTRIM(WPNo)),
           'count=' + CAST(COUNT(*) AS varchar(10))
    FROM dbo.D_WorkProcess
    WHERE aStatus = 'Y'
    GROUP BY LTRIM(RTRIM(WPNo))
    HAVING COUNT(*) > 1

    /*
        D_WorkProcessDetail 上有 (WPNo, SNo) 的 unique index
        （NonClusteredIndex-20231221-145816）。這條是驗「正式區真的有那個 index」——
        DACPAC 只管欄位定義，index 漏掉不會有人發現，直到出現重複的進度。
    */
    UNION ALL
    SELECT 'dup_detail_key', 'ERROR',
           'D_WorkProcessDetail WPNo=' + LTRIM(RTRIM(WPNo)) + ' SNo=' + LTRIM(RTRIM(SNo)),
           'count=' + CAST(COUNT(*) AS varchar(10))
    FROM dbo.D_WorkProcessDetail
    WHERE aStatus = 'Y'
    GROUP BY LTRIM(RTRIM(WPNo)), LTRIM(RTRIM(SNo))
    HAVING COUNT(*) > 1

) x
ORDER BY chk, ident;
