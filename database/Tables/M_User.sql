CREATE TABLE [dbo].[M_User] (
    [ID]             INT          IDENTITY (1, 1) NOT NULL,
    [Account]        VARCHAR (10) NULL,
    [Password]       VARCHAR (50) NULL,
    [UserName]       VARCHAR (40) NULL,
    [IsEnable]       BIT          NOT NULL,
    [IsFirstLogin]   BIT          NOT NULL,
    [LastChangePwd]  DATETIME     NULL,
    [IsAdmin]        BIT          NOT NULL,
    [IsLocked]       BIT          NOT NULL,
    [PwdWrongTime]   TINYINT      NOT NULL,
    CONSTRAINT [PK__M_User__3214EC27F2F69166] PRIMARY KEY CLUSTERED ([ID] ASC)
);


GO

