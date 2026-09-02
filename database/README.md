# 業務議題 Schema 版控 (DACPAC)

把業務議題相關資料表的 schema 納入 git，讓「未上線的欄位」跟著 branch 走，
而不是散在測試區資料庫裡等人手動同步到正式區。

> **Schema 與資料是兩件事。** 這份 README 講的是**結構**。
> 「結構對了但資料是壞的」由 `checks/` 負責 —— 補零格式、尾端空白、孤兒列、
> 以及「議題在 DB 裡好好的但列表看不到它」這類問題。
> 見 [checks/README.md](./checks/README.md)。

## 這個目錄管什麼、不管什麼

**管**：`TABLES.txt` 白名單裡的 8 張表的**結構**（欄位、型別、索引、條件約束）。

**不管**：
- 資料列。所有 extract / publish 都帶 `ExtractAllTableData=false`，不會碰到任何一筆資料。
- View、Stored Procedure。專案規範明訂不動這些。
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

## 相關文件

- `../docs/modules/SalesIssue/logic.md` — 業務議題的資料表關聯與欄位語意
- `TABLES.txt` — 納管白名單
- `Tables/README.md` — 產生物的維護規則
