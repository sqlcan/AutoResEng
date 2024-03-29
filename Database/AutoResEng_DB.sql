USE [AutoResEng]
GO
/****** Object:  Table [dbo].[RestoreRequest]    Script Date: 2021-10-15 11:27:05 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[RestoreRequest](
	[RestoreID] [bigint] IDENTITY(1,1) NOT NULL,
	[SDatabaseID] [int] NULL,
	[SAdHocRestoreLocation] [varchar](8000) NULL,
	[DDatabaseID] [int] NOT NULL,
	[AuthorizedUserID] [int] NOT NULL,
	[RequestorEmail] [varchar](255) NULL,
	[DateTimeRequested] [datetime] NOT NULL,
	[DateTimeRequestCompleted] [datetime] NULL,
	[ForceKillAllowed] [bit] NOT NULL,
	[CreateIfMissing] [bit] NOT NULL,
	[IsSuccessful] [bit] NOT NULL,
 CONSTRAINT [pk_RestoreRequest_RestoreID] PRIMARY KEY CLUSTERED 
(
	[RestoreID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[AuthorizedUsers]    Script Date: 2021-10-15 11:27:05 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AuthorizedUsers](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[UserName] [varchar](255) NOT NULL,
	[ForceKillAllowed] [bit] NOT NULL,
	[CreateIfMissing] [bit] NOT NULL,
	[IsSYSADMIN] [bit] NOT NULL,
	[IsEnabled] [bit] NULL,
 CONSTRAINT [pk_AuthorizedUser_ID] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[SQLInstance]    Script Date: 2021-10-15 11:27:05 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SQLInstance](
	[SQLInstanceID] [int] IDENTITY(1,1) NOT NULL,
	[SQLServerName] [varchar](50) NOT NULL,
	[SQLInstanceName] [varchar](50) NOT NULL,
	[SQLInstancePort] [int] NOT NULL,
 CONSTRAINT [PK_SQLInstance] PRIMARY KEY CLUSTERED 
(
	[SQLInstanceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Database]    Script Date: 2021-10-15 11:27:05 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Database](
	[DatabaseID] [int] IDENTITY(1,1) NOT NULL,
	[SQLInstanceID] [int] NOT NULL,
	[DatabaseName] [varchar](255) NOT NULL,
 CONSTRAINT [PK_Database] PRIMARY KEY CLUSTERED 
(
	[DatabaseID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Application]    Script Date: 2021-10-15 11:27:05 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Application](
	[ApplicationID] [int] IDENTITY(1,1) NOT NULL,
	[ApplicationName] [varchar](255) NOT NULL,
 CONSTRAINT [PK_Application] PRIMARY KEY CLUSTERED 
(
	[ApplicationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[AppDB]    Script Date: 2021-10-15 11:27:05 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AppDB](
	[AppDBID] [int] IDENTITY(1,1) NOT NULL,
	[ApplicationID] [int] NOT NULL,
	[DatabaseID] [int] NOT NULL,
	[Env] [varchar](25) NOT NULL,
 CONSTRAINT [PK_AppDB] PRIMARY KEY CLUSTERED 
(
	[AppDBID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[vRestoreRequest]    Script Date: 2021-10-15 11:27:05 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vRestoreRequest]
AS
SELECT        RR.RestoreID, SSI.SQLServerName AS SSQLServerName, SSI.SQLInstanceName AS SSQLInstanceName, SSI.SQLInstancePort AS SSQLPort, SD.DatabaseName AS SDatabaseName, SA.ApplicationName AS SApplicationName, 
                         SAD.Env AS SEnviornment, RR.SAdHocRestoreLocation, DSI.SQLServerName AS DSQLServerName, DSI.SQLInstanceName AS DSQLInstanceName, DSI.SQLInstancePort AS DSQLPort, DD.DatabaseName AS DDatabaseName, 
                         DA.ApplicationName AS DApplicationName, DDS.Env AS DEnviornment, RR.AuthorizedUserID, AU.UserName, RR.RequestorEmail, RR.DateTimeRequested, RR.DateTimeRequestCompleted, RR.IsSuccessful, 
                         RR.ForceKillAllowed, RR.CreateIfMissing
FROM            dbo.RestoreRequest AS RR INNER JOIN
                         dbo.[Database] AS SD ON RR.SDatabaseID = SD.DatabaseID INNER JOIN
                         dbo.SQLInstance AS SSI ON SD.SQLInstanceID = SSI.SQLInstanceID INNER JOIN
                         dbo.[Database] AS DD ON RR.DDatabaseID = DD.DatabaseID INNER JOIN
                         dbo.SQLInstance AS DSI ON DD.SQLInstanceID = DSI.SQLInstanceID INNER JOIN
                         dbo.AppDB AS SAD ON SD.DatabaseID = SAD.DatabaseID INNER JOIN
                         dbo.Application AS SA ON SAD.ApplicationID = SA.ApplicationID INNER JOIN
                         dbo.AppDB AS DDS ON DD.DatabaseID = DDS.DatabaseID INNER JOIN
                         dbo.Application AS DA ON DDS.ApplicationID = DA.ApplicationID INNER JOIN
                         dbo.AuthorizedUsers AS AU ON RR.AuthorizedUserID = AU.ID
GO
/****** Object:  View [dbo].[vRestoreRequestsQueue]    Script Date: 2021-10-15 11:27:05 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vRestoreRequestsQueue]
AS
WITH OpenRestoreRequests AS (
SELECT RestoreID,
       SSI.SQLServerName AS SSQLServerName,
       SSI.SQLInstanceName AS SSQLInstanceName,
	   SSI.SQLInstancePort AS SSQLPort,
	   SD.DatabaseName AS SDatabaseName,
	   SA.ApplicationName AS SApplicationName,
	   SAD.Env AS SEnviornment,
	   RR.SAdHocRestoreLocation,
	   DSI.SQLServerName AS DSQLServerName,
       DSI.SQLInstanceName AS DSQLInstanceName,
	   DSI.SQLInstancePort AS DSQLPort,
	   DD.DatabaseName AS DDatabaseName,
	   DA.ApplicationName AS DApplicationName,
	   DDS.Env AS DEnviornment,
	   RR.AuthorizedUserID,
	   AU.UserName,
       RR.RequestorEmail,
	   RR.DateTimeRequested,
	   RR.DateTimeRequestCompleted,
	   RR.IsSuccessful,
	   RR.ForceKillAllowed,
	   RR.CreateIfMissing, ROW_NUMBER() OVER (ORDER BY DateTimeRequested ASC) AS QueuePosition
  FROM dbo.RestoreRequest RR
  JOIN dbo.[Database] SD
    ON RR.SDatabaseID = SD.DatabaseID
  JOIN dbo.SQLInstance SSI
    ON SD.SQLInstanceID = SSI.SQLInstanceID
  JOIN dbo.[Database] DD
    ON RR.DDatabaseID = DD.DatabaseID
  JOIN dbo.SQLInstance DSI
    ON DD.SQLInstanceID = DSI.SQLInstanceID
  JOIN dbo.AppDB SAD
    ON SD.DatabaseID = SAD.DatabaseID
  JOIN dbo.Application SA
    ON SAD.ApplicationID = SA.ApplicationID
  JOIN dbo.AppDB DDS
    ON DD.DatabaseID = DDS.DatabaseID
  JOIN dbo.Application DA
    ON DDS.ApplicationID = DA.ApplicationID
  JOIN dbo.AuthorizedUsers AU
    ON RR.AuthorizedUserID = AU.ID
 WHERE DateTimeRequestCompleted IS NULL)
 SELECT *
   FROM OpenRestoreRequests
GO
/****** Object:  View [dbo].[Test_View]    Script Date: 2021-10-15 11:27:05 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[Test_View] AS
SELECT * from sys.databases
GO
/****** Object:  Table [dbo].[RestoreHistory]    Script Date: 2021-10-15 11:27:05 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[RestoreHistory](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[RestoreRequestID] [bigint] NULL,
	[HistoryDateTime] [datetime] NULL,
	[MessageType] [varchar](25) NULL,
	[MessageDetailsUser] [varchar](8000) NULL,
	[MessageDetailsSysAdmin] [varchar](8000) NULL,
 CONSTRAINT [pk_RestoreHistory_ID] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[UserAuthDB]    Script Date: 2021-10-15 11:27:05 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[UserAuthDB](
	[UserAuthDBID] [int] IDENTITY(1,1) NOT NULL,
	[AuthUserID] [int] NOT NULL,
	[SourceDatabaseID] [int] NOT NULL,
	[DestinationDatabaseID] [int] NOT NULL,
 CONSTRAINT [PK_UserAuthDB] PRIMARY KEY CLUSTERED 
(
	[UserAuthDBID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Index [idx_u_AppDB_AppID_DBID]    Script Date: 2021-10-15 11:27:05 AM ******/
CREATE UNIQUE NONCLUSTERED INDEX [idx_u_AppDB_AppID_DBID] ON [dbo].[AppDB]
(
	[ApplicationID] ASC,
	[DatabaseID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idx_u_AppName]    Script Date: 2021-10-15 11:27:05 AM ******/
CREATE UNIQUE NONCLUSTERED INDEX [idx_u_AppName] ON [dbo].[Application]
(
	[ApplicationName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idx_u_UserName]    Script Date: 2021-10-15 11:27:05 AM ******/
CREATE UNIQUE NONCLUSTERED INDEX [idx_u_UserName] ON [dbo].[AuthorizedUsers]
(
	[UserName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idx_u_DBName_InstanceID]    Script Date: 2021-10-15 11:27:05 AM ******/
CREATE UNIQUE NONCLUSTERED INDEX [idx_u_DBName_InstanceID] ON [dbo].[Database]
(
	[SQLInstanceID] ASC,
	[DatabaseName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
/****** Object:  Index [idxRestoreHistory_RestoreRequestID]    Script Date: 2021-10-15 11:27:05 AM ******/
CREATE NONCLUSTERED INDEX [idxRestoreHistory_RestoreRequestID] ON [dbo].[RestoreHistory]
(
	[RestoreRequestID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idx_u_SQLInstance]    Script Date: 2021-10-15 11:27:05 AM ******/
CREATE UNIQUE NONCLUSTERED INDEX [idx_u_SQLInstance] ON [dbo].[SQLInstance]
(
	[SQLServerName] ASC,
	[SQLInstanceName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
/****** Object:  Index [idx_u_User_SDB_DDB]    Script Date: 2021-10-15 11:27:05 AM ******/
CREATE UNIQUE NONCLUSTERED INDEX [idx_u_User_SDB_DDB] ON [dbo].[UserAuthDB]
(
	[AuthUserID] ASC,
	[SourceDatabaseID] ASC,
	[DestinationDatabaseID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AuthorizedUsers] ADD  CONSTRAINT [DF_AuthorizedUsers_ForceKillAllowed]  DEFAULT ((1)) FOR [ForceKillAllowed]
GO
ALTER TABLE [dbo].[AuthorizedUsers] ADD  CONSTRAINT [DF_AuthorizedUsers_CreateIfMissing]  DEFAULT ((1)) FOR [CreateIfMissing]
GO
ALTER TABLE [dbo].[AuthorizedUsers] ADD  CONSTRAINT [DF_AuthorizedUsers_IsSYSADMIN]  DEFAULT ((0)) FOR [IsSYSADMIN]
GO
ALTER TABLE [dbo].[AuthorizedUsers] ADD  CONSTRAINT [DF__Authorize__IsEna__182C9B23]  DEFAULT ((1)) FOR [IsEnabled]
GO
ALTER TABLE [dbo].[RestoreHistory] ADD  DEFAULT (getdate()) FOR [HistoryDateTime]
GO
ALTER TABLE [dbo].[RestoreRequest] ADD  CONSTRAINT [DF__RestoreRe__DateT__70DDC3D8]  DEFAULT (getdate()) FOR [DateTimeRequested]
GO
ALTER TABLE [dbo].[RestoreRequest] ADD  CONSTRAINT [DF__RestoreRe__Force__71D1E811]  DEFAULT ((0)) FOR [ForceKillAllowed]
GO
ALTER TABLE [dbo].[RestoreRequest] ADD  CONSTRAINT [DF__RestoreRe__Creat__72C60C4A]  DEFAULT ((0)) FOR [CreateIfMissing]
GO
ALTER TABLE [dbo].[RestoreRequest] ADD  CONSTRAINT [DF_RestoreRequest_IsSuccessful]  DEFAULT ((0)) FOR [IsSuccessful]
GO
ALTER TABLE [dbo].[SQLInstance] ADD  CONSTRAINT [DF_SQLInstance_SQLInstanceName]  DEFAULT ('MSSQLServer') FOR [SQLInstanceName]
GO
ALTER TABLE [dbo].[SQLInstance] ADD  CONSTRAINT [DF_SQLInstance_SQLInstancePort]  DEFAULT ((0)) FOR [SQLInstancePort]
GO
/****** Object:  StoredProcedure [dbo].[upSubmitRestoreRequest]    Script Date: 2021-10-15 11:27:05 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[upSubmitRestoreRequest]
(@SDatabaseID INT,
 @SAdHocRestoreLocation VARCHAR(255)=NULL,
 @DDatabaseID INT,
 @RequestorEmail VARCHAR(255)=NULL,
 @ForceKillAllowed bit=0,
 @CreateIfMissing bit=0)
AS
BEGIN

    DECLARE @AuthorizedUserID INT
	DECLARE @IsSysAdmin BIT
	DECLARE @UserForceKillAllowed BIT
	DECLARE @UserCreateIfMissing BIT
	DECLARE @RequestStatusMsg  VARCHAR(500)

    SET @AuthorizedUserID = 1
	SET @IsSysAdmin = 0
	SET @UserForceKillAllowed = 0
	SET @UserCreateIfMissing = 0
	SET @RequestStatusMsg = 'Restore request submitted successfully; Restore Request ID '

    IF EXISTS (SELECT * FROM dbo.AuthorizedUsers WHERE UserName = SUSER_NAME() AND IsEnabled = 1)
    BEGIN
        SELECT @AuthorizedUserID = ID,
		       @IsSysAdmin = IsSysAdmin,
			   @UserForceKillAllowed = ForceKillAllowed,
			   @UserCreateIfMissing = CreateIfMissing
			   FROM dbo.AuthorizedUsers WHERE UserName = SUSER_NAME() AND IsEnabled = 1
    END
	ELSE
	BEGIN
		SET @RequestStatusMsg = 'User not authorized to submit restore request.'
		GOTO CleanExit
	END

	IF (@ForceKillAllowed = 1) AND (@UserForceKillAllowed = 0)
	BEGIN
		SET @RequestStatusMsg = 'User requested Force Kill for Restore, however User is Not Authorized to Request Force Kill.'
		GOTO CleanExit
	END

	IF (@CreateIfMissing = 1) AND (@UserCreateIfMissing = 0)
	BEGIN
		SET @RequestStatusMsg = 'User requested Create New DB for Restore, however User is Not Authorized to Create New DB.'
		GOTO CleanExit
	END
		
	IF EXISTS (SELECT *
	             FROM dbo.UserAuthDB
				WHERE ((AuthUserID = @AuthorizedUserID) OR (@IsSysAdmin = 1))
				  AND SourceDatabaseID = @SDatabaseID 
				  AND DestinationDatabaseID = @DDatabaseID)
	BEGIN
		INSERT INTO [dbo].[RestoreRequest]
				   (SDatabaseID
				   ,[SAdHocRestoreLocation]
				   ,[DDatabaseID]
				   ,[AuthorizedUserID]
				   ,[RequestorEmail]
				   ,[DateTimeRequested]
				   ,[DateTimeRequestCompleted]
				   ,[ForceKillAllowed]
				   ,[CreateIfMissing])
			 VALUES ( @SDatabaseID                 
					 ,@SAdHocRestoreLocation
					 ,@DDatabaseID
					 ,@AuthorizedUserID
					 ,@RequestorEmail
					 ,GetDate()
					 ,NULL
					 ,@ForceKillAllowed
					 ,@CreateIfMissing)


		SET @RequestStatusMsg = @RequestStatusMsg + CAST(@@IDENTITY AS VARCHAR)
		GOTO CleanExit
	END
	ELSE
	BEGIN
		SET @RequestStatusMsg =  'User not authorized to request restore.'
		GOTO CleanExit
	END

CleanExit:

	SELECT @RequestStatusMsg AS RequestStatus

END
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "RR"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 136
               Right = 278
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "SD"
            Begin Extent = 
               Top = 138
               Left = 38
               Bottom = 251
               Right = 208
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "SSI"
            Begin Extent = 
               Top = 138
               Left = 246
               Bottom = 268
               Right = 432
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "DD"
            Begin Extent = 
               Top = 252
               Left = 38
               Bottom = 365
               Right = 208
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "DSI"
            Begin Extent = 
               Top = 270
               Left = 246
               Bottom = 400
               Right = 432
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "SAD"
            Begin Extent = 
               Top = 366
               Left = 38
               Bottom = 496
               Right = 208
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "SA"
            Begin Extent = 
               Top = 402
               Left = 246
               Bottom = 498
               Right = 428
            End
            DisplayFlags = 280
            TopColumn = 0
   ' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vRestoreRequest'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane2', @value=N'      End
         Begin Table = "DDS"
            Begin Extent = 
               Top = 498
               Left = 38
               Bottom = 628
               Right = 208
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "DA"
            Begin Extent = 
               Top = 498
               Left = 246
               Bottom = 594
               Right = 428
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "AU"
            Begin Extent = 
               Top = 594
               Left = 246
               Bottom = 724
               Right = 423
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vRestoreRequest'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=2 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vRestoreRequest'
GO
