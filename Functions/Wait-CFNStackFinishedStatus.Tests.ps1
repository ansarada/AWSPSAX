$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

Describe "Wait-CFNStackFinishedStatus" {
	Mock Get-CFNStackSummary {
		return @(
			@{ StackName = "StackName1" },
			@{ StackName = "StackName2" }
		)
	}

	Context "timeout exceeded" {

		It "throws error" {
			{ Wait-CFNStackFinishedStatus -StackName 'StackName3' -Timeout 15 -CheckInterval 2 } | Should Throw
		}
	}

	Context "stack in finished state" {
		$result = Wait-CFNStackFinishedStatus -StackName 'StackName1'

		It "returns stack" {
			$result.StackName | Should Be "StackName1"
		}
	}

	Context "No AWS profile provided" {
		It "should not call Set-AWSCredentials" {

			Mock Set-AWSCredentials {} -Verifiable

			Wait-CFNStackFinishedStatus -StackName 'StackName1'

			Assert-MockCalled Set-AWSCredentials -Exactly 0
		}
	}

	Context "AWS profile provided" {
		It "should not call Set-AWSCredentials" {

			Mock Set-AWSCredentials {} -Verifiable

			Wait-CFNStackFinishedStatus -StackName 'StackName1' -AWSProfileName 'Profile'

			Assert-MockCalled Set-AWSCredentials -Exactly 1
		}
	}
}
