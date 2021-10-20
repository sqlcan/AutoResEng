# Automatic Restore Engine (AutoResEng)

AutoResEng was designed to help mitigate routine DBA tasks and remove blockers from developers to restore non-production databases from production copy.  This tool provides a simple way to request a refresh without elevated permissions.

The refresh is completed by PowerShell Automation and the requestor is sent an email with the updates.

The solution also has basic security to restrict who can request a restore, what they can restore.  The solution masks sensitive information such as server names and databases.  Instead exposes only application name and environment.

The overall solution is built using the following components:
* PowerShell
* SQL Database
* SSRS Reports

Deployment of Solution
1. Run SQL Database Script to Create the Database & Required Objects
2. Update PowerShell script settings (database location and output scripts location).
3. Update connection string in SSRS and deploy the solution.

Identity Account Requirements
* Must create an identity account with sufficient permissions to run the PowerShell Automation solutions.
* Grant read access to all backup locations.
* Grant permission to kill sessions.
* Grant permission to create databases.
* Grant permission to restore databases.
* Grant permission to read msdb for backup history.

Granting Access
1. Add each user that needs access to AutoResEng to the dbo.AuthorizedUsers table.  If the user is a sysadmin enable the "IsAdmin" flag.
2. Add each application the solution will support in dbo.Applications table.
3. Add each SQL instance (dbo.SQLInstance) that can be the source or target of the restore request.
4. Add each database belonging to SQL Instance.  These again are the source and target databases.  Target database name does not have to exist.  If the user has Create New Database permission in dbo.AuthorizedUsers.  The said database will be created at restore time.
5. Create a mapping between Application and Databases (dbo.AppDB), allowing the system to know what databases belong to what applications.
6. Grant user permission to restore databases for an application (dbo.UserAuthDB).

**Limitations**
I have not addressed all the restoration challenges in this solution.  The solution can handle multiple backup files, multiple data files, and multiple log files.  However, there are some assumptions in place.
* All data files belong to the default data path.
* All log files belong to the default log path.
* If backups are being accessed across the network, backups exist in file share accessible by target instance.
* Currently does not support Filestream or In-Memory objects.
* Granting access is currently a manual task, I have not had a chance to set up and create reports.
* I am using SSRS write-back to submit a restore request.  This solution would be much nicer as a Web Front-end, however, although I am a developer at heart.  I have no skills in .NET :(.  So if anyone wants to help please reach out :).
* Masking sensitive production information.
