# 業務議題 Schema 版控 (DACPAC)

把業務議題相關資料表的 schema 納入 git，讓「未上線的欄位」跟著 branch 走，
而不是散在測試區資料庫裡等人手動同步到正式區。

> **Schema 與資料是兩件事。** 這份 README 講的是**結構**。
> 「結構對了但資料是壞的」由 `checks/` 負責 —— 補零格式、尾端空白、孤兒列、
> 以及「議題在 DB 裡好好的但列表看不到它」這類問題。
> 見 [checks/README.md](./checks/README.md)。

## 情境速查表

| 情境 | 方向 | 工具 | 手動程度 |
|---|---|---|---|
| 日常加欄位 | git → DB | `publish.ps1` | 手改一個 .sql 檔案裡的欄位定義 |
| 建基線/校準 | DB → git | `extract.ps1` | 全自動，整批 |
| 看兩環境差多少 | DB → 畫面 | `drift.ps1` | 全自動，唯讀 |
| 欄位加完後同步 EF Model | git（schema）→ C# | `sync-model.ps1` | 手動把提示的差異貼進 `Entities.cs` |
| 快照庫建好後灌資料 | PRORIL_WEB → Proril_Sales_Center | `copy-snapshot-data.ps1` | 半自動，dry-run 預覽 + `-Execute` 確認 |

> ⚠️ `copy-snapshot-data.ps1` **不加 `-Tables` 就是整批覆蓋白名單的每一張表**，
> 包含 `D_WorkProcess*` / `CRM_Customer` / `H_FileLink`——那幾張在 `Proril_Sales_Center`
> 已經是正式讀寫的資料，來源 `PRORIL_WEB` 那份停在 2026-09-03 的快照，
> 整批跑下去等於把業務議題資料倒退回舊版本。補灌特定幾張一律用
> `-Tables M_User,M_Permission` 這種寫法限定範圍。
| 搬 View/SP 到快照庫 | `*ObjectsMigration.sql` → DB | `run-objects-migration.ps1` | 半自動，dry-run 檢查 + `-Execute` 確認 |
| 快照庫定序對齊來源 | DB → DB | `fix-collation.ps1` | 半自動，dry-run 檢查 + `-Execute` 確認（需停機） |

## 這個目錄管什麼、不管什麼

**管**：`TABLES.txt` 白名單裡的表的**結構**（欄位、型別、索引、條件約束）——業務議題
8 張 + 訂單資料檢核 5 張 + 銷貨檢索 1 張 + 跨模組共用的附件 log 1 張 + 權限控管 7 張，
共 22 張。

權限控管那 7 張要分三種看（見 `PortingNotes.md`「權限控管搬遷」段落）：
- **已切連線、`api/` 會寫**：`M_User`、`M_Permission`、`M_PermissionGroup`
- **已切連線、`api/` 唯讀，而且新庫只保留部分資料列**：`M_System`、`M_Function`、
  `M_PermissionLinkType`。只收 2.0 真的有頁面的 3 個系統別 + 8 個功能（及其 4 列細項），
  由 `PermissionMasterSeed.sql` / `FunctionNoFormatMigration.sql` 維護，
  `copy-snapshot-data.ps1` 會跳過 `M_System` / `M_Function`。
- **只收 schema、`api/` 唯讀且仍打 `PRORIL_WEB`**：`M_Department`
  （1.0 的組織維護還在寫它）。**收進版控不等於切連線**，兩件事分開看。

> ⚠️ **`FunctionNo` 在兩個庫型別不同**：`PRORIL_WEB` 是 `int`，
> `Proril_Sales_Center` 是 `varchar(8)`（AAABBCC 格式，見 `PortingNotes.md`
> 「FunctionNo 改成 AAABBCC 格式」）。`Tables/` 底下的 .sql 是 `PRORIL_WEB` 的正本、
> 維持 `int`，所以 `publish.ps1 -Environment snapshot` 與 `drift.ps1` 對快照庫
> 一定會報 `M_Function` / `M_Permission` / `M_PermissionGroup` /
> `M_PermissionLinkType` / `H_FileLink` 這幾個欄位的差異——**那是預期的，不要套用回去**。

**不管**：
- 資料列。所有 extract / publish 都帶 `ExtractAllTableData=false`，不會碰到任何一筆資料
  （資料列的搬移是 `copy-snapshot-data.ps1` 的事，見下面「快照庫資料複製」）。
- View、Stored Procedure。專案規範明訂不動這些。
  把既有的 View/SP **原樣搬一份**到 `Proril_Sales_Center` 是另一回事，那不走 DACPAC，
  物件寫在 `database/*ObjectsMigration.sql`，用 `scripts/run-objects-migration.ps1`
  執行（見下面「View / 預存程序的搬移」）。
- 白名單以外的表。`PRORIL_WEB` 有 400+ 張表（含鼎新 ERP 的），這裡只收業務議題用到的。

**注意**：本 repo (`Proril_Sales_Center`) 是純 Nuxt 前端，沒有自己的資料庫。
這裡納管的是 **1.0 `PRORIL_WEB`** 的表，後端在 `D:\Projects\Source\Proril\PRORIL`
的 `Controllers/WorkProcess/WorkProcessApiController.cs`。
schema 放這裡是因為業務議題功能歸屬 2.0；改後端行為仍然要回 1.0 那個 repo。

## 核心規則

> **main branch 的 `Tables/*.sql` == 正式區 schema。**
> 未上線的欄位不是「不進版控」，而是「進版控但還在 feature branch，還沒 merge」。

這一條是整套機制的重點。它同時解決兩件事：

1. 你 scaffold / 開發時不會吃到別人做到一半的欄位（在他的 branch，不在你的）
2. 你的新欄位有明確路徑上正式區（merge 時跟著程式碼一起部署），不需要有人記得手動補

## 環境

| | 位址 | 用途 |
|---|---|---|
| 測試區 | `192.168.1.142,50002` | feature branch 部署驗證 |
| 正式區 | `192.168.1.142,51002` | main merge 後由 CI 部署 |

兩邊資料庫都叫 `PRORIL_WEB`，只有 instance port 不同 —— **執行任何 publish 前務必確認 port**。

## 前置安裝

```powershell
dotnet tool install -g microsoft.sqlpackage
```

`sqlcmd` 已隨 SQL Server Client SDK 安裝（`drift.ps1` 需要）。
`dotnet build` 需要能連 nuget 下載 `Microsoft.Build.Sql` SDK。

設定連線：

```powershell
Copy-Item .env.example .env
# 編輯 .env 填入帳密
```

## 日常流程

### 1. 看現在差多少（唯讀，隨時可跑）

```powershell
.\scripts\drift.ps1
```

列出測試區有、正式區沒有的欄位 —— 也就是目前累積的未上線變更。
`-Detailed` 會多印完整型別定義。

`-From` / `-To` 可以換成任兩個環境（`test` / `prod` / `snapshot`），不是只能比測試區跟正式區。
`snapshot` 是獨立資料庫 `Proril_Sales_Center`（CLAUDE.md 說的那個「快照，還沒真的切連線」的庫），
用來查它跟 `PRORIL_WEB` 是不是真的長一樣、有沒有漏複製欄位/整張表：

```powershell
.\scripts\drift.ps1 -From snapshot -To prod
```

### 2. 初始化：從正式區建立基線

```powershell
.\scripts\extract.ps1 -Environment prod
git add Tables/
git commit -m "chore(db): 以正式區 schema 建立業務議題基線"
```

只做一次。之後 `Tables/*.sql` 就靠人工編輯維護，不再整包重抓。

### 3. 開發新功能要加欄位

```powershell
git switch -c feature/issue-xxx
# 手動編輯 Tables/D_WorkProcess.sql，加上新欄位
.\scripts\publish.ps1 -Environment test           # dry-run，先看會改什麼
.\scripts\publish.ps1 -Environment test -Execute  # 確認後推到測試區
```

新欄位請遵守 **expand-contract**：一律先 `NULL` 或帶 `DEFAULT`，
這樣正式區既有資料列不會讓 `ALTER TABLE` 失敗，DB 也能先上、程式後上。
`drift.ps1` 會對 `NOT NULL` 且無 `DEFAULT` 的新欄位主動示警。

### 4. 上正式區

```powershell
.\scripts\deploy-report.ps1 -Environment prod   # 必看
.\scripts\publish.ps1 -Environment prod -Execute
```

`publish.ps1` 對 prod 會要求你手動輸入資料庫名稱確認。

## 安全設定（不要拿掉）

所有 publish / deploy-report 都固定帶：

| 參數 | 值 | 作用 |
|---|---|---|
| `BlockOnPossibleDataLoss` | `true` | 會造成資料遺失的變更直接中止 |
| `DropObjectsNotInSource` | `false` | 目標環境多出來的欄位不會被砍掉 |

第二項特別重要：測試區長期領先 main，如果這個設成 `true`，
拿 main 的 dacpac 去 publish 測試區會把所有未上線欄位清掉。

## 為什麼是 DACPAC 而不是 EF Migrations

這個系統是 database-first，而且 `PRORIL_WEB` 裡混著鼎新 ERP 的表（不歸我們管、不能改）。
EF Migrations 會想要管理整個 model，對不歸自己的表很難處理。
DACPAC 只做「擷取 + 差異部署」，可以精準只納管白名單那幾張表。

## 欄位改完之後：同步回 EF Model

`Tables/*.sql` 只管資料庫結構，`api/Data/Entities.cs` + `ProrilWebDbContext.cs`
的 EF Model 是**手寫維護**的（不是 `dotnet ef dbcontext scaffold` 的產物，
不要拿 scaffold 整份覆蓋，會把手動修正的型別/註解/白名單一起洗掉）。

```powershell
.\scripts\sync-model.ps1 -Table D_WorkProcess
```

只列出「資料庫多了/少了哪些欄位」，不動任何檔案，新增屬性跟 fluent 對映仍要
自己手動加進 `api/Data/`。細節、跟 scaffold 相比的取捨看 script 開頭的註解。

## 快照庫（Proril_Sales_Center）資料複製

CLAUDE.md 說的「18 張表一次性複製」是指把 `PRORIL_WEB` 白名單表的**資料列**搬到
同一個 instance 上的獨立資料庫 `Proril_Sales_Center`。這跟上面整套 DACPAC 機制
是兩件事——DACPAC 只管結構，這裡才是真的搬資料：

```powershell
.\scripts\copy-snapshot-data.ps1 -Environment test           # dry-run，列出來源/目標列數對照
.\scripts\copy-snapshot-data.ps1 -Environment test -Execute  # 確認後真的複製（整批覆蓋，不是增量）
```

前置條件（缺一步就會被腳本擋下來，不會半吊子跑一半）：

1. **目標資料庫要先存在**。這支腳本、以及本專案任何工具都**不會、也不能建資料庫本身**——
   建空庫需要比部署帳號更高的權限（`CREATE DATABASE`），本專案的 `PRORIL_DB_PROD`/`PRORIL_DB_TEST`
   帳號刻意不給，要建的話找 DBA 或有權限的帳號手動建一個空的 `Proril_Sales_Center`。
2. **目標資料庫要先有白名單表的結構**：`.\publish.ps1 -Environment snapshot -Execute`
   （正式區則是 `-Environment snapshot-prod`，要先在 `.env` 填 `PRORIL_DB_SNAPSHOT_PROD`）。
3. `.env` 要有對應的連線字串：測試區已經有 `PRORIL_DB_SNAPSHOT`；正式區的
   `PRORIL_DB_SNAPSHOT_PROD` 要等 51002 上的 `Proril_Sales_Center` 真的建好才填，
   `.env.example` 裡先留著註解示範格式。

`-Environment test` / `prod` 選的是**來源** `PRORIL_WEB` 在哪個 instance，目標會自動對到
同一個 instance 上的快照庫（`test` → `snapshot`，`prod` → `snapshot-prod`），因為腳本假設
來源跟目標永遠在同一台 SQL Server 上，用三段式命名跨資料庫查詢，不用設 linked server。

## View / 預存程序的搬移

DACPAC 只管資料表結構，View/SP 不納管（上面「不管」那段）。但要讓某個模組在
`Proril_Sales_Center` 完整跑起來，它吃的 View/SP 還是得原樣複製一份過去。
這些物件寫在 `database/` 底下的 `*ObjectsMigration.sql`，由
`scripts/run-objects-migration.ps1` 執行：

| 腳本 | 內容 | 狀態 |
|---|---|---|
| `OrderCheckObjectsMigration.sql` | 訂單資料檢核：7 View + 5 SP + 1 函式 + 5 表 | 測試區已執行 |
| `SalesShippingObjectsMigration.sql` | 銷貨檢索：3 SP + 1 表 | 測試區已執行 |

```powershell
# 1. 先看看要做什麼（不會動任何東西）
.\scripts\run-objects-migration.ps1 -Script SalesShippingObjectsMigration.sql -Environment snapshot

# 2. 確認無誤再執行
.\scripts\run-objects-migration.ps1 -Script SalesShippingObjectsMigration.sql -Environment snapshot -Execute
```

dry-run 會做四件事：目標資料庫與腳本裡的 `USE` 對帳、檢查 linked server
`[192.168.1.200]`（鼎新 ERP，View/SP 都靠它，缺了建得起來但一執行就失敗）、
列出腳本會建立的物件在目標端「已存在／不存在」、把整份腳本以 `SET PARSEONLY ON`
送進 SQL Server 驗語法。

兩支腳本都可重複執行：`CREATE TABLE` 包 `IF OBJECT_ID(...) IS NULL`、
View/SP/函式一律 `CREATE OR ALTER`、資料複製區塊在表已經有資料時自動跳過。

> **編碼**：腳本是 UTF-8 無 BOM，而且 `prc_ImportSalesOrder` 裡有中文字串常值
> （`'浦瑞ERP'` / `'芳晟ERP'`）。`run-objects-migration.ps1` 一律用 `sqlcmd -f 65001`
> 讀。若要改用 SSMS 手動跑，開檔時務必選 UTF-8，不要以 ANSI 開啟後另存，
> 否則那兩個字串會變亂碼寫進資料。

## 定序（collation）

`Proril_Sales_Center` 的定序**必須與 `PRORIL_WEB` 相同**：`Chinese_Taiwan_Stroke_BIN`。
測試區的那一份已經在 2026-09-14 對齊（原本是建庫時沿用 instance 預設的
`SQL_Latin1_General_CP1_CI_AS`）。

不一致的後果不是只有「中文變問號」那麼直白——**排序與比對語意會變**，
實際踩到的案例是銷貨檢索的預存程序在兩個庫回傳不同的分群統計筆數。
完整來龍去脈見 `PortingNotes.md`「定序已對齊」。

**新建這個資料庫時，`CREATE DATABASE` 就直接指定定序**，不要靠事後修：

```sql
CREATE DATABASE [Proril_Sales_Center] COLLATE Chinese_Taiwan_Stroke_BIN;
```

真的已經建成別的定序了，用這支修（預設 dry-run，會列出所有要改的欄位、
要重建的索引，並掃描 varchar 欄位有沒有非 ASCII 內容）：

```powershell
.\scripts\fix-collation.ps1 -Environment snapshot
.\scripts\fix-collation.ps1 -Environment snapshot -Execute
```

`-Execute` 會 `SET SINGLE_USER WITH ROLLBACK IMMEDIATE`，**踢掉所有連線**，
跑之前要先停掉 `api/` 與任何連著這個庫的工具。

DACPAC 這邊不用配合改：`Tables/*.sql` 不帶 `COLLATE` 子句，publish 出去的欄位
沿用資料庫預設。

## 相關文件

- `../docs/modules/SalesIssue/logic.md` — 業務議題的資料表關聯與欄位語意
- `TABLES.txt` — 納管白名單
- `Tables/README.md` — 產生物的維護規則
