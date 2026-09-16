<details>
  <summary>版號2026.09.16.0938</summary>

##### refactor: 群組預設功能套用改用跟編輯一致的樹狀元件
      permission-manager.vue 原本「群組預設功能編輯」用 PermissionTree 樹狀勾選，
      「群組預設功能套用」卻是另一種扁平勾選清單（只列出群組範本裡已勾的項目、
      看不到樹狀結構），同一頁兩種完全不同的互動方式。

      改成套用也開同一棵 PermissionTree，用第三組獨立的 selected/expanded
      （applySelected/applyExpanded），行為不變：預設帶入該群組範本、可再微調、
      按套用是聯集塞進目前這個人的樹（不覆蓋、不取消既有勾選），套用後仍要
      按「儲存」才寫進 M_Permission。

      移除的 applyItems/applyChecked/toggleApply 沒有其他地方在用。
</details>

<details>
  <summary>版號2026.09.14.2330</summary>

##### feat!: FunctionNo 改成 AAABBCC 格式（int -> varchar(8)）
      M_Function.FunctionNo 從 int 流水號改成看得出歸屬的定長字串：
        AAABBCC   AAA=SystemNo(3) BB=GroupNo(2) CC=序號(2)，欄位 varchar(8)
      定長的用意是字串排序等於「系統別 -> 群組 -> 序號」的正確順序。

        1   -> 0000101  權限管理      8   -> 0000102  人員管理
        16  -> 0070101  類別維護      17  -> 0070102  議題維護
        410 -> 0320101  銷貨檢索      420 -> 0320102  未完成訂單
        440 -> 0320103  客戶檢索      425 -> 0320201  訂單資料檢核

      序號依原本的 FunctionNo 由小到大編。對照表寫死在腳本裡，不用 ROW_NUMBER
      自動算——自動算會隨資料變動，一次性改號要能逐列審閱、重跑結果一致。

      database/FunctionNoFormatMigration.sql（新，測試區已執行）
        M_Function / M_Permission / M_PermissionGroup / H_FileLink 的欄位型別與值，
        外加把 M_PermissionLinkType 整張從 PRORIL_WEB 搬進新庫。
        會先備份成 *_bak_FunctionNo，且不可重入（偵測到已是 varchar 就擋下）。

      M_PermissionLinkType 被迫一起搬
        它原本是「留在 PRORIL_WEB 唯讀」（1.0 FileQueryApiController 還會 Add），
        但改號後跨庫對不起來（舊庫 int 17 vs 新庫 '0070102'），權限樹第三層與
        欄位級權限會整個斷掉。代價：1.0 之後在舊庫新增的細項不會自動同步。

      M_Permission 的 501 列「2.0 沒有頁面的功能」依指示保留，轉成舊數字字串；
      H_FileLink 429 列 17 -> 0070102，其他模組的列保留舊數字字串。

      程式碼
        api: FunctionIds 全部改成 const string、HasFunctionPermission /
             CheckUserPermissionLinkType / HasAmountPermission / SaveByFileName 的
             functionNo 參數改 string、SetPermissionTree 與 SaveDepFunction 的
             HashSet key 改 string、RetLinkType / UserFunctionViewModel /
             PermissionGroupViewModel 的 FunctionNo 改 string、
             M_PermissionLinkType 的 EF 對映從 ProrilWebDbContext 搬到 SalesCenterDbContext
        app: types/system.ts 各 functionNo 改 string、NAV_MODULES 的 functionNo 換新號、
             *_FUNCTION_NO 常數換新號、permissionTree.ts 的 Map/Set key 改 string
        PermissionMasterSeed.sql 同步改成建 varchar(8) 並輸出新號

      **PRORIL_WEB 完全沒動**，1.0 還在用 int。兩個庫的 FunctionNo 型別永久分岔，
      publish/drift 對快照庫一定會報這幾個欄位的差異，那是預期的，不要套用回去。

      踩到的坑：不要在 T-SQL 區塊註解裡寫出 / 緊接 * 的組合（例如檔案路徑萬用字元）。
      T-SQL 區塊註解可以巢狀，那會把後面的程式碼連同環境防呆一起吃掉，只冒一句
      Missing end comment mark 就繼續跑。第一次執行時 DB_NAME 檢查、
      DB_ID('PRORIL_WEB') 檢查、防重入檢查全部因此失效。

##### chore!: 清空 Proril_Sales_Center 的 M_User.Password
      45 列全部設成 NULL，備份在 dbo.M_User_bak_Password。

      前提是 2.0 的登入只走 SSO：login.vue 沒有帳密表單、前端完全沒有呼叫
      MainApi/Login，走的是 /api/auth/sso -> MainApi/LoginSso，而 LoginSso 只檢查
      X-Internal-Secret + 帳號存在 + IsEnable + 未鎖定，不看密碼。
      PRORIL_WEB.M_User 沒有動，1.0 的帳密登入不受影響。

      **留下的不一致（尚未處理）**：AddUser / ResetPassword 仍會寫 AES(帳號) 當密碼，
      在純 SSO 前提下沒有意義，新建的帳號反而會是唯一有密碼的。
      要嘛拿掉那兩段，要嘛連 MainApi/Login 一起下架。
</details>

<details>
  <summary>版號2026.09.14.2200</summary>

##### chore: 執行權限控管的資料庫復原，並修掉過程中發現的兩個腳本 bug
      在 Proril_Sales_Center（測試區 50002）實際跑完，現況：
        M_System 3 列 / M_Function 8 列 / M_User 45 列 /
        M_Permission 579 列 / M_PermissionGroup 52 列（表為新建）
      中文欄位比對 0 筆不一致，112012 的 IsAdmin 已讀得到。

      執行內容
        1. PermissionMasterSeed.sql（建 M_System + 灌 3 + 8 列）
        2. 直接用 Tables/M_PermissionGroup.sql 建那一張表——**刻意不跑整個
           publish.ps1**，它會把整份白名單套到這個庫，可能連帶 ALTER 到其他
           已經在用的表。只建缺的那一張風險最小。
        3. copy-snapshot-data.ps1 -Tables M_PermissionGroup -Execute（52 列）

      bug 1：PermissionMasterSeed.sql 沒有 BOM，sqlcmd 以 ANSI 讀檔
        中文註解被誤解讀，吃掉換行導致 SQL 斷句錯亂（Incorrect syntax near 'ID'），
        表建出來了但資料那段整段沒跑。已把檔案存成 UTF-8 with BOM
        （SSMS 也吃得下），用 sqlcmd 跑時另外建議加 -f 65001。

      bug 2：copy-snapshot-data.ps1 的 -Tables 完全沒生效
        PowerShell 變數不分大小寫，區域變數 $tables 跟參數 $Tables 是同一個，
        `$tables = Get-ManagedTables | ...` 直接把參數覆寫成完整白名單，
        過濾條件就變成「全部都符合」——指定一張表卻列出 20 張。
        區域變數改名 $managedTables，並在該處留了註解避免再犯。

      尚未完成：5211 的 API 還是舊 binary（GetMFunction 仍讀 PRORIL_WEB，
      GetUserFunctions 回 109 筆）。重啟後才會改讀新庫的 8 筆。
</details>

<details>
  <summary>版號2026.09.14.2100</summary>

##### fix: 權限清單回空陣列時整站靜默空白，補上說明
      現象：登入後側欄與業務中心首頁一張卡片都沒有，但 console 沒有任何 error、
      也沒有 toast，完全看不出發生什麼事。

      原因：GetUserFunctions 回的是 {isSuccess:true, body:[]}——「成功但這個人
      沒有任何權限」。useAppNavigation 的 fallback 只處理「API 失敗（null）」，
      空陣列照樣過濾，結果就是全部濾掉、畫面一片空白且無任何提示。

      修法：空陣列仍然照樣過濾（語意上就是「沒權限」，不該退回顯示全部），
      但新增 hasNoAccessibleModule，讓 sales-center/index.vue 與 layouts/default.vue
      顯示「目前沒有任何可用功能，請洽系統管理員開通權限」。

      觸發這次的實際資料狀況（不是程式 bug，是 DB 沒灌）：
      Proril_Sales_Center 的 M_User / M_Permission / M_Function 都是 0 列、
      M_System / M_PermissionGroup 連表都沒有，所以連 IsAdmin 的帳號都被當成沒權限。
      來源 PRORIL_WEB 是 45 / 579 / 90+ 列。推測是 2026-09-14 fix-collation.ps1
      重建表時沒把資料灌回。

##### fix: copy-snapshot-data.ps1 加 -Tables，避免補灌帳號權限時倒退業務議題資料
      要補灌 M_User/M_Permission 時才發現：這支腳本不加參數是**整批覆蓋白名單的
      每一張表**，包含 D_WorkProcess* / CRM_Customer / H_FileLink——那幾張在
      Proril_Sales_Center 已經是正式讀寫的資料，而來源 PRORIL_WEB 停在 2026-09-03
      的快照，跑下去等於把業務議題資料倒退回舊版本。

      新增 -Tables 參數限定範圍（會驗指定的表在白名單內），不指定時印出警告。
      database/README.md 的情境速查表也加了同樣的警語。

        .\copy-snapshot-data.ps1 -Environment test -Tables M_User,M_Permission -Execute
</details>

<details>
  <summary>版號2026.09.14.1930</summary>

##### feat: 功能主檔 M_System / M_Function 切到 Proril_Sales_Center（只搬 2.0 用得到的列）
      api/ 的 MSystems / MFunctions 從 ProrilWebDbContext 改成 SalesCenterDbContext，
      Entity 與對映搬到 api/Data/SalesCenter/。

      重點是**只複製 2.0 真的有頁面的那幾列**，不是整張表：
      PRORIL_WEB.M_Function 有 90+ 個功能，絕大多數是 2.0 還沒搬的模組（品異、託工、
      包裝、報價、庫存…），整份複製的話權限樹會長出一堆點下去 404 的功能。

      新庫只收 3 個系統別（0 系統設定 / 7 業務議題 / 32 業務檢索）與 8 個功能：
        1   權限管理      -> system/permission-manager
        8   人員管理      -> system/user-manager
        16  類別維護      -> sales-issue/kind-maintain
        17  議題維護      -> sales-issue/issues
        410 銷貨檢索      -> sales-search/shipping-inquiry
        420 未完成訂單    -> sales-search/unfinished-orders
        425 訂單資料檢核  -> sales-search/order-info-verify
        440 客戶檢索      -> sales-search/customer

      沒收的：101 格式匯入、199 測試區、18 議題檢視（aStatus=N 早已停用）、
      441 客戶相關資訊（1.0 註記無 UI 入口）、430 預估報價、460 成品報價。

      database/PermissionMasterSeed.sql（新）
        建表 + 從同 instance 的 PRORIL_WEB 複製那 11 列，可重複執行，最後自己驗中文。
        刻意不寫死值而是從 PRORIL_WEB SELECT，這樣正式區跑同一支腳本會拿到正式區的
        M_System.ImagePath（topbar 環境圖示就是靠這個欄位分辨正式/測試區）。

      踩到的兩個工具陷阱，都已處理：
        - copy-snapshot-data.ps1 是整批覆蓋，跑下去會把「只收 8 列」推翻。
          已加 $script:PartialRowTables = @('M_System','M_Function') 排除這兩張。
        - publish.ps1 會依 DACPAC 把 M_Function 建成 varchar，但 FunctionName/GroupName
          存了中文，在 Proril_Sales_Center 的 Latin1 collation 底下會變 ?。
          所以這兩張不要靠 publish 建，交給 seed 腳本（它把那兩欄開成 nvarchar）。
          PortingNotes.md 的 nvarchar 覆寫表從 7 個欄位變 9 個。

      TABLES.txt 20 -> 21 張（新增 M_System），Tables/M_System.sql 新增。

      M_PermissionLinkType 沒有跟著搬（1.0 FileQueryApiController 還會 Add），
      GetMPermissionLinkType 回全部的列，組樹時掛不到功能節點的會被 buildPermissionTree
      自動忽略。跟這 8 個功能有關的細項只有 4 列（17 的 SOP-新增/SOP-公開、
      410 與 420 的顯示金額欄位）。

      順帶記一個既有問題（不是這次搬壞的）：OrderInfoVerifyApiController 會檢查
      (functionNo 425, linkType 100) 的欄位級權限，但 M_PermissionLinkType 沒有這一列，
      權限樹上根本勾不到，只能靠 admin 或直接寫 DB。1.0 也是同樣狀況。

      **PermissionMasterSeed.sql 沒跑之前 2.0 是壞的**：api/ 已經改讀新庫的功能主檔，
      表還不存在的話側欄會空、topbar 環境圖示不見、權限樹長不出來。
</details>

<details>
  <summary>版號2026.09.14.1800</summary>

##### feat: 從 1.0 搬入權限控管（人員管理 / 權限管理）
      把 1.0「系統設定」底下的兩支畫面整組搬到 2.0，並把 M_User / M_Permission /
      M_PermissionGroup 從「唯讀留在 PRORIL_WEB」切成「api/ 打 SalesCenterDbContext
      讀寫 Proril_Sales_Center」。

      後端
        - api/Controllers/Shared/MainApiController.User.cs（新）
          GetUserSetting / AddUser / UpdateUser / DeleteUser / ResetPassword /
          UnlockUser / GetAllUserList
        - api/Controllers/Shared/MainApiController.SystemSetting.cs（新）
          GetMSystem / GetMFunction / GetMPermissionLinkType / GetPermissionLinkType /
          SetPermissionTree / SaveDepFunction / GetDepartmentList / GetUserFunctions
        - api/Controllers/Shared/CommonApiController.cs（新）GetDepFunction
        - BaseApiController 改成同時注入 ProrilWebDbContext + SalesCenterDbContext
          （帳號權限切庫後連 GetUserNameByToken / IsAdmin 都要走 scDb），
          並新增 HasFunctionPermission()：1.0 這些管理端點只掛 [Authorize]，
          擋在前端 checkPermission()，等於任何登入者打 API 就能建管理員帳號。
        - M_User/M_Permission 的 EF 對映從 ProrilWebDbContext 搬到 SalesCenterDbContext，
          新增 M_PermissionGroup；ProrilWebDbContext 改為只留唯讀的 M_System /
          M_Function / M_PermissionLinkType / M_Department。

      前端
        - app/pages/sales-center/system/user-manager.vue（新）
        - app/pages/sales-center/system/permission-manager.vue（新）
        - app/components/system/PermissionTree.vue（新，取代 1.0 的 fancytree）
        - app/utils/permissionTree.ts（新，組樹／勾選對映／存檔取值）
        - app/composables/useSystemSettingApi.ts（新）

      資料表歸屬
        只有「唯一應用層寫入者已經搬過來」的表才切連線。逐一 grep 1.0 全部 Controller
        核對後：M_PermissionLinkType 被 FileQueryApiController 寫、M_Department 被
        OrgApiController 寫、M_System/M_Function 沒有任何應用層寫入路徑，
        這四張維持唯讀打 PRORIL_WEB。詳見 logic.md 與 database/PortingNotes.md。

      與 1.0 的行為差異
        - 人員管理那幾支從裸 bool 改回 CustomApiViewModel 信封（失敗才有訊息可顯示）
        - 刪除帳號連同 M_Permission 一起刪（1.0 只刪 M_User，權限列變孤兒）
        - 新增 UnlockUser（1.0 的 IsLocked 畫面上解不開，只能進 DB 改）
        - 權限樹照 ParentLinkTypeID 巢狀（1.0 的 treeV2 忽略它、細項被攤平）
        - SetPermissionTree 改成算目標集合做差集（1.0 分四段條件、有重疊也有漏）

      未搬：登入失敗自動鎖定（要連 H_Logins 一起搬，屬登入流程）、
      1.0 已無畫面呼叫的舊權限端點、組織管理（M_Department 維護）。

##### feat: 側欄選單改成讀 DB 並依權限過濾
      原本 app/composables/useAppNavigation.ts 的 NAV_MODULES 是寫死的常數，
      跟 M_Permission 完全無關——權限管理勾了什麼不影響任何人看到的選單。

      改成：路由/icon/分組留在 NAV_MODULES（M_Function.Href 是 1.0 的網址對不上
      2.0 路由，且 DB 裡有一票 2.0 還沒搬的功能，照單全收會出現點下去 404 的項目），
      可見性與顯示名稱改由 MainApi/GetUserFunctions 決定（M_Function ∩ M_Permission，
      admin 全開）。每個項目補上 functionNo，模組底下一項都看不到時模組也不顯示。

      GetUserFunctions 打失敗時不過濾、退回顯示全部——真正的把關在後端。

      useAppNavigation 的 modules 因此從陣列變成 computed，
      app/layouts/default.vue 與 [module]/index.vue 一併調整
      （模組存不存在改看未過濾的 allModules，避免權限清單還沒載完就 404）。

      新增「系統管理」模組（systemNo 0），底下「權限控管」群組放這兩支畫面。

##### chore: database/ 把權限控管的 4 張表收進 DACPAC schema 版控
      TABLES.txt 從 16 張變 20 張，新增 M_Function / M_PermissionLinkType /
      M_PermissionGroup / M_Department，Tables/*.sql 比照 M_User/M_Permission
      手寫（沙盒連不到正式區，仍需人工跑 extract.ps1 驗證）。
      scaffold-sales-center.ps1 的 -ExcludeAuthTables 預設改為 $false。

      **收進版控不等於切連線**：只有 M_PermissionGroup 是 api/ 真的會寫的，
      另外三張純粹是讓結構跟著 branch 走。

      資料庫端還要人工執行 publish.ps1（建 M_PermissionGroup）與
      copy-snapshot-data.ps1（M_User/M_Permission 還停在 2026-09-03 的快照，
      不重灌的話 2.0 一切過去會看到過期的帳號權限），見 PortingNotes.md。
</details>
