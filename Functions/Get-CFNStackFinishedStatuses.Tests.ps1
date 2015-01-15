$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

Describe "Get-CFNStackFinishedStatuses" {

	$result = Get-CFNStackFinishedStatuses

	It "returns array length of 9" {
		$result.length | Should be 9
	}
}