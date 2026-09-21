using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class CopSalesOrder
{
    public int Id { get; set; }

    public string? CopSource { get; set; }

    public string? Tg003 { get; set; }

    public string Th001 { get; set; } = null!;

    public string Th002 { get; set; } = null!;

    public string Th003 { get; set; } = null!;

    public string? Th004 { get; set; }

    public string? Th005 { get; set; }

    public string? Th006 { get; set; }

    public string? Th009 { get; set; }

    public string? Th007 { get; set; }

    public decimal? Th008 { get; set; }

    public decimal? SumQty { get; set; }

    public decimal? Th012 { get; set; }

    public decimal? Th013 { get; set; }

    public string? Tg011 { get; set; }

    public decimal? Tg012 { get; set; }

    public decimal? Th037 { get; set; }

    public decimal? Th038 { get; set; }

    public decimal? SumAmt { get; set; }

    public decimal? Th024 { get; set; }

    public string? Th014 { get; set; }

    public string? Th015 { get; set; }

    public string? Th016 { get; set; }

    public string? Th018 { get; set; }

    public string? Tc012 { get; set; }

    public string? SerialNosJson { get; set; }

    public string? Ta001 { get; set; }

    public string? Ta002 { get; set; }

    public string? PlanNumber { get; set; }

    public string? Ta026 { get; set; }

    public string? Ta027 { get; set; }

    public string? Ta028 { get; set; }

    public string? SerialNosJson1 { get; set; }

    public string? Ta0011 { get; set; }

    public string? Ta0021 { get; set; }

    public string? PlanNumber1 { get; set; }

    public string? CustomerNo { get; set; }

    public string? CustomerName { get; set; }

    public string? Memo { get; set; }

    public string? FooterFlag { get; set; }

    public string? AStatus { get; set; }

    public string? Creator { get; set; }

    public DateTime? CreateTime { get; set; }

    public string? Modifier { get; set; }

    public DateTime? ModiTime { get; set; }
}
