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

	.Parameter Force
	Refer to Invoke-SqlBackup (http://files.powershellstation.com/SQLPSX/Invoke-SqlBackup.htm) and Initialize (http://technet.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.backup.initialize.aspx).

	.Parameter AWSProfileName
		Name of AWS profile to use

#>

Push-Location
Import-Module SQLServer
Import-Module SQLPS -DisableNameChecking
Pop-Location

function Invoke-SqlRestoreFromS3 {

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
		[switch]
		$Force,

		[parameter()]
		[string]
		$FilenameSuffix,

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
	else {
		Write-Verbose "Region specified, $Region"
	}

	Write-Verbose "Checking to see if TempFilePath specified"
	if ([String]::IsNullOrEmpty($TempFilePath)) {
		Write-Verbose "TempFilePath not set, using server's directory"
		$TempFilePath = $SqlServer.BackupDirectory
		Write-Verbose "TempFilePath set to $($TempFilePath)"
	}
	else {
		Write-Verbose "TempFilePath specified, $TempFilePath"
	}

	Write-Verbose "Checking to see if TempFilePath exists"
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
	if ($(Test-Path $FilePath) -and -not ($Overwrite)) {
		throw "Temp file already exists: $($FilePath)"
	}

	Write-Verbose "Checking to see if S3 bucket exists"
	if (-not $(Test-S3Bucket -BucketName $BucketName)) {
		throw "S3 bucket does not exist: $($BucketName)"
	}

	Write-Verbose "Reading from $($BucketName)/$($Key) to $($FilePath)"
	Read-S3Object -BucketName $BucketName -Key $Key -File $FilePath -Region $Region | Out-Null

	Write-Verbose "Creating SMO Restore object"
	$Restore = New-Object Microsoft.SqlServer.Management.SMO.Restore

	Write-Verbose "Creating SMO BackupDeviceItem object based on $FilePath"
	$BackupDeviceItem = New-Object Microsoft.SqlServer.Management.SMO.BackupDeviceItem($FilePath, [Microsoft.SqlServer.Management.SMO.DeviceType]::File)

	Write-Verbose "Adding BackupDeviceItem to Restore as device"
	$Restore.Devices.Add($BackupDeviceItem)

	Write-Verbose "Reading database files from backup file using server $($SqlServer.InstanceName)"
	$DatabaseFiles = $Restore.ReadFileList($SqlServer)

	$RelocateFiles = @{}

	Write-Verbose "Checking to see if the locations in the physical names exist"
	foreach ($DatabaseFile in $DatabaseFiles.Rows){

		$OldFilename = Split-Path -Leaf $DatabaseFile.PhysicalName
		$NewFilename = @(
			[System.IO.Path]::GetFileNameWithoutExtension($OldFilename),
			$(if ([String]::IsNullOrEmpty($FilenameSuffix)) { '' } else { "_$FilenameSuffix" }),
			[System.IO.Path]::GetExtension($OldFilename)
		) -join ''

		$DatabaseFileParentPath = Split-Path $DatabaseFile.PhysicalName
		Write-Verbose "DatabaseFile $($DatabaseFile.LogicalName) parent is $DatabaseFileParentPath, from $($DatabaseFile.PhysicalName)"

		Write-Verbose "Checking to see if DatabaseFile ($($DatabaseFile.LogicalName)) parent path exists"
		if (Test-Path $DatabaseFileParentPath) {
			Write-Verbose "DatabaseFile ($($DatabaseFile.LogicalName)) parent exists"
			$NewPhysicalPath = $DatabaseFileParentPath
		}
		else {
			Write-Verbose "DatabaseFile ($($DatabaseFile.LogicalName)) parent path does NOT exist, getting file type"
			if ($DatabaseFile.Type -eq 'D') {
				Write-Verbose "DatabaseFile ($($DatabaseFile.LogicalName)) is a data file"
				$NewPhysicalPath = $SqlServer.DefaultFile
				Write-Verbose "Checking to see if NewPhysicalPath is null/empty"
				if ([String]::IsNullOrEmpty($NewPhysicalPath)) {
					Write-Verbose "Is null/empty, using MasterDBPath"
					$NewPhysicalPath = $SqlServer.MasterDBPath
				}
			}
			elseif ($DatabaseFile.Type -eq 'L') {
				Write-Verbose "DatabaseFile ($($DatabaseFile.LogicalName)) is a log file"
				$NewPhysicalPath = $SqlServer.DefaultLog
				Write-Verbose "Checking to see if NewPhysicalPath is null/empty"
				if ([String]::IsNullOrEmpty($NewPhysicalPath)) {
					Write-Verbose "Is null/empty, using MasterDBLogPath"
					$NewPhysicalPath = $SqlServer.MasterDBLogPath
				}
			}
			else {
				throw "Unknown file type '$($DatabaseFile.Type)' for file $($DatabaseFile.LogicalName)"
			}
		}

		$NewPhysicalFullName = Join-Path $NewPhysicalPath $NewFilename
		Write-Verbose "Moving the DatabaseFile to $NewPhysicalFullName"

		$RelocateFiles.Add($DatabaseFile.LogicalName, $NewPhysicalFullName)
	}

	Write-Verbose "Define parameters for restore"
	$Parameters = @{
		SqlServer = $SqlServer;
		DBName = $DBName;
		FilePath = $FilePath;
		Action = $Action;
		Force = $Force;
		RelocateFiles = $RelocateFiles;
	}
	Write-Verbose "Restoring backup"
	Invoke-SqlRestore @Parameters

	if ($Clean) {
		Write-Verbose "Removing temp backup: $($FilePath)"
		Remove-Item $FilePath
	}

	Write-Verbose "Restoring SqlServer StatementTimeout to $($StatementTimeout) seconds"
	$SqlServer.ConnectionContext.StatementTimeout = $StatementTimeout


}
