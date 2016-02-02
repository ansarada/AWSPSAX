<#
.Synopsis
   When run on an EC2 instance it will return the region that the instance is in
.OUTPUTS
   Region name in string
.EXAMPLE
   Get-MyAWSRegion 
#>
function Get-MyAWSRegion 
{
    [OutputType([String])]
    
    $metadata = Invoke-RestMethod 'http://169.254.169.254/latest/dynamic/instance-identity/document'
    if (!$metadata)
    {
        throw "Metadata information could not be retrieved"
    }
    return $metadata.region
}

