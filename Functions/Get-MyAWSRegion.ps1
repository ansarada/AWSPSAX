<#
    .Synopsis
    When run on an EC2 instance it will return the region that the instance is in
#>

function Get-MyAWSRegion {
	$availability_zone = Invoke-RestMethod 'http://169.254.169.254/latest/meta-data/placement/availability-zone'
    return $availability_zone.Substring(0, $availability_zone.Length - 1)
}
