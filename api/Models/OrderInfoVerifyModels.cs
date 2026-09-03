using Proril.SalesIssue.Api.Data;

namespace Proril.SalesIssue.Api.Models;

/// <summary>
/// COP_PoCheck + 對應的檢核規則說明文字（<see cref="CopCheckRule.ChkRule"/>）。
/// 規則文字是「檢核條件」畫面設定的說明，跟著檢核結果一起回給前端，不用另外查表兜。
/// </summary>
public class CopPoCheckExRule : CopPoCheck
{
    public CopPoCheckExRule() { }

    public CopPoCheckExRule(CopPoCheck src, List<CopCheckRule> checkRules)
    {
        Id = src.Id;
        OrderChkNo = src.OrderChkNo;
        ChkTime = src.ChkTime;
        CopSource = src.CopSource;
        PoNo = src.PoNo;
        SumAmt = src.SumAmt;
        SumQty = src.SumQty;
        CustAmt = src.CustAmt;
        AvailableAmt = src.AvailableAmt;
        DepChk = src.DepChk;
        DepBlankChk = src.DepBlankChk;
        PackListBlankChk = src.PackListBlankChk;
        PriceBlankChk = src.PriceBlankChk;
        PreDateChk = src.PreDateChk;
        CustSumAmtChk = src.CustSumAmtChk;
        CustAmtZeroChk = src.CustAmtZeroChk;
        CustPochk = src.CustPochk;
        ProcessCodeChk = src.ProcessCodeChk;
        TransChk = src.TransChk;
        TradeChk = src.TradeChk;
        OutPortChk = src.OutPortChk;
        InPortChk = src.InPortChk;
        UpFileChk = src.UpFileChk;
        DetailChk = src.DetailChk;
        RateChk = src.RateChk;
        PaidChk = src.PaidChk;
        AvailableChk = src.AvailableChk;
        Credit30Wchk = src.Credit30Wchk;
        FinChk = src.FinChk;
        Memo = src.Memo;
        AStatus = src.AStatus;
        Creator = src.Creator;
        CreateTime = src.CreateTime;
        Modifier = src.Modifier;
        ModiTime = src.ModiTime;

        foreach (var rule in checkRules)
        {
            switch (rule.ChkField)
            {
                case "CustAmtZeroChk": CustAmtZeroChkRule = rule.ChkRule; break;
                case "CustSumAmtChk": CustSumAmtChkRule = rule.ChkRule; break;
                case "CustPOChk": CustPochkRule = rule.ChkRule; break;
                case "DepBlankChk": DepBlankChkRule = rule.ChkRule; break;
                case "DepChk": DepChkRule = rule.ChkRule; break;
                case "InPortChk": InPortChkRule = rule.ChkRule; break;
                case "OutPortChk": OutPortChkRule = rule.ChkRule; break;
                case "PackListBlankChk": PackListBlankChkRule = rule.ChkRule; break;
                case "PackListChk": PackListChkRule = rule.ChkRule; break;
                case "PreDateChk": PreDateChkRule = rule.ChkRule; break;
                case "PriceBlankChk": PriceBlankChkRule = rule.ChkRule; break;
                case "PriceChk": PriceChkRule = rule.ChkRule; break;
                case "ProcessCodeChk": ProcessCodeChkRule = rule.ChkRule; break;
                case "TradeChk": TradeChkRule = rule.ChkRule; break;
                case "TransChk": TransChkRule = rule.ChkRule; break;
                case "UpFileChk": UpFileChkRule = rule.ChkRule; break;
                default:
                    if (string.Equals(rule.ChkField, "RateChk", StringComparison.OrdinalIgnoreCase)) RateChkRule = rule.ChkRule;
                    else if (string.Equals(rule.ChkField, "PaidChk", StringComparison.OrdinalIgnoreCase)) PaidChkRule = rule.ChkRule;
                    else if (string.Equals(rule.ChkField, "AvailableChk", StringComparison.OrdinalIgnoreCase)) AvailableChkRule = rule.ChkRule;
                    else if (string.Equals(rule.ChkField, "Credit30WChk", StringComparison.OrdinalIgnoreCase)) Credit30WchkRule = rule.ChkRule;
                    break;
            }
        }
    }

    public string? DepChkRule { get; set; }
    public string? DepBlankChkRule { get; set; }
    public string? PackListChkRule { get; set; }
    public string? PackListBlankChkRule { get; set; }
    public string? PriceChkRule { get; set; }
    public string? PriceBlankChkRule { get; set; }
    public string? PreDateChkRule { get; set; }
    public string? CustSumAmtChkRule { get; set; }
    public string? CustAmtZeroChkRule { get; set; }
    public string? CustPochkRule { get; set; }
    public string? ProcessCodeChkRule { get; set; }
    public string? TransChkRule { get; set; }
    public string? TradeChkRule { get; set; }
    public string? OutPortChkRule { get; set; }
    public string? InPortChkRule { get; set; }
    public string? UpFileChkRule { get; set; }
    public string? RateChkRule { get; set; }
    public string? PaidChkRule { get; set; }
    public string? AvailableChkRule { get; set; }
    public string? Credit30WchkRule { get; set; }
}

/// <summary>COP_PoDetailCheck + 對應的檢核規則說明文字。</summary>
public class CopPoDetailCheckExRule : CopPoDetailCheck
{
    public CopPoDetailCheckExRule() { }

    public CopPoDetailCheckExRule(CopPoDetailCheck src, List<CopCheckRule> checkRules)
    {
        Id = src.Id;
        OrderChkNo = src.OrderChkNo;
        ChkTime = src.ChkTime;
        CopSource = src.CopSource;
        PoNo = src.PoNo;
        Sno = src.Sno;
        ProductNo = src.ProductNo;
        ProductNoChk = src.ProductNoChk;
        QtyChk = src.QtyChk;
        AmtChk = src.AmtChk;
        PriceChk = src.PriceChk;
        PackListChk = src.PackListChk;
        LinkTypeChk = src.LinkTypeChk;
        LinkNoChk = src.LinkNoChk;
        LinkSnoChk = src.LinkSnoChk;
        LinkQtyChk = src.LinkQtyChk;
        LinkPriceChk = src.LinkPriceChk;
        LinkChk = src.LinkChk;
        MoqamtChk = src.MoqamtChk;
        LinkMoqamtChk = src.LinkMoqamtChk;
        FinChk = src.FinChk;
        Memo = src.Memo;
        AStatus = src.AStatus;
        Creator = src.Creator;
        CreateTime = src.CreateTime;
        Modifier = src.Modifier;
        ModiTime = src.ModiTime;

        foreach (var rule in checkRules)
        {
            switch (rule.ChkField)
            {
                case "ProductNoChk": ProductNoChkRule = rule.ChkRule; break;
                case "QtyChk": QtyChkRule = rule.ChkRule; break;
                case "AmtChk": AmtChkRule = rule.ChkRule; break;
                case "PriceChk": PriceChkRule = rule.ChkRule; break;
                case "PackListChk": PackListChkRule = rule.ChkRule; break;
                case "LinkTypeChk": LinkTypeChkRule = rule.ChkRule; break;
                case "LinkNoChk": LinkNoChkRule = rule.ChkRule; break;
                case "LinkSnoChk": LinkSnoChkRule = rule.ChkRule; break;
                case "LinkQtyChk": LinkQtyChkRule = rule.ChkRule; break;
                case "LinkPriceChk": LinkPriceChkRule = rule.ChkRule; break;
                case "LinkChk": LinkChkRule = rule.ChkRule; break;
                case "MOQAmtChk": MoqamtChkRule = rule.ChkRule; break;
                case "LinkMOQAmtChk": LinkMoqamtChkRule = rule.ChkRule; break;
            }
        }
    }

    public string? ProductNoChkRule { get; set; }
    public string? QtyChkRule { get; set; }
    public string? AmtChkRule { get; set; }
    public string? PriceChkRule { get; set; }
    public string? PackListChkRule { get; set; }
    public string? LinkTypeChkRule { get; set; }
    public string? LinkNoChkRule { get; set; }
    public string? LinkSnoChkRule { get; set; }
    public string? LinkQtyChkRule { get; set; }
    public string? LinkPriceChkRule { get; set; }
    public string? LinkChkRule { get; set; }
    public string? MoqamtChkRule { get; set; }
    public string? LinkMoqamtChkRule { get; set; }
}

/// <summary>
/// GetPOCheckView / ExportXls 的查詢結果列：一張訂單裡的一個品號 + 表頭 + 檢核狀態。
/// 同一張訂單的多個品號會重複同一份表頭與 <see cref="CopPoCheck"/>（1.0 就是這樣攤平的）。
/// </summary>
public class VPoListDetailViewModel : VPoList
{
    public VPoListDetailViewModel() { }

    public VPoListDetailViewModel(
        VPoList src,
        CopPoCheckExRule? poCheck,
        VPoDetailList detail,
        CopPoDetailCheckExRule? poDetailCheck,
        List<CopPassCheck> passChecks,
        VProductEnglishAll? productE,
        CopDepData? depData,
        VUpFileData? upFileData)
    {
        CopSource = src.CopSource;
        單別名稱 = src.單別名稱;
        單別 = src.單別;
        單號 = src.單號;
        訂單日期 = src.訂單日期;
        價格條件 = src.價格條件;
        預交日 = src.預交日;
        客戶代號 = src.客戶代號;
        客戶名稱 = src.客戶名稱;
        部門代號 = src.部門代號;
        業務人員 = src.業務人員;
        業務名稱 = src.業務名稱;
        送貨地址一 = src.送貨地址一;
        送貨地址二 = src.送貨地址二;
        付款條件 = src.付款條件;
        課稅別 = src.課稅別;
        運輸方式 = src.運輸方式;
        幣別 = src.幣別;
        匯率 = src.匯率;
        訂單金額 = src.訂單金額;
        總數量 = src.總數量;
        Packinglist備註 = src.Packinglist備註;
        客戶單號 = src.客戶單號;
        交易條件 = src.交易條件;
        交易條件名稱 = src.交易條件名稱;
        起始港口 = src.起始港口;
        目的港口 = src.目的港口;
        連絡人 = src.連絡人;
        TelNo = src.TelNo;
        FaxNo = src.FaxNo;
        付款檢核 = src.付款檢核;
        流程代號 = src.流程代號;
        FinFlag = src.FinFlag;
        ConfirmFlag = src.ConfirmFlag;

        CopPoCheck = poCheck;
        VPoDetail = detail;
        CopPoDetailCheck = poDetailCheck;
        CopPassChecks = passChecks;
        VProductEnglish = productE;
        DepName = depData?.DepName;
        附件檔案 = upFileData?.FileName ?? "";
    }

    public VPoDetailList VPoDetail { get; set; } = null!;
    public CopPoCheckExRule? CopPoCheck { get; set; }
    public CopPoDetailCheckExRule? CopPoDetailCheck { get; set; }
    public List<CopPassCheck> CopPassChecks { get; set; } = new();
    public VProductEnglishAll? VProductEnglish { get; set; }
    public string? DepName { get; set; }
}
