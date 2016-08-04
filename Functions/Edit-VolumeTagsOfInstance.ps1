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
    Edit-VolumeTagsOfInstance -InstanceID "i-123445" -Tags $testTags

    or simply calling the method in an ec2,
    Edit-VolumeTagsOfInstance 
#>
function Edit-VolumeTagsOfInstance
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
        $Tags,
        
        # Pass in the log object if you wish write to a log file. See Start-Log and Write-Log functions
        $log
    )

    $actualInstanceID = [string]::Empty
    $actualTags = $null

    if ($InstanceID)
    {
        $actualInstanceID = $InstanceID
    }
    else
    {
        if ($log){
            Write-Log -Log $log -LogData @{
                message = "Getting instance ID could not be determined";
            }
        }
        $actualInstanceID = invoke-restmethod -uri http://169.254.169.254/latest/meta-data/instance-id
    }

    if ([string]::IsNullOrEmpty($actualInstanceID))
    {
        if ($log){
            Write-Log -Log $log -LogData @{
                message = "The actual instance ID could not be determined";
            }
        }
        throw "The actual instance ID could not be determined"
    }
    
    if ($log){
        Write-Log -Log $log -LogData @{
            message = "Updating volume tags of instnace $actualInstanceID";
        }
    }
    Write-host "Updating volume tags of instnace $actualInstanceID"

    if ($Tags)
    {
        $actualTags = $Tags
    }
    else
    {
        if ($log){
            Write-Log -Log $log -LogData @{
                message = "Getting current EC2 Tags";
            }
        }
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
        if ($log){
            Write-Log -Log $log -LogData @{
                message = "No tag was identified for update. Method returns now.";
            }
        }
        write-host "No tag was identified for update. Method returns now."
        return
    }

    # Get the volumes of the ec2
    $instanceAttributes = Get-EC2InstanceAttribute -InstanceId $actualInstanceID -Attribute "BlockDeviceMapping"

    if ($instanceAttributes -isnot [Amazon.EC2.Model.InstanceAttribute])
    {
        if ($log){
            Write-Log -Log $log -LogData @{
                message = "Get-EC2InstanceAttribute did not return Amazon.EC2.Model.InstanceAttribute object";
            }
        }
        throw "Get-EC2InstanceAttribute did not return Amazon.EC2.Model.InstanceAttribute object"
    }

    $ec2BlockDeviceMapping = $instanceAttributes.BlockDeviceMappings
    $ebsDevices = $ec2BlockDeviceMapping | where {$_.EBS}

    $ebsDevices | ForEach-Object -Process {
        
        $volumeId = $_.Ebs.VolumeId
        
        Write-host "Updating tags for volume $volumeId"
        if ($log){
            Write-Log -Log $log -LogData @{
                message = "Updating tags for volume $volumeId";
            }
        }
        New-EC2Tag -Resources $volumeId -Tags $actualTags 
    }# Add tags to volumes associated with the EC2 using Amazon.EC2.Model.EbsInstanceBlockDevice 

}