# 2026-09-30：51002 Proril_Sales_Center 補上 RBAC 與欄位對齊

比對 50002（Dev）與 51002（Prod）兩邊 `Proril_Sales_Center` 的物件、欄位、約束、
View／SP 定義（`sys.sql_modules` 定義文字 SHA2 hash）與權限資料的結果與處理方式。

## 比對結果

| 項目 | 50002 | 51002 | 處理 |
|---|---|---|---|
| View / SP / 函式定義 | — | 全部一致 | 不用動 |
| 資料庫定序 | `Chinese_Taiwan_Stroke_BIN` | 同左，逐欄也一致 | 不用動 |
| RBAC | `RBAC_Permission` 樹 + 3 張角色表 | 還是 `M_PermissionDef`，沒有 `RBAC_*` | **01 + 既有腳本 + 02** |
| `M_Permission.FunctionNo` | AAABBCC，`PermissionKey` 已回填 | 801 列全是舊 int 號，`PermissionKey` 全 NULL | **01** |
| `M_PermissionLinkType` / `H_FileLink` | 已換號 | 舊號（被 PRORIL_WEB 資料重灌過） | **01** |
| 權限樹節點 `aStatus` | `salesIssue` 整棵、`system.groupPermission` = N | — | **02** |
| 業務議題表欄位 | nvarchar 覆寫 + 預設值 | PRORIL_WEB 原型別；`SopTitle` NOT NULL | **03** |
| `M_User.Password` | 全 NULL（備份 `M_User_bak_Password`） | 46 列有值 | **04** |
| `H_FileLink.FilePath` | varchar(100) | varchar(255) | 51002 較寬，保留 |
| `COP_CheckRule.testDacPak` | 有 | 無 | DACPAC 測試殘留，不搬 |
| `M_Function` | 多 `0000103`、`0320101` = N | 8 列 | 應用層已不讀，不處理 |
| `M_System.ImagePath` / `aStatus` | 測試區圖示；`7` = N | 正式區 logo | `ImagePath` 本來就是用來分辨正式／測試區，**不同步** |
| PK / DF 約束名稱 | 系統自動命名 | 系統自動命名 | 不影響功能 |

51002 有 `*_bak_FunctionNo` 備份表、`M_Function` 也是新格式，代表 `FunctionNoFormatMigration.sql`
當初跑過，但之後 `M_Permission` 等表又被 PRORIL_WEB 資料重灌、換號被蓋掉。那支腳本已不能重跑
（偵測到 `M_Function` 是 varchar 就停，且要讀 PRORIL_WEB），所以用 `01` 只補換號。

## 角色來源

採「先轉換 51002 的 `M_Permission`」：51002 依自己的個人權限自動歸類角色，
**不複製** 50002 手動建的 `role01`～`role04`（50002 的成員有不少是測試帳號，51002 沒有）。
2026-09-30 對 51002 的唯讀模擬結果：

- `superAdmin`：`M_User.IsAdmin = 1` 的 10 人
- `everyone`：無權限（51002 的 `000000` 只有 1.0 功能 `441`，不在 2.0）
- `移轉角色-01`～`11`：共 15 個帳號

上線後請在「權限管理」把移轉角色改名或合併。

## 執行順序

全部用 `proril_sales_center` 帳號、`-f 65001`（腳本有中文字面值）：

```powershell
$srv = '192.168.1.142,51002'
sqlcmd -S $srv -U proril_sales_center -d Proril_Sales_Center -C -f 65001 -i prod-migration-2026-09-30\01-remap-functionno.sql
sqlcmd -S $srv -U proril_sales_center -d Proril_Sales_Center -C -f 65001 -i PermissionDefObjectsMigration.sql
.\scripts\run-objects-migration.ps1 -Script RbacObjectsMigration.sql -Environment snapshot-prod -Execute
sqlcmd -S $srv -U proril_sales_center -d Proril_Sales_Center -C -f 65001 -i prod-migration-2026-09-30\02-sync-rbac-nodes-from-dev.sql
sqlcmd -S $srv -U proril_sales_center -d Proril_Sales_Center -C -f 65001 -i prod-migration-2026-09-30\03-align-columns.sql
sqlcmd -S $srv -U proril_sales_center -d Proril_Sales_Center -C -f 65001 -i prod-migration-2026-09-30\04-clear-user-password.sql
```

每支都可重跑。各支最後都有驗證輸出，「應為 0 筆」的查詢要確認真的是 0 筆，
尤其 `RbacObjectsMigration.sql` 的「轉換前後有效權限不一致的帳號」。

**跑完 `RbacObjectsMigration.sql` 就要緊接著部署新版**（GitHub Actions → `deploy-prod` →
Run workflow）：新版 `api/` 讀 `RBAC_*`，舊版讀 `M_PermissionDef`（已被改名），
兩者不能同時成立，中間這段時間 Prod 的權限判斷是壞的。

## 執行結果（2026-09-30，51002 已全部執行）

- `01`：`M_Permission` 131 列、`H_FileLink` 116 列換號；`M_PermissionLinkType` 14 → 4 列。
- `PermissionDefObjectsMigration.sql`：2.0 功能回填不到 `PermissionKey` 的列 0 筆。
- `RbacObjectsMigration.sql`：superAdmin 10 人、`migrated01`～`11` 共 15 個帳號；
  「轉換前後有效權限不一致」與「IsAdmin／superAdmin 不一致」**都是 0 筆**。
- `02`：`salesIssue` 模組與 2 個分組改成 N，與 Dev 不一致的節點 0 筆。
- `03`：10 個欄位改型別、4 個預設值補上。
- `04`：46 列密碼備份後清空。
- 重新比對 50002／51002：物件清單完全一致；欄位只剩上表刻意保留的
  `COP_CheckRule.testDacPak`、`D_WorkProcess.FinFlag` 預設值、`H_FileLink.FilePath` 長度。

踩到的坑：`SET PARSEONLY ON` 語法檢查抓不到的 **collation conflict**——暫存表（`#Map` / `#Dev`）
建在 tempdb，沿用 instance 預設定序 `SQL_Latin1_General_CP1_CI_AS`，跟本庫比對會失敗。
`01` 第一次執行就停在這裡（`XACT_ABORT` 整批回滾，資料沒動），暫存表字串欄位補上
`COLLATE DATABASE_DEFAULT` 後重跑。之後寫給這個庫的腳本，`#temp` 表都要加。
