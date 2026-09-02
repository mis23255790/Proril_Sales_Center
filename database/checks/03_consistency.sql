/*
    業務一致性檢查 —— 這一組價值最高。

    這裡抓的不是「資料庫壞掉」，而是「資料合法但畫面會出錯」。
    最典型的就是「議題在 DB 裡好好的，但議題列表就是看不到它」。

    為什麼會看不到？
    ----------------
    WorkProcessApiController.getSOPList() 組列表時用了兩個 **inner join**
    （沒有 into ... DefaultIfEmpty()）：

        join user        in musers_list on wp.Creator equals user.Account
        join modify_user in musers_list on wpdetails?.FirstOrDefault()?.Modifier
                                          equals modify_user.Account

    這代表只要下面任何一條成立，整張議題就會從列表上消失，而且不會有錯誤訊息：

        a. Creator 不在 M_User（離職刪帳號、或 Creator 帶了尾端空白）
        b. 最新一筆進度的 Modifier 不在 M_User
        c. 這張議題「一筆有效進度都沒有」
           —— FirstOrDefault() 回 null，null 配不到任何 Account

    (c) 尤其容易發生：新建的議題在還沒寫第一則進度之前就是這個狀態。

    而且這些 join 是在 .ToList() 之後做的（LINQ to Objects），
    `equals` 不像 SQL 會忽略尾端空白 —— 這也是為什麼 01_format 要抓空白。

    輸出契約：chk / severity / ident / detail 四欄，回 0 列代表通過。
*/
SET NOCOUNT ON;

WITH valid_wp AS (
    SELECT ID, LTRIM(RTRIM(WPNo)) AS WPNo, LTRIM(RTRIM(ISNULL(Creator, ''))) AS Creator,
           SopTitle, PubFlag, FinFlag
    FROM dbo.D_WorkProcess
    WHERE aStatus = 'Y'
),
valid_user AS (
    SELECT LTRIM(RTRIM(ISNULL(Account, ''))) AS Account FROM dbo.M_User
),
latest_detail AS (
    -- 每張議題「最後修改」的那一則進度，對應 dwpdetail_list 的 OrderByDescending(ModiTime).FirstOrDefault()
    SELECT WPNo, Modifier, ModiTime FROM (
        SELECT LTRIM(RTRIM(d.WPNo)) AS WPNo,
               LTRIM(RTRIM(ISNULL(d.Modifier, ''))) AS Modifier,
               d.ModiTime,
               ROW_NUMBER() OVER (PARTITION BY LTRIM(RTRIM(d.WPNo)) ORDER BY d.ModiTime DESC, d.ID DESC) AS rn
        FROM dbo.D_WorkProcessDetail d
        WHERE d.aStatus = 'Y'
    ) t WHERE rn = 1
)

SELECT chk, severity, ident, detail FROM (

    -- (a) Creator 不在 M_User → 整張議題不會出現在議題列表
    SELECT 'invisible_creator_missing' AS chk, 'ERROR' AS severity,
           'WPNo=' + w.WPNo AS ident,
           'Creator=[' + w.Creator + '] 不在 M_User，此議題不會出現在列表' AS detail
    FROM valid_wp w
    WHERE NOT EXISTS (SELECT 1 FROM valid_user u WHERE u.Account = w.Creator)

    -- (b) 最新一筆進度的 Modifier 不在 M_User → 同樣整張消失
    UNION ALL
    SELECT 'invisible_modifier_missing', 'ERROR',
           'WPNo=' + w.WPNo,
           'Modifier=[' + ld.Modifier + '] 不在 M_User，此議題不會出現在列表'
    FROM valid_wp w
    JOIN latest_detail ld ON ld.WPNo = w.WPNo
    WHERE NOT EXISTS (SELECT 1 FROM valid_user u WHERE u.Account = ld.Modifier)

    -- (c) 完全沒有有效進度 → FirstOrDefault() 是 null，inner join 配不到，整張消失
    UNION ALL
    SELECT 'invisible_no_detail', 'ERROR',
           'WPNo=' + w.WPNo,
           'SopTitle=' + ISNULL(w.SopTitle, '') + '：沒有任何有效進度，此議題不會出現在列表'
    FROM valid_wp w
    WHERE NOT EXISTS (SELECT 1 FROM latest_detail ld WHERE ld.WPNo = w.WPNo)

    /*
        非 admin 使用者要在列表看到議題，D_WorkProcessPermission 得有一列
        EnableType 是 10(編輯) 或 20(公開)，帳號是本人或 '000000'(全體)。
        存檔流程會補寫 '000000'，少了這一步就只有 admin 看得到。
    */
    UNION ALL
    SELECT 'no_edit_permission', 'ERROR',
           'WPNo=' + w.WPNo,
           'SopTitle=' + ISNULL(w.SopTitle, '') + '：沒有任何 EnableType in (10,20) 的權限列，非 admin 看不到'
    FROM valid_wp w
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.D_WorkProcessPermission p
        WHERE LTRIM(RTRIM(p.WPNo)) = w.WPNo AND p.EnableType IN (10, 20))

    /*
        UploadFile 與 RenameFile 是兩串分號字串，靠 **索引** 對齊。
        段數不一致就對不回原始檔名，下載會抓錯檔或直接失敗。
    */
    UNION ALL
    SELECT 'attach_name_mismatch', 'ERROR',
           'D_WorkProcessDetail.ID=' + CAST(d.ID AS varchar(20)),
           'WPNo=' + d.WPNo + ' SNo=' + d.SNo
           + ' UploadFile 段數=' + CAST(LEN(d.UploadFile) - LEN(REPLACE(d.UploadFile, ';', '')) + 1 AS varchar(10))
           + ' RenameFile 段數=' + CAST(LEN(ISNULL(d.RenameFile, '')) - LEN(REPLACE(ISNULL(d.RenameFile, ''), ';', '')) + 1 AS varchar(10))
    FROM dbo.D_WorkProcessDetail d
    WHERE d.aStatus = 'Y' AND ISNULL(d.UploadFile, '') <> ''
      AND (LEN(d.UploadFile) - LEN(REPLACE(d.UploadFile, ';', '')))
          <> (LEN(ISNULL(d.RenameFile, '')) - LEN(REPLACE(ISNULL(d.RenameFile, ''), ';', '')))

    -- 有 RenameFile 卻沒有 UploadFile：附件在 zip 裡但畫面上列不出來
    UNION ALL
    SELECT 'attach_orphan_rename', 'WARN',
           'D_WorkProcessDetail.ID=' + CAST(d.ID AS varchar(20)),
           'WPNo=' + d.WPNo + ' SNo=' + d.SNo + ' 有 RenameFile 但 UploadFile 是空的'
    FROM dbo.D_WorkProcessDetail d
    WHERE d.aStatus = 'Y' AND ISNULL(d.RenameFile, '') <> '' AND ISNULL(d.UploadFile, '') = ''

    -- 主題空白：列表上會顯示「（未命名議題）」，通常是存到一半中斷
    UNION ALL
    SELECT 'empty_title', 'WARN',
           'WPNo=' + w.WPNo,
           '主題是空的'
    FROM valid_wp w
    WHERE LTRIM(RTRIM(ISNULL(w.SopTitle, ''))) = ''

    -- 沒有掛任何客戶：不算錯，但議題是「客戶導向」的，數量過多代表流程沒被遵守
    UNION ALL
    SELECT 'no_customer', 'WARN',
           'WPNo=' + w.WPNo,
           'SopTitle=' + ISNULL(w.SopTitle, '') + '：沒有掛任何客戶'
    FROM valid_wp w
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.D_WorkProcessCustomer c
        WHERE LTRIM(RTRIM(c.WPNo)) = w.WPNo AND c.aStatus = 'Y'
          AND ISNULL(c.CustomerNo, '') <> '')

) x
ORDER BY chk, ident;
