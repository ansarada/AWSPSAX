Set-StrictMode -Version Latest
#requires -Version 3 -Modules AWSPowerShell

<#
	.Synopsis
	Gets a single AMI matching name pattern

	.DESCRIPTION
	The highest (alphanumically) matching AMI with a name that matches the pattern supplied is returned

	.OUTPUTS
	Amazon.EC2.Model.Image http://docs.aws.amazon.com/sdkfornet/v3/apidocs/index.html?page=EC2/TEC2Image.html

#>

function Get-LatestEC2ImageByName {
	[CmdletBinding( PositionalBinding = $false )]
	[OutputType([Amazon.EC2.Model.Image])]
	param(

		# The pattern of the name of the AMI must match, uses PowerShell's -like operator
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[String]
		$Pattern,

		# Scopes the images by users with explicit launch permissions. Specify an AWS account ID, self (the sender of the request), or all (public AMIs).
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[String]
		$ExecutableUser = 'self'
	)

	Write-Verbose "Searching for AMI with name matching $Pattern executable by $ExecutableUser"

	$amis = Get-EC2Image -ExecutableUser $ExecutableUser |
		where { $_.Name -like "$Pattern*" } |
		sort -Property Name -Descending

	if ($amis -eq $null) {
		throw 'Found no AMIs matching pattern $Pattern'
	}
	else {
		Write-Verbose "Returning latest AMI found"
		return $amis[0]
	}
}
