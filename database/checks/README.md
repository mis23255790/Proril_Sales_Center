# 資料正確性檢查

`database/` 的另一半。`Tables/` + `scripts/publish.ps1` 管的是**結構**（schema），
這個資料夾管的是**資料**：結構對了，內容仍然可能是壞的。

純讀取，不會寫任何東西到資料庫。

## 怎麼跑

```powershell
# 先確認 database/.env 已設定（cp .env.example .env 後填連線字串）
cd database\scripts

.\check.ps1                          # 預設測試區
.\check.ps1 -Environment prod        # 正式區
.\check.ps1 -Check consistency       # 只跑 03_consistency.sql
.\check.ps1 -Sample 20               # 每項多印一點明細
.\check.ps1 -Sample 0                # 只看統計
```

## 第一次跑：先建立基線

老系統一定有歷史髒資料，第一次跑通常會噴幾百筆。**不要急著修**，
不然你會直接放棄看它。正確順序是：

1. `.\check.ps1 -Environment prod -Sample 20` 先看過內容，確認都是歷史資料
2. `.\check.ps1 -Environment prod -UpdateBaseline` 把現況寫進 `baseline.tsv`
3. `baseline.tsv` **要進版控** —— 這樣任何人讓它變長都會在 code review 看到
4. 之後每次跑，只有不在基線裡的才算「新增」

有了基線，`-FailOnError` 才有意義（只對新增的 ERROR 失敗），可以掛進 CI 或排程。

## 檢查檔的契約

每個 `.sql` 回傳**一個** result set，固定四欄，回 0 列代表通過：

| 欄位 | 意義 |
|---|---|
| `chk` | 檢查代號，同一份 .sql 可以有多個 |
| `severity` | `ERROR`（會壞畫面或壞資料）或 `WARN`（值得看，不一定要修） |
| `ident` | 定位用，例如 `WPNo=000062` 或 `D_WorkProcessDetail.ID=123` |
| `detail` | 給人看的說明 |

`(chk, ident)` 就是基線比對的 key，所以 `ident` 要穩定，不要放時間戳這種每次都變的東西。

新增檢查就是加一段 `UNION ALL`，或加一個新的 `.sql`，runner 會自動撿。

## 目前有哪些

| 檔案 | 抓什麼 |
|---|---|
| `01_format.sql` | WPNo/SNo 補零格式、欄位前後空白、`aStatus` 值域 |
| `02_referential.sql` | 孤兒列、指到已失效資料的參照、重複鍵 |
| `03_consistency.sql` | 資料合法但**畫面會出錯**的情況 |

`03` 是價值最高的一組。它抓的是「議題在 DB 裡好好的，但議題列表就是看不到它」——
因為 `getSOPList()` 對 `M_User` 用了兩個 inner join，Creator 或最新進度的 Modifier
只要對不上（離職刪帳號、帶尾端空白、或**根本還沒有任何進度**），
整張議題就會無聲消失。細節看 `03_consistency.sql` 的檔頭註解。

## 寫檢查時要小心的 T-SQL 陷阱

- **`=` 與 `<>` 會忽略尾端空白**：`'abc ' = 'abc'` 是 TRUE。
  所以 `col <> LTRIM(RTRIM(col))` 永遠抓不到尾端空白，要用
  `DATALENGTH(col) <> DATALENGTH(LTRIM(RTRIM(col)))`。
- **DB 是 case-sensitive collation**：欄位是 `aStatus`（小寫 a），
  寫成 `AStatus` 會噴 `Invalid column name`。
- **`aStatus = 'N'` 是「已失效」不是「已完成」**：所有檢查都要先濾掉。
- **參照比對兩邊都要 `LTRIM(RTRIM())`**：這些欄位是 varchar 且常帶 ERP 來的空白。
- **`.sql` 存成 UTF-8**：runner 用 `sqlcmd -f 65001` 讀，檔案不是 UTF-8 的話
  中文註解與 detail 會變亂碼。

## 下一步：把驗過的規則固化進 DB

跑到 0 違規之後，才適合把規則交給資料庫自己擋：

```sql
ALTER TABLE dbo.D_WorkProcessSearch WITH NOCHECK
  ADD CONSTRAINT FK_WPSearch_WorkProcess
      FOREIGN KEY (WPNo) REFERENCES dbo.D_WorkProcess(WPNo);
```

`WITH NOCHECK` = 不驗既有資料、只擋新寫入，這對清不完的歷史資料是唯一可行的路。

**先決條件**：`D_WorkProcess` 的 PK 是 `ID` 不是 `WPNo`，所以要建這個 FK
得先在 `WPNo` 加 UNIQUE 索引。`D_WorkProcessDetail` 已經有 `(WPNo, SNo)` 的
unique index 了（`NonClusteredIndex-20231221-145816`）。

這一步會動到 schema，屬於 `database/Tables/` 的管轄範圍，要走 DACPAC 流程。
