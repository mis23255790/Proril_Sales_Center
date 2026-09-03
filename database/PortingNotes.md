# 搬遷紀錄：業務議題 + 訂單資料檢核的本地表複製到 Proril_Sales_Center

**2026-09-03**：把以下 13 張**真正本地**的表（結構 + 資料）從 `192.168.1.142,50002`
的 `PRORIL_WEB` 複製一份到同一台主機、同一個 port 底下的獨立資料庫 `Proril_Sales_Center`。

- `TABLES.txt` 白名單的 8 張（業務議題）：
  `D_WorkProcess`/`D_WorkProcessDetail`/`D_WorkProcessSearch`/`D_WorkProcessCustomer`/
  `D_WorkProcessPermission`/`M_WorkProcessPhrase`/`M_WorkProcessType`/`CRM_Customer`
- 另外 5 張（帳號權限 + 訂單資料檢核的本地參照表）：
  `M_User`/`M_Permission`/`H_FileLink`/`COP_CheckRule`/`COP_DepData`

> 這是**一次性快照**，不是同步機制。複製之後兩邊資料不會自動保持一致——
> `PRORIL_WEB` 之後新增/修改的資料不會自動進到 `Proril_Sales_Center`，反之亦然。
> `api/appsettings*.json` 的 `ConnectionStrings:ProrilWeb` **仍然指向 `PRORIL_WEB`**，
> 沒有因為這次複製而改接 `Proril_Sales_Center`（詳見下面「為什麼不能整個切過去」）。

## 訂單資料檢核相關的 View / 預存程序 / 函式（第二階段，另一支腳本）

一開始以為 `V_POList`/`V_PODetailList`/`V_Product_English_All`/`V_UpFileData`/
`V_ERPCustomer` 這幾個 View 是查 `PRORIL_WEB` 本地表，複製資料等於凍結成今天的快照，
會讓訂單資料檢核失去即時性，所以第一輪只複製了上面這 13 張真正本地的表。

後來確認 `Proril_Sales_Center` 跟 `PRORIL_WEB` **在同一台 SQL Server instance**
（`192.168.1.142,50002`），而這些 View 透過的是 **instance 層級的 linked server**
（`[192.168.1.200]`，鼎新 ERP 主機），不是資料庫層級設定——同一個 instance 底下、
不同資料庫都能用同一個 linked server。實測 `Proril_Sales_Center` 底下執行
`SELECT TOP 1 * FROM PRORIL_WEB.dbo.CRM_Customer` 沒問題，代表 View 定義原封不動搬過去，
查到的還是即時 ERP 資料，不是快照。

順著這幾個 View 追依賴關係（`sys.sql_expression_dependencies` 遞迴查兩輪確認無遺漏），
實際範圍比一開始以為的大：

- **7 個 View**：`V_ERPCustomer`、`V_POList`、`V_PODetailList`、`V_Product_English_All`、
  `V_UpFileData`、`V_COPMOQ`（分量計價，`prc_COPOrderChk` 內部用）、`V_COPNoChk`（純靜態
  對照表，無資料表依賴）。全部用四段式命名 `[192.168.1.200].{DB}.dbo.{table}` 查 ERP，
  沒有寫死本地資料庫名稱。
- **5 個預存程序**：`prc_COPOrderChk`（745 行，訂單主檔+明細完整檢核）、`prc_COPPassCheck`、
  `prc_COPGetCredit`、`prc_COPGetCredit_CRM`、`prc_ProductChk_COP`（767 行，
  `prc_COPOrderChk` 內部呼叫，品號中英文品名規格比對）。讀寫的本地表都是 unqualified
  表名（`COP_PoCheck` 等），沒有寫死 `PRORIL_WEB`，搬過去後自動讀寫 `Proril_Sales_Center`
  自己的表。
- **1 個函式**：`fu_RemoveParentheses`，純運算無依賴。
- **5 張表**（SP 的寫入目標，第一輪沒複製）：`COP_PoCheck`/`COP_PoDetailCheck`/
  `COP_PassCheck`（訂單/明細/特規Pass 檢核結果）+ `COP_AvailableAmt`（信用額度計算紀錄，
  2790 筆）/`COP_ProductCheck`（品號檢核紀錄，23135 筆，`prc_ProductChk_COP` 的寫入目標）。

這批物件的完整腳本在 **`database/OrderCheckObjectsMigration.sql`**（結構、資料複製、
View/函式/預存程序，一支腳本包完，可重複執行）。**這支腳本尚未執行**——因為它會重新
建立業務邏輯複雜的預存程序（`prc_COPOrderChk`/`prc_ProductChk_COP` 各 700+ 行），
改用「產出腳本交給人工在 SSMS 審閱後自己執行」的方式，不是這次對話直接連線跑掉。

執行前那支腳本裡也寫了同樣的提醒：`V_Product_English_All` 這個 View 的儲存文字裡
CREATE VIEW 開頭寫的是舊名字 `V_Produce_English_All`（`sp_rename` 只改物件名稱、
不會更新已儲存的定義文字，SQL Server 已知行為），腳本裡已經手動修正成正確名稱，
不是謄寫錯誤，這點不要在之後「校對」時誤改回去。

腳本執行完之後，`SalesIssueDbContext` 用到的全部物件（業務議題 13 張表 + 訂單資料檢核
7 View/5 SP/1 函式/5 表）在 `Proril_Sales_Center` 就會齊全，`api/` 要不要把
`ConnectionStrings:ProrilWeb` 真的切過去（或拆成雙 DbContext）是下一步的決定，
這次只確保「換過去時東西都在」。

## 為什麼有 7 個欄位型別跟來源不一樣

兩個資料庫的 collation（定序）不同：

| 資料庫 | Collation |
|---|---|
| `PRORIL_WEB`（來源） | `Chinese_Taiwan_Stroke_BIN`（支援繁體中文的 code page） |
| `Proril_Sales_Center`（目標） | `SQL_Latin1_General_CP1_CI_AS`（西歐語系 code page，**不支援中文**） |

這 13 張表裡有幾個 `varchar`（非 Unicode）欄位實際存了繁體中文（關鍵字名稱、附件原始檔名、
使用者姓名）。若照原型別直接建表，資料從 `PRORIL_WEB` 複製過去時會經過 code page 轉換，
中文字會變成 `?`（不可逆的資料損毀）。已抽查證實以下欄位確實有中文內容，因此**建表時改成
`nvarchar`**，其餘欄位型別、長度、可為空、預設值、PK/索引名稱都跟 `PRORIL_WEB` 現況逐欄
核對後 1:1 複製：

| 表 | 欄位 | 來源型別 | `Proril_Sales_Center` 型別 |
|---|---|---|---|
| `M_WorkProcessPhrase` | `PhraseName` | `varchar(40)` | `nvarchar(40)` |
| `M_WorkProcessPhrase` | `Directions` | `varchar(MAX)` | `nvarchar(MAX)` |
| `M_WorkProcessType` | `TypeName` | `varchar(40)` | `nvarchar(40)` |
| `M_WorkProcessType` | `Descript` | `varchar(MAX)` | `nvarchar(MAX)` |
| `D_WorkProcessDetail` | `UploadFile` | `varchar(200)` | `nvarchar(200)` |
| `D_WorkProcessDetail` | `RenameFile` | `varchar(200)` | `nvarchar(200)` |
| `M_User` | `UserName` | `varchar(40)` | `nvarchar(40)` |

（`COP_CheckRule`/`COP_DepData` 的中文欄位如 `ChkRule`/`DepName` 在來源本來就已經是
`nvarchar`，不用覆寫。）

複製完成後已在資料庫端逐筆比對這些中文欄位（`CAST ... COLLATE Chinese_Taiwan_Stroke_BIN`
比對來源與目標），0 筆不一致；13 張表的資料列數也與來源一致
（業務議題 8 張：44/63/187/109/72/117/36/4；另外 5 張：
`COP_CheckRule` 31、`COP_DepData` 19、`H_FileLink` 1799、`M_Permission` 574、`M_User` 45）。

`api/Data/Entities.cs`／`api/Data/OrderInfoVerifyEntities.cs` 的 EF Core 對映不受影響——
這些欄位在 C# 端本來就宣告 `string`，ORM 層不區分 `varchar`/`nvarchar`，型別差異只存在於
資料庫端的實體 DDL。

## 之後更新這批 schema 時要注意

- 若之後要重新從 `PRORIL_WEB` 對 `Proril_Sales_Center` 做 DACPAC extract/publish、
  或用 `database/scripts/*.ps1` 重新產生 `Proril_Sales_Center` 的建表腳本，
  **記得把上面這 7 個欄位重新改回 `nvarchar`**——直接照抄 `PRORIL_WEB` 的 `varchar` 定義
  會重新踩到同一個 collation 問題。
- `database/` 目前的 DACPAC 版控（`Tables/*.sql`、`scripts/*.ps1`、`TABLES.txt`）納管的
  仍然只是 `PRORIL_WEB` 的業務議題 8 張表（見 `README.md`「本 repo 沒有自己的資料庫」），
  這次額外複製的 `M_User`/`M_Permission`/`H_FileLink`/`COP_CheckRule`/`COP_DepData`
  **不在** `TABLES.txt` 白名單、也不受 DACPAC drift 檢查涵蓋。跟 `Proril_Sales_Center`
  要不要／怎麼整合進這套 schema 版控機制，還沒有規劃，需要另外決定。
- 訂單資料檢核相關的 7 View/5 SP/1 函式/5 表不在這一段（13 張表）的複製範圍內，
  腳本另外放在 `database/OrderCheckObjectsMigration.sql`，見上面「訂單資料檢核相關的
  View / 預存程序 / 函式」小節。
- 複製用的 SQL 是即席產生（比對 `sys.columns`/`sys.indexes` 逐欄核對），沒有存成
  repo 裡的腳本檔——若要重跑，流程是：查詢 `PRORIL_WEB` 對應表的 `sys.columns`/
  `sys.indexes` 組出 `CREATE TABLE`（欄位型別套用上表覆寫），
  `SET IDENTITY_INSERT ON` 後 `INSERT INTO ... SELECT ... FROM PRORIL_WEB.dbo.表名`。
