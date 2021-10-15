<# PowerShell Automated Database Restore Script
   Version: 3.00
   Developed By: Mohit K. Gupta (Microsoft Customer Engineer)
   Last Updated: Oct. 9, 2021 #>

# This script does not accept any parameters, however has some hardcoded values that must
# be updated before script can be deployed.
#
# These values below are one-time update to specifiy the meta-data for the Restore
# automation engine.
#
# Solution restores the oldest request, one at a time.

Import-Module SQLServer -DisableNameChecking

$AutoResEngServer = 'MOGUPTA-PC01'
$AutoResEngDB = 'AutoResEng'
$SecurityScriptDirectory = 'C:\Temp\'
$EmailProfile = '' #SQL Server Email Profile Name
$EmailAddress = '' #DBA Team Email Address to Receive Recovery Alerts

# Constants used script
$NOT_AUTHORIZED_USER = 1 # 1 is the user ID of the first user in AuthorizedUsers table.
$IsForceKillAllowed = 1
$AllowNewDBCreation = 1

function Log-Event
{
    [CmdletBinding()]
    param ([Parameter(Position=0, Mandatory=$true)] [int]$ID,
           [Parameter(Position=1, Mandatory=$true)] [string]$MessageType,
           [Parameter(Position=2, Mandatory=$true)] [string]$MessageDetails,
           [Parameter(Position=3, Mandatory=$false)] [string]$MessageDetailsSA,
           [Parameter(Position=4, Mandatory=$false)] [boolean]$SendEmailUpdate=$false,
           [Parameter(Position=5, Mandatory=$false)] [string]$EmailTo=$null)

    <# $MessageType - 123456789 123456789 12345
                      Info                      - Information Message
                      Security Audit            - Security related checks
                      Security Audit - Failed   - Security audit failed
                      Error                     - Error, something didn't work
                      Exception                 - Something unexpected happened.
    #>

    if ([String]::IsNullOrEmpty($MessageDetailsSA))
    {
        $MessageDetailsSA = $MessageDetails
    }
    $MessageDetails = $MessageDetails -replace "'", "''"
    $MessageDetailsSA = $MessageDetailsSA -replace "'", "''"
    $SQLCode = "INSERT INTO dbo.RestoreHistory (RestoreRequestID, MessageType, MessageDetailsUser, MessageDetailsSysadmin) VALUES ($ID,'$MessageType','$MessageDetails','$MessageDetailsSA')"
    Invoke-SQLcmd -Server $AutoResEngServer -Database $AutoResEngDB -Query $SQLCode

    if ($SendEmailUpdate)
    {
    }
}

function Write-PostRestoreScript
{
    [CmdletBinding()]
    param ([Parameter(Position=0, Mandatory=$true)] $DataRows,
           [Parameter(Position=1, Mandatory=$true)] $ColHeading,
           [Parameter(Position=2, Mandatory=$true)] $OutputFile)

    ForEach ($Row IN $DataRows)
    {
        $Row[$ColHeading] | Out-File $OutputFile -Append
        #"GO" | Out-File $OutputFile -Append
    }

}

function Check-ServicesAreRunning ($ServerName,$InstanceName)
{
    try
    {
        $SvcList = Get-Service -ComputerName $ServerName | ? {($_.Name -Like 'MSSQL*') -And ($_.Status -Eq 'Running')}
        $ReturnValue = $false

        ForEach ($Svc IN $SvcList)
        {
            if (($svc.Name -Eq $InstanceName) -And ($InstanceName -Eq 'MSSQLServer'))
            {
                $ReturnValue = $true
            }
            elseif (($svc.Name -Eq "MSSQL`$$InstanceName") -And ($InstanceName -Ne 'MSSQLServer'))
            {
                $ReturnValue = $true
            }
        }

    }
    catch [System.InvalidOperationException]
    {
        $ReturnValue=$false
        if ($_.Exception.Message -like '*Cannot open Service Control Manager*')
        {
            Log-Event -ID $RequestID -MessageType "Error" -MessageDetails "... ... $_"
        }
    }
    catch [Exception]
    {
        Log-Event -ID $RequestID -MessageType "Error" -MessageDetails "... ... ... ... [$($_.Exception.GetType().FullName)] $($_.Exception.Message)"
        $ReturnValue=$false
    }

    Return $ReturnValue

}

#Check if any restore request are waiting in the queue.
$SQLQuery = "SELECT TOP 1 RestoreID
      ,SSQLServerName
      ,SSQLInstanceName
      ,SSQLPort
      ,SDatabaseName
      ,SApplicationName
      ,SEnviornment
      ,SAdHocRestoreLocation
      ,DSQLServerName
      ,DSQLInstanceName
      ,DSQLPort
      ,DDatabaseName
      ,DApplicationName
      ,DEnviornment
      ,AuthorizedUserID
      ,UserName
      ,RequestorEmail
      ,DateTimeRequested
      ,DateTimeRequestCompleted
      ,IsSuccessful
      ,ForceKillAllowed
      ,CreateIfMissing
      ,QueuePosition
  FROM dbo.vRestoreRequestsQueue"

$Request = Invoke-Sqlcmd -Server $AutoResEngServer -Database $AutoResEngDB -Query $SQLQuery 

$RequestID = $Request['RestoreID']
$SServerName= $Request['SSQLServerName']
$SInstanceName = $Request['SSQLInstanceName']
$SDatabaseName = $Request['SDatabaseName']
$SPort = $Request['SSQLPort']
$SAdHocRestoreLocation = $Request['SAdHocRestoreLocation'].ToString().Trim()
$SApplication = $Request['SApplicationName']
$SEnviornment = $Request['SEnviornment']
$DServerName = $Request['DSQLServerName']
$DInstanceName = $Request['DSQLInstanceName']
$DDatabaseName = $Request['DDatabaseName']
$DPort = $Request['DSQLPort']
$DApplication = $Request['DApplicationName']
$DEnvironment = $Request['DEnviornment']
$AuthorizedUserID = $Request['AuthorizedUserID']
$AuthorizedUserName = $Request['Username']
$RequestorEmail = $Request['RequestorEmail'].ToString().Trim()
$DateTimeRequested = $Request['DateTimeRequested']
$ForceKillAllowed = $Request['ForceKillAllowed']
$CreateIfMissing = $Request['CreateIfMissing']
$RestorePossible = $true
$SServerAvailable = $true
$DServerAvailable = $true
$DatabaseExists = $true

$SConnection = $SServerName

IF ($SInstanceName -ne 'MSSQLServer')
{
    $SConnection += "\$SInstanceName"
}

IF ($SPort -ne 0)
{
    $SConnection += ",$SPort"
}

$DConnection = $DServerName

IF ($DInstanceName -ne 'MSSQLServer')
{
    $DConnection += "\$DInstanceName"
}

IF ($DPort -ne 0)
{
    $DConnection += ",$DPort"
}

Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "Restore request started for [$SApplication] Enviornment [$SEnviornment]" `
                                                -MessageDetailsSA "Restore requested by [$AuthorizedUserName] for [$SServerName\$SInstanceName] database [$DDatabaseName]."
Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... Checking source server is accessible and instance is running." `
                                                -MessageDetailsSA "... Checking source server [$SServerName] is accessible and [$SInstanceName] instance is running."
if (!(Check-ServicesAreRunning $SServerName $SInstanceName $SPort))
{
    Log-Event -ID $RequestID -MessageType "Error" -MessageDetails "... ... Source server\instance is not avalaible."
    $RestorePossible = $false
    $SServerAvailable = $false
}

Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... Checking destination server is accessible and instance is running." `
                                                -MessageDetailsSA "... Checking destination server [$DServerName] is accessible and [$DInstanceName] instance is running."
if (!(Check-ServicesAreRunning $DServerName $DInstanceName $DPort))
{
    Log-Event -ID $RequestID -MessageType "Error" -MessageDetails "... ... Destination server\instance is not avalaible."
    $RestorePossible = $false
    $DServerAvailable = $false
}

if ((!($SDatabaseName -eq $null)) -and ($SServerAvailable) -and ($RestorePossible))
{
    Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... Checking of source database is available."

    try
    {
        $Results = Invoke-Sqlcmd -ServerInstance $SConnection -Database $SDatabaseName -Query "SELECT DATABASEPROPERTYEX('$SDatabaseName','Collation')"

        Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... database is available."
        Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... checking for last full backup."

        $TSQL_GetLastDatabaseBackup = "WITH LastBackupDate AS (
                                        SELECT database_name, max(backup_start_date) LastBackupDate
                                            FROM dbo.backupset bs
                                            WHERE bs.type = 'D'
                                        GROUP BY database_name)
                                            SELECT bmf.physical_device_name
                                            FROM dbo.backupmediafamily bmf
                                            JOIN dbo.backupset bs ON bmf.media_set_id = bs.media_set_id
	                                        JOIN LastBackupDate LBD ON  bs.backup_start_date = LBD.LastBackupDate
                                            WHERE bs.type = 'D'
                                                AND bs.database_name = '$SDatabaseName'
                                        ORDER BY bs.backup_start_date DESC"

        $Results = Invoke-Sqlcmd -ServerInstance $SConnection -Database msdb -Query $TSQL_GetLastDatabaseBackup

        if (!($Results))
        {
            Log-Event -ID $RequestID -MessageType "Error" -MessageDetails "... ... ... no backups found."
            $RestorePossible = $false
        }
        else
        {
            $SourceBackupFile = @()

            ForEach ($BackupFile IN $Results)
            {
                $BkFile = $BackupFile['physical_device_name'] 

                if (!(Test-Path $BkFile))
                {
                    Log-Event -ID $RequestID -MessageType "Error" -MessageDetails "... ... ... backup file is not accessible or does not exist." `
                                                                    -MessageDetailsSA "... ... ... backup file [$BkFile] is not accessible or does not exist."
                    $RestorePossible = $false
                }

                $SourceBackupFile += $BkFile

            }

        }

    }
    catch [System.Management.Automation.MethodInvocationException]
    {
        if ($_.Exception.Message -like '*Cannot open database*')
        {
            Log-Event -ID $RequestID -MessageType "Error" -MessageDetails "... ... database not avaliable or accessible."
            $RestorePossible = $false
        }
    }
    catch [Exception]
    {
        Log-Event -ID $RequestID -MessageType "Error" -MessageDetails "... ... database not avaliable or accessible." `
                                                      -MessageDetailsSA "... ... ... ... [$($_.Exception.GetType().FullName)] $($_.Exception.Message)"
        $RestorePossible = $false
    }

}

if ((!($SAdHocRestoreLocation -eq $null)) -and (!($SAdHocRestoreLocation -eq '')) -and ($SServerAvailable) -and ($RestorePossible))
{
    Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... Special backup requested, checking if backup file is accessible."

    $SAdHocRestoreLocationSplit = $SAdHocRestoreLocation -split ';'

    $SourceBackupFile = @()

    ForEach ($BackupFile IN $SAdHocRestoreLocationSplit)
    {

        if (!(Test-Path $BackupFile))
        {
            Log-Event -ID $RequestID -MessageType "Error" -MessageDetails "... ... ... backup file is not accessible or does not exist." `
                                                            -MessageDetailsSA "... ... ... backup file [$BackupFile] is not accessible or does not exist."
            $RestorePossible = $false
        }

        $SourceBackupFile += $BkFile

    }
}

if (($DServerAvailable)  -and ($RestorePossible))
{

    Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... Destination database checks."
    Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... Checking if database already exists?"

    $Results = Invoke-Sqlcmd -ServerInstance $DConnection -Database "master" -Query "SELECT COUNT(*) AS DBCount FROM sys.databases WHERE name = '$DDatabaseName'"

    if (($Results['DBCount'] -eq 0) -and ($CreateIfMissing -eq $true))
    {
        Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... ... database does not exist, restore will create new database." `
                                                        -MessageDetailsSA "... ... ... database does not exist, restore will create new database with name [$DDatabaseName]."
        $DatabaseExists = $false
    }
    elseif (($Results['DBCount'] -eq 0) -and ($CreateIfMissing -eq $false))
    {
        Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... ... database does not exist, restore not allowed to create new database."
        $RestorePossible = $false
        $DatabaseExists = $false
    }
    else
    {
        try
        {
            Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... ... database exists, checking if database is locked."
            $LckCount = 0
            $Results = Invoke-Sqlcmd -ServerInstance $DConnection -Database $DDatabaseName -Query "SELECT COUNT(*) AS LckCount FROM sys.dm_tran_locks WHERE resource_database_id = db_id()"
            $LckCount = $Results['LckCount']

            if (($LckCount -gt 0) -and ($ForceKillAllowed -eq $true))
            {
                Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... ... ... database is locked and force kill is allowed; connections will be forced killed before restore."                    
            }
            elseif (($LckCount -gt 0) -and ($ForceKillAllowed -eq $false))
            {
                Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... ... ... database is locked and force kill is not allowed."
                $RestorePossible = $false
            }
            else
            {
                Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... ... ... no locks found."
            }
        }
        catch [System.Management.Automation.MethodInvocationException]
        {
            if ($_.Exception.Message -like '*Cannot open database*')
            {
                Log-Event -ID $RequestID -MessageType "Error" -MessageDetails "... ... ... ... database not avaliable or accessible."
                $RestorePossible = $false
                continue; 
            }
        }
        catch [Exception]
        {
            Log-Event -ID $RequestID -MessageType "Error" -MessageDetails "... ... ... ... database not avaliable or accessible." `
                                                          -MessageDetailsSA "... ... ... ... [$($_.Exception.GetType().FullName)] $($_.Exception.Message)"
            $RestorePossible = $false
            continue; 
        }

    }

    # Database is restoreable therefore we need to start building
    #  the restore command, saving database properites and security script.
    if ($RestorePossible)
    {
        Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... Database Restorable"

        $OwnerName = 'sa'
        $AutoUpdateStats = 1
        $AutoUpdateStatsAync = 0
        $AutoCreateStatus = 1

        $SecurityScript = "$SecurityScriptDirectory$DDatabaseName`_RQST$($RequestID.ToString().PadLeft(10,'0')).sql"
        "-- Post Database Restore Script [$DDatabaseName] on Server [$DServerName]" | Out-File $SecurityScript
        "USE [$DDatabaseName]"  | Out-File $SecurityScript -Append

        if ($DatabaseExists -eq $true)
        {
            Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... destination database exists, copying key configuration settings."

            $TSQL_DatabaseConfig = "SELECT (SELECT name FROM sys.server_principals WHERE sid = owner_sid) AS OwnerName,
                                            is_auto_create_stats_on,
                                            is_auto_update_stats_on,
                                            is_auto_update_stats_async_on
                                        FROM sys.databases
                                        WHERE name = '$DDatabaseName'"

            $Results = Invoke-Sqlcmd -ServerInstance $DConnection -Database "master" -Query $TSQL_DatabaseConfig

            $OwnerName = $Results['OwnerName']
            $AutoUpdateStats = $Results['is_auto_update_stats_on']
            $AutoUpdateStatsAync = $Results['is_auto_update_stats_async_on']
            $AutoCreateStatus = $Results['is_auto_create_stats_on']

            Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... ... Database Owner: ************" `
                                                         -MessageDetailsSA "... ... ... Database Owner: $OwnerName"
            Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... ... Auto Update Stats: $AutoUpdateStats"
            Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... ... Auto Update Stats Aync: $AutoUpdateStatsAync"
            Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... ... Auto Create Stats: $AutoCreateStatus"
            Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... Generating database user list."

            $TSQL_DatabaseUserList = "SELECT 'CREATE USER [' + DP.name + '] FROM LOGIN [' + SP.name + ']' AS CreateUser
                                        FROM sys.database_principals DP
                                        JOIN sys.server_principals SP
                                            ON DP.sid = SP.sid
                                            AND DP.name = SP.name
                                        WHERE SP.name <> 'dbo'"

            $Results = Invoke-Sqlcmd -ServerInstance $DConnection -Database $DDatabaseName -Query $TSQL_DatabaseUserList

            if ($Results)
            {
                "-- Database Users -- " | Out-File $SecurityScript -Append
                Write-PostRestoreScript $Results 'CreateUser' $SecurityScript
            }
            else
            {
                Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... ... No database user found."
            }

            Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... Generating database user membership details."

            $TSQL_RoleMembership = "SELECT 'EXEC sp_addrolemember ''' + DR.name + ''', ''' + DP.name + '''' AS RoleMembership
                                        FROM sys.database_principals   AS DR
                                        JOIN sys.database_role_members AS DRM
                                        ON DR.principal_id = DRM.role_principal_id
                                        JOIN sys.database_principals   AS DP
                                        ON DP.principal_id = DRM.member_principal_id
                                        WHERE DP.name <> 'dbo'"

            $Results = Invoke-Sqlcmd -ServerInstance $DConnection -Database $DDatabaseName -Query $TSQL_RoleMembership

            if ($Results)
            {
                "-- Database Users Role Assignment -- " | Out-File $SecurityScript -Append
                Write-PostRestoreScript $Results 'RoleMembership' $SecurityScript
            }
            else
            {
                Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... ... No membership details found."
            }

            Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... Generating explicit permissions list."

            $TSQL_DatabaseExplicitPermissions = "   SELECT PE.state_desc + ' ' + PE.permission_name + ' ON [' + S.name + '].[' + AO.name + '] TO [' + DP.name + ']' COLLATE SQL_Latin1_General_CP1_CI_AS AS PermissionGrant
                                                        FROM sys.database_principals  AS DP
                                                        JOIN sys.database_permissions AS PE 
                                                        ON PE.grantee_principal_id = DP.principal_id
                                                    LEFT JOIN sys.all_objects          AS AO
                                                        ON pe.major_id = AO.object_id
                                                    LEFT JOIN sys.schemas              AS S 
                                                        ON AO.schema_id = S.schema_id
                                                        WHERE DP.type_desc <> 'DATABASE_ROLE'
                                                        AND DP.name <> 'dbo'
                                                        AND DP.name <> 'public'
                                                        AND DP.name <> 'guest'
                                                        AND PE.permission_name <> 'CONNECT'"

            $Results = Invoke-Sqlcmd -ServerInstance $DConnection -Database $DDatabaseName -Query $TSQL_DatabaseExplicitPermissions

            if ($Results)
            {
                "-- Database Users's Explicit Permissions -- " | Out-File $SecurityScript -Append
                Write-PostRestoreScript $Results 'PermissionGrant' $SecurityScript
            }
            else
            {
                Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... ... No explicit permissions found."
            }

            "-- Database Configuration Settings -- " | Out-File $SecurityScript -Append
            "EXEC dbo.sp_changedbowner '$OwnerName'" | Out-File $SecurityScript -Append

            if ($AutoUpdateStats -eq 1)
            {
                "ALTER DATABASE [$DDatabaseName] SET AUTO_UPDATE_STATISTICS ON" | Out-File $SecurityScript -Append
            }
            else
            {
                "ALTER DATABASE [$DDatabaseName] SET AUTO_UPDATE_STATISTICS OFF" | Out-File $SecurityScript -Append
            }

            if ($AutoUpdateStatsAync -eq 1)
            {
                "ALTER DATABASE [$DDatabaseName] SET AUTO_UPDATE_STATISTICS_ASYNC ON" | Out-File $SecurityScript -Append
            }
            else
            {
                "ALTER DATABASE [$DDatabaseName] SET AUTO_UPDATE_STATISTICS_ASYNC OFF" | Out-File $SecurityScript -Append
            }

            if ($AutoCreateStatus -eq 1)
            {
                "ALTER DATABASE [$DDatabaseName] SET AUTO_CREATE_STATISTICS ON" | Out-File $SecurityScript -Append
            }
            else
            {
                "ALTER DATABASE [$DDatabaseName] SET AUTO_CREATE_STATISTICS OFF" | Out-File $SecurityScript -Append
            }

        }

        "-- DEV/UAT Microsoft Best Practice Configuration Settings -- " | Out-File $SecurityScript -Append
        "ALTER DATABASE [$DDatabaseName] SET AUTO_CLOSE OFF" | Out-File $SecurityScript -Append
        "ALTER DATABASE [$DDatabaseName] SET AUTO_SHRINK OFF" | Out-File $SecurityScript -Append
        "ALTER DATABASE [$DDatabaseName] SET PAGE_VERIFY CHECKSUM" | Out-File $SecurityScript -Append
        "ALTER DATABASE [$DDatabaseName] SET RECOVERY SIMPLE" | Out-File $SecurityScript -Append

        "-- Shrink Transaction Log file to Minimal Size -- " | Out-File $SecurityScript -Append
        "DBCC SHRINKFILE('$DDatabaseName`_Log',5)" | Out-File $SecurityScript -Append

        Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... Post Restore Script Built." `
                                                     -MessageDetailsSA "... ... Post Restore Script Built [$SecurityScript]."

        $DServer = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $DConnection
        $DefaultDataPath = $DServer.Settings.DefaultFile
        $DefaultLogPath = $DServer.Settings.DefaultLog

        Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... Getting the Default Data Path." `
                                                     -MessageDetailsSA "... ... Default Data Path Found [$DefaultDataPath]."
        Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... Getting the Default Log Path." `
                                                     -MessageDetailsSA "... ... Default Log Path Found [$DefaultLogPath]."

        #$SourceBackupFile

        #Restore-SqlDatabase -ServerInstance $SConnection -Database master -BackupFile $SourceBackupFile

        $Results = Invoke-Sqlcmd -ServerInstance $SConnection -Database "master" -Query "RESTORE FILELISTONLY FROM DISK = '$($SourceBackupFile[0])'"
            
        $RelocateFiles = @()
        $DataFileCount = 0
        $LogFileCount = 0

        foreach($DBFiles in $Results)
        {
            $FileName = [System.IO.Path]::GetFileName($DBFiles.PhysicalName)
            $FileExt = $FileName.Substring($FileName.LastIndexOf('.'))
            switch($DBFiles.Type){
                'D'{
                    $DataFileCount++
                    if ($DataFileCount -ge 2) { $RestoreFilePath = Join-Path $DefaultDataPath "$DDatabaseName`_$DataFileCount$FileExt" }
                    else { $RestoreFilePath = Join-Path $DefaultDataPath "$DDatabaseName$FileExt" }
                }
                'L'{
                    $LogFileCount++
                    if ($LogFileCount -ge 2) { $RestoreFilePath = Join-Path $DefaultLogPath "$DDatabaseName`_Log$LogFileCount$FileExt" }
                    else { $RestoreFilePath = Join-Path $DefaultLogPath "$DDatabaseName`_Log$FileExt" }                        
                }
            }
            $RelocateFiles += New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($DBFiles.LogicalName, $RestoreFilePath)
        }
            
        if (($LckCount -gt 0) -and ($ForceKillAllowed -eq $true) -and ($DatabaseExists -eq $true))
        {
            Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... ... ... database is locked and force kill is allowed; connections will be forced killed before restore."
            Invoke-Sqlcmd -ServerInstance $DConnection -Database "master" -Query "ALTER DATABASE [$DDatabaseName] SET OFFLINE WITH ROLLBACK IMMEDIATE"
        }

        Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... Restoring database."
        Restore-SqlDatabase -ServerInstance $DConnection -Database $DDatabaseName -BackupFile $SourceBackupFile -RelocateFile $RelocateFiles -ReplaceDatabase

        Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... Adjusting logical names to match database names."
        $DataFileCount = 0
        $LogFileCount = 0
        foreach($DBFiles in $Results)
        {
            $LogicalFileName = [System.IO.Path]::GetFileName($DBFiles.LogicalName)
                
            switch($DBFiles.Type){
                'D'{
                    $DataFileCount++
                    if ($DataFileCount -ge 2) { $NewLogicalFileName = "$DDatabaseName`_$DataFileCount" }
                    else { $NewLogicalFileName = "$DDatabaseName" }
                }
                'L'{
                    $LogFileCount++
                    if ($LogFileCount -ge 2) { $NewLogicalFileName = "$DDatabaseName`_Log$DataFileCount" }
                    else { $NewLogicalFileName = "$DDatabaseName`_Log" }                      
                }
            }
            Invoke-Sqlcmd -ServerInstance $DConnection -Database "master" -Query "ALTER DATABASE [$DDatabaseName] MODIFY FILE (NAME=N'$LogicalFileName', NEWNAME=N'$NewLogicalFileName')"
        }

        Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... Dropping database users."
        $TSQL_DropDatabaseUsers = "DECLARE @SQL Varchar(255)
                                           
                                    DECLARE DropUser CURSOR FOR 
                                    SELECT 'DROP USER [' + DP.name + ']'  AS DropUser
                                        FROM sys.database_principals DP
                                        JOIN sys.server_principals SP ON DP.sid = SP.sid
                                        AND DP.name = SP.name
                                    WHERE SP.name <> 'dbo'
                                           
                                    OPEN DropUser

                                    FETCH NEXT FROM DropUser
                                    INTO @SQL

                                    WHILE @@FETCH_STATUS = 0
                                    BEGIN
                                        EXEC (@SQL)
                                        FETCH NEXT FROM DropUser
                                        INTO @SQL
                                    END

                                    CLOSE DropUser
                                    DEALLOCATE DropUser"

        $Results = Invoke-Sqlcmd -ServerInstance $DConnection -Database $DDatabaseName -Query $TSQL_DropDatabaseUsers

        Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "... ... Running post restore script."
        Invoke-Sqlcmd -ServerInstance $DConnection -Database $DDatabaseName -InputFile $SecurityScript
            
    }

}
            
if (!($RestorePossible))
{
    Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "Restore request failed for [$DApplication] environment [$DEnvironment]." `
                                                    -MessageDetailsSA "Restore request failed for [$DServerName\$DInstanceName] database [$DDatabaseName]."
    Invoke-Sqlcmd -Server $AutoResEngServer -Database $AutoResEngDB -Query "UPDATE dbo.RestoreRequest SET DateTimeRequestCompleted = GetDate(), IsSuccessful = 0 WHERE RestoreID = $RequestID"
    $EmailSubject = "Restore request RQST$($RequestID.ToString().PadLeft(10,'0')): Application [$DApplication] failed!"
    $EmailSubjectSA = "Restore request RQST$($RequestID.ToString().PadLeft(10,'0')): Database [$DDatabaseName] failed!"
}
else
{
    Log-Event -ID $RequestID -MessageType "Info" -MessageDetails "Restore request completed for [$DApplication] environment [$DEnvironment]." `
                                                    -MessageDetailsSA "Restore request completed for [$DServerName\$DInstanceName] database [$DDatabaseName]."
    Invoke-Sqlcmd -Server $AutoResEngServer -Database $AutoResEngDB -Query "UPDATE dbo.RestoreRequest SET DateTimeRequestCompleted = GetDate(), IsSuccessful = 1 WHERE RestoreID = $RequestID"
    $EmailSubject = "Restore request RQST$($RequestID.ToString().PadLeft(10,'0')): Application [$DApplication] completed!"
    $EmailSubjectSA = "Restore request RQST$($RequestID.ToString().PadLeft(10,'0')): Database [$DDatabaseName] completed!"
}

<#

# Send SysAdmin Email with details.
$TSQL_SendEmail = "sp_send_dbmail
                    @profilename = '$EmailProfile',
                    @recipients = '$EmailAddress;',
                    @from_address = '$EmailAddress',
                    @subject = '$EmailSubjectSA',
                    @importance = 'Low',
                    @query = 'SELECT HistoryDateTime, MessageType, MessageDetailsSysAdmin AS MessageDetails
                                FROM $AutoResEngDB.dbo.RestoreHistory WHERE RestoreRequestID = $RequestID  ORDER BY HistoryDateTime'"
                                
Invoke-Sqlcmd -Server $AutoResEngServer -Database $AutoResEngDB -Query $TSQL_SendEmail

# Send Users Email with details (stripping out senstive information).
$TSQL_SendEmail = "sp_send_dbmail
                    @profilename = '$EmailProfile',
                    @recipients = '$RequestorEmail;',
                    @from_address = '$EmailAddress',
                    @subject = '$EmailSubject',
                    @importance = 'Low',
                    @query = 'SELECT HistoryDateTime, MessageType, MessageDetailsUser AS MessageDetails
                                FROM $AutoResEngDB.dbo.RestoreHistory WHERE RestoreRequestID = $RequestID ORDER BY HistoryDateTime'"

Invoke-Sqlcmd -Server $AutoResEngServer -Database $AutoResEngDB -Query $TSQL_SendEmail

                                #>