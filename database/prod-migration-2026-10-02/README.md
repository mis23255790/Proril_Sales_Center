# 2026-10-02：1.0 有業務議題權限的人，在 2.0 正式區也開通

腳本：`01-grant-sales-issue-from-1.0.sql`（在 `Proril_Sales_Center` 上執行，可重跑）。

- 來源是**當下的** `PRORIL_WEB.dbo.M_Permission`（FunctionNo 16 類別維護／17 議題維護，
  含 SOP-新增 LinkType 10／SOP-公開 LinkType 20），有效權限照 1.0 算「本人 ∪ `000000`」。
- 扣掉 2.0 已有效擁有的 key（所屬角色 ∪ everyone，superAdmin 略過），依 key 組合分群建
  「業務議題-NN」角色（`salesIssueNN`，`Sort` 200+NN）並掛成員。只加不刪。
- `@EnableModule = 1`：`salesIssue` 模組與 `grpIssue`／`grpBasic` 分組改回 `aStatus = 'Y'`
  （2026-09-30 對齊 Dev 時設成 `'N'`，不改回來角色勾了也進不去）。
- 2.0 `M_User` 沒有的帳號不會開通，腳本會列出來。

## 跑法

要同時讀 `PRORIL_WEB`、寫 `Proril_Sales_Center`，**`proril_sales_center` 帳號不行**
（對 `PRORIL_WEB` 沒有 SELECT），要用兩邊都有權限的帳號。

1. 預設 `@Execute = 0`，先跑一次 dry-run（最後 ROLLBACK），檢查輸出：
   「對不到 2.0 key 的」與最後的「驗證」都要是 0 筆。
2. 確認後把 `@Execute` 改成 `1` 再跑。
3. 上線後在「權限管理」把 `業務議題-NN` 改名或合併。

```powershell
sqlcmd -S 192.168.1.142,51002 -U <帳號> -d Proril_Sales_Center -C -f 65001 -i 01-grant-sales-issue-from-1.0.sql
```

## 執行紀錄

- 50002（測試區）dry-run（2026-10-02）：會建 4 個角色／9 筆角色權限／8 位成員，
  驗證 0 筆，已 ROLLBACK，**測試區資料沒動**。另有 `T11503` 在 1.0 有權限但 2.0 沒帳號。
- 51002（正式區）：**尚未執行**。
