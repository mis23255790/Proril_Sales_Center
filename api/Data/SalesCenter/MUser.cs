using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class MUser
{
    public int Id { get; set; }

    public string? Account { get; set; }

    public string? Password { get; set; }

    public string? UserName { get; set; }

    public bool IsEnable { get; set; }

    public bool IsFirstLogin { get; set; }

    public DateTime? LastChangePwd { get; set; }

    public bool IsAdmin { get; set; }

    public bool IsLocked { get; set; }

    public byte PwdWrongTime { get; set; }
}
