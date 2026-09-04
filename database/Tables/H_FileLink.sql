CREATE TABLE [dbo].[H_FileLink] (
    [ID]             INT           IDENTITY (1, 1) NOT NULL,
    [FilePath]       VARCHAR (255) NULL,
    [FileType]       VARCHAR (10)  NULL,
    [LinkFunctionNo] INT           CONSTRAINT [DF__H_FileLin__LinkF__6EF57B66] DEFAULT ((0)) NOT NULL,
    [LinkNo]         VARCHAR (40)  NOT NULL,
    [UpdateTime]     DATETIME      NOT NULL,
    [UpdateUser]     VARCHAR (10)  NOT NULL,
    CONSTRAINT [PK__H_FileLi__3214EC2786B36236] PRIMARY KEY CLUSTERED ([ID] ASC)
);


GO

