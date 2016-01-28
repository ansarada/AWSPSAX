<#
.Synopsis
   Adds set of tags to volumes of an EC2
.DESCRIPTION
   This function first locates all attached volumes of an EC2. And then applies a set of tags to each. Any Tag key that starts
   with aws is ignored.
.EXAMPLE
   When both parameters are passed,
   $testTags = @(
                @{
                    Key   = 'Name'
                    Value = "test"
                },
                @{
                    Key   = 'Application'
                    Value = 'DataRoom'
                }
            )
    Edit-VolimeTagsOfInstance -InstanceID "i-123445" -Tags $testTags

    or simply calling the method in an ec2,
    Edit-VolimeTagsOfInstance 
#>
function Edit-VolimeTagsOfInstance
{
    [CmdletBinding( PositionalBinding = $false )]
    Param
    (
        # If an instance ID is passed then tags are applied to that particular instances' volumes. Otherwise, this method expects
        # the executing environment is an EC2. Then this method applies tags to this instance's volumes. 
        [ValidateNotNullOrEmpty()]
        [String]
        $InstanceID,

        # A array containing key and value of each tag. If this parameter is passed then the method applies these tags.
        # If this parameter is not passed then this method expects that the executing environment is an EC2 and tags
        # associated with this current ec2 will be applied.
        [ValidateNotNullOrEmpty()]
        [Array]
        $Tags
    )

    $actualInstanceID = [string]::Empty
    $actualTags = $null

    if ($InstanceID)
    {
        $actualInstanceID = $InstanceID
    }
    else
    {
        $actualInstanceID = invoke-restmethod -uri http://169.254.169.254/latest/meta-data/instance-id
    }

    if ([string]::IsNullOrEmpty($actualInstanceID))
    {
        throw "The actual instance ID could not be determined"
    }

    Write-host "Updating volume tags of instnace $actualInstanceID"

    if ($Tags)
    {
        $actualTags = $Tags
    }
    else
    {
        $currentEC2Tags = Get-EC2Tag -Filter @{ Name="resource-id";Values=$actualInstanceID} 
        $listedTags = $currentEC2Tags | Where {$_.key -notlike "aws*"} 
	
	    $actualTags = @()

	    $listedTags | where {$_} | foreach {
	        $tag = @{
        	    Key   = $_.key
        	    Value = $_.Value
    	    }

	    $actualTags += $tag

	    }
    }

    if ($actualTags.Count -le 0)
    {
        write-host "No tag was identified for update. Method returns now."
        return
    }

    # Get the volumes of the ec2
    $instanceAttributes = Get-EC2InstanceAttribute -InstanceId $actualInstanceID -Attribute "BlockDeviceMapping"

    if ($instanceAttributes -isnot [Amazon.EC2.Model.InstanceAttribute])
    {
        throw "Get-EC2InstanceAttribute did not return Amazon.EC2.Model.InstanceAttribute object"
    }

    $ec2BlockDeviceMapping = $instanceAttributes.BlockDeviceMappings
    $ebsDevices = $ec2BlockDeviceMapping | where {$_.EBS}

    $ebsDevices | ForEach-Object -Process {
        
        $volumeId = $_.Ebs.VolumeId
        
        Write-host "Updating tags for volume $volumeId"

        New-EC2Tag -Resources $volumeId -Tags $actualTags 
    }# Add tags to volumes associated with the EC2 using Amazon.EC2.Model.EbsInstanceBlockDevice 

}