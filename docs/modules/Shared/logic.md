<details>
  <summary>程式邏輯</summary>

###### 對應舊系統
     PRORIL (.NET MVC) 的 M_Function / M_Permission 權限模型
       Controllers/MainApiController.cs（登入、帳號、IsAdmin）
       Controllers/System/MainApiController_SystemSetting.cs（權限維護畫面，寫 M_Permission）

###### 相關資料表
     M_User        帳號主檔
     M_Function    功能主檔
     M_Permission  帳號 ←→ 功能 權限對照
</details>

# 權限管控：維持集中式，不要拆到各功能自己判斷

1.0 的功能權限（誰能用哪個功能）集中在 `M_Function`/`M_Permission`，由後台「系統設定」
畫面（`MainApiController_SystemSetting.cs`）維護，各業務 Controller 只是查這兩張表
判斷能不能執行。2.0 依模組拆成 `api/Controllers/{模組}/` 之後，**權限判斷邏輯本身
不要跟著拆到各模組自己重寫一份**：

- `M_Permission` 已確認目前是 1.0 後台在寫（見 [CLAUDE.md](../../../CLAUDE.md) 資料庫
  遷移段落），維護權限的人還是透過 1.0 畫面操作。只要那支維護畫面沒有一起搬過來，
  2.0 所有模組都只是讀取端，就該讀同一份權限來源，不要各自兜邏輯——否則 1.0 那邊
  改了權限，2.0 各模組會漏改，或是各自實作出不一致的判斷方式。
- 現況 `BaseApiController.IsAdmin()`（`api/Controllers/Shared/BaseApiController.cs`）
  只做到 `M_User.IsAdmin` 這個粗粒度判斷，還沒接回細粒度的 `M_Function`/`M_Permission`
  查詢。之後哪個模組需要細粒度權限，邏輯加在 `BaseApiController` 或一支共用的
  `PermissionService`，不要在各模組的 Controller 裡各自查 `M_Permission`。

**Tradeoff**：集中式代表 2.0 短期內權限管理 UI 還是得依賴 1.0（管理者仍要回 1.0 改
權限）。等哪天權限維護畫面也搬進 2.0、`M_Function`/`M_Permission` 交給 2.0 自己寫，
再一次把資料來源從讀 `PRORIL_WEB` 切成讀 `Proril_Sales_Center`，而不是現在就分散到
各功能各自接。
