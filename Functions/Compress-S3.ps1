<#

.SYNOPSIS
	Will upload and array of files/directories to S3 and leave files pointing to those S3 objects.

.PARAMETER Src
	The array of files/directories to upload

.PARAMETER BucketName
	The S3 bucket to upload to

.PARAMETER KeyPrefix
	The prefix to add to the key of the objects uploaded

.INPUTS
	The set of paths to create if they don't exist

#>

function Compress-S3 {
	[CmdletBinding()]

	param (
		[parameter(ValueFromPipeline=$true,Mandatory=$true)]
		[String[]]
		$Src,

		[parameter(Mandatory=$true)]
		[String]
		$BucketName,

		[parameter()]
		[String]
		$KeyPrefix
	)

	begin {
		Write-Verbose "Checking that bucket $BucketName exists"
		if (Test-S3Bucket -BucketName $BucketName) {
			Write-Verbose "Bucket $BucketName exists"
		}
		else {
			throw "Bucket $BucketName could not be found"
		}
	}

	process {
		$Src | foreach {
			Write-Verbose "Processing $_"
			if (-not (Test-Path $_)) {
				throw "Src path ($_)"
			}
			else {
				Write-Debug "Src path ($_) exists"
			}

			$Name = Split-Path $_ -Leaf
			$Path = Split-Path $_ -Parent
			$S3KeyFilename = Join-Path $Path "$Name.s3key"

			if (Test-Path $S3KeyFilename) {
				throw "S3 key file ($S3KeyFilename) already exists"
			}
			else {
				Write-Debug "S3 key file does not already exist"
			}

			if ((Get-Item $_) -is [System.IO.DirectoryInfo]) {
				Write-Debug "Src is a directory, so compressing"
				$ArchiveFullname = Join-Path $Path "$Name.zip"

				if (Test-Path $ArchiveFullname) {
					throw "Archive file ($ArchiveFullname) already exists"
				}
				else {
					Write-Debug "Archive ($($ArchiveFullname)) does not exist"
				}

				$WriteZipParams = @{
					OutputPath = $ArchiveFullname;
					LiteralPath = $_
				}
				Write-Debug "Creating zip ($($WriteZipParams.OutputPath)) from $($WriteZipParams.LiteralPath)"
				Write-Zip @WriteZipParams

				$UploadFile = Get-Item $ArchiveFullname
			}
			else {
				Write-Debug "Src is a file so skipping compression"
				$UploadFile = Get-Item $_
			}

			$S3Key = "$KeyPrefix/$($UploadFile.Name)"

			$WriteS3ObjectParams = @{
				BucketName = $BucketName;
				Key = $S3Key;
				File = $UploadFile.Name
			}
			Write-Debug "Uploading $($WriteS3ObjectParams.File) to bucket $($WriteS3ObjectParams.BucketName) under key $($WriteS3ObjectParams.Key)"
			Write-S3Object @WriteS3ObjectParams

			if (Test-Path $_) {
				Write-Debug "Removing $_"
				Remove-Item $_ -Force -Recurse
			}
			if (Test-Path $UploadFile) {
				Write-Debug "Removing $UploadFile"
				Remove-Item $UploadFile -Force
			}

			Write-Debug "Writing S3 key ($S3Key) to $S3KeyFilename"
			$S3Key | Out-File $S3KeyFilename
		}
	}
}
