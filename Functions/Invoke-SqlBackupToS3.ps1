<#
	.Synopsis
	Backup SQL database to S3

	.Description
	Will backup a SQL database to a local or network share and then write that backup to a S3 bucket.

	.Parameter SqlServer
	The SQL server.

	.Parameter DBName
	The name of the DB to backup.

	.Parameter BucketName
	The name of the S3 bucket to send the buckup to.

	.Parameter Key
	The S3 key, the last part will be the name of the backup file.

	.Parameter TempFilePath
	The place to write the backup to. If left blank then the backup directory for the SQL server is used.

	.Parameter TempFileSuffix
	The suffix to be appended to the database backup file

	.Parameter Overwrite
	Set if you want overwrite the temporary backup or S3 object if they already exist.

	.Parameter Clean
	Set if you want the temporary backup file deleted after it is uploaded to S3.

	.Parameter Action
	Refer to Invoke-SqlBackup (http://files.powershellstation.com/SQLPSX/Invoke-SqlBackup.htm) and BackupActionType (http://technet.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.backupactiontype.aspx).

	.Parameter Description
	Refer to Invoke-SqlBackup (http://files.powershellstation.com/SQLPSX/Invoke-SqlBackup.htm) and BackupSetDescription (http://technet.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.backup.backupsetdescription.aspx).

	.Parameter Name
	Refer to Invoke-SqlBackup (http://files.powershellstation.com/SQLPSX/Invoke-SqlBackup.htm) and BackupSetName (http://technet.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.backup.backupsetname.aspx).

	.Parameter Force
	Refer to Invoke-SqlBackup (http://files.powershellstation.com/SQLPSX/Invoke-SqlBackup.htm) and Initialize (http://technet.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.backup.initialize.aspx).

	.Parameter Incremental
	Refer to Invoke-SqlBackup (http://files.powershellstation.com/SQLPSX/Invoke-SqlBackup.htm) and Incremental (http://technet.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.backup.incremental.aspx).

	.Parameter CopyOnly
	Refer to Invoke-SqlBackup (http://files.powershellstation.com/SQLPSX/Invoke-SqlBackup.htm) and CopyOnly (http://technet.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.backup.copyonly.aspx).

	.Parameter AWSProfileName
	AWS profile to use

#>

function Invoke-SqlBackupToS3 {

	[cmdletbinding()]

	param(
		[parameter(Mandatory=$true)]
		[Microsoft.SqlServer.Management.Smo.Server]
		$SqlServer,

		[parameter(Mandatory=$true)]
		[string]
		$DBName,

		[parameter(Mandatory=$true)]
		[string]
		$BucketName,

		[parameter(Mandatory=$true)]
		[string]
		$Key,

		[parameter()]
		[string]
		$Region,

		[parameter()]
		[string]
		$TempFilePath,

		[parameter()]
		[string]
		$TempFileSuffix,

		[parameter()]
		[switch]
		$Overwrite,

		[parameter()]
		[switch]
		$Clean,

		[parameter()]
		[ValidateSet("Database", "Files", "Log")]
		[string]
		$Action = "Database",

		[parameter()]
		[string]
		$Description,

		[parameter()]
		[string]
		$Name,

		[parameter()]
		[switch]
		$Force,

		[parameter()]
		[switch]
		$Incremental,

		[parameter()]
		[switch]
		$CopyOnly,

		[parameter()]
		[string]
		$AWSProfileName
	)

	if ($AWSProfileName) {
		Write-Verbose "Switching to AWS profile $AWSProfileName"
		Set-AWSCredentials -ProfileName $AWSProfileName
	}

	Write-Verbose "Saving SqlServer StatementTimeout ($($SqlServer.ConnectionContext.StatementTimeout))"
	$StatementTimeout = $SqlServer.ConnectionContext.StatementTimeout
	Write-Verbose "Setting SqlServer StatementTimeout"
	$SqlServer.ConnectionContext.StatementTimeout = 6000
	Write-Verbose "Set SqlServer StatementTimeout to $($SqlServer.ConnectionContext.StatementTimeout) seconds"

	Write-Verbose "Checking to see if Region specified"
	if ($Region -eq $null -or $Region -eq "") {
		$Region = Get-DefaultAWSRegion
		if ($Region) {
			Write-Verbose "No Region specified, using default $Region"
		}
		else {
		    throw "No Region specified and no default set"
		}
	}

	if ([String]::IsNullOrEmpty($TempFilePath)) {
		Write-Verbose "TempFilePath not set, using server's directory"
		$TempFilePath = $SqlServer.BackupDirectory
		Write-Verbose "TempFilePath set to $($TempFilePath)"
	}

	Write-Verbose "Checking to see if TempFilePath"
	if (-not $(Test-Path $TempFilePath)) {
		throw "Could not find TempFilePath: $($TempFilePath)"
	}

	$Filename = @(
		[System.IO.Path]::GetFileNameWithoutExtension($Key),
		$(if ([String]::IsNullOrEmpty($TempFileSuffix)) { [String]::Empty } else { "_$TempFileSuffix" }),
		[System.IO.Path]::GetExtension($Key)
	) -join ''
	$FilePath = Join-Path $TempFilePath $Filename

	Write-Verbose "Checking to see if temp file already exists"
	if (Test-Path $FilePath) {
		if ($Overwrite) {
			Write-Verbose "Temp file ($FilePath) already exists, deleting"
			Remove-Item -Force $FilePath
		}
		else {
			throw "Temp file already exists: $($FilePath)"
		}
	}

	Write-Verbose "Checking to see if S3 bucket exists"
	if (-not $(Test-S3Bucket -BucketName $BucketName)) {
		throw "S3 bucket does not exist: $($BucketName)"
	}

	Write-Verbose "Getting bucket versioning status"
	$BucketVersioning = Get-S3BucketVersioning -BucketName $BucketName -Region $Region
	$BucketVersioningEnabled = $BucketVersioning.Status -eq [Amazon.S3.VersionStatus]::Enabled

	Write-Verbose "Checking to see if S3 object exists"
	if ($(Get-S3Object -BucketName $BucketName -Key $Key -Region $Region) -and -not ($Overwrite -or $BucketVersioningEnabled)) {
		throw "S3 object already exists: $BucketName/$Key"
	}

	Write-Verbose "Checking to see if S3 bucket exists"
	if (Test-S3Bucket -BucketName $BucketName -Region $Region) {
		Write-Verbose "Connected to bucket $($BucketName)"
	}
	else {
		throw "Unable to connect to bucket $BucketName"
	}

	$Parameters = @{
		SqlServer = $SqlServer;
		DBName = $DBName;
		FilePath = $FilePath;
		Action = $Action;
		Description = $Description;
		Name = $Name;
		Force = $Force;
		Incremental = $Incremental;
		CopyOnly = $CopyOnly
	}

	Write-Verbose "Creating backup"
	Invoke-SqlBackup @Parameters

	Write-Verbose "Writing $($FilePath) to $($BucketName)/$($Key)"
	Write-S3Object -BucketName $BucketName -Key $Key -File $FilePath -Region $Region

	if ($Clean) {
		Write-Verbose "Removing temp backup: $($FilePath)"
		Remove-Item $FilePath
	}

	Write-Verbose "Restoring SqlServer StatementTimeout to $($StatementTimeout) seconds"
	$SqlServer.ConnectionContext.StatementTimeout = $StatementTimeout
}
