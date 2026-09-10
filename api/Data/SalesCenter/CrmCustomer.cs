using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class CrmCustomer
{
    public int Id { get; set; }

    public string? CustomerNo { get; set; }

    public string? CustomerSource { get; set; }

    public string? ErpcustomerNo { get; set; }

    public string? LongName { get; set; }

    public string? ShortName { get; set; }

    public string? ContactName { get; set; }

    public string? ContactTel1 { get; set; }

    public string? ContactTel2 { get; set; }

    public string? ContactFax { get; set; }

    public string? ContactEmail { get; set; }

    public string? Addr1 { get; set; }

    public string? Addr2 { get; set; }

    public string? AreaCode { get; set; }

    public string? CountryCode { get; set; }

    public string? SalesNo { get; set; }

    public string? SalesName { get; set; }

    public string? PotentialCustom { get; set; }

    public string? ErpheadCustomer { get; set; }

    public string? Erpsource { get; set; }

    public string? Memo { get; set; }

    public string? AStatus { get; set; }

    public string? Creator { get; set; }

    public DateTime? CreateTime { get; set; }

    public string? Modifier { get; set; }

    public DateTime? ModiTime { get; set; }
}
