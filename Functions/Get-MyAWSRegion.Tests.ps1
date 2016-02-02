#requires -Version 3 -Modules AWSPowerShell

$currentDirectory = Split-Path -Parent $PSCommandPath
$sourceFile = (Split-Path -Leaf $PSCommandPath).Replace(".Tests.", ".")
. "$currentDirectory\$sourceFile"

Describe "Get-MyAWSRegion" {

    It "An internal error should throw an exception" {

        Mock -CommandName Invoke-RestMethod -MockWith {throw}

        { Get-MyAWSRegion } | Should throw
	}

    It "With mock checking for null" {

        Mock -CommandName Invoke-RestMethod -MockWith {$null}

        {Get-MyAWSRegion} | Should throw
	}
	
	It "With mock checking return value" {

        $mockObject = New-Object PSCustomObject
        $mockObject | Add-Member -MemberType NoteProperty –Name "region" –Value "regionA"
        $actualOutput = "regionA"

        Mock -CommandName Invoke-RestMethod -MockWith {$mockObject}

        Get-MyAWSRegion | Should Be $actualOutput
	}
}