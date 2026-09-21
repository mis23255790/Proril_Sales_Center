# 2026-09-21：補齊 51002 Proril_Sales_Center 的物件

比對 50002（測試區）與 51002（正式區）兩邊 `Proril_Sales_Center` 的物件清單時，
發現 51002 缺少訂單資料檢核的 2 張表 + 全部 9 個 View + 全部 10 個預存程序 + 1 個函式，
另外 51002 多了一張 50002 沒有的 `M_Department`。這個資料夾保留當時用的建置腳本，
供**正式上線時再對正式區資料重跑一次資料同步**。

## 為什麼不是直接跑 `database/*ObjectsMigration.sql`

CLAUDE.md／PortingNotes.md 都寫明這個庫的建表/建物件要走 `*ObjectsMigration.sql`
（`run-objects-migration.ps1`），但那幾支腳本的資料複製區塊是
`INSERT INTO ... SELECT ... FROM PRORIL_WEB.dbo.表名`——單一連線同時要有
`Proril_Sales_Center`（寫）與 `PRORIL_WEB`（讀）的權限。

51002 上目前可用的兩組帳號權限**互相不重疊**：
- `proril_sales_center`：`Proril_Sales_Center` db_owner，但對 `PRORIL_WEB` **沒有** SELECT。
- `proril_ac1`：對 `PRORIL_WEB` 有 SELECT，但對 `Proril_Sales_Center` 沒有寫入權限。

所以這次拆成「先用 `proril_sales_center` 建表/建 View/建 SP」+
「用 `proril_ac1` bcp 匯出 `PRORIL_WEB` 資料、`proril_sales_center` bcp 匯入」兩段做，
而不是整支腳本一次跑完。**這個帳號權限的落差本身也是之後正式上線要處理的事**——
要嘛拿到一組兩邊都有權限的帳號、要嘛比照這次的拆法。

## 這個資料夾裡的腳本

跑法：`sqlcmd -S <server> -U proril_sales_center -d Proril_Sales_Center -C -f 65001 -i <檔名>`
（`-f 65001` 是因為腳本裡有中文字面值，UTF-8 讀取，這幾支腳本本身也存成 UTF-8 無 BOM）。

1. **`01-create-tables.sql`** —— `COP_AvailableAmt` / `COP_ProductCheck`
   （訂單資料檢核的寫入目標表，schema 取自 `database/OrderCheckObjectsMigration.sql`）。
   只建表，不含資料。
2. **`02-create-views.sql`** —— 9 個 View（`V_SalesTotal`／`V_UnfinOrder`／`V_COPMOQ`／
   `V_COPNoChk`／`V_ERPCustomer`／`V_PODetailList`／`V_POList`／`V_Product_English_All`／
   `V_UpFileData`），定義取自 50002 測試區已驗證的版本（`OBJECT_DEFINITION` 逐一核對）。
3. **`03-create-procedures.sql`** —— 1 個函式（`fu_RemoveParentheses`）+ 10 個預存程序
   （`prc_COPGetCredit`／`prc_COPGetCredit_CRM`／`prc_ProductChk_COP`／`prc_COPOrderChk`／
   `prc_COPPassCheck`／`prc_ImportSalesOrder`／`prc_QuerySalesOrder`／`prc_QuerySalesOrder_1`／
   `prc_QueryUnfinOrder`／`prc_QueryUnfinOrder_1`），逐字從
   `OrderCheckObjectsMigration.sql`／`SalesShippingObjectsMigration.sql`／
   `SalesOrderUnfinishObjectsMigration.sql` 用行號範圍擷取（`awk`），不是手動謄寫，
   避免大型 SP（`prc_COPOrderChk` 700+ 行）轉貼出錯。
4. **`04-create-table-m-department.sql`** —— 方向相反，是把 51002 既有的 `M_Department`
   搭一份回 50002（見 `database/PortingNotes.md`「M_Department：兩邊 Proril_Sales_Center
   快照對齊」），不是這次「51002 缺什麼」的範圍，放在這裡只是因為同一次操作一起做的。

**這些腳本目前只在 51002 執行過（01-03）／50002 執行過（04）**，全部驗證通過
（見下面「已完成的驗證」）。50002 本來就有這些物件（`*ObjectsMigration.sql` 執行的結果），
不需要重跑 01-03。

## 資料同步：這次怎麼做、正式上線要重做什麼

01-03 只建了「空殼」（表結構、View、SP），**資料是另外用 `bcp` 搬的**，指令沒有存成腳本
（帳密不能進版控），流程記錄如下，正式上線時比照做（帳密另外取得，不要抄這裡的）：

```powershell
# 1. 用 proril_ac1（對 51002 PRORIL_WEB 有 SELECT）匯出
bcp "PRORIL_WEB.dbo.COP_AvailableAmt" out COP_AvailableAmt.bcp -S 192.168.1.142,51002 -U proril_ac1 -P <password> -n -C 65001
bcp "PRORIL_WEB.dbo.COP_ProductCheck" out COP_ProductCheck.bcp -S 192.168.1.142,51002 -U proril_ac1 -P <password> -n -C 65001

# 2. 用 proril_sales_center（對 51002 Proril_Sales_Center 有寫入權限）匯入，-E 保留原始 ID
bcp "Proril_Sales_Center.dbo.COP_AvailableAmt" in COP_AvailableAmt.bcp -S 192.168.1.142,51002 -U proril_sales_center -P <password> -n -C 65001 -E
bcp "Proril_Sales_Center.dbo.COP_ProductCheck" in COP_ProductCheck.bcp -S 192.168.1.142,51002 -U proril_sales_center -P <password> -n -C 65001 -E

# 3. 驗證：兩邊各自對該表跑 CHECKSUM_AGG(BINARY_CHECKSUM(*))，數字要一致
```

`M_Department`（反方向，51002 -> 50002）也是同一套 `bcp out` / `bcp in -E` 流程，
來源改成 `Proril_Sales_Center.dbo.M_Department`（51002），目的地是 50002 的
`Proril_Sales_Center.dbo.M_Department`。

**正式上線時**：這次搬的 `COP_AvailableAmt`／`COP_ProductCheck` 資料是 2026-09-21
當下的快照（51002 `PRORIL_WEB` 那時的內容），跟其他所有 `*ObjectsMigration.sql`
搬過的表一樣**不會自動同步**。正式上線前應該重新跑一次上面的 `bcp` 流程，
用當下最新的 `PRORIL_WEB` 資料覆蓋，而不是延用這次的快照。

## 已完成的驗證（2026-09-21）

- `COP_AvailableAmt`（3611 筆）／`COP_ProductCheck`（6945 筆）：51002 兩邊
  `CHECKSUM_AGG(BINARY_CHECKSUM(*))` 一致。
- `M_Department`（11 筆）：50002／51002 兩邊 checksum 一致（`2050093221`）。
- 9 個 View 在 51002 建立後可正常查詢，含依賴 ERP linked server 的
  `V_ERPCustomer`（198 筆）與依賴本機 `COP_SalesOrder` 的 `V_SalesTotal`（1203 筆）。
- 10 個 SP + 1 個函式在 51002 建立無誤（`CREATE OR ALTER` 成功），**沒有實際執行**
  （多數會寫資料，比照 `OrderCheckObjectsMigration.sql`／`SalesShippingObjectsMigration.sql`
  原本的說明，沒有「只查不寫」的跑法，這次不試跑，留給正式上線前另外驗證）。

## 已知限制（沒有處理，留給之後）

- **`M_Department` 的定位沒有改變**：`api/` 的 `OrgApiController` 仍然只打
  `PRORIL_WEB`，這次搬的兩份 `Proril_Sales_Center.M_Department` 只是手動對齊過一次
  的快照，不是切連線，之後也不會自動同步。

## `prc_ImportSalesOrder` 的 `NPS_D_Order` 跨庫 JOIN 已拿掉（2026-09-21）

上面提到的權限問題（`proril_sales_center` 對 51002 `PRORIL_WEB` 沒有 SELECT）不只擋到
這次的資料搬移，`prc_ImportSalesOrder` 裡對 `PRORIL_WEB.dbo.NPS_D_Order` 的跨庫 JOIN
在 51002 用這個帳號執行也會失敗——這支 SP 不是唯讀查詢，是 `prc_QuerySalesOrder(_1)`
每次查詢都會觸發的即時匯入，壞了整個銷貨檢索都會壞。

`NPS_D_Order` 是銘版序號資料，業務上屬於 `Proril_Manufacturing_Center`（銘版系統），
不是 Sales Center 自己的表，所以**不比照 `COP_*` 整張複製過來**（複製了也只是又一份
「快照,不會跟寫入端同步」的表，治標不治本，而且 Manufacturing Center 才是資料的正確
owner）。改成：

1. `prc_ImportSalesOrder`（`database/SalesShippingObjectsMigration.sql` 與這裡的
   `03-create-procedures.sql`）裡的兩處
   `LEFT join PRORIL_WEB.dbo.NPS_D_Order TB on ...` **註解掉**，`SerialNosJson` 欄位
   匯入當下先寫 `NULL`。50002／51002 都已經用 `CREATE OR ALTER PROCEDURE` 更新過，
   `OBJECT_DEFINITION` 確認兩邊都只剩註解、沒有真的執行這段 JOIN。
2. 新增 [api/Services/SerialNoSyncHostedService.cs](../../api/Services/SerialNoSyncHostedService.cs)：
   每 10 分鐘跑一次，對 `ProrilWebDbContext`（`CopSalesOrder` 現在還沒切到
   `SalesCenterDbContext`，跟 `NPS_D_Order` 剛好是同一顆資料庫）下一個本機
   `UPDATE ... FROM` 把 `SerialNosJson` 補回去，不用等 Manufacturing Center 有 API、
   也不用額外的 `HttpClient`。已在 `Program.cs` 註冊。
3. **這是暫時的接法,不是最終架構**：`NPS_D_Order` 現在還是躺在 `PRORIL_WEB`，跟
   `COP_SalesOrder`（透過 `ProrilWebDbContext`）剛好同一個連線，才能用一句 SQL 補資料。
   哪天 `Proril_Manufacturing_Center` 真的獨立成有自己 API 的服務、或 `CopSalesOrder`
   切到 `SalesCenterDbContext`（變成跨資料庫），`SerialNoSyncHostedService.DoWork`
   要換成「呼叫 Manufacturing Center API 拿序號 + 寫回 `SalesCenterDbContext`」，
   排程本身的架構（`IHostedService` + `Timer`，比照既有的 `LogTimedHostedService`）
   不用動。
4. **序號會比訂單本身晚最多 10 分鐘才出現**：`prc_QuerySalesOrder(_1)` 觸發的即時匯入
   只匯訂單，序號要等下一次排程跑。跟其他 ERP 快取表本來就有的落差是同一種取捨。

## `V_UnfinOrder` 的同一個 `NPS_D_Order` JOIN 也拿掉了（2026-09-21，同一次處理）

用 `sys.sql_modules` 掃過 51002 兩邊 `Proril_Sales_Center` 全部 View/SP 定義文字找
`PRORIL_WEB` 才發現：`V_UnfinOrder`（未完成訂單檢索用的 View，`SalesOrderUnfinishObjectsMigration.sql`）
也有兩處一模一樣的 `LEFT join PRORIL_WEB.dbo.NPS_D_Order`，實測用 `proril_sales_center`
帳號查會噴同一種權限錯誤（`SELECT permission was denied on the object 'NPS_D_Order'`）。

跟 `prc_ImportSalesOrder` 不同的是，`V_UnfinOrder` **是即時查詢、沒有本地快取表**
（`prc_QueryUnfinOrder(_1)` 直接 `FROM V_UnfinOrder`，每次查詢都重新算），所以不能比照
`SerialNoSyncHostedService` 那種「排程批次補寫」的做法——沒有表可以 `UPDATE`。改成：

1. `V_UnfinOrder` 兩處 `NPS_D_Order` JOIN 註解掉，`SerialNosJson` 改成
   `CAST(NULL AS NVARCHAR(MAX))`（`database/SalesOrderUnfinishObjectsMigration.sql`
   與這裡的 `02-create-views.sql` 都已更新，50002／51002 都已用 `CREATE OR ALTER VIEW`
   套用）。
2. 新增 `GET /Manufacturing/GetSerialNos` 端點
   （[api/Controllers/Manufacturing/ManufacturingApiController.cs](../../api/Controllers/Manufacturing/ManufacturingApiController.cs)），
   回傳 `{ "{OrderType}-{RTRIM(OrderNo)}{OrderSno}": "SerialNosJson" }` 這種字典，
   資料來源是共用的
   [api/Services/ManufacturingSerialNoLookupService.cs](../../api/Services/ManufacturingSerialNoLookupService.cs)
   （查 `ProrilWebDbContext` 的 `NPS_D_Order`，邏輯跟 `SerialNoSyncHostedService` 讀的
   是同一張表，只是這裡是同步查、不落地）。
3. `SalesOrderUnFinishApiController`（`GetUnfinOrder` / `QueryUnfinOrder_1`）改成
   直接注入同一個 `ManufacturingSerialNoLookupService`（**in-process 呼叫該服務，
   不是真的發一個 HTTP request 打自己的 `/Manufacturing/GetSerialNos`**——同一個
   ASP.NET Core process 內部呼叫用 DI 注入的服務就好，自我 HTTP 迴環只有徒增延遲、
   認證處理的複雜度，沒有任何好處），查完訂單後在應用層用同一套 key 規則
   （`OrderType-RTRIM(OrderNo)+OrderSno`）left join 回 `SerialNosJson`。
   `GetSerialNos` 端點本身是為了讓「Manufacturing 這個查詢能力」有一個獨立、
   之後可以被其他消費者（或換成真的 Manufacturing_Center API）取代的邊界，
   不是要求同進程內的呼叫端也走 HTTP。
4. `dotnet build` 通過（0 警告 0 錯誤；如果建置卡在複製 DLL 失敗，通常是 Visual Studio
   還在偵錯執行中把 DLL 鎖住，不是編譯錯誤，停掉偵錯或建到別的輸出目錄就能確認）。

**還沒做的**：沒有拿一筆真的對得上 `NPS_D_Order` 的未完成訂單實測序號真的補得回來
（需要真實資料才能驗證 key 組法完全正確），也還沒在畫面上驗證。
