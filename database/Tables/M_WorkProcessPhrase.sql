CREATE TABLE [dbo].[M_WorkProcessPhrase] (
    [ID]              INT           IDENTITY (1, 1) NOT NULL,
    [PhraseType]      VARCHAR (4)   NOT NULL,
    [PhraseCode]      VARCHAR (10)  NOT NULL,
    [PhraseName]      VARCHAR (40)  NOT NULL,
    [Directions]      VARCHAR (MAX) NULL,
    [PubFlag]         BIT           NULL,
    [Principal]       VARCHAR (10)  NULL,
    [PotentialCustom] VARCHAR (1)   CONSTRAINT [DF_M_WorkProcessPhrase_PotentialCustom] DEFAULT ('N') NULL,
    [aStatus]         VARCHAR (1)   NULL,
    [Creator]         VARCHAR (10)  NULL,
    [CreateTime]      DATETIME      NULL,
    CONSTRAINT [PK_M_Phrase] PRIMARY KEY CLUSTERED ([ID] ASC)
);


GO

