# Tables/

這個目錄的 `*.sql` 是**產生物**，來源是 `scripts/extract.ps1`。

- **main branch 的內容 == 正式區 schema。** 不要把未上線欄位 merge 進 main。
- 要加新欄位：在 feature branch 直接編輯對應的 `CREATE TABLE`，
  跑 `scripts/publish.ps1 -Environment test -Execute` 推到測試區，
  功能驗完連同程式碼一起 merge，CI 再部署到正式區。
- 不要為了「同步一下」就從測試區重新 extract 蓋掉整包，
  那會把別人未上線的欄位一起吃進來 —— 這正是這套機制要解決的問題。

納管哪些表看 `../TABLES.txt`。
