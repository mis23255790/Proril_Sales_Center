# 2026-10-05：1.0 有業務檢索權限的人，在 2.0 正式區也開通

腳本：`01-grant-sales-search-from-1.0.sql`（在 `Proril_Sales_Center` 上執行，可重跑）。
寫法比照 `prod-migration-2026-10-02/01-grant-sales-issue-from-1.0.sql`。

| 1.0 FunctionNo / LinkType | 2.0 PermissionKey |
|---|---|
| 410 / ≤1 | `salesSearch.mixSalesShipping`（銷貨檢索） |
| 410 / 100 | `salesSearch.mixSalesShipping.viewAmount` |
| 420 / ≤1 | `salesSearch.queryUnFinish`（未完成訂單） |
| 420 / 100 | `salesSearch.queryUnFinish.viewAmount` |
| 425 / ≤1 | `salesSearch.orderInfoVerify`（訂單資料檢核） |
| 425 / 100 | `salesSearch.orderInfoVerify.viewAmount` |
| 440 / ≤1 | `salesSearch.customQuery`（客戶檢索） |
| 441 | **不轉**（見下） |

- 來源是**當下的** `PRORIL_WEB.dbo.M_Permission`，有效權限照 1.0 算「本人 ∪ `000000`」。
- **441 客戶相關資訊不轉**：2.0 沒有自己的 key（頁面靠 `customQuery`／`mixSalesShipping` 進去），
  而且正式區 1.0 的 `000000` 有 441，照算會讓所有帳號都拿到客戶檢索（含編輯內網客戶）。
  腳本只在分布表列出筆數。
- **顯示金額（LinkType 100）連帶開頁面**：2.0 規則是細項一定帶祖先，1.0 只有金額、沒有頁面權限的人
  也照開頁面；腳本會先列出這些人。
- 扣掉 2.0 已有效擁有的 key（所屬角色 ∪ everyone，superAdmin 略過），依 key 組合分群建
  「業務檢索-NN」角色（`salesSearchNN`，`Sort` 300+NN）並掛成員，角色權限補上分組／模組祖先。只加不刪。
- `@EnableModule` 預設 `0`：只列出 `salesSearch` 節點狀態。若模組或分組是 `'N'`，
  改成 `1` 會一併改回 `'Y'`，不改回來角色勾了也進不去。
- 2.0 `M_User` 沒有的帳號不會開通，腳本會列出來。

## 跑法

要同時讀 `PRORIL_WEB`、寫 `Proril_Sales_Center`，**`proril_sales_center` 帳號不行**
（對 `PRORIL_WEB` 沒有 SELECT），要用兩邊都有權限的帳號。

1. 預設 `@Execute = 0`，先跑一次 dry-run（最後 ROLLBACK），檢查輸出：
   「對不到 2.0 key 的」、「權限樹找不到的對照 key」與最後的「驗證」都要是 0 筆；
   「業務檢索節點狀態」全部是 `Y`（不是的話把 `@EnableModule` 改成 `1`）。
2. 確認後把 `@Execute` 改成 `1` 再跑。
3. 上線後在「權限管理」把 `業務檢索-NN` 改名或合併。

```powershell
sqlcmd -S 192.168.1.142,51002 -U <帳號> -d Proril_Sales_Center -C -f 65001 -i 01-grant-sales-search-from-1.0.sql
```

## 執行紀錄

- 語法：已用 `SET PARSEONLY ON` 對 50002 驗過（2026-10-05）。
- 51002（正式區）：**尚未執行**（dry-run 也還沒跑）。
