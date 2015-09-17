function New-CustomEC2Image {

	[cmdletbinding()]

	param(
	    [parameter(Mandatory=$true)]
	    [string]
	    $BranchId,

	    [parameter(Mandatory=$true)]
	    [string]
	    $BuildId,

	    [parameter(Mandatory=$true)]
	    [string]
	    $Type,

	    [parameter(Mandatory=$true)]
	    [string]
	    $CFNTemplateRoot,

	    [parameter(Mandatory=$true)]
	    [string]
	    $ArtifactsRoot,

	    [parameter()]
	    [string]
	    $AmiId = "ami-bdb1dc87",

	    [parameter()]
	    [string]
	    $InstanceType = "c3.large",

	    [parameter()]
	    [string]
	    $KeyName = "builds"
	)

	try {

	    $StackName = "image-$($Type)-$($BranchId)-$($BuildId)"
	    $CFNTemplateFilename = Join-Path $CFNTemplateRoot "image-$($Type).template"

	    Write-Host "Checking to see if stack $($StackName) exists"
	    if (Test-CFNStack -StackName $StackName) {
	        Write-Host "Deleting stack $($StackName)"
	        Remove-CFNStack -StackName $StackName -Force
	    }

	    $Parameters = @{
	        StackName = $StackName;
	        TemplateBody = $($(Get-Content $CFNTemplateFilename) -join "`n");
	        Parameters = @(
	            @{ ParameterKey = "BranchId"; ParameterValue = $BranchId },
	            @{ ParameterKey = "BuildId"; ParameterValue = $BuildId },
	            @{ ParameterKey = "AmiId"; ParameterValue = $AmiId },
	            @{ ParameterKey = "InstanceType"; ParameterValue = $InstanceType },
	            @{ ParameterKey = "KeyName"; ParameterValue = $KeyName }
	        );
	        Capabilities = "CAPABILITY_IAM";
	        DisableRollback = $true
	    }
	    Write-Host "Creating stack $($StackName)"
	    New-CFNStack @Parameters

	    Start-Sleep -Seconds 30

	    Write-Host "Waiting for stack $($StackName) to finish building"
	    Wait-CFNStackComplete -StackName $StackName -TimeoutInMinutes 120

	    $Stack = Get-CFNStack -StackName $StackName
	    $InstanceId = $($Stack.Outputs | Where-Object { $_.OutputKey -eq "InstanceId" }).OutputValue

	    $Parameters = @{
	        InstanceId = $InstanceId;
	        Name = "$($Type)-$($BranchId)-$($BuildId)";
	        Description = "$($Type)-$($BranchId)-$($BuildId)"
	    }
	    Write-Host "Creating AMI based on instance $($InstanceId)"
	    $AmiId = New-EC2Image @Parameters

	    $Parameters = @{
	    	Resources = @($AmiId);
	    	Tags = @(
	    		@{ Key = "Application"; Value = "DataRoom" },
	    		@{ Key = "Branch"; Value = $BranchId },
	    		@{ Key = "Build"; Value = $BuildId },
	    		@{ Key = "Type"; Value = $Type }
	    	)
	    }
	    Write-Host "Adding tags to AMI"
	    New-EC2Tag @Parameters

	    $AmiIdFilename = Join-Path $ArtifactsRoot "$($Type).amiid"

	    Write-Host "Writing AmiId $($AmiId) to $($AmiIdFilename)"
	    $AmiId | Out-File $AmiIdFilename

	    $WaitPeriod = 60
	    Write-Host "Waiting $($WaitPeriod) seconds before starting to get state of image"
	    Start-Sleep -Seconds $WaitPeriod

	    $AmiState = $(Get-EC2Image -ImageIds $AmiId).State.Value
	    Write-Host "Ami $($AmiId) has a state of $($AmiState)"
	    while ($AmiState -ne [Amazon.EC2.ImageState]::Available.Value) {
	        Start-Sleep -Seconds 10
	        $AmiState = $(Get-EC2Image -ImageIds $AmiId).State.Value
	        Write-Host "Ami $($AmiId) has a state of $($AmiState)"
	    }
	    Write-Host "Ami $($AmiId) has a state of $($AmiState)"

	    Write-Host "Deleting stack $($StackName)"
	    Remove-CFNStack -StackName $StackName -Force

	    Write-Host "Finished building $($Type) image"
	    exit 0
	}
	catch {
	    throw $_
	    exit 1
	}
}

Export-ModuleMember New-CustomEC2Image
