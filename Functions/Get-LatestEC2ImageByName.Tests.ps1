$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "Get-LatestEC2ImageByName" {

	Context "Pattern matches zero AMIs" {
		Mock Get-EC2Image { return $null }
		It "thows an error" {
			{ Get-LatestEC2ImageByName -Pattern 'pattern*' } | Should throw
		}
	}

	Context "Pattern matches 1 AMI" {
		$ami = New-Object Amazon.EC2.Model.Image
		$ami.Name = 'Name1'
		Mock Get-EC2Image { return $ami }
		It "returns AMI" {
			Get-LatestEC2ImageByName -Pattern "Name*" | Should be $ami
		}
	}

	Context "Pattern matches multiple AMIs" {
		$amis = @(
			(New-Object Amazon.EC2.Model.Image),
			(New-Object Amazon.EC2.Model.Image),
			(New-Object Amazon.EC2.Model.Image)
		)
		$amis[0].Name = 'Name0'
		$amis[1].Name = 'Name1'
		$amis[2].Name = 'Name2'
		Mock Get-EC2Image { return $amis }
		It "returns AMI" {
			Get-LatestEC2ImageByName -Pattern "Name*" | Should be $amis[2]
		}
	}

	Context "No AWS profile provided" {
		It "should not call Set-AWSCredentials" {
			$amis = @(
				(New-Object Amazon.EC2.Model.Image),
				(New-Object Amazon.EC2.Model.Image),
				(New-Object Amazon.EC2.Model.Image)
			)
			$amis[0].Name = 'Name0'
			$amis[1].Name = 'Name1'
			$amis[2].Name = 'Name2'
			Mock Get-EC2Image { return $amis }

			Mock Set-AWSCredentials {} -Verifiable

			Get-LatestEC2ImageByName -Pattern "Name*"

			Assert-MockCalled Set-AWSCredentials -Exactly 0
		}
	}

	Context "AWS profile provided" {
		It "should call Set-AWSCredentials" {
			$amis = @(
				(New-Object Amazon.EC2.Model.Image),
				(New-Object Amazon.EC2.Model.Image),
				(New-Object Amazon.EC2.Model.Image)
			)
			$amis[0].Name = 'Name0'
			$amis[1].Name = 'Name1'
			$amis[2].Name = 'Name2'
			Mock Get-EC2Image { return $amis }

			Mock Set-AWSCredentials {} -Verifiable

			Get-LatestEC2ImageByName -Pattern "Name*" -AWSProfileName 'Profile'

			Assert-MockCalled Set-AWSCredentials -Exactly 1
		}
	}
}
