<details>
  <summary>程式邏輯</summary>

###### 對應舊系統
     PRORIL (.NET MVC) 的「業務檢索」系統下的「訂單資料檢核」
       Controllers/MixSalesShip/MixSalesShipController.cs   MVC 入口 `OrderInfoVerify()`（回空 View）
       Views/Mix/OrderInfoVerify.cshtml
       wwwroot/js/mix/{order-info-verify, order-info-verify-apis}.js
       Controllers/MixSalesShip/OrderInfoVerifyApiController.cs      ← 後端也搬過來了（見下）
       Controllers/MixSalesShip/OrderInfoVerifyApiController_Xls.cs  ← ExportXls
       SystemId.MixSales = 32 / FunctionId.OrderInfoVerify = 425

     enum 註解寫「訂單資料查核」，但畫面 modal 標題與 JS top-title 顯示的是
     **「訂單資料檢核」**，2.0 沿用畫面上實際看到的字樣（頁面標題、導覽選單皆是）。

###### 相關資料表 / 預存程序
     V_POList / V_PODetailList          訂單主檔／明細 View（1.0 唯讀在用的既有 View）
     COP_PoCheck / COP_PoDetailCheck    檢核結果表頭／明細，prc_COPOrderChk 執行後寫回
     COP_PassCheck                      特規 Pass 紀錄，prc_COPPassCheck 執行後寫回
     COP_CheckRule                      檢核規則說明文字，「檢核條件」畫面在用
     V_Product_English_All / COP_DepData / V_UpFileData   英文品名／部門名稱／附件檔名，
                                         GetPOCheckView 組列表時 join 進來的顯示欄位
     prc_COPOrderChk        執行一次訂單檢核，寫回 COP_PoCheck/COP_PoDetailCheck
     prc_COPPassCheck       對單一檢核項目下特規 Pass，寫回 COP_PassCheck
     prc_COPGetCredit       客戶信用額度
     prc_COPGetCredit_CRM   客戶信用額度（幣別分開版本，前端目前沒有呼叫）

     這些表/預存程序不在 `database/` 的 DACPAC 版控範圍——那批表是 1.0 既有的表，
     不是這次搬移新增或修改的 schema，`database/` 的版控範圍仍然只限業務議題的表。
</details>

# 架構：前後端都搬

跟只搬前端的 [銷貨檢索](../SalesShipping/logic.md)、[未完成訂單檢索](../SalesOrderUnfinish/logic.md)
不同，這個模組**含寫入操作**（執行檢核、特規Pass 都會呼叫預存程序寫回資料表），所以後端
也整支搬進 `Proril.SalesIssue.Api`（`Controllers/SalesSearch/OrderInfoVerifyApiController*.cs`），
不是純轉發打 1.0。

```
Nuxt 頁面 ──▶ useOrderInfoVerifyApi() ──▶ /api/proxy/... ──▶ server/api/proxy/[...path].ts
                                                                 └─▶ NUXT_PUBLIC_API_BASE
                                                                       (指向 1.0，或指向 2.0 api/)
```

跟業務議題一樣，2.0 API 與 1.0 打同一個 `PRORIL_WEB`，可以並存、token 互通。

# 資料形狀：一個品號一列，同一張訂單重複表頭

`GetPOCheckView` 回傳的是攤平清單：一筆代表「一張訂單裡的一個品號」，同一張訂單的多個
品號會重複同一份表頭欄位與 `copPoCheck`（檢核結果是訂單層級，不是品號層級）。前端
`groupOrderInfoVerifyRows()`（`app/utils/orderInfoVerify.ts`）依 `copSource+單別+單號`
把攤平清單重新分組成「一張訂單一列」給主表格顯示，點開「檢核結果」才看得到底下所有品號。

# 主表格不做巢狀展開列（刻意簡化）

1.0 用 bootstrap-table 的 `exp` 展開箭頭，在列表裡巢狀顯示品號明細列。2.0 拿掉這層，
品號明細只在「檢核結果」modal 的卡片區呈現。純 UI 呈現簡化，資料完整性不受影響。

# 檢核 modal 開啟時自己重新查詢

`OrderCheckDetailModal` 不是被動吃父層傳進來的資料，而是在 `open`/`orderKey` 變動時
自己呼叫 `GetPOCheckView`（帶該訂單 `copSource`/`單別`/`單號`）與 `SP_GetCredit`（帶
客戶代號），對照舊版 `show_order_detail` 同時打兩支 API 的做法。這樣「執行檢核」/
「特規Pass」送出後，modal 可以直接重新查詢自己刷新，不用父層介入。

# 執行檢核 / 特規Pass：SP 是黑盒子，回傳字串含 "SUCCESS" 才算成功

`CheckCOPOrderInfo`／`COPOrderInfoPassCheck` 呼叫的 `prc_COPOrderChk`／`prc_COPPassCheck`
用 output 參數回一段訊息字串，**訊息裡有沒有出現 `"SUCCESS"` 子字串是唯一能判斷成敗的
方式**——這是 1.0 既有的判斷法，因為不能碰資料庫／SP，2.0 原封不動照抄，不是這裡新寫的
怪邏輯。`creditAvalAmt` 參數雖然有收在簽章上，但沒有真的傳進 SQL——1.0 本來就是這樣。

# 只顯示NG：改用品號自己的 FinFlag（修正 1.0 的失效判斷）

1.0 的「只顯示NG」checkbox 比對 `item.copPoCheck?.FinChk?.toLowerCase() == 'Y'`——
`toLowerCase()` 後永遠是小寫 `'y'`，跟大寫 `'Y'` 比對永遠不相等，導致這個判斷式永遠走
「NG」分支，checkbox 勾不勾其實都顯示全部卡片，等於這個功能在 1.0 是壞的。而且比對的
`copPoCheck.FinChk` 是**訂單層級**欄位，同一張訂單裡所有品號卡片都會拿到同一個值，
就算判斷式修好了也濾不出「哪個品號有問題」。

2.0 改用**品號自己的** `vPoDetail.finFlag`（`!= 'Y'` 才算 NG）過濾，這樣「只顯示NG」
才有意義：只留下該品號本身檢核未過的卡片。

# 檢核狀態徽章：17 個表頭欄位任一 NG 即 NG

`feFinChk()`（`app/utils/orderInfoVerify.ts`）判斷一張訂單的整體檢核狀態：17 個
`XxxChk` 欄位任一為 `N`→`N`，否則任一為 `P`（特規Pass）→`P`，否則 `Y`，完全沒有檢核
資料（`copPoCheck` 為 null）回 `null`（顯示「未檢核」），照抄 1.0
`get_FEFinCheck_pass_flag`/`set_FEFinCheck_pass_flag`。

# 金額欄位權限

`FunctionId.OrderInfoVerify(425)` 底下 `LinkType=100` 控制金額欄位（訂單金額、
交易條件），跟銷貨檢索/未完成訂單檢索共用同一個 `usePermission()` composable。
**匯出 Excel 的金額欄位權限也統一用 425**——1.0 匯出時查的其實是
`FunctionId.MixSalesShipping(410)` 的權限，但查詢 Excel 格式設定用的又是 425，兩個
FunctionId 對不上號，找不到明顯理由，2.0 統一用 425。

# Excel 匯出：改寫死格式，不吃 CMN_XlsFileFormat（刻意簡化）

1.0 用資料庫驅動的通用格式引擎（`CMN_XlsFileFormat` 資料表 + `XlsFormatterApis_Cmn`）
決定欄寬/表頭/樣式，那套引擎是給多個「還沒搬」的模組共用的排版基礎設施，只為這一個匯出
去搬整套 DB 驅動格式系統不成比例。2.0 直接在 C#（`OrderInfoVerifyApiController.Xls.cs`）
寫死欄位配置，輸出結果（`訂單總表` + 每張訂單一個 `訂單細項` 分頁、依檢核結果上色）
與 1.0 一致，只是格式設定不再走 DB。

上色規則（`ApplyRowColor`）：Y=淡綠 `#FF98FF98` / P=淡黃 `#FFFFC40C` / N=淡紅 `#FFFDBCB4` /
未檢核=灰 `#FFDCDCDC`，數值照抄 1.0。

# 頁面

| 路徑 | 對應舊畫面 | 說明 |
|---|---|---|
| `/sales-center/sales-search/order-info-verify` | `Mix/OrderInfoVerify` | 訂單資料檢核：未確認/已確認兩個頁籤 + 檢核 modal + 檢核條件 modal + Excel 匯出 |

# 尚未搬移

- `SP_GetCreditCRM`（幣別分開版本的信用額度查詢）：後端端點已搬，但前端沒有呼叫——
  比照 1.0，這支在 1.0 前端本身也沒被用到。
- 頁面級功能權限檢查（`MainApi/CheckUserPermission`）——跟其他業務檢索模組一樣，
  2.0 目前假設能進到路由就有權限。
- 訂單單別查詢欄位改成純文字輸入，不做動態下拉——1.0 該下拉的選項來源查無對應 API。
