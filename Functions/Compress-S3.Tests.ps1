$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

Describe "Compress-S3" {

	BeforeEach {
		Get-Module -Name Pscx | Remove-Module
		New-Module -Name Pscx -ScriptBlock {
			function Write-Zip {
				param (
					[parameter()]
					[String]
					$OutputPath,

					[parameter()]
					[String[]]
					$LiteralPath
				)
			}

			Export-ModuleMember -Function Write-Zip
		} | Import-Module
	}

	Context "bucket does not exist" {
		Mock Test-S3Bucket { return $false }

		It "Throws an exception" {
			{ Compress-S3 -Src 'TestDrive:\TestDir' -BucketName 'TestBucket' } | Should Throw
		}
	}

	Context "S3 key file already exists" {
		Mock Test-S3Bucket { return $true }

		New-Item "TestDrive:\TestDir" -Type directory
		Set-Content "TestDrive:\TestDir.s3key" -Value ""

		It "Throws and exception" {
			{ Compress-S3 -Src 'TestDrive:\TestDir' -BucketName 'TestBucket' } | Should Throw
		}
	}

	Context "Archive file already exists" {
		Mock Test-S3Bucket { return $true }

		New-Item "TestDrive:\TestDir" -Type directory
		Set-Content "TestDrive:\TestDir.zip" -Value ""

		It "Throws and exception" {
			{ Compress-S3 -Src 'TestDrive:\TestDir' -BucketName 'TestBucket' } | Should Throw
		}
	}

	Context "source does not exist" {
		Mock Test-S3Bucket { return $true }

		It "Throws and exception" {
			{ Compress-S3 -Src 'TestDrive:\TestDir' -BucketName 'TestBucket' } | Should Throw
		}
	}

	Context "source is directory" {
		Mock Test-S3Bucket { return $true }
		Mock Write-Zip {
			Set-Content $OutputPath -value "Archive contents"
		}
		Mock Write-S3Object {}

		New-Item "TestDrive:\TestDir" -Type directory
		Set-Content "TestDrive:\TestDir\file1" -Value "File1 Contents"

		Compress-S3 -Src 'TestDrive:\TestDir' -BucketName 'TestBucket' -KeyPrefix "KeyPrefix"

		It "Creates S3key files which contains pointer" {
			"TestDrive:\TestDir.s3key" | Should ContainExactly "KeyPrefix/TestDir.zip"
		}

		It "Calls Write-Zip to create archive" {
			Assert-MockCalled Write-Zip 1 -ParameterFilter {
			 	$OutputPath -eq "TestDrive:\TestDir.zip" -and $LiteralPath -eq "TestDrive:\TestDir"
			}
		}

		It "Calls Write-S3Object to upload archive" {
			Assert-MockCalled Write-S3Object 1 -ParameterFilter {
				$BucketName -eq "TestBucket" -and $Key -eq "KeyPrefix/TestDir.zip" -and $File -eq 'TestDir.zip'
			}
		}

		It "Removes the archive file" {
			"TestDrive:\TestDir.zip" | Should not exist
		}

		It "Removes the src directory" {
			"TestDrive:\TestDir" | Should not exist
		}
	}

	Context "source is file" {
		Mock Test-S3Bucket { return $true }
		Mock Write-Zip {
			Set-Content $OutputPath -value "Archive contents"
		}
		Mock Write-S3Object {}

		Set-Content "TestDrive:\TestFile.txt" -Value "TestFile Contents"

		Compress-S3 -Src 'TestDrive:\TestFile.txt' -BucketName 'TestBucket' -KeyPrefix "KeyPrefix"

		It "Creates S3key files which contains pointer" {
			"TestDrive:\TestFile.txt.s3key" | Should ContainExactly "KeyPrefix/TestFile.txt"
		}

		It "Does not call Write-Zip" {
			Assert-MockCalled Write-Zip 0
		}

		It "Calls Write-S3Object to upload archive" {
			Assert-MockCalled Write-S3Object 1 -ParameterFilter {
				$BucketName -eq "TestBucket" -and $Key -eq "KeyPrefix/TestFile.txt" -and $File -eq 'TestFile.txt'
			}
		}

		It "Removes the src file" {
			"TestDrive:\TestFile.txt" | Should not exist
		}
	}

	Context "stream of sources passed via pipe" {
		Mock Test-S3Bucket { return $true }
		Mock Write-Zip {
			Set-Content $OutputPath -value "Archive contents"
		}
		Mock Write-S3Object {}

		Set-Content "TestDrive:\TestFile1.txt" -Value "TestFile1 Contents"
		Set-Content "TestDrive:\TestFile2.txt" -Value "TestFile2 Contents"
		New-Item "TestDrive:\TestDir" -Type directory
		Set-Content "TestDrive:\TestDir\file1" -Value "File1 Contents"

		$Src = @(
			"TestDrive:\TestFile1.txt",
			"TestDrive:\TestFile2.txt",
			"TestDrive:\TestDir"
		)
		$Src | Compress-S3 -BucketName 'TestBucket' -KeyPrefix "KeyPrefix"

		It "Creates S3key file for TestFile1.txt which contains pointer" {
			"TestDrive:\TestFile1.txt.s3key" | Should ContainExactly "KeyPrefix/TestFile1.txt"
		}

		It "Creates S3key file for TestFile2.txt which contains pointer" {
			"TestDrive:\TestFile2.txt.s3key" | Should ContainExactly "KeyPrefix/TestFile2.txt"
		}

		It "Creates S3key file for TestDir which contains pointer" {
			"TestDrive:\TestDir.s3key" | Should ContainExactly "KeyPrefix/TestDir.zip"
		}

		It "Calls Write-Zip once to create archive" {
			Assert-MockCalled Write-Zip 1 -ParameterFilter {
			 	$OutputPath -eq "TestDrive:\TestDir.zip" -and $LiteralPath -eq "TestDrive:\TestDir"
			}
		}

		It "Calls Write-S3Object 3 times to upload" {
			Assert-MockCalled Write-S3Object 3
		}

		It "Removes the srcs" {
			"TestDrive:\TestFile1.txt" | Should not exist
			"TestDrive:\TestFile2.txt" | Should not exist
			"TestDrive:\TestDir" | Should not exist
		}

		It "Removes the archive file" {
			"TestDrive:\TestDir.zip" | Should not exist
		}
	}

	Context "array of sources passed via parameter" {
		Mock Test-S3Bucket { return $true }
		Mock Write-Zip {
			Set-Content $OutputPath -value "Archive contents"
		}
		Mock Write-S3Object {}

		Set-Content "TestDrive:\TestFile1.txt" -Value "TestFile1 Contents"
		Set-Content "TestDrive:\TestFile2.txt" -Value "TestFile2 Contents"
		New-Item "TestDrive:\TestDir" -Type directory
		Set-Content "TestDrive:\TestDir\file1" -Value "File1 Contents"

		$Src = @(
			"TestDrive:\TestFile1.txt",
			"TestDrive:\TestFile2.txt",
			"TestDrive:\TestDir"
		)
		Compress-S3 -Src $Src -BucketName 'TestBucket' -KeyPrefix "KeyPrefix"

		It "Creates S3key file for TestFile1.txt which contains pointer" {
			"TestDrive:\TestFile1.txt.s3key" | Should ContainExactly "KeyPrefix/TestFile1.txt"
		}

		It "Creates S3key file for TestFile2.txt which contains pointer" {
			"TestDrive:\TestFile2.txt.s3key" | Should ContainExactly "KeyPrefix/TestFile2.txt"
		}

		It "Creates S3key file for TestDir which contains pointer" {
			"TestDrive:\TestDir.s3key" | Should ContainExactly "KeyPrefix/TestDir.zip"
		}

		It "Calls Write-Zip once to create archive" {
			Assert-MockCalled Write-Zip 1 -ParameterFilter {
			 	$OutputPath -eq "TestDrive:\TestDir.zip" -and $LiteralPath -eq "TestDrive:\TestDir"
			}
		}

		It "Calls Write-S3Object 3 times to upload" {
			Assert-MockCalled Write-S3Object 3
		}

		It "Removes the srcs" {
			"TestDrive:\TestFile1.txt" | Should not exist
			"TestDrive:\TestFile2.txt" | Should not exist
			"TestDrive:\TestDir" | Should not exist
		}

		It "Removes the archive file" {
			"TestDrive:\TestDir.zip" | Should not exist
		}
	}
}