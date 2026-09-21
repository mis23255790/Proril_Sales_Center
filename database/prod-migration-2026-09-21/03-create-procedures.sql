CREATE OR ALTER FUNCTION [dbo].[fu_RemoveParentheses]
(
    @InputString NVARCHAR(MAX) -- 輸入的字串
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    WHILE CHARINDEX('(', @InputString) > 0 AND CHARINDEX(')', @InputString) > CHARINDEX('(', @InputString)
    BEGIN
        SET @InputString = STUFF(
            @InputString,
            CHARINDEX('(', @InputString),
            CHARINDEX(')', @InputString) - CHARINDEX('(', @InputString) + 1,
            ''
        );
    END;

    RETURN @InputString;
END;
GO

CREATE OR ALTER PROCEDURE [dbo].[prc_COPGetCredit]

@InCustNo varchar(40), -- 客戶代號
@Executor varchar(40) -- 執行人員

AS
BEGIN


DECLARE

@MA065 varchar(50) = '',
@MA014 varchar(50) = '',

@NotifyAmt numeric (16,3) = 0, --  訂貨(出貨通知)金額
@OrderAmt numeric (16,3) = 0, --  未出貨訂單總金額
@OrderAmtRate numeric (16,6) = 0, --  未出貨訂單金額比率
@ReceivableSumAmt numeric (16,3) = 0, --  應收合計金額
@ReceivableAmt numeric (16,3) = 0, --  應收金額
@GainAmt numeric (16,3) = 0, --  已出貨抵預收金額
@UnbilledAmt numeric (16,3) = 0, --  未結帳銷貨
@PreGainAmt numeric (16,3) = 0, --  預收金額
@AvailableAmt numeric (16,3) = 0, --  信用餘額
@AvailableSetAmt numeric (16,3) = 0, --  信用可超出額


@Memo varchar(500),
@aStatus varchar(1),

@RET VARCHAR(50),

@Field NVARCHAR(50),
@Value NVARCHAR(50),
@where NVARCHAR(500),
@statement NVARCHAR(500),

@CreateTime datetime


  SET @CreateTime = GETDATE()

  BEGIN TRANSACTION
  --開啟交易

    BEGIN TRY

  --程式邏輯:
  --  1.未出貨訂單金額比率 分為總公司請款及個別請款兩類
  --    總公司請款旗標為COPMA.MA066 = Y
  --    判斷是否為[信用額度依總公司控管]
  --    按照此旗標分成兩個取得可用額度的邏輯,各自取值
  --  2.訂貨(出貨通知)金額 = 未出貨訂單總金額 * 未出貨訂單金額比率
  --  3.應收合計金額 = 應收金額 + 已出貨抵預收金額 + 未結帳銷貨 - 預收金額 + 訂貨(出貨通知)金額
  --  4.信用餘額 = 設定額度金額 - 應收合計金額

-- MA065          	總店號	V	10.0	總店的代號
-- MA066          	總公司請款	V	1.0	Y/N
-- MA082          	信用額度依總公司控管	V	1.0	Y/N[DEF:"N"] //890801

      -- 1.判斷是否為[信用額度依總公司控管]
		select @MA065 = case when MA065 = '' then @InCustNo else MA065 end,@MA014 = MA014 from [192.168.1.200].TWPR.dbo.COPMA MA
		where 1=1
		and MA066 = 'Y'
		and MA082 = 'Y'
    	AND (MA001 = @InCustNo OR (MA065 = @InCustNo AND MA082 = 'Y' ))


		print @MA065

		if (@MA065 <> '') -- 歸總公司控管客戶
		begin
            -- 2.訂貨(出貨通知)金額 = 未出貨訂單總金額 * 未出貨訂單金額比率
			--@OrderAmt numeric (16,3) = 0, --  未出貨訂單總金額

			select @NotifyAmt = ISNULL(SUM((TD008-TD009) * TD011 * MA.MA094),0)
			FROM [192.168.1.200].TWPR.dbo.COPTD TD
			INNER JOIN [192.168.1.200].TWPR.dbo.COPTC TC ON TC.TC001 = TD.TD001 and TC.TC002 = TD.TD002
			LEFT JOIN ( SELECT MA.MA001,MA.MA082,CASE WHEN MA.MA082 = 'Y' THEN MA.MA065 ELSE MA.MA001 END MA065,CASE WHEN MA.MA082 = 'Y' THEN MA1.MA094 ELSE MA.MA094 END MA094  FROM  [192.168.1.200].TWPR.dbo.COPMA MA
							   LEFT JOIN [192.168.1.200].TWPR.dbo.COPMA MA1 ON MA.MA082 = 'Y' AND MA1.MA001 = MA.MA065) MA ON MA.MA001 = TC.TC004
			WHERE 1=1
			and TC.TC027 = 'Y' and TD.TD021 = 'Y' and TD.TD016 = 'N'
			AND MA.MA065 = @MA065
			and ((TD.TD001 >= '2702' and TD.TD001 <= '2798') or (TD.TD001 = '2210'))
			AND TD008<>TD009

			PRINT '@NotifyAmt = ' + CAST(@NotifyAmt AS VARCHAR(100))

			select @OrderAmtRate = MA.MA094, @OrderAmt = SUM((TD008-TD009) * TD011)
			FROM [192.168.1.200].TWPR.dbo.COPTD TD
			INNER JOIN [192.168.1.200].TWPR.dbo.COPTC TC ON TC.TC001 = TD.TD001 and TC.TC002 = TD.TD002
			LEFT JOIN ( SELECT MA.MA001,MA.MA082,CASE WHEN MA.MA082 = 'Y' THEN MA.MA065 ELSE MA.MA001 END MA065,CASE WHEN MA.MA082 = 'Y' THEN MA1.MA094 ELSE MA.MA094 END MA094  FROM  [192.168.1.200].TWPR.dbo.COPMA MA
							   LEFT JOIN [192.168.1.200].TWPR.dbo.COPMA MA1 ON MA.MA082 = 'Y' AND MA1.MA001 = MA.MA065) MA ON MA.MA001 = TC.TC004
			WHERE 1=1
			and TC.TC027 = 'Y' and TD.TD021 = 'Y' and TD.TD016 = 'N'
			AND MA.MA065 = @MA065
			and ((TD.TD001 >= '2702' and TD.TD001 <= '2798') or (TD.TD001 = '2210'))
			AND TD008<>TD009
			GROUP BY MA.MA065,MA.MA094


            --  3.應收合計金額 = 應收金額 - 預收金額 + 已出貨抵預收金額 + 未結帳銷貨  + 訂貨(出貨通知)金額
			-- 應收金額
		    SELECT @ReceivableAmt = ISNULL(sum(TA029+TA030-TA031-TA047),0)
			FROM [192.168.1.200].TWPR.dbo.ACRTA ACRTA
			INNER JOIN [192.168.1.200].TWPR.dbo.COPMA COPMA ON MA001=TA004
			LEFT JOIN [192.168.1.200].TWPR.dbo.CMSMQ CMSMQ ON MQ001=TA001
			LEFT JOIN [192.168.1.200].TWPR.dbo.CMSMF CMSMF ON MF001=TA009
			WHERE 1=1
			AND TA025='Y'
			AND TA027='N'
			AND TA019='N'
			AND (MA001 = @MA065 OR (MA065 = @MA065 AND MA082 = 'Y' ))
			and TA001 IN ('6111','6112','6601')

			PRINT '@ReceivableAmt = ' + CAST(@ReceivableAmt AS VARCHAR(100))

			-- 預收金額
		    SELECT @PreGainAmt = ISNULL(sum(TA029),0)
			FROM [192.168.1.200].TWPR.dbo.ACRTA ACRTA
			INNER JOIN [192.168.1.200].TWPR.dbo.COPMA COPMA ON MA001=TA004
			LEFT JOIN [192.168.1.200].TWPR.dbo.CMSMQ CMSMQ ON MQ001=TA001
			LEFT JOIN [192.168.1.200].TWPR.dbo.CMSMF CMSMF ON MF001=TA009
			WHERE 1=1
			AND TA025='Y'
			AND TA027='N'
			AND TA019='N'
			AND (MA001 = @MA065 OR (MA065 = @MA065 AND MA082 = 'Y' ))
			and TA001 IN ('6212')

			PRINT '@PreGainAmt = ' + CAST(@PreGainAmt AS VARCHAR(100))

			-- 已出貨抵預收金額
		    SELECT @GainAmt = ISNULL(sum(TA031),0)
			FROM [192.168.1.200].TWPR.dbo.ACRTA ACRTA
			INNER JOIN [192.168.1.200].TWPR.dbo.COPMA COPMA ON MA001=TA004
			LEFT JOIN [192.168.1.200].TWPR.dbo.CMSMQ CMSMQ ON MQ001=TA001
			LEFT JOIN [192.168.1.200].TWPR.dbo.CMSMF CMSMF ON MF001=TA009
			WHERE 1=1
			AND TA025='Y'
			AND TA027='N'
			AND TA019='N'
			AND (MA001 = @MA065 OR (MA065 = @MA065 AND MA082 = 'Y'))
			and TA001 IN ('6212')

			PRINT '@GainAmt = ' + CAST(@GainAmt AS VARCHAR(100))

			-- 未結帳銷貨
			SELECT @UnbilledAmt = ISNULL(SUM(DISTINCT TH.TH035),0)
			FROM [192.168.1.200].TWPR.dbo.COPTH TH
			LEFT JOIN [192.168.1.200].TWPR.dbo.COPTG TG ON TG.TG001 = TH.TH001 AND TG.TG002 = TH.TH002
			INNER JOIN [192.168.1.200].TWPR.dbo.COPMA MA ON MA.MA001 = TG.TG004
			WHERE 1=1
			AND TH.TH020 = 'Y'
			AND TH.TH026 = 'N'
			AND (MA001 = @MA065 OR (MA065 = @MA065 AND MA082 = 'Y'))

			PRINT '@UnbilledAmt = ' + CAST(@UnbilledAmt AS VARCHAR(100))

			SET @ReceivableSumAmt = @ReceivableAmt - @PreGainAmt + @GainAmt + @UnbilledAmt + @NotifyAmt

			PRINT '@ReceivableSumAmt = ' + CAST(@ReceivableSumAmt AS VARCHAR(100))

			--  4.信用餘額 = 設定額度金額 - 應收合計金額
			-- ERP設定額度金額
			SELECT @AvailableSetAmt = MA033 * (1+MA034),@MA014 = MA014 FROM [192.168.1.200].TWPR.dbo.COPMA
			where 1=1
			and MA001 = @MA065

			PRINT '@AvailableSetAmt = ' + CAST(@AvailableSetAmt AS VARCHAR(100))

			set @AvailableAmt = @AvailableSetAmt - @ReceivableSumAmt

			PRINT '@AvailableAmt = ' + CAST(@AvailableAmt AS VARCHAR(100))
		end
		else
		begin
            print '111'

            -- 2.訂貨(出貨通知)金額 = 未出貨訂單總金額 * 未出貨訂單金額比率
			select @NotifyAmt = ISNULL(SUM((TD008-TD009) * TD011 * MA.MA094),0)
			FROM [192.168.1.200].TWPR.dbo.COPTD TD
			INNER JOIN [192.168.1.200].TWPR.dbo.COPTC TC ON TC.TC001 = TD.TD001 and TC.TC002 = TD.TD002
			LEFT JOIN ( SELECT MA.MA001,MA.MA082,CASE WHEN MA.MA082 = 'Y' THEN MA.MA065 ELSE MA.MA001 END MA065,CASE WHEN MA.MA082 = 'Y' THEN MA1.MA094 ELSE MA.MA094 END MA094  FROM  [192.168.1.200].TWPR.dbo.COPMA MA
						LEFT JOIN [192.168.1.200].TWPR.dbo.COPMA MA1 ON MA.MA082 = 'Y' AND MA1.MA001 = MA.MA065) MA ON MA.MA001 = TC.TC004
			WHERE 1=1
			and TC.TC027 = 'Y' and TD.TD021 = 'Y' and TD.TD016 = 'N'
			AND MA.MA065 = @InCustNo
			and ((TD.TD001 >= '2702' and TD.TD001 <= '2798') or (TD.TD001 = '2210'))
			AND TD008<>TD009

			select @OrderAmtRate = MA.MA094, @OrderAmt = SUM((TD008-TD009) * TD011)
			FROM [192.168.1.200].TWPR.dbo.COPTD TD
			INNER JOIN [192.168.1.200].TWPR.dbo.COPTC TC ON TC.TC001 = TD.TD001 and TC.TC002 = TD.TD002
			LEFT JOIN ( SELECT MA.MA001,MA.MA082,CASE WHEN MA.MA082 = 'Y' THEN MA.MA065 ELSE MA.MA001 END MA065,CASE WHEN MA.MA082 = 'Y' THEN MA1.MA094 ELSE MA.MA094 END MA094  FROM  [192.168.1.200].TWPR.dbo.COPMA MA
							   LEFT JOIN [192.168.1.200].TWPR.dbo.COPMA MA1 ON MA.MA082 = 'Y' AND MA1.MA001 = MA.MA065) MA ON MA.MA001 = TC.TC004
			WHERE 1=1
			and TC.TC027 = 'Y' and TD.TD021 = 'Y' and TD.TD016 = 'N'
			AND MA.MA065 = @InCustNo
			and ((TD.TD001 >= '2702' and TD.TD001 <= '2798') or (TD.TD001 = '2210'))
			AND TD008<>TD009
			GROUP BY MA.MA065,MA.MA094

			PRINT '@NotifyAmt = ' + CAST(@NotifyAmt AS VARCHAR(100))

            --  3.應收合計金額 = 應收金額 - 預收金額 + 已出貨抵預收金額 + 未結帳銷貨  + 訂貨(出貨通知)金額
		    SELECT @ReceivableAmt = ISNULL(sum(TA029+TA030-TA031-TA047),0)
			FROM [192.168.1.200].TWPR.dbo.ACRTA ACRTA
			INNER JOIN [192.168.1.200].TWPR.dbo.COPMA COPMA ON MA001=TA004
			LEFT JOIN [192.168.1.200].TWPR.dbo.CMSMQ CMSMQ ON MQ001=TA001
			LEFT JOIN [192.168.1.200].TWPR.dbo.CMSMF CMSMF ON MF001=TA009
			WHERE 1=1
			AND TA025='Y'
			AND TA027='N'
			AND TA019='N'
			AND (MA001 = @InCustNo OR (MA065 = @InCustNo AND MA082 = 'Y' ))
			and TA001 IN ('6111','6112','6601')

			PRINT '@ReceivableAmt = ' + CAST(@ReceivableAmt AS VARCHAR(100))

			-- 預收金額
		    SELECT @PreGainAmt = ISNULL(sum(TA029),0)
			FROM [192.168.1.200].TWPR.dbo.ACRTA ACRTA
			INNER JOIN [192.168.1.200].TWPR.dbo.COPMA COPMA ON MA001=TA004
			LEFT JOIN [192.168.1.200].TWPR.dbo.CMSMQ CMSMQ ON MQ001=TA001
			LEFT JOIN [192.168.1.200].TWPR.dbo.CMSMF CMSMF ON MF001=TA009
			WHERE 1=1
			AND TA025='Y'
			AND TA027='N'
			AND TA019='N'
			AND (MA001 = @InCustNo OR (MA065 = @InCustNo AND MA082 = 'Y' ))
			and TA001 IN ('6212')

			PRINT '@PreGainAmt = ' + CAST(@PreGainAmt AS VARCHAR(100))

			-- 已出貨抵預收金額
		    SELECT @GainAmt = ISNULL(sum(TA031),0)
			FROM [192.168.1.200].TWPR.dbo.ACRTA ACRTA
			INNER JOIN [192.168.1.200].TWPR.dbo.COPMA COPMA ON MA001=TA004
			LEFT JOIN [192.168.1.200].TWPR.dbo.CMSMQ CMSMQ ON MQ001=TA001
			LEFT JOIN [192.168.1.200].TWPR.dbo.CMSMF CMSMF ON MF001=TA009
			WHERE 1=1
			AND TA025='Y'
			AND TA027='N'
			AND TA019='N'
			AND (MA001 = @InCustNo OR (MA065 = @InCustNo AND MA082 = 'Y'))
			and TA001 IN ('6212')

			PRINT '@GainAmt = ' + CAST(@GainAmt AS VARCHAR(100))

			-- 未結帳銷貨
			SELECT @UnbilledAmt = ISNULL(SUM(DISTINCT TH.TH035),0)
			FROM [192.168.1.200].TWPR.dbo.COPTH TH
			LEFT JOIN [192.168.1.200].TWPR.dbo.COPTG TG ON TG.TG001 = TH.TH001 AND TG.TG002 = TH.TH002
			INNER JOIN [192.168.1.200].TWPR.dbo.COPMA MA ON MA.MA001 = TG.TG004
			WHERE 1=1
			AND TH.TH020 = 'Y'
			AND TH.TH026 = 'N'
			AND (MA001 = @InCustNo OR (MA065 = @InCustNo AND MA082 = 'Y'))

			PRINT '@UnbilledAmt = ' + CAST(@UnbilledAmt AS VARCHAR(100))

			SET @ReceivableSumAmt = @ReceivableAmt - @PreGainAmt + @GainAmt + @UnbilledAmt + @NotifyAmt

			PRINT '@ReceivableSumAmt = ' + CAST(@ReceivableSumAmt AS VARCHAR(100))

			--  4.信用餘額 = 設定額度金額 - 應收合計金額

			-- ERP設定額度金額
			SELECT @AvailableSetAmt = MA033 * (1+MA034),@MA014 = MA014 FROM [192.168.1.200].TWPR.dbo.COPMA
			where 1=1
			and MA001 = @InCustNo

			PRINT '@AvailableSetAmt = ' + CAST(@AvailableSetAmt AS VARCHAR(100))

			set @AvailableAmt = @AvailableSetAmt - @ReceivableSumAmt

			PRINT '@AvailableAmt = ' + CAST(@AvailableAmt AS VARCHAR(100))

		end

  --  2.訂貨(出貨通知)金額 = 未出貨訂單總金額 * 未出貨訂單金額比率
  --    @NotifyAmt = @OrderAmt * @OrderAmtRate
  --  3.應收合計金額 = 應收金額 - 預收金額 + 已出貨抵預收金額 + 未結帳銷貨  + 訂貨(出貨通知)金額
  --    @ReceivableSumAmt = @ReceivableAmt - @PreGainAmt + @GainAmt + @UnbilledAmt + @NotifyAmt
  --  4.信用餘額 = 設定額度金額 - 應收合計金額
  --    @AvailableAmt = @AvailableSetAmt - @ReceivableSumAmt

        INSERT INTO COP_AvailableAmt (
          CustNo,OrderChkNo,NotifyAmt,OrderAmt,OrderAmtRate,
		  ReceivableSumAmt,ReceivableAmt,GainAmt,UnbilledAmt,PreGainAmt,
		  AvailableAmt,AvailableSetAmt,Memo,aStatus,Creator,CreateTime)
		select
          @InCustNo,'',@NotifyAmt,@OrderAmt,@OrderAmtRate,
		  @ReceivableSumAmt,@ReceivableAmt,@GainAmt,@UnbilledAmt,@PreGainAmt,
		  @AvailableAmt,@AvailableSetAmt,'','Y',@Executor,@CreateTime

		select @ReceivableAmt as 應收金額,@UnbilledAmt as 未結帳銷貨,@NotifyAmt as 訂貨出貨通知金額,@PreGainAmt as 預收金額,@GainAmt as 已出貨抵預收金額,
		       @ReceivableSumAmt as 應收合計金額,@OrderAmt as 未出貨訂單總金額,@OrderAmtRate as 未出貨訂單金額比率,
			   @AvailableSetAmt as 信用可超出額,@AvailableAmt as 信用餘額

       COMMIT


	END TRY

	BEGIN CATCH

		ROLLBACK;

		PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR(MAX));
		PRINT 'Error Message: ' + ERROR_MESSAGE();

    END CATCH


END
GO

CREATE OR ALTER PROCEDURE [dbo].[prc_COPGetCredit_CRM]

@InCustNo varchar(40), -- 客戶代號
@Executor varchar(40) -- 執行人員

AS
BEGIN


DECLARE

@MA065 varchar(50) = '',
@MA014 varchar(50) = '',

@NotifyAmt numeric (16,3) = 0,
@OrderAmt numeric (16,3) = 0,
@OrderAmtRate numeric (16,6) = 0,
@ReceivableSumAmt numeric (16,3) = 0,
@ReceivableAmt numeric (16,3) = 0,
@GainAmt numeric (16,3) = 0,
@UnbilledAmt numeric (16,3) = 0,
@PreGainAmt numeric (16,3) = 0,
@AvailableAmt numeric (16,3) = 0,
@AvailableSetAmt numeric (16,3) = 0,


@Memo varchar(500),
@aStatus varchar(1),

@RET VARCHAR(50),

@Field NVARCHAR(50),
@Value NVARCHAR(50),
@where NVARCHAR(500),
@statement NVARCHAR(500),
@CreateTime datetime


  SET @CreateTime = GETDATE()

    BEGIN TRANSACTION
  --開啟交易

    BEGIN TRY

		SELECT @MA014 = MA014 FROM [192.168.1.200].TWPR.dbo.COPMA
		where 1=1
		and MA001 = @InCustNo

      print 'exec prc_COPGetCredit'

	  -- 呼叫[prc_COPGetCredit] 取得相關金額
	  -- 建立暫存表來存放結果
	  CREATE TABLE #TempCreditData (
		應收金額 numeric (16,3),
		未結帳銷貨  numeric (16,3),
		訂貨出貨通知金額  numeric (16,3),
		預收金額  numeric (16,3),
		已出貨抵預收金額  numeric (16,3),
		應收合計金額  numeric (16,3),
	    未出貨訂單總金額  numeric (16,3),
		未出貨訂單金額比率  numeric (16,6),
		信用可超出額  numeric (16,3),
		信用餘額  numeric (16,3)
        );

	  INSERT INTO #TempCreditData
	  exec prc_COPGetCredit @InCustNo, @Executor

	  select 應收金額,未結帳銷貨,訂貨出貨通知金額,預收金額,已出貨抵預收金額,
             應收合計金額,未出貨訂單總金額,未出貨訂單金額比率,
		     信用可超出額,信用餘額,@MA014 AS 幣別  FROM #TempCreditData

      -- 清除暫存表
	  DROP TABLE #TempCreditData;



       COMMIT


	END TRY

	BEGIN CATCH

		ROLLBACK;

		PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR(MAX));
		PRINT 'Error Message: ' + ERROR_MESSAGE();

    END CATCH


END
GO

CREATE OR ALTER PROCEDURE [dbo].[prc_ProductChk_COP]

@ChkType varchar(20), -- 檢核類別  A:全部成品,P:品號檢核,訂單檢核序號:訂單檢核(例:20250205002)
@ChkSource varchar(40), -- 訂單檢核:傳入訂單單號, 功能檢核:傳入功能代碼,例: BomQuery
@ERPSource varchar(40), -- ERP資料庫別 '芳晟ERP' OR '浦瑞ERP'
@InProductNo varchar(40), -- 檢核品號
@Executor varchar(40), -- 執行人員
@result VARCHAR(40) OUTPUT    --傳回結果



AS
BEGIN
DECLARE
@TotalNum INT,
@TotalNum_E INT,
@TotalNum_S INT,
@Num INT,
@MB001 NVARCHAR(20),
@MB002 NVARCHAR(120),
@MB003 NVARCHAR(120),
@TmpStr NVARCHAR(120),
@ValStr NVARCHAR(50),
@TmpIdx INT,
@ProductNo NVARCHAR(20),
@ProductName NVARCHAR(120),
@ProductSpec NVARCHAR(120),
@ProductName_EN NVARCHAR(120),
@ProductSpec_EN NVARCHAR(120),

@C01 NVARCHAR(50),
@C02 NVARCHAR(50),
@C03 NVARCHAR(50),
@C04 NVARCHAR(50),
@C05 NVARCHAR(50),
@C06 NVARCHAR(50),
@C07 NVARCHAR(50),
@C08 NVARCHAR(50),
@C09 NVARCHAR(50),
@C10 NVARCHAR(50),
@C11 NVARCHAR(50),
@C12 NVARCHAR(50),

@E01 NVARCHAR(50),
@E02 NVARCHAR(50),
@E03 NVARCHAR(50),
@E04 NVARCHAR(50),
@E05 NVARCHAR(50),
@E06 NVARCHAR(50),
@E07 NVARCHAR(50),
@E08 NVARCHAR(50),
@E09 NVARCHAR(50),
@E10 NVARCHAR(50),
@E11 NVARCHAR(50),
@E12 NVARCHAR(50),

@NoChk NVARCHAR(10),
@PHChk NVARCHAR(10),
@HZChk NVARCHAR(10),
@StartChk NVARCHAR(10),
@VolChk NVARCHAR(10),
@FloatChk NVARCHAR(10),
@WireSpecChk NVARCHAR(10),
@WireSizeChk NVARCHAR(10),
@PlusChk NVARCHAR(10),
@Ext1Chk NVARCHAR(10),
@Ext2Chk NVARCHAR(10),
@Ext3Chk NVARCHAR(10),

@FinChk NVARCHAR(10),

@ModelName_Spec NVARCHAR(50),

@ModelName NVARCHAR(50),
@Phase NVARCHAR(20),
@Frequency NVARCHAR(20),
@Voltage NVARCHAR(20),

@ChkNo varchar(20),

@OrderChkNo varchar(20),

@Memo NVARCHAR(500),

@CreateTime datetime




  SET @CreateTime = GETDATE()

  BEGIN TRANSACTION
  --開啟交易

    BEGIN TRY

    -- 品名拆解後各項目的暫存資料檔
	CREATE TABLE [dbo].[#TmpDataSet](
		[ID] [int] IDENTITY(1,1) NOT NULL,
		[ProductNo] [nvarchar](120) NULL,
		[ProductName] [nvarchar](120) NULL,
		[Specification] [nvarchar](120) NULL,
		[ProductName_E] [nvarchar](120) NULL,
		[Specification_E] [nvarchar](120) NULL,
		[FType] [nvarchar](50) NULL,
		[F01] [nvarchar](50) NULL,
		[F02] [nvarchar](50) NULL,
		[F03] [nvarchar](50) NULL,
		[F04] [nvarchar](50) NULL,
		[F05] [nvarchar](50) NULL,
		[F06] [nvarchar](50) NULL,
		[F07] [nvarchar](50) NULL,
		[F08] [nvarchar](50) NULL,
		[F09] [nvarchar](50) NULL,
		[F10] [nvarchar](50) NULL,
		[F11] [nvarchar](50) NULL,
		[F12] [nvarchar](50) NULL
		)


    	--  取得品號相關資料
        IF (@ERPSource = '芳晟ERP')
		BEGIN
			SELECT @ProductName = RTRIM(MB.MB002),
				   @ProductSpec = RTRIM(MB.MB003),
				   @ProductName_EN = RTRIM(MV.MV003),
				   @ProductSpec_EN = RTRIM(MV.MV004)
			FROM [192.168.1.200].PRORIL.dbo.INVMB MB
			LEFT JOIN [192.168.1.200].PRORIL.dbo.INVMV MV ON MV.MV001 = MB.MB001
			WHERE 1=1
			AND MB.MB001 = @InProductNo
        END
        ELSE
		BEGIN
			SELECT @ProductName = RTRIM(MB.MB002),
				   @ProductSpec = RTRIM(MB.MB003),
				   @ProductName_EN = RTRIM(MV.MV003),
				   @ProductSpec_EN = RTRIM(MV.MV004)
			FROM [192.168.1.200].TWPR.dbo.INVMB MB
			LEFT JOIN [192.168.1.200].TWPR.dbo.INVMV MV ON MV.MV001 = MB.MB001
			WHERE 1=1
			AND MB.MB001 = @InProductNo
         END
      --程式邏輯:
      --1.先比對所有項目是否符合
      --2.按照項目數量及內容判斷項目類型,將比對結果寫入適當的旗標
      --  其中8項的有兩種不同組合,必須特別判斷

      --1.先比對所有項目是否符合
        -- 解析中文品名
		SET @Num =1
		SET @TmpStr = @ProductName
        SET @TotalNum = (LEN(RTRIM(@TmpStr)) - LEN(REPLACE(RTRIM(@TmpStr),'，',''))) / LEN('，') + 1

		-- 中文品名第一個字元如果是中文字要從第二組開始解析
        IF (UNICODE(SUBSTRING(@TmpStr, 1, 1)) BETWEEN 0x4E00 AND 0x9FFF)
		BEGIN
    	  SET @TmpIdx = CHARINDEX('，',@TmpStr)
	  	  SET @TmpStr = SUBSTRING(@TmpStr,@TmpIdx+1,LEN(@TmpStr)-@TmpIdx)
          SET @TotalNum = (LEN(RTRIM(@TmpStr)) - LEN(REPLACE(RTRIM(@TmpStr),'，',''))) / LEN('，') + 1
        END

        WHILE (@Num <= @TotalNum)
		BEGIN
			SET @TmpIdx = CHARINDEX('，',@TmpStr)

			IF (@TmpIdx > 0)
			BEGIN
			  SET @ValStr = SUBSTRING(@TmpStr,1,@TmpIdx-1)
			  SET @TmpStr = SUBSTRING(@TmpStr,@TmpIdx+1,LEN(@TmpStr)-@TmpIdx)
            END
			ELSE
			BEGIN
			  SET @ValStr = @TmpStr
			  SET @TmpStr = @TmpStr
			END

			if (@Num = 1)
			BEGIN
				SET @C01 = @ValStr
			END
			ELSE if (@Num = 2)
			BEGIN
				SET @C02 = @ValStr
			END
			ELSE if (@Num = 3)
			BEGIN
				SET @C03 = @ValStr
			END
			ELSE if (@Num = 4)
			BEGIN
				SET @C04 = @ValStr
			END
			ELSE if (@Num = 5)
			BEGIN
				SET @C05 = @ValStr
			END
			ELSE if (@Num = 6)
			BEGIN
				SET @C06 = @ValStr
			END
			ELSE if (@Num = 7)
			BEGIN
				SET @C07 = @ValStr
			END
			ELSE if (@Num = 8)
			BEGIN
				SET @C08 = @ValStr
			END
			ELSE if (@Num = 9)
			BEGIN
				SET @C09 = @ValStr
			END
			ELSE if (@Num = 10)
			BEGIN
				SET @C10 = @ValStr
			END
			ELSE if (@Num = 11)
			BEGIN
				SET @C11 = @ValStr
			END
			ELSE if (@Num = 12)
			BEGIN
				SET @C12 = @ValStr
			END

			SET @Num = @Num + 1
       END

        -- 解析英文品名
        SET @Num =1
		SET @TmpStr = @ProductName_EN
        SET @TotalNum_E = (LEN(RTRIM(@TmpStr)) - LEN(REPLACE(RTRIM(@TmpStr),'，',''))) / LEN('，') + 1

		WHILE (@Num <= @TotalNum_E)
		BEGIN
			SET @TmpIdx = CHARINDEX('，',@TmpStr)
			IF (@TmpIdx > 0)
			BEGIN
			  SET @ValStr = SUBSTRING(@TmpStr,1,@TmpIdx-1)
			  SET @TmpStr = SUBSTRING(@TmpStr,@TmpIdx+1,LEN(@TmpStr)-@TmpIdx)
            END
			ELSE
			BEGIN
			  SET @ValStr = @TmpStr
			  SET @TmpStr = @TmpStr
			END

			if (@Num = 2)
			BEGIN
				SET @E01 = @ValStr
			END
			ELSE if (@Num = 3)
			BEGIN
				SET @E02 = @ValStr
			END
			ELSE if (@Num = 4)
			BEGIN
				SET @E03 = @ValStr
			END
			ELSE if (@Num = 5)
			BEGIN
				SET @E04 = @ValStr
			END
			ELSE if (@Num = 6)
			BEGIN
				SET @E05 = @ValStr
			END
			ELSE if (@Num = 7)
			BEGIN
				SET @E06 = @ValStr
			END
			ELSE if (@Num = 8)
			BEGIN
				SET @E07 = @ValStr
			END
			ELSE if (@Num = 9)
			BEGIN
				SET @E08 = @ValStr
			END
			ELSE if (@Num = 10)
			BEGIN
				SET @E09 = @ValStr
			END
			ELSE if (@Num = 11)
			BEGIN
				SET @E10 = @ValStr
			END
			ELSE if (@Num = 12)
			BEGIN
				SET @E11 = @ValStr
			END
			ELSE if (@Num = 13)
			BEGIN
				SET @E12= @ValStr
			END

			SET @Num = @Num + 1
       END

        -- 解析中文規格
		SET @Num =1
		SET @TmpStr = @ProductSpec
        SET @TotalNum_S = (LEN(RTRIM(@TmpStr)) - LEN(REPLACE(RTRIM(@TmpStr),'，',''))) / LEN('，') + 1

		WHILE (@Num <= @TotalNum_S)
		BEGIN
			SET @TmpIdx = CHARINDEX('，',@TmpStr)
			IF (@TmpIdx > 0)
			BEGIN
			  SET @ValStr = SUBSTRING(@TmpStr,1,@TmpIdx-1)
			  SET @TmpStr = SUBSTRING(@TmpStr,@TmpIdx+1,LEN(@TmpStr)-@TmpIdx)
            END
			ELSE
			BEGIN
			  SET @ValStr = @TmpStr
			  SET @TmpStr = @TmpStr
			END

			if (@Num = 4)
			BEGIN
				SET @ModelName_Spec = @ValStr
			END

			SET @Num = @Num + 1
        END

	   DROP TABLE #TmpDataSet

      SET @OrderChkNo = ''


      IF (@ChkType = 'A')
	  BEGIN
	    SET @ChkNo = @ChkSource
      END
	  ELSE IF (@ChkType = 'P')
	  BEGIN
		  -- 取得檢核序號
		SELECT
			CONVERT(VARCHAR(8), GETDATE(), 112) +
			RIGHT(
				'0000' +
				CONVERT(VARCHAR(4),
					ISNULL(MAX(CAST(SUBSTRING(ChkNo, 9, 4) AS INT)), 0) + 1
				),
			4)
		FROM COP_ProductCheck
		WHERE ChkNo LIKE CONVERT(VARCHAR(8), GETDATE(), 112) + '%'

      END
	  ELSE
	  BEGIN
		  -- 取得品號檢核序號
		  SELECT @ChkNo = CASE WHEN MAX(ChkNo) IS NULL THEN ISNULL(MAX(ChkNo),CONVERT(VARCHAR(12),getdate(),112) +
									  substring('0000'+convert(varchar(4),1),len(convert(varchar(4),1))+1,4))
			   ELSE CONVERT(VARCHAR(12),getdate(),112) + substring('0000'+convert(varchar(4),CONVERT(INT,SUBSTRING(MAX(ChkNo),9,4)) + 1),
							len(convert(varchar(3),CONVERT(INT,SUBSTRING(MAX(ChkNo),9,4)) + 1))+1,4) END
		  FROM COP_ProductCheck
		  WHERE 1=1
		  AND ChkNo LIKE CONVERT(VARCHAR(12),getdate(),112)+'%'

          SET @OrderChkNo = @ChkType -- 訂單檢核時傳入訂單檢核序號
      END

      --2.按照項目數量及內容判斷項目類型,將比對結果寫入適當的旗標

	  set @NoChk = 'Y'
	  set @PHChk = 'Y'
	  set @HZChk = 'Y'
	  set @StartChk = 'Y'
	  set @VolChk = 'Y'
	  set @FloatChk = 'Y'
	  set @WireSpecChk = 'Y'
	  set @WireSizeChk = 'Y'
	  set @PlusChk = 'Y'
	  set @Ext1Chk = 'Y'
	  set @Ext2Chk = 'Y'
	  set @Ext3Chk = 'Y'

	  set @FinChk = 'N'
	  set @Memo = ''


-------- 資料檢核----------
      -- 1~5項各種組合類型的檢核邏輯都相同
      -- 型號檢查
	  if ((@E01 <> @C01) and (@E01 <> @ModelName_Spec) )
	  begin
    	if EXISTS(select * from V_COPNoChk where C01 = @C01 and E01 = @E01)
	    begin
	      set @NoChk = 'P'
	    end
		else
		begin
	      set @NoChk = 'N'
		  set @Memo = @Memo + '型號錯誤:中文-- '+ @C01 +' <> 英文-- '+ @E01 + ' <> 規格-- '+ @ModelName_Spec + '; '
        end
	  end


	  -- F02:PH檢查 @E02 = @C02
	  if (@E02 <> @C02)
	  begin
	    if EXISTS(select * from V_COPNoChk where C01 = @C02 and E01 = @E02)
	    begin
	      set @PHChk = 'P'
	    end
	    else
		begin
  	      set @PHChk = 'N'
	  	  set @Memo = @Memo + 'PH錯誤:中-- '+ @C02 + ' <> 英-- '+ @E02+ '; '
        end
	  end

	  -- F03:HZ檢查 @E03 = @C03
	  if (@E03 <> @C03 )
	  begin
	    if EXISTS(select * from V_COPNoChk where C01 = @C03 and E01 = @E03)
	    begin
	      set @HZChk = 'P'
	    end
	    else
		begin
  	      set @HZChk = 'N'
		  set @Memo = @Memo + 'HZ錯誤:中-- '+ @C03 + ' <> 英-- '+ @E03+ '; '
        end
	  end

	  -- F04:啟動檢查 @E04 = @C04
	  if (@E04 <> @C04 )
	  begin
	    if EXISTS(select * from V_COPNoChk where C01 = @C04 and E01 = @E04)
	    begin
	      set @StartChk = 'P'
	    end
	    else
		begin
  	      set @StartChk = 'N'
		  set @Memo = @Memo + '啟動錯誤:中-- '+ @C04 + ' <> 英-- '+ @E04+ '; '
        end
	  end

	  -- F05:電壓檢查 @E05 = @C05
	  if (@E05 <> @C05 )
	  begin
	    if EXISTS(select * from V_COPNoChk where C01 = @C05 and E01 = @E05)
	    begin
	      set @VolChk = 'P'
	    end
	    else
		begin
	      set @VolChk = 'N'
		  set @Memo = @Memo + '電壓錯誤:中-- '+ @C05 + ' <> 英-- '+ @E05+ '; '
        end
	  end

	  -- F06:線規檢查 @E06 = @C06
	  if (@E06 <> @C06 )
	  begin
	    if ( (@TotalNum = 6) or  (@TotalNum = 7) or ( (@TotalNum = 8) and (CHARINDEX('浮球',@C06) = 0)) )
		begin
		  if EXISTS(select * from V_COPNoChk where C01 = @C06 and E01 = @E06)
		  begin
			set @WireSpecChk = 'P'
		  end
		  else
		  begin
	        set @WireSpecChk = 'N'
		    set @Memo = @Memo + '線規錯誤:中-- '+ @C06 + ' <> 英-- '+ @E06+ '; '
          end
        end
		else if ( ((@TotalNum = 8) and (CHARINDEX('浮球',@C06) > 0)) or (@TotalNum = 9) )
		begin
		  if EXISTS(select * from V_COPNoChk where C01 = @C06 and E01 = @E06)
		  begin
			set @FloatChk = 'P'
		  end
		  else
		  begin
	        set @FloatChk = 'N'
		    set @Memo = @Memo + '浮球錯誤:中-- '+ @C06 + ' <> 英-- '+ @E06+ '; '
          end
        end
	  end

	  -- F07:線徑檢查 @E07 = @C07
	  if (@E07 <> @C07 )
	  begin
	    if ( (@TotalNum = 7) or ( (@TotalNum = 8) and (CHARINDEX('浮球',@C06) = 0)) )
		begin
		  if EXISTS(select * from V_COPNoChk where C01 = @C07 and E01 = @E07)
		  begin
			set @WireSizeChk = 'P'
		  end
		  else
		  begin
		    -- 線徑去括號後再檢核
            if ((SELECT dbo.fu_RemoveParentheses(@E07)) <> (SELECT dbo.fu_RemoveParentheses(@C07)) )
			begin
    	      set @WireSizeChk = 'N'
	          set @Memo = @Memo + '線徑錯誤:中-- '+ @C07 + ' <> 英-- '+ @E07+ '; '
            end
          end
        end
		else if ( ((@TotalNum = 8) and (CHARINDEX('浮球',@C06) > 0)) or (@TotalNum = 9) )
		begin
		  if EXISTS(select * from V_COPNoChk where C01 = @C07 and E01 = @E07)
		  begin
			set @WireSpecChk = 'P'
		  end
		  else
		  begin
	        set @WireSpecChk = 'N'
		    set @Memo = @Memo + '線規錯誤:中-- '+ @C07 + ' <> 英-- '+ @E07+ '; '
          end
        end
	  end

	  -- F08:插頭檢查 @E08 = @C08
      if (@E08 <> @C08 )
	  begin
	    if ( ( (@TotalNum = 8) and (CHARINDEX('浮球',@C06) = 0)) )
		begin
		  if EXISTS(select * from V_COPNoChk where C01 = @C08 and E01 = @E08)
		  begin
			set @PlusChk = 'P'
		  end
		  else
		  begin
    	    set @PlusChk = 'N'
	        set @Memo = @Memo + '插頭錯誤:中-- '+ @C08 + ' <> 英-- '+ @E08+ '; '
          end
        end
		else if ( ((@TotalNum = 8) and (CHARINDEX('浮球',@C06) > 0)) or (@TotalNum = 9) )
		begin
		  if EXISTS(select * from V_COPNoChk where C01 = @C08 and E01 = @E08)
		  begin
			set @WireSizeChk = 'P'
		  end
		  else
		  begin
		    -- 線徑去括號後再檢核
            if ((SELECT dbo.fu_RemoveParentheses(@E08)) <> (SELECT dbo.fu_RemoveParentheses(@C08)) )
  		    begin
    	      set @WireSizeChk = 'N'
	          set @Memo = @Memo + '線徑錯誤:中-- '+ @C08 + ' <> 英-- '+ @E08+ '; '
            end
          end
        end
	  end

	  -- F09:插頭檢查 @E09 = @C09
      if (@E09 <> @C09 )
	  begin
	    if (@TotalNum = 9)
		begin
		  if EXISTS(select * from V_COPNoChk where C01 = @C09 and E01 = @E09)
		  begin
			set @PlusChk = 'P'
		  end
		  else
		  begin
    	    set @PlusChk = 'N'
	        set @Memo = @Memo + '插頭錯誤:中-- '+ @C09 + ' <> 英-- '+ @E09+ '; '
          end
        end
	  end

	  if     @NoChk <> 'N'
	     and @PHChk <> 'N'
		 and @HZChk <> 'N'
		 and @StartChk <> 'N'
		 and @VolChk <> 'N'
		 and @FloatChk <> 'N'
		 and @WireSpecChk <> 'N'
		 and @WireSizeChk <> 'N'
		 and @PlusChk <> 'N'

	     set @FinChk = 'Y'


	  -- 寫入檢核資料
      INSERT INTO [dbo].[COP_ProductCheck] (
	  [ChkNo],[ChkSource],[OrderChkNo],[ChkTime],[ProductNo],[ProductName]
      ,[ProductName_EN],[ProductSpec],[ProductSpec_EN],[NoChk],[PHChk]
      ,[HZChk],[StartChk],[VolChk],[FloatChk],[WireSpecChk]
	  ,[WireSizeChk],[PlusChk],[FinChk],[Memo],[aStatus]
	  ,[Creator],[CreateTime] )
	  select
      @ChkNo,@ChkSource,@OrderChkNo,@CreateTime,@InProductNo,@ProductName
	  ,@ProductName_EN,@ProductSpec,@ProductSpec_EN,@NoChk,@PHChk
	  ,@HZChk,@StartChk,@VolChk,@FloatChk,@WireSpecChk
	  ,@WireSizeChk,@PlusChk,@FinChk,@Memo,'Y'
	  ,@Executor,@CreateTime

	   IF (@ChkType = 'P')
	   begin
	     select * from [COP_ProductCheck] where ChkNo = @ChkNo
         SET  @result = 'SUCCESS'
       end
	   else
	   begin
         SET  @result = @FinChk
	   end

       COMMIT


	END TRY

	BEGIN CATCH

		SET  @result = 'error'
		ROLLBACK;

		PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR(MAX));
		PRINT 'Error Message: ' + ERROR_MESSAGE();

    END CATCH


END
GO

CREATE OR ALTER PROCEDURE [dbo].[prc_COPOrderChk]

@InSource varchar(40), -- 訂單單號來源
@InPoNo varchar(40), -- 訂單單號 單別 + '-' + 單號
@InCustAmt NUMERIC(16,3), -- 客戶訂單金額
@InPaidChk varchar(20), -- 付款確認旗標
@Executor varchar(40), -- 執行人員
@result VARCHAR(40) OUTPUT    --傳回結果



AS
BEGIN


DECLARE

-- 主檔檢核欄位
@TC001 NVARCHAR(20), --單別,
@TC002 NVARCHAR(20), --單號,
@MQ002 NVARCHAR(40), --單別名稱,
@TC003 NVARCHAR(20), --訂單日期,
@TC004 NVARCHAR(20), --客戶代號,
@MA002 NVARCHAR(120), --客戶名稱,
@TC005 NVARCHAR(20), --部門代號,
@TC006 NVARCHAR(20), --業務人員,
@MV002 NVARCHAR(120), --業務名稱,
@TC010 NVARCHAR(120), --送貨地址,
@TC014 NVARCHAR(120), --付款條件,
@TC016 NVARCHAR(10), --課稅別,
@TC019 NVARCHAR(10), --運輸方式,
@TC008 NVARCHAR(10), --幣別,
@TC009 NUMERIC(16,3), --匯率,
@TC029 NUMERIC(16,3), --訂單金額,
@TC031 NUMERIC(16,3), --總數量,
@TC038 NVARCHAR(120), --PACKINGLIST備註,
@TD013 NVARCHAR(20), --預交日,
@TA033 NVARCHAR(120), -- 計劃批號,
@TC012 NVARCHAR(120), --客戶單號,
@TC068 NVARCHAR(10), --交易條件,
@TC020 NVARCHAR(120), --起始港口,
@TC021 NVARCHAR(120), --目的港口
@TC013 NVARCHAR(40), -- 價格條件
@FileName NVARCHAR(120),
@Rate NUMERIC(16,3), --匯率設定數值,


-- 主檔檢核結果
@SumAmt	NUMERIC(16,3),
@SumQty	NUMERIC(16,3),
@DepChk NVARCHAR(20) = 'Y',
@DepBlankChk NVARCHAR(20) = 'Y',
@PackListBlankChk NVARCHAR(20) = 'Y',
@PriceBlankChk NVARCHAR(20) = 'Y',
@PreDateChk NVARCHAR(20) = 'Y',
@CustSumAmtChk NVARCHAR(20) = 'Y',
@CustAmtZeroChk NVARCHAR(20) = 'Y',
@CustPOChk NVARCHAR(20) = 'Y',
@TransChk NVARCHAR(20) = 'Y',
@TradeChk NVARCHAR(20) = 'Y',
@OutPortChk	 NVARCHAR(20) = 'Y',
@InPortChk NVARCHAR(20) = 'Y',
@ProductNoChk_M NVARCHAR(20) = 'Y',
@UpFileChk NVARCHAR(20) = 'Y',
@DetailChk NVARCHAR(20) = 'Y',
@RateChk NVARCHAR(20) = 'Y',
@PaidChk NVARCHAR(20) = 'Y', --是否已付款
@AvailableChk NVARCHAR(20) = 'Y',
@Credit30WChk NVARCHAR(20) = 'Y',
@FinChk_M NVARCHAR(20),
@Memo_M NVARCHAR(500),

-- 訂單明細項目檢核欄位
@TD001 NVARCHAR(20), --單別,
@TD002 NVARCHAR(20), --單號,
@TD003 NVARCHAR(20), --序號,
@TD004 NVARCHAR(20), --品號,
@TD005 NVARCHAR(120), --品名,
@TD006 NVARCHAR(120), --規格,
@TD008 NUMERIC(16,3), --訂單數量,
@TD010 NVARCHAR(20), --單位,
@TD011 NUMERIC(16,3), --外幣單價,
@TD012 NUMERIC(16,3), --外幣金額,
@TD017 NVARCHAR(20), --前置單別,
@TD018 NVARCHAR(20), --前置單號,
@TD019 NVARCHAR(20), --前置序號,
@TB007 NUMERIC(16,3), --前置數量,
@TB009 NUMERIC(16,3), --前置單價,
@ProcessCode NVARCHAR(20), --流程代號, 20260518 加入

@PreDate_D NVARCHAR(20), --預交日
@FinFlag_D NVARCHAR(20), --訂單明細完成旗標


-- 明細項目檢核結果
@ProductNoChk NVARCHAR(10),
@QtyChk NVARCHAR(10),
@AmtChk NVARCHAR(10),
@PriceChk NVARCHAR(20),
@PackListChk NVARCHAR(20),

@LinkTypeChk NVARCHAR(10),
@LinkNoChk NVARCHAR(10),
@LinkSNoChk NVARCHAR(10),
@LinkQtyChk NVARCHAR(10),
@LinkPriceChk NVARCHAR(10),
@LinkChk NVARCHAR(10),
@MOQAmtChk NVARCHAR(10),
@LinkMOQAmtChk NVARCHAR(10),
@ProcessCodeChk NVARCHAR(10),

@ByQtyFlag NVARCHAR(10),
@ByQtyPrice numeric (16,3) = 0,

@FinChk_D NVARCHAR(10),
@Memo_D NVARCHAR(500),


@PLDate VARCHAR(12), -- PACKING LIST 日期

@PriceDate VARCHAR(12), -- 價格條件日期

@ChkNo varchar(20),
@OrderChkNo varchar(20),

@RET VARCHAR(50),

-- 信用額度相關金額
@NotifyAmt numeric (16,3) = 0, --  訂貨(出貨通知)金額
@OrderAmt numeric (16,3) = 0, --  未出貨訂單總金額
@OrderAmtRate numeric (16,6) = 0, --  未出貨訂單金額比率
@ReceivableSumAmt numeric (16,3) = 0, --  應收合計金額
@ReceivableAmt numeric (16,3) = 0, --  應收金額
@GainAmt numeric (16,3) = 0, --  已出貨抵預收金額
@UnbilledAmt numeric (16,3) = 0, --  未結帳銷貨
@PreGainAmt numeric (16,3) = 0, --  預收金額
@AvailableAmt numeric (16,3) = 0, --  信用餘額
@AvailableSetAmt numeric (16,3) = 0, --  設定額度金額

@CreateTime datetime


  SET @CreateTime = GETDATE()

  BEGIN TRANSACTION
  --開啟交易

    BEGIN TRY


	-- 檢核訂單是否存在 暫先不做防呆

	-- 取得訂單主檔記錄資料
	SELECT
	  @TC001 = 單別,@MQ002 = 單別名稱,@TC005 = 部門代號, @TC038 = [PACKINGLIST備註], @TC029 = 訂單金額, @TC031 = 總數量, @TC012 = 客戶單號,
	  @TC003 = 訂單日期,@TC019 = 運輸方式, @TC068 = 交易條件, @TC020 = 起始港口, @TC021 = 目的港口,  @TC013  = 價格條件, @TC008 = 幣別,
	  @TC009 = 匯率, @FileName  = 附件檔案,@TC004 = 客戶代號,@ProcessCode = 流程代號
    FROM V_POList
	where 1=1
	and COP_Source = @InSource
	and 單別 + '-' + 單號 = @InPoNo

	set @DepChk = 'Y'
	set @DepBlankChk = 'Y'
	set @PackListBlankChk = 'Y'
	set @PriceBlankChk = 'Y'
	set @CustSumAmtChk = 'Y'
	set @CustAmtZeroChk = 'Y'
	set @CustPOChk = 'Y'
	set @TransChk = 'Y'
	set @TradeChk = 'Y'
	set @OutPortChk = 'Y'
	set @InPortChk = 'Y'
	set @PreDateChk = 'Y'
	set @ProductNoChk_M = 'Y'
	set @UpFileChk = 'Y'
	set @RateChk = 'Y'
	set @PaidChk = 'Y'
	set @AvailableChk = 'Y'
	set @Credit30WChk = 'Y'
	set @ProcessCodeChk = 'Y'
	set @FinChk_M = 'N'
	set @Memo_M = ''

	set @DetailChk = 'Y'

	-- 檢核訂單主檔資料
	  --  1.部門不得空白,和單別要對應
	  if (@TC005= '')
	  begin
	    set @DepBlankChk = 'N'
	  end
	  else if not EXISTS(select * from COP_DepData where OrderType = @TC001 and DepNo = @TC005)
	  begin
	    set @DepChk = 'N'
	  end

	  --  2.日期注意事項
	  --  PACKING LIST備註 前四碼為月日<出貨月日(明細的預交日)
	  --  詢問單 不檢核
      -- 取當天日期年份可能會出現錯誤,改為取訂單日期的年份
	  set @PLDate = SUBSTRING(@TC003,1,4) + SUBSTRING(@TC038,1,4)

	  print '@PLDate : '+@PLDate
	  if ((@TC001 not in ('2700','2200')) and (@MQ002 not like '%詢問單%') )
	  begin
		  if (@TC038= '')
		  begin
			set @PackListBlankChk = 'N'
		  end
      end

      --  3.主檔價格條件 = 明細檔預交日
	  --    @.不可為空白
	  --    @.詢問單不檢核

		-- 設置語言為英文以解析英語日期格式
		SET LANGUAGE English;

		set @PriceDate = '0000'

		BEGIN TRY
			-- 確保 @TC013 是有效日期才轉換
			IF ISDATE(@TC013) = 1
				SET @PriceDate = CONVERT(varchar(12), CONVERT(DATETIME, @TC013), 112);
			ELSE
				THROW 50001, '日期格式錯誤: @TC013 不是有效日期', 1;
		END TRY
		BEGIN CATCH
			PRINT @PriceDate + ' 轉換錯誤';
			PRINT ERROR_MESSAGE();
			-- 繼續執行不拋出錯誤
		END CATCH;

		-- 設置語言回中文
		SET LANGUAGE 繁體中文;

		print @PriceDate

	  if ((@TC001 not in ('2700','2200')) and (@MQ002 not like '%詢問單%') )
	  begin
		  if (@TC013= '')
		  begin
			set @PriceBlankChk = 'N'
		  end
      end

	  --  4.判斷客人訂單金額≦ERP訂單金額
	  if (@InCustAmt = 0)
	  begin
	    set @CustAmtZeroChk = 'W'
	  end
	  ELSE if (@InCustAmt > @TC029)
	  begin
	    set @CustSumAmtChk = 'N'
	  end

   --  5.客戶單號不得為空白
      if (@TC012= '')
	  begin
	    set @CustPOChk = 'N'
	  end

   --  6.運輸方式 不得為空白
      if (@TC019= '')
	  begin
	    set @TransChk = 'N'
	  end

   --  7.交易條件 不得為空白
      if (@TC068= '')
	  begin
	    set @TradeChk = 'N'
	  end

   --  8.出口港 不得為空白
      if ((@TC020= '') AND (@InSource = '浦瑞ERP') AND (@TC001 <> '2210'))
	  begin
	    set @OutPortChk = 'N'
	  end

   --  9.目的地港 不得為空白
      if ((@TC021= '') AND (@InSource = '浦瑞ERP') AND (@TC001 <> '2210'))
	  begin
	    set @InPortChk = 'N'
	  end

   -- 10.訂單明細不可有多個預交日期
      if exists(select 單別,單號 ,COUNT(*) 筆數 FROM V_POList where COP_Source = @InSource AND 單別 + '-' + 單號 = @InPoNo group by COP_Source,單別,單號 having COUNT(*) > 1)
	  begin
	    set @PreDateChk = 'N'
	  end

   --  11.附件檔案必需上傳
	  if ((@TC001 not in ('2700','2200')) and (@MQ002 not like '%詢問單%') )
		  if not exists(SELECT * FROM [V_UpFileData] where KeyValues = @InPoNo)
		  begin
			set @UpFileChk = 'N'
		  end


   -- 12.檢核匯率
   -- @TC008 = 幣別, @TC009 = 匯率
      set @Rate = 0
      if (@InSource = '浦瑞ERP')
	  begin
		SELECT @Rate = MG003 FROM [192.168.1.200].TWPR.dbo.CMSMG
		WHERE 1=1
		AND MG001 = @TC008
		AND MG002 =(
		SELECT MAX(MG002) MG002 FROM [192.168.1.200].TWPR.dbo.CMSMG
		WHERE 1=1
		AND MG001 = @TC008)
	  end
	  else
      begin
		SELECT @Rate = MG003 FROM [192.168.1.200].PRORIL.dbo.CMSMG
		WHERE 1=1
		AND MG001 = @TC008
		AND MG002 =(
		SELECT MAX(MG002) MG002 FROM [192.168.1.200].PRORIL.dbo.CMSMG
		WHERE 1=1
		AND MG001 = @TC008)
	  end

	  IF (@Rate <> @TC009)
	  begin
	    set @RateChk = 'N'
	  end


      print 'exec prc_COPGetCredit'

	  -- 呼叫[prc_COPGetCredit] 取得相關金額
	  -- 建立暫存表來存放結果
	  CREATE TABLE #TempCreditData (
		應收金額 numeric (16,3), --  ReceivableAmt
		未結帳銷貨  numeric (16,3), -- UnbilledAmt
		訂貨出貨通知金額  numeric (16,3), -- NotifyAmt
		預收金額  numeric (16,3), --  PreGainAmt
		已出貨抵預收金額  numeric (16,3), --  GainAmt
		應收合計金額  numeric (16,3), -- ReceivableSumAmt
	    未出貨訂單總金額  numeric (16,3), -- OrderAmt
		未出貨訂單金額比率  numeric (16,6), -- OrderAmtRate
		信用可超出額  numeric (16,3), -- AvailableSetAmt
		信用餘額  numeric (16,3) --  AvailableAmt
        );

	  INSERT INTO #TempCreditData
	  exec prc_COPGetCredit @TC004, @Executor

	  select @ReceivableAmt = 應收金額,@UnbilledAmt = 未結帳銷貨,@NotifyAmt = 訂貨出貨通知金額,@PreGainAmt = 預收金額,@GainAmt = 已出貨抵預收金額,
		     @ReceivableSumAmt = 應收合計金額,@OrderAmt = 未出貨訂單總金額,@OrderAmtRate = 未出貨訂單金額比率,
		     @AvailableSetAmt = 信用可超出額,@AvailableAmt = 信用餘額 FROM #TempCreditData


      -- 清除暫存表
	  DROP TABLE #TempCreditData;


      -- 13.檢核信用額度
	  IF ((@TC029 > @AvailableAmt) AND (@InSource = '浦瑞ERP')  and (@TC004 not like '101%'))
	  begin
	    set @AvailableChk = 'N'
	  end

     -- 14.檢核101信用額度不可超過30W
     --    未出貨訂單總金額 - 已出貨抵預收金額  + 待檢核的[訂單金額] <= 30W
	  IF ((@TC004 like '101%') AND (@InSource = '浦瑞ERP'))
	  begin
		print '@OrderAmt - @GainAmt + @TC029 = ' + CAST(@OrderAmt - @GainAmt + @TC029 AS VARCHAR(100))
	    if (@OrderAmt - @GainAmt + @TC029 >= 300000)
		begin
	      set @Credit30WChk = 'N'
        end
	  end


	  print '@TC008' + ': ' + @TC008 +'--@@TC004' + ': ' + @TC004 +'--@@ProcessCode' + ': ' + @ProcessCode
	  -- 20260518 增加檢核流程代號檢核
		--15.訂單當中對應幣別的流程代號是否正確
		--  1.幣別EUR，對應流程代號E2
		--  2.幣別USD，對應流程代號U2
		--  3.但幣別USD，客戶代號是501開頭的，對應流程代號A3
		--  4.幣別AUD，對應流程代號A2
	  IF (not (@TC008 = 'EUR' and @ProcessCode = 'E2')) and
	     (not (@TC008 = 'USD' and @ProcessCode = 'U2')) and
	     (not (@TC008 = 'USD' and @TC004 like '501%' and @ProcessCode = 'A3')) and
	     (not (@TC008 = 'AUD' and @ProcessCode = 'A2'))
	  begin
	    print '流程代號檢核  ' + @InPoNo
		  -- 20260525 國外訂單以及單別為 2702 2705 2706  才需要檢核
	    if (@InSource = '浦瑞ERP') and (@TC001 in ('2702','2705','2706'))
		  set @ProcessCodeChk = 'N'
	  end


	  print '@OrderAmt' + CAST(@OrderAmt AS VARCHAR(100))
	  print '@GainAmt' + CAST(@GainAmt AS VARCHAR(100))

	-- 寫入檢核結果到[COP_PoCheck]
	-- 取得檢核序號
	SELECT @OrderChkNo = CASE WHEN MAX(OrderChkNo) IS NULL THEN ISNULL(MAX(OrderChkNo),CONVERT(VARCHAR(12),getdate(),112) +
								substring('0000'+convert(varchar(4),1),len(convert(varchar(4),1))+1,4))
		ELSE CONVERT(VARCHAR(12),getdate(),112) + substring('0000'+convert(varchar(4),CONVERT(INT,SUBSTRING(MAX(OrderChkNo),9,4)) + 1),
					len(convert(varchar(3),CONVERT(INT,SUBSTRING(MAX(OrderChkNo),9,4)) + 1))+1,4) END
	FROM COP_PoCheck
	WHERE 1=1
	AND OrderChkNo LIKE CONVERT(VARCHAR(12),getdate(),112)+'%'

	-- 檢核訂單明細資料
	-- 此部份會是一個資料集,以迴圈逐筆檢核
	-- 取得訂單明細資料
	DECLARE CRS CURSOR FOR
	SELECT
	單別,單號,序號,品號,訂單數量,外幣單價,預交日,前置單別,前置單號,前置序號, 前置數量, 前置單價,FinFlag
	FROM V_PODetailList
	WHERE 1=1
	and COP_Source = @InSource
	and 單別 + '-' + 單號 = @InPoNo


	OPEN CRS
	FETCH NEXT FROM CRS INTO @TD001,@TD002,@TD003,@TD004,@TD008,@TD011,@PreDate_D,@TD017,@TD018,@TD019,@TB007,@TB009,@FinFlag_D

	while(@@fetch_status != -1)
	begin

      set @ProductNoChk = 'Y'
      set @QtyChk = 'Y'
      set @AmtChk = 'Y'
	  set @PackListChk = 'Y'
	  set @PriceChk = 'Y'
	  set @LinkTypeChk = 'Y'
	  set @LinkNoChk = 'Y'
	  set @LinkSNoChk = 'Y'
	  set @LinkQtyChk = 'Y'
	  set @LinkPriceChk = 'Y'
	  set @LinkChk = 'Y'
	  set @MOQAmtChk = 'Y'
	  set @LinkMOQAmtChk = 'Y'
      set @FinChk_D = 'N'
      set @Memo_D = ''


    --明細檢核規則:
      --  1.品號正確性,中英文品名及規格內容是否符合邏輯
	  IF ((@TD004 LIKE '5%') AND (@TD004 NOT LIKE '58%'))
	  begin
        EXEC prc_ProductChk_COP @OrderChkNo,@InPoNo,@InSource,@TD004,@Executor,@RET OUTPUT

        if (@RET = 'N')
		begin
		  set @ProductNoChk = 'N'
		end
	  end

      --  2.訂單數量≠0
	  if (@TD008 = 0)
	  begin
	    set @QtyChk = 'N'
	  end

      --  3.單價≠0
	  if (@TD011 = 0)
	  begin
	    set @AmtChk = 'N'
	  end

		  print '@PLDate ' + @PLDate
		  print '@PreDate_D ' + @PreDate_D

	  if ((@TC001 not in ('2700','2200')) and (@MQ002 not like '%詢問單%') )
	  begin

		  print '@@TC001 ' + @TC001

		  if (@PLDate >= @PreDate_D)
		  begin
			set @PackListChk = 'N'
    		print '@PackListChk ' + @PackListChk
		  end


		  if (@PriceDate <> @PreDate_D)
		  begin
			set @PriceChk = 'N'
		  end
      end

	  ---------------------------------------------------------------------------------
	  -- 20250603 Mars
	  -- 分量計價檢核
	  -- 取得此客戶及品號是否有分量計價設定

	  -- 檢核訂單單價
	  Set @ByQtyPrice = @TD011
	  SELECT @ByQtyPrice = min(ByQtyPrice) FROM  V_COPMOQ
      WHERE 1=1
	  and ByQtyFlag = 'Y'
	  and CustomerNo = @TC004
	  and ProductNo = @TD004
	  and Qty <= @TD008

	  if (@ByQtyPrice <> @TD011)
	  begin
    	set @MOQAmtChk = 'N'
	  end

	  -- 檢核報價單單價
	  Set @ByQtyPrice = @TB009
	  SELECT @ByQtyPrice = min(ByQtyPrice) FROM  V_COPMOQ
      WHERE 1=1
	  and ByQtyFlag = 'Y'
	  and CustomerNo = @TC004
	  and ProductNo = @TD004
	  and Qty <= @TB007

	  if (@ByQtyPrice <> @TB009)
	  begin
    	set @LinkMOQAmtChk = 'N'
	  end


	  -- 20250314 前置單據相關檢核
	  if ((@TC001 not in ('2700','2200')) and (@MQ002 not like '%詢問單%') )
	  begin
		  if (isnull(@TD017,'') = '')
		  begin
			set @LinkTypeChk = 'N'
		  end

		  if (isnull(@TD018,'') = '')
		  begin
			set @LinkNoChk = 'N'
		  end

		  if (isnull(@TD019,'') = '')
		  begin
			set @LinkSNoChk = 'N'
		  end

		  if (isnull(@TB007,0) <> @TD008)
		  begin
			set @LinkQtyChk = 'W'
		  end

		  if (isnull(@TB009,0) <> @TD011)
		  begin
			set @LinkPriceChk = 'W'
		  end

		  if (@TB007 is null)
		  begin
			set @LinkChk = 'N'
		  end
      end

	-- 寫入檢核結果到[COP_PoDetailCheck]

		if @ProductNoChk = 'Y' and
		 @QtyChk = 'Y' and
		 @AmtChk = 'Y' and
		 @PackListChk = 'Y' and
		 @PriceChk = 'Y' and

		 @LinkTypeChk = 'Y' and
		 @LinkNoChk = 'Y' and
		 @LinkSNoChk = 'Y' and
		 @LinkQtyChk in ('Y','W') and
		 @LinkPriceChk in ('Y','W') and
		 @LinkChk = 'Y' and
		 @MOQAmtChk = 'Y' and
		 @LinkMOQAmtChk = 'Y'
        begin
		  set @FinChk_D = 'Y'
        end
		else
		begin
		  set @FinChk_D = 'N'
          set @DetailChk = 'N' -- 主檔的明細項目檢核旗標
		end

	  -- 寫入訂單明細項目檢核資料
      INSERT INTO COP_PoDetailCheck (
        OrderChkNo,ChkTime,COP_Source,PoNo,SNo,ProductNo,
		ProductNoChk,QtyChk,AmtChk,PackListChk,PriceChk,
		LinkTypeChk,LinkNoChk,LinkSNoChk,LinkQtyChk,LinkPriceChk,
		LinkChk,MOQAmtChk,LinkMOQAmtChk,
		FinChk,Memo,aStatus,Creator,CreateTime)
	  select
        @OrderChkNo,@CreateTime,@InSource,@InPoNo,@TD003,@TD004,
		@ProductNoChk,@QtyChk,@AmtChk,@PackListChk,@PriceChk,
		@LinkTypeChk,@LinkNoChk,@LinkSNoChk,@LinkQtyChk,@LinkPriceChk,
		@LinkChk,@MOQAmtChk,@LinkMOQAmtChk,
		@FinChk_D,@Memo_D,'Y',@Executor,@CreateTime

      FETCH NEXT FROM CRS INTO @TD001,@TD002,@TD003,@TD004,@TD008,@TD011,@PreDate_D,@TD017,@TD018,@TD019,@TB007,@TB009,@FinFlag_D

	 end
	 close CRS
	 deallocate CRS

     -- 寫入訂單主檔檢核資料
        set @FinChk_M = 'Y'

		if @DepChk = 'N' or
		 @DepBlankChk = 'N' or
		 @PackListBlankChk = 'N' or
		 @PriceBlankChk = 'N' or
		 @PreDateChk = 'N' or

		 @CustSumAmtChk = 'N' or
		 @CustAmtZeroChk = 'N' or
		 @CustPOChk = 'N' or
		 @TransChk = 'N' or
		 @TradeChk = 'N' or

		 @OutPortChk = 'N' or
		 @InPortChk = 'N' or
		 @UpFileChk = 'N' or
         @DetailChk = 'N' or
		 @RateChk = 'N' or

		 @PaidChk = 'N' or
		 @AvailableChk = 'N' or
 	     @Credit30WChk = 'N' or
		 @ProcessCodeChk = 'N'

         begin
		   set @FinChk_M = 'N'
		 end

print	@DepChk+','+@DepBlankChk+','+@PackListBlankChk+','+@PriceBlankChk+','+@PreDateChk+','+
		@CustSumAmtChk+','+@CustAmtZeroChk+','+@CustPOChk+','+@TransChk+','+@TradeChk+','+
		@OutPortChk+','+@InPortChk+','+@UpFileChk+','+@DetailChk+','+@RateChk+','+
		@InPaidChk+','+@AvailableChk + ','+@Credit30WChk +','+ @ProcessCodeChk +','+ @FinChk_M

print '@FinChk_M:  ' + @FinChk_M



      INSERT INTO COP_PoCheck (
        OrderChkNo,ChkTime,COP_Source,PoNo,SumAmt,SumQty,CustAmt,AvailableAmt,
		DepChk,DepBlankChk,PackListBlankChk,PriceBlankChk,PreDateChk,
		CustSumAmtChk,CustAmtZeroChk,CustPOChk,TransChk,TradeChk,
		OutPortChk,InPortChk,UpFileChk,DetailChk,RateChk,
		PaidChk,AvailableChk,Credit30WChk,ProcessCodeChk,FinChk,Memo,aStatus,
		Creator,CreateTime)
	  select
        @OrderChkNo,@CreateTime,@InSource,@InPoNo,@TC029,@TC031,@InCustAmt,@AvailableAmt,
		@DepChk,@DepBlankChk,@PackListBlankChk,@PriceBlankChk,@PreDateChk,
		@CustSumAmtChk,@CustAmtZeroChk,@CustPOChk,@TransChk,@TradeChk,
		@OutPortChk,@InPortChk,@UpFileChk,@DetailChk,@RateChk,
		@InPaidChk,@AvailableChk,@Credit30WChk,@ProcessCodeChk,@FinChk_M,@Memo_M,'Y',
	    @Executor,@CreateTime

       COMMIT

	   SET  @result = 'SUCCESS'

	END TRY

	BEGIN CATCH

		SET  @result = 'error'
		ROLLBACK;

		PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR(MAX));
		PRINT 'Error Message: ' + ERROR_MESSAGE();

    END CATCH

     PRINT @result

END
GO

CREATE OR ALTER PROCEDURE [dbo].[prc_COPPassCheck]

@InOrderChkNo varchar(40), -- 訂單檢核序號
@PassItem varchar(40), -- 特淮項目
@PassMemo varchar(500), -- 特淮說明
@Executor varchar(40), -- 執行人員
@result VARCHAR(40) OUTPUT    --傳回結果



AS
BEGIN


DECLARE


@OrderChkNo varchar(40),
@Sno varchar(40),
@PassTime datetime,
@Memo varchar(500),
@aStatus varchar(1),

-- 主檔檢核結果
@SumAmt	NUMERIC(16,3),
@SumQty	NUMERIC(16,3),
@DepChk NVARCHAR(20),
@DepBlankChk NVARCHAR(20),
@PackListBlankChk NVARCHAR(20),
@PriceBlankChk NVARCHAR(20),
@PreDateChk NVARCHAR(20),
@CustSumAmtChk NVARCHAR(20),
@CustAmtZeroChk NVARCHAR(20),
@CustPOChk NVARCHAR(20),
@TransChk NVARCHAR(20),
@TradeChk NVARCHAR(20),
@OutPortChk	 NVARCHAR(20),
@InPortChk NVARCHAR(20),
@UpFileChk NVARCHAR(20),
@RateChk NVARCHAR(20),
@PaidChk NVARCHAR(20),
@AvailableChk NVARCHAR(20),
@Credit30WChk NVARCHAR(20),
@DetailChk NVARCHAR(20),
@FinChk_M NVARCHAR(20),


@RET VARCHAR(50),

@Field NVARCHAR(50),
@Value NVARCHAR(50),
@where NVARCHAR(500),
@statement NVARCHAR(500),

@CreateTime datetime


  SET @CreateTime = GETDATE()

  BEGIN TRANSACTION
  --開啟交易

    BEGIN TRY

	--程式邏輯:
 --     1.將特淮項目檢核旗標改為 P

		set @Field = @PassItem
		set @Value = 'P'
		SET @where = ' WHERE 1 = 1 '

		set @statement = 'update COP_PoCheck set '

		SET @statement = @statement + @Field + ' = ''' + @Value + ''''

		SET @where = @where + ' AND OrderChkNo = '''+@InOrderChkNo +''' '

		set @statement = @statement + @where

		print @where

		print @statement

		EXEC sp_executesql @statement


 --     2.逐項產生[COP_PassCheck]特淮記錄資料

      -- 取得Sno
	  SELECT @Sno = CASE WHEN MAX(Sno) IS NULL THEN '0001'
		ELSE  substring('0000'+ convert(varchar(4),CONVERT(int,MAX(Sno)) + 1 ), LEN(convert(varchar(4),CONVERT(int,MAX(Sno)) + 1 )) +1,4) END
      FROM COP_PassCheck
      WHERE 1=1
      AND OrderChkNo = @InOrderChkNo

      -- 寫入特淮記錄
      INSERT INTO COP_PassCheck (
        OrderChkNo,Sno,PassTime,PassItems,PassMemo,
		Memo,aStatus,Creator,CreateTime)
	  select
        @InOrderChkNo,@Sno,@CreateTime,@PassItem,@PassMemo,
		'','Y',@Executor,@CreateTime

		-- 更新檢核主檔資料

		set @FinChk_M = 'N'

	    select
          @DepChk = DepChk,
          @DepBlankChk = DepBlankChk,
          @PackListBlankChk = PackListBlankChk,
          @PriceBlankChk = PriceBlankChk,
          @PreDateChk = PreDateChk,
          @CustSumAmtChk = CustSumAmtChk,
          @CustAmtZeroChk = CustAmtZeroChk,
          @CustPOChk = CustPOChk,
          @TransChk = TransChk,
          @TradeChk = TradeChk,
          @OutPortChk = OutPortChk,
          @InPortChk = InPortChk,
          @UpFileChk = UpFileChk,
          @RateChk = RateChk,
          @PaidChk = PaidChk,
          @AvailableChk = AvailableChk,
          @Credit30WChk = Credit30WChk,
          @DetailChk = DetailChk
		from COP_PoCheck where OrderChkNo = @InOrderChkNo

     -- 寫入訂單主檔檢核資料
		if @DepChk = 'N' or
		 @DepBlankChk = 'N' or
		 @PackListBlankChk = 'N' or
		 @PriceBlankChk = 'N' or
		 @PreDateChk = 'N' or

		 @CustSumAmtChk = 'N' or
		 @CustAmtZeroChk = 'N' or
		 @CustPOChk = 'N' or
		 @TransChk = 'N' or
		 @TradeChk = 'N' or

		 @OutPortChk = 'N' or
		 @InPortChk = 'N' or
		 @UpFileChk = 'N' or
         @DetailChk = 'N' or
		 @RateChk = 'N' or

		 @PaidChk = 'N' or
		 @AvailableChk = 'N' or
		 @Credit30WChk = 'N'

		  set @FinChk_M = 'N'
		else
          set @FinChk_M = 'Y'

		update COP_PoCheck set FinChk = @FinChk_M
		where OrderChkNo = @InOrderChkNo

       COMMIT

	   SET  @result = 'SUCCESS'



	END TRY

	BEGIN CATCH

		SET  @result = 'error'
		ROLLBACK;

		PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR(MAX));
		PRINT 'Error Message: ' + ERROR_MESSAGE();

    END CATCH

     PRINT @result

END
GO

CREATE OR ALTER PROCEDURE [dbo].[prc_ImportSalesOrder]

@Executor varchar(40), -- 執行人員
@result VARCHAR(50) OUTPUT  --傳回結果

AS
BEGIN
DECLARE 

@aStatus varchar(1),
@Creator varchar(40), 
@CreateTime datetime

SET @Creator = 'ImportSalesOrder'

if (@Executor <> '')
  SET @Creator = @Executor


SET @CreateTime = GETDATE()

  --開啟交易
  BEGIN TRANSACTION;
    BEGIN TRY

	    -- 匯入國外銷貨單資料
        insert into COP_SalesOrder (COP_Source,TG003,
		TH001,TH002,TH003,TH004,TH005,
		TH006,TH009,TH007,TH008,TH012,
		TH013,TG011,TG012,TH037,TH038,
		TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
		TA001,TA002,PlanNumber,CustomerNo,CustomerName,
		Memo,aStatus,Creator,CreateTime)

		SELECT DISTINCT '浦瑞ERP' COP_Source,TG.TG003 銷貨日期,
		TH.TH001 銷貨單別,TH.TH002 銷貨單號,TH.TH003 銷貨序號,TH.TH004 品號,TH.TH005 品名,
		TH.TH006 規格,TH.TH009 單位,TH.TH007 倉別,TH.TH008 數量,TH.TH012 單價,
		TH.TH013 金額,TG.TG011 幣別,TG.TG012 匯率,TH.TH037 本幣未稅金額,TH.TH038 本幣稅額,
		TH.TH024 贈品數量,TH.TH014 訂單單別,TH.TH015 訂單單號,TH.TH016 訂單序號,TH.TH018 備註, TC.TC012 客戶單號, NULL 銘版序號,
		'' 製令單別,'' 製令單號,RTRIM(TA.TA033) AS PlanNumber,TG.TG004 as 客戶代號,MA.MA002 as 客戶名稱,
		'','Y',@Creator,@CreateTime--,*
		--  select *
		FROM [192.168.1.200].TWPR.dbo.COPTH TH
--		LEFT JOIN [192.168.1.200].PBS.dbo.OrderDTB TB ON TB.OrderNo = rtrim(TH.TH014+'-'+TH.TH015) AND TB.OrderSeq = TH.TH016
        -- 2026-09-21 註解掉：PRORIL_WEB.dbo.NPS_D_Order 的跨庫 JOIN 在部分環境（51002）執行帳號
        -- 對 PRORIL_WEB 沒有 SELECT 權限會直接失敗；SerialNosJson 改由 SerialNoSyncHostedService
        -- 排程另外補寫，見 api/Services/SerialNoSyncHostedService.cs。
        -- LEFT join PRORIL_WEB.dbo.NPS_D_Order TB on TB.OrderType+'-'+ rtrim(TB.OrderNo)+TB.OrderSno = TH.TH014 + '-'+ RTRIM(TH.TH015) + TH.TH016
-- 		LEFT JOIN [192.168.1.200].PRORIL.dbo.MOCTA TA ON TH.TH014 = TA.TA026 and TH.TH015 = TA.TA027 and TH.TH016 = TA.TA028 AND TH.TH004 = TA.TA006 AND TA.TA013 ='Y' AND  TA.TA011 = 'Y'-- 製令單 AND  TA.TA011 <> 'y'
		LEFT JOIN (SELECT DISTINCT TA001,TA002,TA026,TA027,TA028,TA006,TA033 FROM [192.168.1.200].PRORIL.dbo.MOCTA WHERE TA013 ='Y' AND  TA011 = 'Y') TA ON TH.TH014 = TA.TA026 and TH.TH015 = TA.TA027 and TH.TH016 = TA.TA028 AND TH.TH004 = TA.TA006
		LEFT JOIN [192.168.1.200].PRORIL.dbo.COPTC TC ON TC.TC001 = TH.TH014 AND TC.TC002 = TH.TH015
		LEFT JOIN [192.168.1.200].TWPR.dbo.COPTG TG ON TG.TG001 = TH.TH001 AND TG.TG002 = TH.TH002 
		LEFT JOIN [192.168.1.200].TWPR.dbo.COPMA MA ON MA.MA001 = TG.TG004
		LEFT JOIN dbo.COP_SalesOrder CSO ON CSO.TH001 = TH.TH001 COLLATE DATABASE_DEFAULT and CSO.TH002 = TH.TH002 COLLATE DATABASE_DEFAULT and CSO.TH003 = TH.TH003 COLLATE DATABASE_DEFAULT
		WHERE 1=1
		AND TH.TH020 = 'Y'
		AND TH.TH001 LIKE '28%'
		AND CSO.TH001 IS NULL
		--AND TA.TA001 IS NULL -- 查無製令及訂單的浦瑞銷貨單
		--AND TG.TG001 IS not NULL
		order by TH.TH001,TH.TH002,TH.TH003


	    -- 匯入國內銷貨單資料
        insert into COP_SalesOrder (COP_Source,TG003,
		TH001,TH002,TH003,TH004,TH005,
		TH006,TH009,TH007,TH008,TH012,
		TH013,TG011,TG012,TH037,TH038,
		TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
		TA001,TA002,PlanNumber,CustomerNo,CustomerName,
		Memo,aStatus,Creator,CreateTime)

		SELECT DISTINCT '芳晟ERP' COP_Source,TG.TG003,
		TH.TH001 銷貨單別,TH.TH002 銷貨單號,TH.TH003 銷貨序號,TH.TH004 品號,TH.TH005 品名,
		TH.TH006 規格,TH.TH009 單位,TH.TH007 倉別,TH.TH008 數量,TH.TH012 單價,
		TH.TH013 金額,TG.TG011 幣別,TG.TG012 匯率,TH.TH037 本幣未稅金額,TH.TH038 本幣稅額,
		TH.TH024 贈品數量,TH.TH014 訂單單別,TH.TH015 訂單單號,TH.TH016 訂單序號,TH.TH018 備註, TC.TC012 客戶單號,NULL 銘版序號,
		'' 製令單別,'' 製令單號,RTRIM(TA.TA033) AS PlanNumber,TG.TG004 as 客戶代號,MA.MA002 as 客戶名稱,
		'','Y',@Creator,@CreateTime--,*
--      select *
		FROM [192.168.1.200].PRORIL.dbo.COPTH TH
--		LEFT JOIN [192.168.1.200].PBS.dbo.OrderDTB TB ON TB.OrderNo = rtrim(TH.TH014+'-'+TH.TH015) AND TB.OrderSeq = TH.TH016
        -- 2026-09-21 註解掉，理由同上一個 INSERT（國外銷貨單）那段。
        -- LEFT join PRORIL_WEB.dbo.NPS_D_Order TB on TB.OrderType+'-'+ rtrim(TB.OrderNo)+TB.OrderSno = TH.TH014 + '-'+ RTRIM(TH.TH015) + TH.TH016
--		LEFT JOIN [192.168.1.200].PRORIL.dbo.MOCTA TA ON TH.TH014 = TA.TA026 and TH.TH015 = TA.TA027 and TH.TH016 = TA.TA028 AND TH.TH004 = TA.TA006 AND TA.TA013 ='Y' AND  TA.TA011 = 'Y' --AND  TA.TA011 <> 'y'-- 製令單
		LEFT JOIN (SELECT DISTINCT TA001,TA002,TA026,TA027,TA028,TA006,TA033 FROM [192.168.1.200].PRORIL.dbo.MOCTA WHERE TA013 ='Y' AND  TA011 = 'Y') TA ON TH.TH014 = TA.TA026 and TH.TH015 = TA.TA027 and TH.TH016 = TA.TA028 AND TH.TH004 = TA.TA006
		LEFT JOIN [192.168.1.200].PRORIL.dbo.COPTC TC ON TC.TC001 = TH.TH014 AND TC.TC002 = TH.TH015
		LEFT JOIN [192.168.1.200].PRORIL.dbo.COPTG TG ON TG.TG001 = TH.TH001 AND TG.TG002 = TH.TH002 
		LEFT JOIN [192.168.1.200].PRORIL.dbo.COPMA MA ON MA.MA001 = TG.TG004
		LEFT JOIN dbo.COP_SalesOrder CSO ON CSO.TH001 = TH.TH001 COLLATE DATABASE_DEFAULT and CSO.TH002 = TH.TH002 COLLATE DATABASE_DEFAULT and CSO.TH003 = TH.TH003 COLLATE DATABASE_DEFAULT
		WHERE 1=1
		AND TH.TH020 = 'Y'
		AND TH.TH001 LIKE '23%'
		AND CSO.TH001 IS NULL
		--AND TH.TH004 LIKE '5%'
		--AND TA.TA001 IS NULL -- 查無製令及訂單的浦瑞銷貨單
		--AND TG.TG001 IS not NULL
		order by TH.TH001,TH.TH002,TH.TH003

		-- 刪除重覆資料
		delete CSO
		-- select *
		-- select distinct CSO.COP_Source,CSO.TH001,CSO.TH002,CSO.TH003,CSO.TH004
		from COP_SalesOrder CSO 
		inner join 
		  (select COP_Source,TH001,TH002,TH003,TH004, min(ID) ID from COP_SalesOrder
		   where 1=1
		   GROUP BY COP_Source,TH001,TH002,TH003,TH004 HAVING COUNT(*) > 1) F on F.TH001 = CSO.TH001 and F.TH002 = CSO.TH002 and F.TH003 = CSO.TH003
		where 1=1
		and CSO.ID <> F.ID


	COMMIT
        
	SET  @result = 'SUCCESS' 

	END TRY
	BEGIN CATCH
    SET  @result = 'error'
	ROLLBACK;
	PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR(MAX));
	PRINT 'Error Message: ' + ERROR_MESSAGE();
    END CATCH

    PRINT @result



END


GO

CREATE OR ALTER PROCEDURE [dbo].[prc_QuerySalesOrder]

@InCustomerNo varchar(20), -- 客戶編號
@ProductNo_Type varchar(1), -- 品號類型 A:不選(全部記錄) 1:全選(目前只有5,x) 5:成品 x:非成品
@ProductNo varchar(40), -- 品號
@ProductName varchar(120), -- 品名
@ProductSpecification varchar(120), -- 規格
@StartDate varchar(40), -- 起始日期
@EndDate varchar(40), -- 終止日期
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

-- 20260605 以銷貨單號排序,造成[銷貨單統計]頁面資料錯誤,增加[TG003]改為以銷貨日期排序
@TG003 nvarchar(50), 
--------------------------------------------------------------------------------------

@TH001 nvarchar(50),
@TH002 nvarchar(50),
@TH003 nvarchar(50),
@TH004 nvarchar(40),
@TH005 nvarchar(120),
@TH006 nvarchar(120),
@TH009 nvarchar(6),
@TH007 nvarchar(10),
@TH008 numeric(16, 3),
@TH012 numeric(21, 6),
@TH013 numeric(21, 6),
@TG011 nvarchar(4),
@TG012 numeric(16, 3),
@TH037 numeric(21, 6),
@TH038 numeric(21, 6),
@TH024 numeric(16, 3),
@TH014 nvarchar(4),
@TH015 nvarchar(11),
@TH016 nvarchar(4),
@SerialNosJson nvarchar(max),
@TA001 nchar(4),
@TA002 nchar(11),
@PlanNumber nvarchar(40),
@TA026 nvarchar(4),
@TA027 nvarchar(11),
@TA028 nvarchar(4),
@SerialNosJson1 nvarchar(max),
@TA0011 nchar(4),
@TA0021 nchar(11),
@PlanNumber1 nvarchar(40),
@CustomerNo varchar(20),
@CustomerName nvarchar(80),
@Memo nvarchar(500),
@aStatus varchar(1),
@Creator nvarchar(40),
--@CreateTime datetime,
@Modifier nvarchar(40),
@ModiTime datetime,


@TH018 nvarchar(255),
@TC012 nvarchar(20),


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

  exec prc_ImportSalesOrder 'system',@ret

  BEGIN TRANSACTION;
  --開啟交易

    -- 建立匯出使用的資料集
	CREATE TABLE [dbo].[#SalesOrder](
		[ID] [int] IDENTITY(1,1) NOT NULL,
		[COP_Source] [nvarchar](10)  NULL,
		[TG003] [nvarchar](50)  NULL,
		[TH001] [nvarchar](50)  NULL,
		[TH002] [nvarchar](50)  NULL,
		[TH003] [nvarchar](50)  NULL,
		[TH004] [nvarchar](40) NULL,
		[TH005] [nvarchar](120) NULL,
		[TH006] [nvarchar](120) NULL,
		[TH009] [nvarchar](6) NULL,
		[TH007] [nvarchar](10) NULL,
		[TH008] [numeric](16, 3) NULL,
		[SumQty] [numeric](16, 3) NULL,
		[TH012] [numeric](21, 6) NULL,
		[TH013] [numeric](21, 6) NULL,
		[TG011] [nvarchar](4) NULL,
		[TG012] [numeric](16, 3) NULL,
		[TH037] [numeric](21, 6) NULL,
		[TH038] [numeric](21, 6) NULL,
		[SumAmt] [numeric](21, 6) NULL,
		[TH024] [numeric](16, 3) NULL,
		[TH014] [nvarchar](4) NULL,
		[TH015] [nvarchar](11) NULL,
		[TH016] [nvarchar](4) NULL,
		[TH018] [nvarchar](255) NULL,
		[TC012] [nvarchar](20) NULL,
		[SerialNosJson] [nvarchar](max) NULL,
		[TA001] [nchar](4) NULL,
		[TA002] [nchar](11) NULL,
		[PlanNumber] [nvarchar](40) NULL,
		[TA026] [nvarchar](4) NULL,
		[TA027] [nvarchar](11) NULL,
		[TA028] [nvarchar](4) NULL,
		[SerialNosJson1] [nvarchar](max) NULL,
		[TA0011] [nchar](4) NULL,
		[TA0021] [nchar](11) NULL,
		[PlanNumber1] [nvarchar](40) NULL,
		[CustomerNo] [varchar](20) NULL,
		[CustomerName] [nvarchar](80) NULL,
		[Memo] [nvarchar](500) NULL,
        [FooterFlag] [varchar](1) null,
        [aStatus] [varchar](1) NULL,
		[Creator] [nvarchar](40) NULL,
		[CreateTime] [datetime] NULL,
		[Modifier] [nvarchar](40) NULL,
		[ModiTime] [datetime] NULL)


    BEGIN TRY

	  SET @CreateTime = GETDATE()

	  set @FooterFlag = 'N'

	  SET @statement = '
	    insert into #SalesOrder (COP_Source,TG003,
		  TH001,TH002,TH003,TH004,TH005,
		  TH006,TH009,TH007,TH008,TH012,
		  TH013,TG011,TG012,TH037,TH038,
		  TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
		  TA001,TA002,PlanNumber,CustomerNo,CustomerName,Memo,FooterFlag,aStatus,Creator,CreateTime) 
        select DISTINCT COP_Source,TG003,
          TH001,TH002,TH003,TH004,TH005,
		  TH006,TH009,TH007,TH008,TH012,
		  TH013,TG011,TG012,TH037,TH038,
		  TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
		  TA001,TA002,PlanNumber,CustomerNo,CustomerName,Memo,''N'',aStatus,Creator,CreateTime 
		from COP_SalesOrder CSO
	  '

      SET @where = ' WHERE 1 = 1 '
      SET @orderby = ''
      

      -- 取得查詢資料集

	    IF (ISNULL(@InCustomerNo,'') <> '')
		BEGIN
		  SET @where = @where + ' AND CustomerNo = '''+ @InCustomerNo + ''''
		END

		-- 品號類型 A:不選(全部記錄) 1:全選(目前只有5,x) 5:成品 x:非成品
	    IF (ISNULL(@ProductNo_Type,'A') <> 'A' and ISNULL(@ProductNo_Type,'A') <> 'a')
		BEGIN
		  SET @where = @where + ' AND TH004 LIKE  '''+ @ProductNo_Type + '%'' '
		END
		else
	    IF (ISNULL(@ProductNo_Type,'A') = 'a')
		BEGIN
		  SET @where = @where + ' AND substring(TH004,1,1) in (''5'',''x'') '
		END

	    IF (ISNULL(@ProductNo,'') <> '')
		BEGIN
		  SET @where = @where + ' AND TH004 LIKE  ''%'+ @ProductNo + '%'' '
		END

	    IF (ISNULL(@ProductName,'') <> '')
		BEGIN
		  SET @where = @where + ' AND TH005 LIKE  ''%'+ @ProductName + '%'' '
		END

	    IF (ISNULL(@ProductSpecification,'') <> '')
		BEGIN
		  SET @where = @where + ' AND TH006 LIKE  ''%'+ @ProductSpecification + '%'' '
		END

--		PRINT @StartDate

	    IF (ISNULL(@StartDate,'') <> '')
		BEGIN
		  SET @where = @where + 
		  ' AND CONVERT(date,cast(SUBSTRING(TH002,1,3)+1911 as varchar(4))+SUBSTRING(TH002,4,4)) >= CONVERT(date,'''+ @StartDate + ''')' 
		END

	    IF (ISNULL(@EndDate,'') <> '')
		BEGIN
		  SET @where = @where + 
		  ' AND CONVERT(date,cast(SUBSTRING(TH002,1,3)+1911 as varchar(4))+SUBSTRING(TH002,4,4)) <= CONVERT(date,'''+ @EndDate + ''')' 
		END

	    IF (ISNULL(@SerialNo,'') <> '')
		BEGIN
		  SET @where = @where + ' AND SerialNosJson LIKE  ''%'+ @SerialNo + '%'' '
		END

	    IF (ISNULL(@PoNo,'') <> '')
		BEGIN
		  SET @where = @where + ' AND TH014 + ''-'' + TH015  LIKE ''%'+ @PoNo + '%'''
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

	   SELECT * into #tmpCSO FROM  [#SalesOrder]

	   delete from [#SalesOrder]

--	  select * from #tmpCSO

--    drop table #tmpCSO

--    drop table [#SalesOrder]

		-- 按群組計算統計資料

		-- 逐筆寫入並產生Footer

          DECLARE CRS CURSOR FOR 
		  select COP_Source,TG003,
		  TH001,TH002,TH003,TH004,TH005,
		  TH006,TH009,TH007,TH008,TH012,
		  TH013,TG011,TG012,TH037,TH038,
		  TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
		  TA001,TA002,PlanNumber,CustomerNo,CustomerName,Memo,aStatus,Creator,CreateTime
		  FROM #tmpCSO
			order by ID

			OPEN CRS 
			FETCH NEXT FROM CRS INTO  @COP_Source,@TG003,
		    @TH001,@TH002,@TH003,@TH004,@TH005,
		    @TH006,@TH009,@TH007,@TH008,@TH012,
		    @TH013,@TG011,@TG012,@TH037,@TH038,
		    @TH024,@TH014,@TH015,@TH016,@TH018,@TC012,@SerialNosJson,
		    @TA001,@TA002,@PlanNumber,@CustomerNo,@CustomerName,@Memo,@aStatus,@Creator,@CreateTime

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


			while(@@fetch_status != -1)
			begin
			  -- 總數計算
			  SET @TotalQty = @TotalQty + @TH008
			  SET @TotalAmt = @TotalAmt + @TH037 + @TH038

    	      SET @SumQty = @SumQty + @TH008
              SET @SumAmt = @SumAmt + @TH037 + @TH038

                -- 寫入記錄
				insert into #SalesOrder (COP_Source,TG003,
				TH001,TH002,TH003,TH004,TH005,
				TH006,TH009,TH007,TH008,SumQty,TH012,
				TH013,TG011,TG012,TH037,TH038,SumAmt,
				TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
				TA001,TA002,PlanNumber,CustomerNo,CustomerName,Memo,FooterFlag,aStatus,Creator,CreateTime) 

				select  @COP_Source,@TG003,
				@TH001,@TH002,@TH003,@TH004,@TH005,
				@TH006,@TH009,@TH007,@TH008,@TH008,@TH012,
				@TH013,@TG011,@TG012,@TH037,@TH038,@TH037+@TH038,
				@TH024,@TH014,@TH015,@TH016,@TH018,@TC012,@SerialNosJson,
				@TA001,@TA002,@PlanNumber,@CustomerNo,@CustomerName,@Memo,@FooterFlag,@aStatus,@Creator,@CreateTime

        	   SET @RecIdx = @RecIdx + 1

			   print @TH004

			   SELECT @RecCnt = count(*) FROM #tmpCSO
				WHERE 1=1
				AND TH004 = @TH004

               print @RecCnt
               print @RecIdx


--			   if (@RecCnt > 1  AND @SumProductNo <> @TH004) 
			   if (@RecCnt > 1  AND @RecIdx = @RecCnt) 
               begin
                   set @GroupFlag = 'Y'

                   print '@SumProductNo : ' +  @SumProductNo

                   print '@TH004 : ' +  @TH004

					set @FooterFlag = 'Y'
					set @FooterWrite = 'Y'

					-- 產生Footer記錄
					insert into #SalesOrder (COP_Source,TG003,
					TH001,TH002,TH003,TH004,TH005,
					TH006,TH009,TH007,TH008,SumQty,TH012,
					TH013,TG011,TG012,TH037,TH038,SumAmt,
					TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
					TA001,TA002,PlanNumber,CustomerNo,CustomerName,
					Memo,FooterFlag,aStatus,Creator,CreateTime) 

					select  '','',
					'','','',@SumProductNo,@TH005,
					@TH006,NULL,'',@SumQty,@SumQty,NULL,
					NULL,'',NULL,NULL,NULL,@SumAmt,
					NULL,'','','','','','',
					'','','','','',
					'',@FooterFlag,'Y','',null

				    set @RecIdx = 0
					set @SumQty = 0
					set @SumAmt = 0
					set @SumProductNo = @TH004
					set @FooterWrite = 'N'
					set @FooterFlag = 'N'

                end 
				else
			    if (@RecCnt = 1 ) 
                begin
				    set @RecIdx = 0
					set @SumQty = 0
					set @SumAmt = 0
					set @SumProductNo = @TH004
					set @FooterWrite = 'N'
					set @FooterFlag = 'N'
--					set @FooterFlag = 'S'
			    end

				set @SumProductNo = @TH004

				FETCH NEXT FROM CRS INTO @COP_Source,@TG003,
				@TH001,@TH002,@TH003,@TH004,@TH005,
				@TH006,@TH009,@TH007,@TH008,@TH012,
				@TH013,@TG011,@TG012,@TH037,@TH038,
				@TH024,@TH014,@TH015,@TH016,@TH018,@TC012,@SerialNosJson,
				@TA001,@TA002,@PlanNumber,@CustomerNo,@CustomerName,@Memo,@aStatus,@Creator,@CreateTime
			
			end
			-- 產生Total記錄
			insert into #SalesOrder (COP_Source,TG003,
			TH001,TH002,TH003,TH004,TH005,
			TH006,TH009,TH007,TH008,SumQty,TH012,
			TH013,TG011,TG012,TH037,TH038,SumAmt,
			TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
			TA001,TA002,PlanNumber,CustomerNo,CustomerName,
			Memo,FooterFlag,aStatus,Creator,CreateTime) 

			select  '','',
			'','','','Total','',
			@TH006,NULL,'',@TotalQty,@TotalQty,NULL,
			NULL,'',NULL,NULL,NULL,@TotalAmt,
			NULL,'','','','','','',
			'','','','','',
			'','T','Y','',null

			close CRS
			deallocate CRS

       -- 群組條件下單一記錄填入 S

	   UPDATE A SET FooterFlag = 'S'
	   -- select *  
		from #SalesOrder A
		INNER JOIN (
			select TH004,COUNT(*) CNT from #SalesOrder
			where 1=1
			AND FooterFlag <> 'Y'
			group by TH004 having COUNT(*) =1
			) B ON B.TH004 = A.TH004


---	   drop table tmp_SalesOrder
	
--	   select * into tmp_SalesOrder from #SalesOrder order by ID
	   select * from #SalesOrder order by ID
        
--	    SET  @ret = 'SUCCESS' 
      

	  DROP TABLE  #tmpCSO

	  DROP TABLE #SalesOrder

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

CREATE OR ALTER PROCEDURE [dbo].[prc_QuerySalesOrder_1]

@InCustomerNo varchar(20), -- 客戶編號
@ProductNo_Type varchar(1), -- 品號類型 A:不選(全部記錄) 1:全選(目前只有5,x) 5:成品 x:非成品
@ProductNo varchar(40), -- 品號
@ProductName varchar(120), -- 品名
@ProductSpecification varchar(120), -- 規格
@StartDate varchar(40), -- 起始日期
@EndDate varchar(40), -- 終止日期
@SerialNo varchar(40), -- 銘版序號
@PoNo varchar(120), -- 訂單號
@OrderType varchar(4), -- 銷貨單別
@OrderNo varchar(12), -- 銷貨單號
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
@TG003 nvarchar(50),
@TH001 nvarchar(50),
@TH002 nvarchar(50),
@TH003 nvarchar(50),
@TH004 nvarchar(40),
@TH005 nvarchar(120),
@TH006 nvarchar(120),
@TH009 nvarchar(6),
@TH007 nvarchar(10),
@TH008 numeric(16, 3),
@TH012 numeric(21, 6),
@TH013 numeric(21, 6),
@TG011 nvarchar(4),
@TG012 numeric(16, 3),
@TH037 numeric(21, 6),
@TH038 numeric(21, 6),
@TH024 numeric(16, 3),
@TH014 nvarchar(4),
@TH015 nvarchar(11),
@TH016 nvarchar(4),
@SerialNosJson nvarchar(max),
@TA001 nchar(4),
@TA002 nchar(11),
@PlanNumber nvarchar(40),
@TA026 nvarchar(4),
@TA027 nvarchar(11),
@TA028 nvarchar(4),
@SerialNosJson1 nvarchar(max),
@TA0011 nchar(4),
@TA0021 nchar(11),
@PlanNumber1 nvarchar(40),
@CustomerNo varchar(20),
@CustomerName nvarchar(80),
@Memo nvarchar(500),
@aStatus varchar(1),
@Creator nvarchar(40),
@Modifier nvarchar(40),
@ModiTime datetime,

@TH018 nvarchar(255),
@TC012 nvarchar(20),

@HeaderWrite varchar(1) ,
@FooterWrite varchar(1) ,
@FooterFlag varchar(1) ,
@GroupFlag varchar(1) ,

-- 加總計算
@RecCnt int,
@RecIdx int,
@SumQty numeric(16, 3),
@SumAmt numeric(16, 3),
@SumTH013 numeric(21, 6),   -- TH013 小計變數
@TotalQty numeric(16, 3),
@TotalAmt numeric(16, 3),
@TotalTH013 numeric(21, 6), -- TH013 總計變數
@SumNo varchar(40),

-- 判斷 TG011 幣別是否一致的控制變數
@FirstTG011 nvarchar(4),
@HasDiffTG011 varchar(1),
@TotalFirstTG011 nvarchar(4),
@TotalHasDiffTG011 varchar(1),

@ret VARCHAR(50)  --傳回結果

exec prc_ImportSalesOrder 'system',@ret

  BEGIN TRANSACTION;
  --開啟交易

  CREATE TABLE [dbo].[#SalesOrder_1](
    [ID] [int] IDENTITY(1,1) NOT NULL,
    [COP_Source] [nvarchar](10)  NULL,
    [TG003] [nvarchar](50)  NULL,
    [TH001] [nvarchar](50)  NULL,
    [TH002] [nvarchar](50)  NULL,
    [TH003] [nvarchar](50)  NULL,
    [TH004] [nvarchar](40) NULL,
    [TH005] [nvarchar](120) NULL,
    [TH006] [nvarchar](120) NULL,
    [TH009] [nvarchar](6) NULL,
    [TH007] [nvarchar](10) NULL,
    [TH008] [numeric](16, 3) NULL,
    [SumQty] [numeric](16, 3) NULL,
    [TH012] [numeric](21, 6) NULL,
    [TH013] [numeric](21, 6) NULL,
    [TG011] [nvarchar](4) NULL,
    [TG012] [numeric](16, 3) NULL,
    [TH037] [numeric](21, 6) NULL,
    [TH038] [numeric](21, 6) NULL,
    [SumAmt] [numeric](21, 6) NULL,
    [TH024] [numeric](16, 3) NULL,
    [TH014] [nvarchar](4) NULL,
    [TH015] [nvarchar](11) NULL,
    [TH016] [nvarchar](4) NULL,
    [TH018] [nvarchar](255) NULL,
    [TC012] [nvarchar](20) NULL,
    [SerialNosJson] [nvarchar](max) NULL,
    [TA001] [nchar](4) NULL,
    [TA002] [nchar](11) NULL,
    [PlanNumber] [nvarchar](40) NULL,
    [TA026] [nvarchar](4) NULL,
    [TA027] [nvarchar](11) NULL,
    [TA028] [nvarchar](4) NULL,
    [SerialNosJson1] [nvarchar](max) NULL,
    [TA0011] [nchar](4) NULL,
    [TA0021] [nchar](11) NULL,
    [PlanNumber1] [nvarchar](40) NULL,
    [CustomerNo] [varchar](20) NULL,
    [CustomerName] [nvarchar](80) NULL,
    [Memo] [nvarchar](500) NULL,
    [FooterFlag] [varchar](1) null,
    [aStatus] [varchar](1) NULL,
    [Creator] [nvarchar](40) NULL,
    [CreateTime] [datetime] NULL,
    [Modifier] [nvarchar](40) NULL,
    [ModiTime] [datetime] NULL)

    BEGIN TRY

    SET @CreateTime = GETDATE()
    set @FooterFlag = 'N'

    SET @statement = '
      insert into #SalesOrder_1 (COP_Source,TG003,
      TH001,TH002,TH003,TH004,TH005,
      TH006,TH009,TH007,TH008,TH012,
      TH013,TG011,TG012,TH037,TH038,
      TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
      TA001,TA002,PlanNumber,CustomerNo,CustomerName,Memo,FooterFlag,aStatus,Creator,CreateTime) 
        select DISTINCT COP_Source,TG003,
          TH001,TH002,TH003,TH004,TH005,
      TH006,TH009,TH007,TH008,TH012,
      TH013,TG011,TG012,TH037,TH038,
      TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
      TA001,TA002,PlanNumber,CustomerNo,CustomerName,Memo,''N'',aStatus,Creator,CreateTime 
    from COP_SalesOrder CSO
    '

      SET @where = ' WHERE 1 = 1 '
      SET @orderby = ''
      
      IF (ISNULL(@InCustomerNo,'') <> '')
    BEGIN
      SET @where = @where + ' AND CustomerNo = '''+ @InCustomerNo + ''''
    END

      IF (ISNULL(@ProductNo_Type,'A') <> 'A' and ISNULL(@ProductNo_Type,'A') <> 'a')
    BEGIN
      SET @where = @where + ' AND TH004 LIKE  '''+ @ProductNo_Type + '%'' '
    END
    else
      IF (ISNULL(@ProductNo_Type,'a') = 'a')
    BEGIN
      SET @where = @where + ' AND substring(TH004,1,1) in (''5'',''x'') '
    END

      IF (ISNULL(@ProductNo,'') <> '')
    BEGIN
      SET @where = @where + ' AND TH004 LIKE  ''%'+ @ProductNo + '%'' '
    END

      IF (ISNULL(@ProductName,'') <> '')
    BEGIN
      SET @where = @where + ' AND TH005 LIKE  ''%'+ @ProductName + '%'' '
    END

      IF (ISNULL(@ProductSpecification,'') <> '')
    BEGIN
      SET @where = @where + ' AND TH006 LIKE  ''%'+ @ProductSpecification + '%'' '
    END

      IF (ISNULL(@StartDate,'') <> '')
    BEGIN
      SET @where = @where + 
      ' AND CONVERT(date,cast(SUBSTRING(TH002,1,3)+1911 as varchar(4))+SUBSTRING(TH002,4,4)) >= CONVERT(date,'''+ @StartDate + ''')' 
    END

      IF (ISNULL(@EndDate,'') <> '')
    BEGIN
      SET @where = @where + 
      ' AND CONVERT(date,cast(SUBSTRING(TH002,1,3)+1911 as varchar(4))+SUBSTRING(TH002,4,4)) <= CONVERT(date,'''+ @EndDate + ''')' 
    END

      IF (ISNULL(@SerialNo,'') <> '')
    BEGIN
      SET @where = @where + ' AND SerialNosJson LIKE  ''%'+ @SerialNo + '%'' '
    END

      IF (ISNULL(@PoNo,'') <> '')
    BEGIN
      SET @where = @where + ' AND TH014 + ''-'' + TH015  LIKE ''%'+ @PoNo + '%'''
    END

      IF (ISNULL(@OrderType,'') <> '')
    BEGIN
      SET @where = @where + ' AND TH001 = '''+ @OrderType + ''''
    END

      IF (ISNULL(@OrderNo,'') <> '')
    BEGIN
      SET @where = @where + ' AND TH002 = '''+ @OrderNo + ''''
    END

      IF (ISNULL(@InPlanNumber,'') <> '')
    BEGIN
      SET @where = @where + ' AND PlanNumber LIKE ''%'+ @InPlanNumber + '%'''
    END

      IF (ISNULL(@GroupType,'') <> '')
    BEGIN
      SET @orderby = ' ORDER BY TG003,COP_Source,TH001,TH002,TH003 ' 
    END

       SET @statement = @statement + @where + @orderby
 
       PRINT 'STATEMENT: ' + @statement

       EXEC sp_executesql @statement

     SELECT * into #tmpCSO_1 FROM  [#SalesOrder_1]

     delete from [#SalesOrder_1]

      DECLARE CRS CURSOR FOR 
      select COP_Source,TG003,
      TH001,TH002,TH003,TH004,TH005,
      TH006,TH009,TH007,TH008,TH012,
      TH013,TG011,TG012,TH037,TH038,
      TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
      TA001,TA002,PlanNumber,CustomerNo,CustomerName,Memo,aStatus,Creator,CreateTime
      FROM #tmpCSO_1
      order by ID

      OPEN CRS 
      FETCH NEXT FROM CRS INTO @COP_Source,@TG003,
        @TH001,@TH002,@TH003,@TH004,@TH005,
        @TH006,@TH009,@TH007,@TH008,@TH012,
        @TH013,@TG011,@TG012,@TH037,@TH038,
        @TH024,@TH014,@TH015,@TH016,@TH018,@TC012,@SerialNosJson,
        @TA001,@TA002,@PlanNumber,@CustomerNo,@CustomerName,@Memo,@aStatus,@Creator,@CreateTime

      set @SumNo = ''
      set @RecCnt = 0
      set @RecIdx = 0
      set @SumQty = 0
      set @SumAmt = 0
      set @SumTH013 = 0
      set @TotalQty = 0
      set @TotalAmt = 0
      set @TotalTH013 = 0
      set @FooterWrite = 'N'
      set @FooterFlag = 'N'
      set @GroupFlag = 'N'

      -- 初始化 TG011 檢查欄位
      set @FirstTG011 = NULL
      set @HasDiffTG011 = 'N'
      set @TotalFirstTG011 = NULL
      set @TotalHasDiffTG011 = 'N'

      while(@@fetch_status != -1)
      begin
        -- 檢查全域的 TG011 幣別是否一致 (計算 Total 用)
        IF (@TotalFirstTG011 IS NULL)
        BEGIN
          SET @TotalFirstTG011 = ISNULL(@TG011, '')
        END
        ELSE IF (@TotalFirstTG011 <> ISNULL(@TG011, ''))
        BEGIN
          SET @TotalHasDiffTG011 = 'Y'
        END

        -- 檢查單一銷貨單群組內的 TG011 幣別是否一致 (計算 Footer 用)
        IF (@FirstTG011 IS NULL)
        BEGIN
          SET @FirstTG011 = ISNULL(@TG011, '')
        END
        ELSE IF (@FirstTG011 <> ISNULL(@TG011, ''))
        BEGIN
          SET @HasDiffTG011 = 'Y'
        END

        -- 總數計算
        SET @TotalQty = @TotalQty + ISNULL(@TH008, 0)
        SET @TotalAmt = @TotalAmt + ISNULL(@TH037, 0) + ISNULL(@TH038, 0)
        SET @TotalTH013 = @TotalTH013 + ISNULL(@TH013, 0)

        SET @SumQty = @SumQty + ISNULL(@TH008, 0)
        SET @SumAmt = @SumAmt + ISNULL(@TH037, 0) + ISNULL(@TH038, 0)
        SET @SumTH013 = @SumTH013 + ISNULL(@TH013, 0)

        -- 寫入記錄
        insert into #SalesOrder_1 (COP_Source,TG003,
        TH001,TH002,TH003,TH004,TH005,
        TH006,TH009,TH007,TH008,SumQty,TH012,
        TH013,TG011,TG012,TH037,TH038,SumAmt,
        TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
        TA001,TA002,PlanNumber,CustomerNo,CustomerName,Memo,FooterFlag,aStatus,Creator,CreateTime) 

        select  @COP_Source,@TG003,
        @TH001,@TH002,@TH003,@TH004,@TH005,
        @TH006,@TH009,@TH007,@TH008,@TH008,@TH012,
        @TH013,@TG011,@TG012,@TH037,@TH038,ISNULL(@TH037,0)+ISNULL(@TH038,0),
        @TH024,@TH014,@TH015,@TH016,@TH018,@TC012,@SerialNosJson,
        @TA001,@TA002,@PlanNumber,@CustomerNo,@CustomerName,@Memo,@FooterFlag,@aStatus,@Creator,@CreateTime

        SET @RecIdx = @RecIdx + 1

        print @TH004

        SELECT @RecCnt = count(*) FROM #tmpCSO_1
        WHERE 1=1
        AND TH001 = @TH001
        AND TH002 = @TH002

        print @RecCnt
        print @RecIdx

        if (@RecCnt > 1  AND @RecIdx = @RecCnt) 
        begin
          set @GroupFlag = 'Y'

          print '@SumNo : ' +  @SumNo
          print '@TH001 : ' +  @TH001 + ' ' + @TH002

          set @FooterFlag = 'Y'
          set @FooterWrite = 'Y'

          -- 產生Footer記錄 (小計)：若 TG011 有不同值，TH013 給 NULL
          insert into #SalesOrder_1 (COP_Source,TG003,
          TH001,TH002,TH003,TH004,TH005,
          TH006,TH009,TH007,TH008,SumQty,TH012,
          TH013,TG011,TG012,TH037,TH038,SumAmt,
          TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
          TA001,TA002,PlanNumber,CustomerNo,CustomerName,
          Memo,FooterFlag,aStatus,Creator,CreateTime) 

          select  '','',
          @TH001,@TH002,'','','',
          '','','',@SumQty,@SumQty,NULL,
          CASE WHEN @HasDiffTG011 = 'Y' THEN NULL ELSE @SumTH013 END,'',NULL,NULL,NULL,@SumAmt,
          NULL,'','','','','','',
          '','','',@CustomerNo,@CustomerName,
          '',@FooterFlag,'Y','',null

          set @RecIdx = 0
          set @SumQty = 0
          set @SumAmt = 0
          set @SumTH013 = 0
          set @FirstTG011 = NULL        -- 重置小計幣別
          set @HasDiffTG011 = 'N'       -- 重置異動標記
          set @SumNo = @TH001 + @TH002
          set @FooterWrite = 'N'
          set @FooterFlag = 'N'

        end 
        else
          if (@RecCnt = 1 ) 
          begin
            set @RecIdx = 0
            set @SumQty = 0
            set @SumAmt = 0
            set @SumTH013 = 0
            set @FirstTG011 = NULL      -- 重置小計幣別
            set @HasDiffTG011 = 'N'     -- 重置異動標記
            set @SumNo = @TH001 + @TH002
            set @FooterWrite = 'N'
            set @FooterFlag = 'N'
          end

          set @SumNo = @TH001 + @TH002

        FETCH NEXT FROM CRS INTO @COP_Source,@TG003,
        @TH001,@TH002,@TH003,@TH004,@TH005,
        @TH006,@TH009,@TH007,@TH008,@TH012,
        @TH013,@TG011,@TG012,@TH037,@TH038,
        @TH024,@TH014,@TH015,@TH016,@TH018,@TC012,@SerialNosJson,
        @TA001,@TA002,@PlanNumber,@CustomerNo,@CustomerName,@Memo,@aStatus,@Creator,@CreateTime
      
      end

      -- 產生 Total 記錄 (總計)：若整體查詢結果中 TG011 有不同值，TH013 給 NULL
      insert into #SalesOrder_1 (COP_Source,TG003,
      TH001,TH002,TH003,TH004,TH005,
      TH006,TH009,TH007,TH008,SumQty,TH012,
      TH013,TG011,TG012,TH037,TH038,SumAmt,
      TH024,TH014,TH015,TH016,TH018,TC012,SerialNosJson,
      TA001,TA002,PlanNumber,CustomerNo,CustomerName,
      Memo,FooterFlag,aStatus,Creator,CreateTime) 

      select  '','',
      '','','','','',
      '','','',@TotalQty,@TotalQty,NULL,
      CASE WHEN @TotalHasDiffTG011 = 'Y' THEN NULL ELSE @TotalTH013 END,'',NULL,NULL,NULL,@TotalAmt,
      NULL,'','','','','','',
      '','','','','Total',
      '','T','Y','',null

      close CRS
      deallocate CRS

      -- 群組條件下單一記錄填入 S
      UPDATE A SET FooterFlag = 'S'
      from #SalesOrder_1 A
      INNER JOIN (
        select TH001,TH002,COUNT(*) CNT from #SalesOrder_1
        where 1=1
        AND FooterFlag <> 'Y'
        group by TH001,TH002 having COUNT(*) =1
        ) B ON B.TH001 = A.TH001 and B.TH002 = A.TH002

      select * from #SalesOrder_1 order by ID

      DROP TABLE #tmpCSO_1
      DROP TABLE #SalesOrder_1

      COMMIT

  END TRY

  BEGIN CATCH

    ROLLBACK;

    PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR(MAX));
    PRINT 'Error Message: ' + ERROR_MESSAGE();

  END CATCH

END

GO

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

