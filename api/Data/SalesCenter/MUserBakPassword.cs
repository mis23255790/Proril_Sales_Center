using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class MUserBakPassword
{
    public int Id { get; set; }

    public string? Account { get; set; }

    public string? Password { get; set; }
}
