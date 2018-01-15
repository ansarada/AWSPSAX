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
		$ExecutableUser = 'self',

		# Name of AWS profile to use
		[parameter()]
		[string]
		$AWSProfileName,

		# Search for AWS owned images
		[parameter()]
		[string]
		$Owner
	)

	if ($AWSProfileName) {
		Write-Verbose "Setting AWS profile to $AWSProfileName"
		Set-AWSCredentials -ProfileName $AWSProfileName
	}

	$params = @{
		filter = @{
			Name = "name"
			Value = "$($Pattern)*"
		}
	}

	if ($Owner){
		Write-Verbose "Searching for AMI with name matching $Pattern owned by $Owner"
		$params.Owner = $Owner
		$sortObject = 'creationdate'
	}
	else{
		Write-Verbose "Searching for AMI with name matching $Pattern executable by $ExecutableUser"
		$params.ExecutableUser = $ExecutableUser
		$sortObject = 'Name'
	}
	$amis = Get-EC2Image @params | sort-object -Property $sortObject -Descending

	if ($amis -eq $null) {
		throw 'Found no AMIs matching pattern $Pattern'
	}
	else {
		Write-Verbose "Returning latest AMI found"
		return $amis[0]
	}
}
