using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class VUnfinOrder
{
    public string CopSource { get; set; } = null!;

    public string? Mq002 { get; set; }

    public string Tc001 { get; set; } = null!;

    public string Tc002 { get; set; } = null!;

    public string Td003 { get; set; } = null!;

    public string? Tc003 { get; set; }

    public string? Tc004 { get; set; }

    public string Ma002 { get; set; } = null!;

    public string? Tc006 { get; set; }

    public string Mv002 { get; set; } = null!;

    public string? Tc010 { get; set; }

    public string? Tc014 { get; set; }

    public string? Tc016 { get; set; }

    public string? Tc019 { get; set; }

    public string? Td004 { get; set; }

    public string? Td005 { get; set; }

    public string? Td006 { get; set; }

    public decimal? Td008 { get; set; }

    public string? Td010 { get; set; }

    public decimal? Td011 { get; set; }

    public decimal? Td012 { get; set; }

    public string? Tc008 { get; set; }

    public decimal? Tc009 { get; set; }

    public decimal? Ntd { get; set; }

    public string? Td013 { get; set; }

    public decimal? Td024 { get; set; }

    public string PlanNumber { get; set; } = null!;

    public string? SerialNosJson { get; set; }

    public string FooterFlag { get; set; } = null!;
}
