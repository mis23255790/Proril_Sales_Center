/*
 * 未完成訂單檢索（SalesOrderUnFinishApi）用到的 View / 預存程序，
 * 從 PRORIL_WEB 搬到 Proril_Sales_Center。
 *
 * 背景：業務議題 8 張表 + M_User/M_Permission/H_FileLink/COP_CheckRule/COP_DepData
 * 已在 Proril_Sales_Center（見 PortingNotes.md）；訂單資料檢核那批由
 * OrderCheckObjectsMigration.sql 負責、銷貨檢索由 SalesShippingObjectsMigration.sql
 * 負責。這支腳本補上未完成訂單檢索的部分。
 *
 * 依賴關係是把兩支預存程序的定義逐行讀過得出的——兩支都是組字串再 EXEC sp_executesql，
 * sys.sql_expression_dependencies 對這種動態 SQL 查不出真正依賴（只會回一個沒有意義的
 * 系統物件 'A'），只能人工核對：
 *   - 0 張表。兩支 SP 都是純讀，資料來源是下面這個 View，不像銷貨檢索的
 *     COP_SalesOrder 那樣落地快取——V_UnfinOrder 每次查都直接打 ERP linked server，
 *     沒有「查詢其實會寫資料」的顧慮，也不用另外複製任何表的資料。
 *   - 1 個 View：V_UnfinOrder（UNION ALL 兩段，浦瑞 ERP 用 TWPR.dbo.COPTC/COPTD/CMSMQ、
 *     芳晟 ERP 用 PRORIL.dbo.COPTC/COPTD/CMSMQ，都 LEFT JOIN 鼎新的 MOCTA（計劃批號）/
 *     COPMA（客戶名稱）/CMSMV（業務名稱），以及 PRORIL_WEB.dbo.NPS_D_Order 取銘版序號）。
 *   - 2 個預存程序：prc_QueryUnfinOrder（依品號 TD004 分群，GetUnfinOrder 呼叫）、
 *     prc_QueryUnfinOrder_1（依訂單 TC001+TC002 分群，QueryUnfinOrder_1 呼叫，
 *     也是「單一訂單明細」modal 在用）。
 *
 * 特別注意：
 *   1. **V_UnfinOrder 對 PRORIL_WEB.dbo.NPS_D_Order 的參照刻意保留**，處理方式跟
 *      SalesShippingObjectsMigration.sql 對同一張表的做法一致：NPS_D_Order 屬於別的模組
 *      （1.0 的 sp_ImportPurchaseOrder 等在寫），這次不搬，兩個資料庫在同一個
 *      SQL Server instance，三段式跨庫查詢可行。哪天 NPS_D_Order 也搬過來，記得回頭
 *      把這個前綴拿掉。
 *   2. **沒有 collation 衝突，不需要 COLLATE DATABASE_DEFAULT**：跟
 *      SalesShippingObjectsMigration.sql 當時踩到的狀況不同——那支是本地快取表
 *      （建在目標資料庫、用目標資料庫定序）去 JOIN ERP linked server 欄位，兩側定序
 *      對不上。這裡完全沒有本地快取表，NPS_D_Order／ERP linked server 兩側欄位本來就都是
 *      Chinese_Taiwan_Stroke_BIN，跟 View 建在哪個資料庫無關；何況 Proril_Sales_Center
 *      現在定序也已經對齊同一個定序了（見 PortingNotes.md「定序已對齊」），連這層顧慮都不用有。
 *   3. **兩支 SP 完全不寫資料**：跟 prc_QuerySalesOrder(_1) 進來就先 EXEC
 *      prc_ImportSalesOrder 不同，這兩支單純查詢、無副作用。
 *   4. CREATE VIEW / CREATE PROCEDURE 全部改成 CREATE OR ALTER，可重複執行。
 *   5. 除了第 4 點，其餘與來源（PRORIL_WEB 目前的定義，2026-09-15 用
 *      OBJECT_DEFINITION 直接從資料庫撈出來）一字不差，沒有額外改寫。
 *
 * 怎麼執行：走 database/scripts/run-objects-migration.ps1（比照銷貨檢索/訂單資料檢核，
 * 不要直接把檔案丟進 SSMS 執行——那支 ps1 一律用 sqlcmd -f 65001，這支腳本雖然沒有
 * 中文字串常值，仍統一走同一套流程）：
 *
 *   .\scripts\run-objects-migration.ps1 -Script SalesOrderUnfinishObjectsMigration.sql -Environment snapshot
 *   .\scripts\run-objects-migration.ps1 -Script SalesOrderUnfinishObjectsMigration.sql -Environment snapshot -Execute
 *
 * 不加 -Execute 只做檢查：目標庫與這裡的 USE 對帳、linked server 在不在、
 * 物件現況、SET PARSEONLY ON 驗語法。
 *
 * 執行前建議：
 *   - 確認連到的是 Proril_Sales_Center（192.168.1.142,50002），不是 PRORIL_WEB。
 *   - 確認 instance 上的 linked server [192.168.1.200] 可用（V_UnfinOrder 靠它查
 *     鼎新 ERP 的 PRORIL / TWPR 兩個資料庫）。
 *   - 執行後把 api/Controllers/SalesSearch/SalesOrderUnFinishApiController.cs 的
 *     CallQueryUnfinOrder / CallQueryUnfinOrder1 確認是打 scDb（SalesCenterDbContext），
 *     不是 db（ProrilWebDbContext）。
 */

USE Proril_Sales_Center;
GO

-- ============================================================
-- 1. View：V_UnfinOrder
-- ============================================================

CREATE OR ALTER VIEW [dbo].[V_UnfinOrder]
AS


--查詢未完成訂單 -- 浦瑞
select DISTINCT '浦瑞ERP' COP_Source,MQ.MQ002,TC001,TC002,TD003,TC003,TC004 ,ISNULL(MA.MA002,'') MA002,TC006,
ISNULL(MV.MV002,'') MV002,TC010,TC014,TC016,TC019,TD004,TD005,TD006,TD008,TD010,TD011,
TD012,TC008,TC009,TC009*TD012 NTD,TD013,TD024,ISNULL(TA033,'') PlanNumber,ISNULL(TB.SerialNosJson,'') SerialNosJson,'N' FooterFlag
--  select DISTINCT TC.TC001,MQ.MQ002 ,COUNT(*)
 FROM [192.168.1.200].TWPR.dbo.COPTC TC
INNER JOIN [192.168.1.200].TWPR.dbo.COPTD TD ON TC.TC001 = TD.TD001 and TC.TC002 = TD.TD002
INNER JOIN [192.168.1.200].TWPR.dbo.CMSMQ MQ ON MQ.MQ001 = TC.TC001
LEFT join PRORIL_WEB.dbo.NPS_D_Order TB on TB.OrderType+'-'+ rtrim(TB.OrderNo)+TB.OrderSno = TD.TD001 + '-'+ RTRIM(TD.TD002) + TD.TD003
LEFT JOIN [192.168.1.200].PRORIL.dbo.MOCTA TA ON TA.TA026 = TC.TC001 AND TA.TA027 = TC.TC002 AND TA.TA028 = TD.TD003
LEFT JOIN [192.168.1.200].TWPR.dbo.COPMA MA ON MA.MA001 = TC.TC004
LEFT JOIN [192.168.1.200].PRORIL.dbo.CMSMV MV ON MV.MV001 = TC.TC006
WHERE 1=1
AND (TD.TD004 LIKE '5%' or  TD.TD004 LIKE 'x%')
and TC.TC027 = 'Y'
and TD.TD021 = 'Y'
and TD.TD016 = 'N'
and TC.TC001 LIKE '27%'

union all

select DISTINCT '芳晟ERP' COP_Source,MQ.MQ002 單別名稱,TC001 單別,TC002 單號,TD003 序號,TC003 訂單日期,TC004 客戶代號,ISNULL(MA.MA002,'') 客戶名稱,TC006 業務人員,
ISNULL(MV.MV002,'') 業務名稱,TC010 送貨地址,TC014 付款條件,TC016 課稅別,TC019 運輸方式,TD004 品號,TD005 品名,TD006 規格,TD008 訂單數量,TD010 單位,TD011 本幣單價,
TD012 本幣金額,TC008 幣別,TC009 匯率,TC009*TD012 台幣金額,TD013 預交日,TD024 贈品量,ISNULL(TA033,'') 計劃批號,ISNULL(TB.SerialNosJson,'') 銘版序號,'N' FooterFlag
--  select DISTINCT TC.TC001,MQ.MQ002 ,COUNT(*)
 FROM [192.168.1.200].PRORIL.dbo.COPTC TC
INNER JOIN [192.168.1.200].PRORIL.dbo.COPTD TD ON TC.TC001 = TD.TD001 and TC.TC002 = TD.TD002
INNER JOIN [192.168.1.200].PRORIL.dbo.CMSMQ MQ ON MQ.MQ001 = TC.TC001
LEFT join PRORIL_WEB.dbo.NPS_D_Order TB on TB.OrderType+'-'+ rtrim(TB.OrderNo)+TB.OrderSno = TD.TD001 + '-'+ RTRIM(TD.TD002) + TD.TD003
LEFT JOIN [192.168.1.200].PRORIL.dbo.MOCTA TA ON TA.TA026 = TC.TC001 AND TA.TA027 = TC.TC002 AND TA.TA028 = TD.TD003
LEFT JOIN [192.168.1.200].PRORIL.dbo.COPMA MA ON MA.MA001 = TC.TC004
LEFT JOIN [192.168.1.200].PRORIL.dbo.CMSMV MV ON MV.MV001 = TC.TC006
WHERE 1=1
AND (TD.TD004 LIKE '5%' or  TD.TD004 LIKE 'x%')
and TC.TC027 = 'Y'
and TD.TD021 = 'Y'
and TD.TD016 = 'N'
and TC.TC001 LIKE '22%'
GO

-- ============================================================
-- 2. 預存程序：prc_QueryUnfinOrder（依品號 TD004 分群）
-- ============================================================

-- =============================================
-- Author:		Name
-- Create date: 20241216
-- Description: 業務未完成訂單資料查詢
-- =============================================

CREATE OR ALTER PROCEDURE [dbo].[prc_QueryUnfinOrder]

@InCOP_Source nvarchar(10), -- 訂單來源
@InCustomerNo varchar(20), -- 客戶編號
@ProductNo_Type varchar(1), -- 品號類型 A:不選(全部記錄) 1:全選(目前只有5,x) 5:成品 x:非成品
@ProductNo varchar(40), -- 品號
@ProductName varchar(120), -- 品名
@ProductSpecification varchar(120), -- 規格
@StartDate varchar(40), -- 起始日期
@EndDate varchar(40), -- 終止日期
@DeliveryStartDate varchar(40), -- 預交起始日期
@DeliveryEndDate varchar(40), -- 預交終止日期
@SerialNo varchar(40), -- 銘版序號
@PoNo varchar(120), -- 訂單號
@InPlanNumber varchar(120), -- 計劃批號
@GroupType varchar(100), -- 統計群組類別
@GroupDesc varchar(10) -- 統計群組排序


AS
BEGIN
DECLARE



@ID int,
@CreateTime datetime,

@statement nvarchar(4000),
@where nvarchar(1000),
@orderby nvarchar(500),


@COP_Source nvarchar(10),
@MQ002 nvarchar(40),
@TC001 nchar(4),
@TC002 nchar(11),
@TC003 nvarchar(8),
@TC004 nvarchar(10),
@MA002 nvarchar(30),
@TC006 nvarchar(10),
@MV002 nvarchar(30),
@TC008 nvarchar(4),
@TC009 numeric(20, 9),
@TC010 nvarchar(255),
@TC014 nvarchar(16),
@TC016 nvarchar(1),
@TC019 nvarchar(1),
@TD003 nchar(4),
@TD004 nvarchar(40),
@TD005 nvarchar(120),
@TD006 nvarchar(120),
@TD008 numeric(16, 3),
@TD010 nvarchar(6),
@TD011 numeric(21, 6),
@TD012 numeric(21, 6),
@TD013 nvarchar(8),
@NTD numeric(38, 11) ,
@TD024 numeric(16, 3) ,

@PlanNumber nvarchar(120),
@SerialNosJson nvarchar(max),


@HeaderWrite varchar(1) ,
@FooterWrite varchar(1) ,
@FooterFlag varchar(1) ,
@GroupFlag varchar(1) ,

-- 加總計算
@RecCnt int,
@RecIdx int,
@SumQty numeric(16, 3),
@SumAmt numeric(16, 3),
@TotalQty numeric(16, 3),
@TotalAmt numeric(16, 3),
@SumProductNo varchar(40),


@ret VARCHAR(50)  --傳回結果

  BEGIN TRANSACTION
  --開啟交易

    -- 建立匯出使用的資料集
	CREATE TABLE [dbo].[#TmpDataSet](
		[ID] [int] IDENTITY(1,1) NOT NULL,
		[COP_Source] [varchar](7) NULL,
		[MQ002] [nvarchar](40) NULL,
		[TC001] [nchar](4) NOT NULL,
		[TC002] [nchar](11) NOT NULL,
		[TD003] [nchar](4) NOT NULL,
		[TC003] [nvarchar](8) NULL,
		[TC004] [nvarchar](10) NULL,
		[MA002] [nvarchar](30) NULL,
		[TC006] [nvarchar](10) NULL,
		[MV002] [nvarchar](30) NULL,
		[TC010] [nvarchar](255) NULL,
		[TC014] [nvarchar](16) NULL,
		[TC016] [nvarchar](1) NULL,
		[TC019] [nvarchar](1) NULL,
		[TD004] [nvarchar](40) NULL,
		[TD005] [nvarchar](120) NULL,
		[TD006] [nvarchar](120) NULL,
		[TD008] [numeric](16, 3) NULL,
		[TD010] [nvarchar](6) NULL,
		[TD011] [numeric](21, 6) NULL,
		[TD012] [numeric](21, 6) NULL,
		[TC008] [nvarchar](4) NULL,
		[TC009] [numeric](20, 9) NULL,
		[NTD] [numeric](38, 11) NULL,
		[TD013] [nvarchar](255) NULL,
		[TD024] [numeric](16, 3) NULL,
		[PlanNumber] [nvarchar](120) NULL,
		[SerialNosJson] [nvarchar](max) NULL,
        [FooterFlag] [varchar](1) null
		)


    BEGIN TRY

	  SET @CreateTime = GETDATE()

	  set @FooterFlag = 'N'

	  SET @statement = '
	    insert into #TmpDataSet (
		  COP_Source,MQ002,TC001,TC002,TD003,
		  TC003,TC004,MA002,TC006,MV002,
          TC010,TC014,TC016,TC019,TD004,
		  TD005,TD006,TD008,TD010,TD011,
		  TD012,TC008,TC009,NTD,TD013,
		  TD024,PlanNumber,SerialNosJson,FooterFlag)
        select DISTINCT
          COP_Source,MQ002,TC001,TC002,TD003,
		  TC003,TC004,MA002,TC006,MV002,
          TC010,TC014,TC016,TC019,TD004,
		  TD005,TD006,TD008,TD010,TD011,
		  TD012,TC008,TC009,NTD,TD013,
		  TD024,PlanNumber,SerialNosJson,FooterFlag
		from V_UnfinOrder VUO
	  '

      SET @where = ' WHERE 1 = 1 '
      SET @orderby = ''


      -- 取得查詢資料集

	    IF (ISNULL(@InCOP_Source,'') <> '')
		BEGIN
		  SET @where = @where + ' AND COP_Source = '''+ @InCOP_Source + ''''
		END

	    IF (ISNULL(@InCustomerNo,'') <> '')
		BEGIN
		  SET @where = @where + ' AND TC004 = '''+ @InCustomerNo + ''''
		END

		-- 品號類型 A:不選(全部記錄) 1:全選(目前只有5,x) 5:成品 x:非成品
	    IF (ISNULL(@ProductNo_Type,'A') <> 'A' and ISNULL(@ProductNo_Type,'A') <> 'a')
		BEGIN
		  SET @where = @where + ' AND TD004 LIKE  '''+ @ProductNo_Type + '%'' '
		END
		else
	    IF (ISNULL(@ProductNo_Type,'A') = 'a')
		BEGIN
--		  SET @where = @where + ' AND substring(TD004,1,1) in (''5'',''x'') '
		  SET @where = @where + ' AND (TD004 LIKE ''5%'' OR  TD004 LIKE ''x%'') '
		END

	    IF (ISNULL(@ProductNo,'') <> '')
		BEGIN
		  SET @where = @where + ' AND TD004 LIKE  ''%'+ @ProductNo + '%'' '
		END

	    IF (ISNULL(@ProductName,'') <> '')
		BEGIN
		  SET @where = @where + ' AND TD005 LIKE  ''%'+ @ProductName + '%'' '
		END

	    IF (ISNULL(@ProductSpecification,'') <> '')
		BEGIN
		  SET @where = @where + ' AND TD006 LIKE  ''%'+ @ProductSpecification + '%'' '
		END

--		PRINT @StartDate

	    IF (ISNULL(@StartDate,'') <> '')
		BEGIN
		  SET @where = @where +
--		  ' AND CONVERT(date,cast(SUBSTRING(TC002,1,3)+1911 as varchar(4))+SUBSTRING(TC002,4,4)) >= CONVERT(date,'''+ @StartDate + ''')'
		  ' AND CONVERT(date,TC003) >= CONVERT(date,'''+ @StartDate + ''')'
		END

	    IF (ISNULL(@EndDate,'') <> '')
		BEGIN
		  SET @where = @where +
--		  ' AND CONVERT(date,cast(SUBSTRING(TC002,1,3)+1911 as varchar(4))+SUBSTRING(TC002,4,4)) <= CONVERT(date,'''+ @EndDate + ''')'
		  ' AND CONVERT(date,TC003) <= CONVERT(date,'''+ @EndDate + ''')'
		END

		--@DeliveryStartDate varchar(40), -- 預交起始日期
		--@DeliveryEndDate varchar(40), -- 預交終止日期

	    IF (ISNULL(@DeliveryStartDate,'') <> '')
		BEGIN
		  SET @where = @where +
		  ' AND CONVERT(date,TD013) >= CONVERT(date,'''+ @DeliveryStartDate + ''')'
		END

	    IF (ISNULL(@DeliveryEndDate,'') <> '')
		BEGIN
		  SET @where = @where +
		  ' AND CONVERT(date,TD013) <= CONVERT(date,'''+ @DeliveryEndDate + ''')'
		END

	    IF (ISNULL(@SerialNo,'') <> '')
		BEGIN
		  SET @where = @where + ' AND SerialNosJson LIKE  ''%'+ @SerialNo + '%'' '
		END

	    IF (ISNULL(@PoNo,'') <> '')
		BEGIN
		  SET @where = @where + ' AND TC001 + ''-'' + TC002  LIKE ''%'+ @PoNo + '%'''
		END


	    IF (ISNULL(@InPlanNumber,'') <> '')
		BEGIN
		  SET @where = @where + ' AND PlanNumber LIKE ''%'+ @InPlanNumber + '%'''
		END


	    IF (ISNULL(@GroupType,'') <> '')
		BEGIN
		  SET @orderby = ' ORDER BY '+ @GroupType + ' ' + @GroupDesc
		END



        -- 寫入暫存檔做為計算及整理使用

       SET @statement = @statement + @where + @orderby

       PRINT 'STATEMENT: ' + @statement

--	   DECLARE crs CURSOR FOR

       EXEC sp_executesql @statement

	   SELECT * into #tmpVUO FROM  #TmpDataSet

	   delete from #TmpDataSet

--	  select * from #tmpVUO

--    drop table #tmpVUO

--    drop table [#SalesOrder]

		-- 按群組計算統計資料

		-- 逐筆寫入並產生Footer

          DECLARE CRS CURSOR FOR
		  select
          COP_Source,MQ002,TC001,TC002,TD003,
		  TC003,TC004,MA002,TC006,MV002,
          TC010,TC014,TC016,TC019,TD004,
		  TD005,TD006,TD008,TD010,TD011,
		  TD012,TC008,TC009,NTD,TD013,
		  TD024,PlanNumber,SerialNosJson,FooterFlag
		  FROM #tmpVUO
		  order by ID

			OPEN CRS
			FETCH NEXT FROM CRS INTO
			  @COP_Source,@MQ002,@TC001,@TC002,@TD003,
			  @TC003,@TC004,@MA002,@TC006,@MV002,
			  @TC010,@TC014,@TC016,@TC019,@TD004,
			  @TD005,@TD006,@TD008,@TD010,@TD011,
			  @TD012,@TC008,@TC009,@NTD,@TD013,
			  @TD024,@PlanNumber,@SerialNosJson,@FooterFlag

			set @SumProductNo = ''
			set @RecCnt = 0
			set @RecIdx = 0
			set @SumQty = 0
			set @SumAmt = 0
			set @TotalQty = 0
			set @TotalAmt = 0
			set @FooterWrite = 'N'
			set @FooterFlag = 'N'
            set @GroupFlag = 'N'


--TD008          	訂單數量	N	16.3	訂單數量 //950808 S00-9508031 N11.3-> N16.3
--TD009          	已交數量	N	16.3	已交數量 //950808 S00-9508031 N11.3-> N16.3
--TD010          	單位	V	6.0	單位  //981125 S07-971110003 C4->C6
--TD011          	單價	N	21.6	單價  //901008 S06-9006006 N13.4->N15.6//950808 S00-9508031 N15.6->N21.6
--TD012          	金額	N	21.6	金額  //950808 S00-9508031 N13.2->N21.6


			while(@@fetch_status != -1)
			begin
			  -- 總數計算
			  SET @TotalQty = @TotalQty + @TD008
			  SET @TotalAmt = @TotalAmt + @NTD

    	      SET @SumQty = @SumQty + @TD008
              SET @SumAmt = @SumAmt + @NTD

                -- 寫入記錄
				insert into #TmpDataSet (
				  COP_Source,MQ002,TC001,TC002,TD003,
				  TC003,TC004,MA002,TC006,MV002,
				  TC010,TC014,TC016,TC019,TD004,
				  TD005,TD006,TD008,TD010,TD011,
				  TD012,TC008,TC009,NTD,TD013,
				  TD024,PlanNumber,SerialNosJson,FooterFlag)
				select
				  @COP_Source,@MQ002,@TC001,@TC002,@TD003,
				  @TC003,@TC004,@MA002,@TC006,@MV002,
				  @TC010,@TC014,@TC016,@TC019,@TD004,
				  @TD005,@TD006,@TD008,@TD010,@TD011,
				  @TD012,@TC008,@TC009,@NTD,@TD013,
				  @TD024,@PlanNumber,@SerialNosJson,@FooterFlag

        	   SET @RecIdx = @RecIdx + 1

			  print @TD004

			   SELECT @RecCnt = count(*) FROM #tmpVUO
				WHERE 1=1
				AND TD004 = @TD004

               print @RecCnt
               print @RecIdx


--			   if (@RecCnt > 1  AND @SumProductNo <> @TH004)
			   if (@RecCnt > 1  AND @RecIdx = @RecCnt)
               begin
                   set @GroupFlag = 'Y'

                   print '@SumProductNo : ' +  @SumProductNo

                   print '@TD004 : ' +  @TD004

					set @FooterFlag = 'Y'
					set @FooterWrite = 'Y'

					-- 產生Footer記錄
					insert into #TmpDataSet (
				  COP_Source,MQ002,TC001,TC002,TC003,
				  TC004,MA002,TC006,MV002,TC010,
				  TC014,TC016,TC019,TD003,TD004,
				  TD005,TD006,TD008,TD010,TD011,
				  TD012,TC008,TC009,NTD,TD013,
				  TD024,PlanNumber,SerialNosJson,FooterFlag)
/*
 '芳晟ERP' COP_Source,MQ.MQ002 單別名稱,TC001 單別,TC002 單號,TC003 訂單日期,
 TC004 客戶代號,MA.MA002 客戶名稱,TC006 業務人員,ISNULL(MV.MV002,'') 業務名稱,TC010 送貨地址,
 TC014 付款條件,TC016 課稅別,TC019 運輸方式,TD003 序號,TD004 品號,
 TD005 品名,TD006 規格,TD008 訂單數量,TD010 單位,TD011 本幣單價,
 TD012 本幣金額,TC008 幣別,TC009 匯率,TC009*TD012 台幣金額,TD013 預交日,
 TD024 贈品量,'N' FooterFlag
*/
					select
					'Footer','','','','',
					'','','','','',
					'','','','',@SumProductNo,
					@TD005,@TD006,@SumQty,@TD010,0,
					0,'',0,@SumAmt,'',
					0,'','',@FooterFlag

				    set @RecIdx = 0
					set @SumQty = 0
					set @SumAmt = 0
					set @SumProductNo = @TD004
					set @FooterWrite = 'N'
					set @FooterFlag = 'N'

                end
				else
			    if (@RecCnt = 1 )
                begin
                    print '@RecCnt = 1'

				    set @RecIdx = 0
					set @SumQty = 0
					set @SumAmt = 0
					set @SumProductNo = @TD004
					set @FooterWrite = 'N'
					set @FooterFlag = 'N'
--					set @FooterFlag = 'S'
			    end

				set @SumProductNo = @TD004

                print 'set @SumProductNo = @TD004'



				FETCH NEXT FROM CRS INTO
				  @COP_Source,@MQ002,@TC001,@TC002,@TD003,
				  @TC003,@TC004,@MA002,@TC006,@MV002,
				  @TC010,@TC014,@TC016,@TC019,@TD004,
				  @TD005,@TD006,@TD008,@TD010,@TD011,
				  @TD012,@TC008,@TC009,@NTD,@TD013,
				  @TD024,@PlanNumber,@SerialNosJson,@FooterFlag


			end
			-- 產生Total記錄
					insert into #TmpDataSet (
				  COP_Source,MQ002,TC001,TC002,TC003,
				  TC004,MA002,TC006,MV002,TC010,
				  TC014,TC016,TC019,TD003,TD004,
				  TD005,TD006,TD008,TD010,TD011,
				  TD012,TC008,TC009,NTD,TD013,
				  TD024,PlanNumber,SerialNosJson,FooterFlag)
/*
 '芳晟ERP' COP_Source,MQ.MQ002 單別名稱,TC001 單別,TC002 單號,TC003 訂單日期,
 TC004 客戶代號,MA.MA002 客戶名稱,TC006 業務人員,ISNULL(MV.MV002,'') 業務名稱,TC010 送貨地址,
 TC014 付款條件,TC016 課稅別,TC019 運輸方式,TD003 序號,TD004 品號,
 TD005 品名,TD006 規格,TD008 訂單數量,TD010 單位,TD011 本幣單價,
 TD012 本幣金額,TC008 幣別,TC009 匯率,TC009*TD012 台幣金額,TD013 預交日,
 TD024 贈品量,'N' FooterFlag
*/
					select
					'','','','','',
					'','','','','',
					'','','','','Total',
					'','',@TotalQty,'',0,
					0,'',0,@TotalAmt,'',
					0,'','','Y'

			close CRS
			deallocate CRS

       -- 群組條件下單一記錄填入 S

	   UPDATE A SET FooterFlag = 'S'
	   -- select *
		from #TmpDataSet A
		INNER JOIN (
			select TD004,COUNT(*) CNT from #TmpDataSet
			where 1=1
			AND FooterFlag <> 'Y'
			group by TD004 having COUNT(*) =1
			) B ON B.TD004 = A.TD004


---	   drop table tmp_SalesOrder

--	   select * into tmp_SalesOrder from #SalesOrder order by ID
	   select * from #TmpDataSet order by ID

--	    SET  @ret = 'SUCCESS'


	  DROP TABLE  #tmpVUO

	  DROP TABLE #TmpDataSet

      COMMIT

	END TRY

	BEGIN CATCH

--		SET  @ret = 'error'
		ROLLBACK;

		PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR(MAX));
		PRINT 'Error Message: ' + ERROR_MESSAGE();

    END CATCH

--    SET  @result = @ret

--    PRINT @result


END
GO

-- ============================================================
-- 3. 預存程序：prc_QueryUnfinOrder_1（依訂單 TC001+TC002 分群）
-- ============================================================

-- =============================================
-- Author:		Name
-- Create date: 20241223
-- Description: 業務未完成訂單資料查詢,訂單單號為統計群組
-- =============================================

CREATE OR ALTER PROCEDURE [dbo].[prc_QueryUnfinOrder_1]

@InCOP_Source nvarchar(10), -- 訂單來源
@InCustomerNo varchar(20), -- 客戶編號
@ProductNo_Type varchar(1), -- 品號類型 A:不選(全部記錄) 1:全選(目前只有5,x) 5:成品 x:非成品
@ProductNo varchar(40), -- 品號
@ProductName varchar(120), -- 品名
@ProductSpecification varchar(120), -- 規格
@StartDate varchar(40), -- 起始日期
@EndDate varchar(40), -- 終止日期
@DeliveryStartDate varchar(40), -- 預交起始日期
@DeliveryEndDate varchar(40), -- 預交終止日期
@SerialNo varchar(40), -- 銘版序號
@PoNo varchar(120), -- 訂單號
@InPlanNumber varchar(120), -- 計劃批號
@GroupType varchar(100), -- 統計群組類別
@GroupDesc varchar(10) -- 統計群組排序


AS
BEGIN
DECLARE



@ID int,
@CreateTime datetime,

@statement nvarchar(4000),
@where nvarchar(1000),
@orderby nvarchar(500),


@COP_Source nvarchar(10),
@MQ002 nvarchar(40),
@TC001 nchar(4),
@TC002 nchar(11),
@TC003 nvarchar(8),
@TC004 nvarchar(10),
@MA002 nvarchar(30),
@TC006 nvarchar(10),
@MV002 nvarchar(30),
@TC008 nvarchar(4),
@TC009 numeric(20, 9),
@TC010 nvarchar(255),
@TC014 nvarchar(16),
@TC016 nvarchar(1),
@TC019 nvarchar(1),
@TD003 nchar(4),
@TD004 nvarchar(40),
@TD005 nvarchar(120),
@TD006 nvarchar(120),
@TD008 numeric(16, 3),
@TD010 nvarchar(6),
@TD011 numeric(21, 6),
@TD012 numeric(21, 6),
@TD013 nvarchar(8),
@NTD numeric(38, 11) ,
@TD024 numeric(16, 3) ,

@PlanNumber nvarchar(120),
@SerialNosJson nvarchar(max),

@HeaderWrite varchar(1) ,
@FooterWrite varchar(1) ,
@FooterFlag varchar(1) ,
@GroupFlag varchar(1) ,

-- 加總計算
@RecCnt int,
@RecIdx int,
@SumQty numeric(16, 3),
@SumAmt numeric(16, 3),
@TotalQty numeric(16, 3),
@TotalAmt numeric(16, 3),
@SumNo varchar(40),


@ret VARCHAR(50)  --傳回結果

  BEGIN TRANSACTION
  --開啟交易

    -- 建立匯出使用的資料集
	CREATE TABLE [dbo].[#TmpDataSet_1](
		[ID] [int] IDENTITY(1,1) NOT NULL,
		[COP_Source] [varchar](7) NULL,
		[MQ002] [nvarchar](40) NULL,
		[TC001] [nchar](4) NOT NULL,
		[TC002] [nchar](11) NOT NULL,
		[TD003] [nchar](4) NOT NULL,
		[TC003] [nvarchar](8) NULL,
		[TC004] [nvarchar](10) NULL,
		[MA002] [nvarchar](30) NULL,
		[TC006] [nvarchar](10) NULL,
		[MV002] [nvarchar](30) NULL,
		[TC010] [nvarchar](255) NULL,
		[TC014] [nvarchar](16) NULL,
		[TC016] [nvarchar](1) NULL,
		[TC019] [nvarchar](1) NULL,
		[TD004] [nvarchar](40) NULL,
		[TD005] [nvarchar](120) NULL,
		[TD006] [nvarchar](120) NULL,
		[TD008] [numeric](16, 3) NULL,
		[TD010] [nvarchar](6) NULL,
		[TD011] [numeric](21, 6) NULL,
		[TD012] [numeric](21, 6) NULL,
		[TC008] [nvarchar](4) NULL,
		[TC009] [numeric](20, 9) NULL,
		[NTD] [numeric](38, 11) NULL,
		[TD013] [nvarchar](255) NULL,
		[TD024] [numeric](16, 3) NULL,
		[PlanNumber] [nvarchar](120) NULL,
		[SerialNosJson] [nvarchar](max) NULL,
        [FooterFlag] [varchar](1) null
		)


    BEGIN TRY

	  SET @CreateTime = GETDATE()

	  set @FooterFlag = 'N'

	  SET @statement = '
	    insert into #TmpDataSet_1 (
		  COP_Source,MQ002,TC001,TC002,TD003,
		  TC003,TC004,MA002,TC006,MV002,
          TC010,TC014,TC016,TC019,TD004,
		  TD005,TD006,TD008,TD010,TD011,
		  TD012,TC008,TC009,NTD,TD013,
		  TD024,PlanNumber,SerialNosJson,FooterFlag)
        select DISTINCT
          COP_Source,MQ002,TC001,TC002,TD003,
		  TC003,TC004,MA002,TC006,MV002,
          TC010,TC014,TC016,TC019,TD004,
		  TD005,TD006,TD008,TD010,TD011,
		  TD012,TC008,TC009,NTD,TD013,
		  TD024,PlanNumber,SerialNosJson,FooterFlag
		from V_UnfinOrder VUO
	  '

      SET @where = ' WHERE 1 = 1 '
      SET @orderby = ''


      -- 取得查詢資料集

	    IF (ISNULL(@InCOP_Source,'') <> '')
		BEGIN
		  SET @where = @where + ' AND COP_Source = '''+ @InCOP_Source + ''''
		END

	    IF (ISNULL(@InCustomerNo,'') <> '')
		BEGIN
		  SET @where = @where + ' AND TC004 = '''+ @InCustomerNo + ''''
		END

		-- 品號類型 A:不選(全部記錄) 1:全選(目前只有5,x) 5:成品 x:非成品
	    IF (ISNULL(@ProductNo_Type,'A') <> 'A' and ISNULL(@ProductNo_Type,'A') <> 'a')
		BEGIN
		  SET @where = @where + ' AND TD004 LIKE  '''+ @ProductNo_Type + '%'' '
		END
		else
	    IF (ISNULL(@ProductNo_Type,'A') = 'a')
		BEGIN
--		  SET @where = @where + ' AND substring(TD004,1,1) in (''5'',''x'') '
		  SET @where = @where + ' AND (TD004 LIKE ''5%'' OR  TD004 LIKE ''x%'') '
		END

	    IF (ISNULL(@ProductNo,'') <> '')
		BEGIN
		  SET @where = @where + ' AND TD004 LIKE  ''%'+ @ProductNo + '%'' '
		END

	    IF (ISNULL(@ProductName,'') <> '')
		BEGIN
		  SET @where = @where + ' AND TD005 LIKE  ''%'+ @ProductName + '%'' '
		END

	    IF (ISNULL(@ProductSpecification,'') <> '')
		BEGIN
		  SET @where = @where + ' AND TD006 LIKE  ''%'+ @ProductSpecification + '%'' '
		END

--		PRINT @StartDate

	    IF (ISNULL(@StartDate,'') <> '')
		BEGIN
		  SET @where = @where +
--		  ' AND CONVERT(date,cast(SUBSTRING(TC002,1,3)+1911 as varchar(4))+SUBSTRING(TC002,4,4)) >= CONVERT(date,'''+ @StartDate + ''')'
		  ' AND CONVERT(date,TC003) >= CONVERT(date,'''+ @StartDate + ''')'
		END

	    IF (ISNULL(@EndDate,'') <> '')
		BEGIN
		  SET @where = @where +
--		  ' AND CONVERT(date,cast(SUBSTRING(TC002,1,3)+1911 as varchar(4))+SUBSTRING(TC002,4,4)) <= CONVERT(date,'''+ @EndDate + ''')'
		  ' AND CONVERT(date,TC003) <= CONVERT(date,'''+ @EndDate + ''')'
		END

		--@DeliveryStartDate varchar(40), -- 預交起始日期
		--@DeliveryEndDate varchar(40), -- 預交終止日期

	    IF (ISNULL(@DeliveryStartDate,'') <> '')
		BEGIN
		  SET @where = @where +
		  ' AND CONVERT(date,TD013) >= CONVERT(date,'''+ @DeliveryStartDate + ''')'
		END

	    IF (ISNULL(@DeliveryEndDate,'') <> '')
		BEGIN
		  SET @where = @where +
		  ' AND CONVERT(date,TD013) <= CONVERT(date,'''+ @DeliveryEndDate + ''')'
		END

	    IF (ISNULL(@SerialNo,'') <> '')
		BEGIN
		  SET @where = @where + ' AND SerialNosJson LIKE  ''%'+ @SerialNo + '%'' '
		END

	    IF (ISNULL(@PoNo,'') <> '')
		BEGIN
		  SET @where = @where + ' AND TC001 + ''-'' + TC002  LIKE ''%'+ @PoNo + '%'''
		END


	    IF (ISNULL(@InPlanNumber,'') <> '')
		BEGIN
		  SET @where = @where + ' AND PlanNumber LIKE ''%'+ @InPlanNumber + '%'''
		END


	    IF (ISNULL(@GroupType,'') <> '')
		BEGIN
--		  SET @orderby = ' ORDER BY '+ @GroupType + ' ' + @GroupDesc
		  SET @orderby = ' ORDER BY TC002,TC001,TD003 '
		END


        -- 寫入暫存檔做為計算及整理使用

       SET @statement = @statement + @where + @orderby

       PRINT 'STATEMENT: ' + @statement

--	   DECLARE crs CURSOR FOR

       EXEC sp_executesql @statement

	   SELECT * into #tmpVUO_1 FROM  #TmpDataSet_1

	   delete from #TmpDataSet_1

--	  select * from #tmpVUO_1

--    drop table #tmpVUO_1

--    drop table [#SalesOrder]

		-- 按群組計算統計資料

		-- 逐筆寫入並產生Footer

          DECLARE CRS CURSOR FOR
		  select
          COP_Source,MQ002,TC001,TC002,TD003,
		  TC003,TC004,MA002,TC006,MV002,
          TC010,TC014,TC016,TC019,TD004,
		  TD005,TD006,TD008,TD010,TD011,
		  TD012,TC008,TC009,NTD,TD013,
		  TD024,PlanNumber,SerialNosJson,FooterFlag
		  FROM #tmpVUO_1
		  order by ID

			OPEN CRS
			FETCH NEXT FROM CRS INTO
			  @COP_Source,@MQ002,@TC001,@TC002,@TD003,
			  @TC003,@TC004,@MA002,@TC006,@MV002,
			  @TC010,@TC014,@TC016,@TC019,@TD004,
			  @TD005,@TD006,@TD008,@TD010,@TD011,
			  @TD012,@TC008,@TC009,@NTD,@TD013,
			  @TD024,@PlanNumber,@SerialNosJson,@FooterFlag

			set @SumNo = ''
			set @RecCnt = 0
			set @RecIdx = 0
			set @SumQty = 0
			set @SumAmt = 0
			set @TotalQty = 0
			set @TotalAmt = 0
			set @FooterWrite = 'N'
			set @FooterFlag = 'N'
            set @GroupFlag = 'N'


--TD008          	訂單數量	N	16.3	訂單數量 //950808 S00-9508031 N11.3-> N16.3
--TD009          	已交數量	N	16.3	已交數量 //950808 S00-9508031 N11.3-> N16.3
--TD010          	單位	V	6.0	單位  //981125 S07-971110003 C4->C6
--TD011          	單價	N	21.6	單價  //901008 S06-9006006 N13.4->N15.6//950808 S00-9508031 N15.6->N21.6
--TD012          	金額	N	21.6	金額  //950808 S00-9508031 N13.2->N21.6


			while(@@fetch_status != -1)
			begin
			  -- 總數計算
			  SET @TotalQty = @TotalQty + @TD008
			  SET @TotalAmt = @TotalAmt + @NTD

    	      SET @SumQty = @SumQty + @TD008
              SET @SumAmt = @SumAmt + @NTD

                -- 寫入記錄
				insert into #TmpDataSet_1 (
				  COP_Source,MQ002,TC001,TC002,TD003,
				  TC003,TC004,MA002,TC006,MV002,
				  TC010,TC014,TC016,TC019,TD004,
				  TD005,TD006,TD008,TD010,TD011,
				  TD012,TC008,TC009,NTD,TD013,
				  TD024,PlanNumber,SerialNosJson,FooterFlag)
				select
				  @COP_Source,@MQ002,@TC001,@TC002,@TD003,
				  @TC003,@TC004,@MA002,@TC006,@MV002,
				  @TC010,@TC014,@TC016,@TC019,@TD004,
				  @TD005,@TD006,@TD008,@TD010,@TD011,
				  @TD012,@TC008,@TC009,@NTD,@TD013,
				  @TD024,@PlanNumber,@SerialNosJson,@FooterFlag

        	   SET @RecIdx = @RecIdx + 1

			  print @TD004

			   SELECT @RecCnt = count(*) FROM #tmpVUO_1
				WHERE 1=1
				AND TC001 = @TC001
				AND TC002 = @TC002

               print @RecCnt
               print @RecIdx


--			   if (@RecCnt > 1  AND @SumProductNo <> @TH004)
			   if (@RecCnt > 1  AND @RecIdx = @RecCnt)
               begin
                   set @GroupFlag = 'Y'

                   print '@SumNo : ' +  @SumNo

                   print '@TC001 : ' +  @TC001 + ' ' + @TC002

					set @FooterFlag = 'Y'
					set @FooterWrite = 'Y'

					-- 產生Footer記錄
					insert into #TmpDataSet_1 (
				  COP_Source,MQ002,TC001,TC002,TC003,
				  TC004,MA002,TC006,MV002,TC010,
				  TC014,TC016,TC019,TD003,TD004,
				  TD005,TD006,TD008,TD010,TD011,
				  TD012,TC008,TC009,NTD,TD013,
				  TD024,PlanNumber,SerialNosJson,FooterFlag)
/*
 '芳晟ERP' COP_Source,MQ.MQ002 單別名稱,TC001 單別,TC002 單號,TC003 訂單日期,
 TC004 客戶代號,MA.MA002 客戶名稱,TC006 業務人員,ISNULL(MV.MV002,'') 業務名稱,TC010 送貨地址,
 TC014 付款條件,TC016 課稅別,TC019 運輸方式,TD003 序號,TD004 品號,
 TD005 品名,TD006 規格,TD008 訂單數量,TD010 單位,TD011 本幣單價,
 TD012 本幣金額,TC008 幣別,TC009 匯率,TC009*TD012 台幣金額,TD013 預交日,
 TD024 贈品量,'N' FooterFlag
*/
					select
					@COP_Source,@MQ002,@TC001,@TC002,@TC003,
					@TC004,@MA002,@TC006,@MV002,@TC010,
					@TC014,@TC016,@TC019,'','',
					'','',@SumQty,'',0,
					0,'',0,@SumAmt,@TD013,
					0,@PlanNumber,@SerialNosJson,@FooterFlag

				    set @RecIdx = 0
					set @SumQty = 0
					set @SumAmt = 0
					set @SumNo = @TC001 + @TC002
					set @FooterWrite = 'N'
					set @FooterFlag = 'N'

                end
				else
			    if (@RecCnt = 1 )
                begin
                    print '@RecCnt = 1'

				    set @RecIdx = 0
					set @SumQty = 0
					set @SumAmt = 0
					set @SumNo = @TC001 + @TC002
					set @FooterWrite = 'N'
					set @FooterFlag = 'N'
--					set @FooterFlag = 'S'
			    end

				set @SumNo = @TC001 + @TC002

                print 'set @SumNo = @SumNo'

				FETCH NEXT FROM CRS INTO
				  @COP_Source,@MQ002,@TC001,@TC002,@TD003,
				  @TC003,@TC004,@MA002,@TC006,@MV002,
				  @TC010,@TC014,@TC016,@TC019,@TD004,
				  @TD005,@TD006,@TD008,@TD010,@TD011,
				  @TD012,@TC008,@TC009,@NTD,@TD013,
				  @TD024,@PlanNumber,@SerialNosJson,@FooterFlag

			end
			-- 產生Total記錄
					insert into #TmpDataSet_1 (
				  COP_Source,MQ002,TC001,TC002,TC003,
				  TC004,MA002,TC006,MV002,TC010,
				  TC014,TC016,TC019,TD003,TD004,
				  TD005,TD006,TD008,TD010,TD011,
				  TD012,TC008,TC009,NTD,TD013,
				  TD024,PlanNumber,SerialNosJson,FooterFlag)
/*
 '芳晟ERP' COP_Source,MQ.MQ002 單別名稱,TC001 單別,TC002 單號,TC003 訂單日期,
 TC004 客戶代號,MA.MA002 客戶名稱,TC006 業務人員,ISNULL(MV.MV002,'') 業務名稱,TC010 送貨地址,
 TC014 付款條件,TC016 課稅別,TC019 運輸方式,TD003 序號,TD004 品號,
 TD005 品名,TD006 規格,TD008 訂單數量,TD010 單位,TD011 本幣單價,
 TD012 本幣金額,TC008 幣別,TC009 匯率,TC009*TD012 台幣金額,TD013 預交日,
 TD024 贈品量,'N' FooterFlag
*/
					select
					'','','','Total','',
					'','','','','',
					'','','','','',
					'','',@TotalQty,'',0,
					0,'',0,@TotalAmt,'',
					0,'','','Y'

			close CRS
			deallocate CRS

       -- 群組條件下單一記錄填入 S

	   UPDATE A SET FooterFlag = 'S'
	   -- select *
		from #TmpDataSet_1 A
		INNER JOIN (
			select TC001,TC002,COUNT(*) CNT from #TmpDataSet_1
			where 1=1
			AND FooterFlag <> 'Y'
			group by TC001,TC002 having COUNT(*) =1
			) B ON B.TC001 = A.TC001 and B.TC002 = A.TC002


---	   drop table tmp_SalesOrder

--	   select * into TmpDataSet from #TmpDataSet_1 order by ID
	   select * from #TmpDataSet_1 order by ID

--	    SET  @ret = 'SUCCESS'


	  DROP TABLE  #tmpVUO_1

	  DROP TABLE #TmpDataSet_1

      COMMIT

	END TRY

	BEGIN CATCH

--		SET  @ret = 'error'
		ROLLBACK;

		PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR(MAX));
		PRINT 'Error Message: ' + ERROR_MESSAGE();

    END CATCH

--    SET  @result = @ret

--    PRINT @result


END
GO
