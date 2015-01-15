$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

Describe "Invoke-SqlBackupToS3" {

	Context "no region specified but default is set" {
		Mock Get-DefaultAWSRegion { return 'default-region'}
		Mock Invoke-SqlBackup { return $null }
		Mock Write-S3Object { return $null }
		Mock Get-S3Bucket { return @{BucketName = 'BucketName'} }
		Mock Test-S3Bucket { return $true }
		Mock Get-S3BucketVersioning { return @{Status = [Amazon.S3.VersionStatus]::Enabled} }
		Mock Get-S3Object { return 'Object' }

		New-Item 'TestDrive:\DefaultBackupPath' -Type directory

		$Parameters = @{
			SqlServer = @{BackupDirectory = 'TestDrive:\DefaultBackupPath'};
			DBName = 'DatabaseName';
			BucketName = 'BucketName';
			Key = 'DatabaseName.bak'
		}
		Invoke-SqlBackupToS3 @Parameters

		It "Calls Get-DefaultAWSRegion" {
			Assert-MockCalled Get-DefaultAWSRegion 1
		}

		It "Calls Invoke-SqlBackup" {
			Assert-MockCalled Invoke-SqlBackup 1
		}

		It "Calls Write-S3Object" {
			Assert-MockCalled Write-S3Object 1 -ParameterFilter {
			 	$Region -eq 'default-region'
			}
		}
	}

	Context "no region specified but default is not set" {
		Mock Get-DefaultAWSRegion { return $null}
		Mock Invoke-SqlBackup { return $null }
		Mock Write-S3Object { return $null }
		Mock Get-S3Bucket { return @{BucketName = 'BucketName'} }
		Mock Test-S3Bucket { return $true }
		Mock Get-S3BucketVersioning { return @{Status = [Amazon.S3.VersionStatus]::Enabled} }
		Mock Get-S3Object { return 'Object' }

		New-Item 'TestDrive:\DefaultBackupPath' -Type directory

		$Parameters = @{
			SqlServer = @{BackupDirectory = 'TestDrive:\DefaultBackupPath'};
			DBName = 'DatabaseName';
			BucketName = 'BucketName';
			Key = 'DatabaseName.bak'
		}

		It "Throws an exception" {
			{ Invoke-SqlBackupToS3 @Parameters } | Should Throw
		}
	}

	Context "region specified" {
		Mock Get-DefaultAWSRegion { return 'default-region'}
		Mock Invoke-SqlBackup { return $null }
		Mock Write-S3Object { return $null }
		Mock Get-S3Bucket { return @{BucketName = 'BucketName'} }
		Mock Test-S3Bucket { return $true }
		Mock Get-S3BucketVersioning { return @{Status = [Amazon.S3.VersionStatus]::Enabled} }
		Mock Get-S3Object { return 'Object' }

		New-Item 'TestDrive:\DefaultBackupPath' -Type directory

		$Parameters = @{
			SqlServer = @{BackupDirectory = 'TestDrive:\DefaultBackupPath'};
			DBName = 'DatabaseName';
			BucketName = 'BucketName';
			Key = 'DatabaseName.bak';
			Region = 'Region'
		}
		Invoke-SqlBackupToS3 @Parameters

		It "Calls Invoke-SqlBackup" {
			Assert-MockCalled Invoke-SqlBackup 1
		}

		It "Calls Write-S3Object" {
			Assert-MockCalled Write-S3Object 1 -ParameterFilter {
			 	$Region -eq 'Region'
			}
		}
	}

	Context "TempFilePath does not exist" {
		Mock Get-DefaultAWSRegion { return 'default-region'}
		Mock Invoke-SqlBackup { return $null }
		Mock Write-S3Object { return $null }
		Mock Get-S3Bucket { return @{BucketName = 'BucketName'} }
		Mock Test-S3Bucket { return $true }
		Mock Get-S3BucketVersioning { return @{Status = [Amazon.S3.VersionStatus]::Enabled} }
		Mock Get-S3Object { return 'Object' }

		$Parameters = @{
			SqlServer = @{BackupDirectory = 'TestDrive:\DefaultBackupPath'};
			DBName = 'DatabaseName';
			BucketName = 'BucketName';
			Key = 'DatabaseName.bak';
			Region = 'Region';
			TempFilePath = "TestDrive:\Path"
		}

		It "Throws an exception" {
			{ Invoke-SqlBackupToS3 @Parameters } | Should Throw
		}
	}

	Context "temp file already exists" {
		Mock Get-DefaultAWSRegion { return 'default-region'}
		Mock Invoke-SqlBackup { return $null }
		Mock Write-S3Object { return $null }
		Mock Test-S3Bucket { return $true }
		Mock Get-S3Bucket { return @{BucketName = 'BucketName'} }
		Mock Get-S3BucketVersioning { return @{Status = [Amazon.S3.VersionStatus]::Enabled} }
		Mock Get-S3Object { return 'Object' }

		New-Item 'TestDrive:\DefaultBackupPath' -Type directory
		New-Item 'TestDrive:\DefaultBackupPath\DatabaseName.bak' -Type directory

		$Parameters = @{
			SqlServer = @{BackupDirectory = 'TestDrive:\DefaultBackupPath'};
			DBName = 'DatabaseName';
			BucketName = 'BucketName';
			Key = 'DatabaseName.bak'
		}

		It "Throws an exception" {
			{ Invoke-SqlBackupToS3 @Parameters } | Should Throw
		}
	}

	Context "bucket does not exist" {
		Mock Get-DefaultAWSRegion { return 'default-region'}
		Mock Invoke-SqlBackup { return $null }
		Mock Write-S3Object { return $null }
		Mock Get-S3Bucket { return $null }
		Mock Test-S3Bucket { return $false }
		Mock Get-S3BucketVersioning { return @{Status = [Amazon.S3.VersionStatus]::Enabled} }
		Mock Get-S3Object { return 'Object' }

		New-Item 'TestDrive:\DefaultBackupPath' -Type directory

		$Parameters = @{
			SqlServer = @{BackupDirectory = 'TestDrive:\DefaultBackupPath'};
			DBName = 'DatabaseName';
			BucketName = 'BucketName';
			Key = 'DatabaseName.bak'
		}

		It "Throws an exception" {
			{ Invoke-SqlBackupToS3 @Parameters } | Should Throw
		}
	}

	Context "bucket versioning not enabled and target exists" {
		Mock Get-DefaultAWSRegion { return 'default-region'}
		Mock Invoke-SqlBackup { return $null }
		Mock Write-S3Object { return $null }
		Mock Get-S3Bucket { return @{BucketName = 'BucketName'} }
		Mock Test-S3Bucket { return $true }
		Mock Get-S3BucketVersioning { return @{Status = [Amazon.S3.VersionStatus]::Disabled} }
		Mock Get-S3Object { return 'Object' }

		New-Item 'TestDrive:\DefaultBackupPath' -Type directory

		$Parameters = @{
			SqlServer = @{BackupDirectory = 'TestDrive:\DefaultBackupPath'};
			DBName = 'DatabaseName';
			BucketName = 'BucketName';
			Key = 'DatabaseName.bak'
		}

		It "Throws an exception" {
			{ Invoke-SqlBackupToS3 @Parameters } | Should Throw
		}
	}

	Context "bucket versioning not enabled and target does not exist" {
		Mock Get-DefaultAWSRegion { return 'default-region'}
		Mock Invoke-SqlBackup { return $null }
		Mock Write-S3Object { return $null }
		Mock Get-S3Bucket { return @{BucketName = 'BucketName'} }
		Mock Test-S3Bucket { return $true }
		Mock Get-S3BucketVersioning { return @{Status = [Amazon.S3.VersionStatus]::Disabled} }
		Mock Get-S3Object { return $null }

		New-Item 'TestDrive:\DefaultBackupPath' -Type directory

		$Parameters = @{
			SqlServer = @{BackupDirectory = 'TestDrive:\DefaultBackupPath'};
			DBName = 'DatabaseName';
			BucketName = 'BucketName';
			Key = 'DatabaseName.bak';
			Region = 'Region'
		}
		Invoke-SqlBackupToS3 @Parameters

		It "Calls Invoke-SqlBackup" {
			Assert-MockCalled Invoke-SqlBackup 1
		}

		It "Calls Write-S3Object" {
			Assert-MockCalled Write-S3Object 1
		}
	}

	Context "bucket versioning enabled" {
		Mock Get-DefaultAWSRegion { return 'default-region'}
		Mock Invoke-SqlBackup { return $null }
		Mock Write-S3Object { return $null }
		Mock Get-S3Bucket { return @{BucketName = 'BucketName'} }
		Mock Test-S3Bucket { return $true }
		Mock Get-S3BucketVersioning { return @{Status = [Amazon.S3.VersionStatus]::Enabled} }
		Mock Get-S3Object { return 'Object' }

		New-Item 'TestDrive:\DefaultBackupPath' -Type directory

		$Parameters = @{
			SqlServer = @{BackupDirectory = 'TestDrive:\DefaultBackupPath'};
			DBName = 'DatabaseName';
			BucketName = 'BucketName';
			Key = 'DatabaseName.bak';
			Region = 'Region'
		}
		Invoke-SqlBackupToS3 @Parameters

		It "Calls Invoke-SqlBackup" {
			Assert-MockCalled Invoke-SqlBackup 1
		}

		It "Calls Write-S3Object" {
			Assert-MockCalled Write-S3Object 1
		}
	}

	Context "unable to connect to bucket" {
		Mock Get-DefaultAWSRegion { return 'default-region'}
		Mock Invoke-SqlBackup { return $null }
		Mock Write-S3Object { return $null }
		Mock Get-S3Bucket { return $null }
		Mock Test-S3Bucket { return $true }
		Mock Get-S3BucketVersioning { return @{Status = [Amazon.S3.VersionStatus]::Enabled} }
		Mock Get-S3Object { return 'Object' }

		New-Item 'TestDrive:\DefaultBackupPath' -Type directory

		$Parameters = @{
			SqlServer = @{BackupDirectory = 'TestDrive:\DefaultBackupPath'};
			DBName = 'DatabaseName';
			BucketName = 'BucketName';
			Key = 'DatabaseName.bak'
		}

		It "Throws an exception" {
			{ Invoke-SqlBackupToS3 @Parameters } | Should Throw
		}
	}
}