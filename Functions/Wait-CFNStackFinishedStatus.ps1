. $PSScriptRoot\Get-CFNStackFinishedStatuses.ps1

<#
	.Synopsis
	Waits until a stack is in a finished state, i.e. not a in progress status

	.PARAMETER StackName
	The name of the stack to wait for

	.PARAMETER Timeout
	How long in seconds to wait for the stack to reach a finished state

	.PARAMETER AWSProfileName
		Name of AWS profile to use

	.PARAMETER CheckInterval
	How often to re-check the status of the stack
#>

function Wait-CFNStackFinishedStatus {

	[cmdletbinding()]

	param(
		[parameter(Mandatory=$true)]
		[String]
		$StackName,

		[parameter()]
		[int32]
		$Timeout = 1800,

		[parameter()]
		[int32]
		$CheckInterval = 15,

		[parameter()]
		[string]
		$AWSProfileName
	)

	if ($AWSProfileName) {
		Write-Verbose "Switching to AWS profile $AWSProfileName"
		Set-AWSCredentials -ProfileName $AWSProfileName
	}

	$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

	$Parameters = @{StackStatusFilter = Get-CFNStackFinishedStatuses}

	Write-Verbose "Waiting to see if stack $($StackName) is in a finished state"
	$Stack = Get-CFNStackSummary @Parameters | where { $_.StackName -eq $StackName }
	Write-Verbose "Stack $($StackName) has a status of $($Stack.StackStatus), waited $($Stopwatch.Elapsed.ToString("h\:mm\:ss")) seconds"

	While (($Stack -eq $null -or -not ($Stack.StackStatus)) -and $Stopwatch.Elapsed.TotalMinutes -lt $TimeoutInMinutes) {
		Start-Sleep -s $CheckIntervalSeconds
		$Stack = Get-CFNStackSummary @Parameters | where { $_.StackName -eq $StackName }
		Write-Verbose "Stack $($StackName) has a status of $($Stack.StackStatus), waited $($Stopwatch.Elapsed.ToString("h\:mm\:ss")) seconds"
	}

	if ($Stack) {
		return $Stack
	}
	else {
		throw "Stack $($StackName) still not in finished state after $($Stopwatch.Elapsed.TotalMinutes)"
	}
}
