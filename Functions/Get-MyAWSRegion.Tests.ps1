$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

Describe "Get-MyAWSRegion" {
	Mock Invoke-RestMethod { return 'regionA' }

	$result = Get-MyAWSRegion

	It "returns region" {
		$result | Should be 'region'
	}
}