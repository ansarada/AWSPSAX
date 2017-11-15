#requires -Version 4 -Modules AWSPowerShell
<#
.SYNOPSIS
    Will create an Ingress rule for cross account access
    
.DESCRIPTION
    This function performs the following steps:
    - Find both Source and Destination Security Group Ids
    - Confirm rule parameters are vaid (protocol + Port)
    - Confirm peering exists between vpcs
    - Remove any Stale rules on dest security group
    - Confirm rule doesn't already exist
    - Add new Ingress rule on dest security group 
#>

function Get-SecurityGroupByFilter {
    param(
        [parameter(Mandatory = $true)]
        [String]
        $SecurityGroupName,

        [parameter(Mandatory = $true)]
        [String]
        $CICDEnvironment,

        [parameter(Mandatory = $true)]
        [String]
        $AwsProfile
    )
    Write-Verbose "Getting security group $($SecurityGroupName) from environment $($CICDEnvironment)"
    try {
        $SecurityGroupParameters = @{
            Filter = @(
                @{
                    name = 'tag:Name';
                    values = $SecurityGroupName
                };
                @{
                    name = 'tag:Environment';
                    values = $CICDEnvironment
                }
            );
            ProfileName = $AwsProfile
        }
        $SecurityGroup = Get-EC2SecurityGroup @SecurityGroupParameters
        $SecurityGroupMeasure = $SecurityGroup | measure
        if ($SecurityGroupMeasure.count -ne 1) {
            throw "$($SecurityGroupMeasure.count) Security Groups found"
        }
        Write-Verbose "Found security group $($SecurityGroup.GroupId)"
        return $SecurityGroup
    }
    catch {        
        throw "Failed to locate Security Group $SecurityGroupName in environment $CICDEnvironment using AwsProfile $AwsProfile"
    }
}

function Test-PeerConnection {
    param(
        [parameter(Mandatory = $true)]
        [String]
        $SourceVPC,

        [parameter(Mandatory = $true)]
        [String]
        $DestinationVPC,

        [parameter(Mandatory = $true)]
        [String]
        $AwsProfile
    )
    Write-Verbose "Checking that Peering is Enabled between VPCs"

    try {
        $parametersSourceRequester = @{
            Filter = @(
                @{
                    name = 'requester-vpc-info.vpc-id';
                    values = $SourceVPC
                },@{
                    name = 'accepter-vpc-info.vpc-id';
                    values = $DestinationVPC
                },@{
                    name = 'status-code'
                    value = 'active'
                }
            );
            ProfileName = $AwsProfile
        }

        $parametersDestinationRequester = @{
            Filter = @(
                @{
                    name = 'requester-vpc-info.vpc-id';
                    values = $DestinationVPC
                },@{
                    name = 'accepter-vpc-info.vpc-id';
                    values = $SourceVPC
                },@{
                    name = 'status-code'
                    value = 'active'
                }
            );
            ProfileName = $AwsProfile
        }
        
        $peeringConnectionSourceRequester = Get-EC2VpcPeeringConnections @parametersSourceRequester
        $peeringConnectionDestinationRequester = Get-EC2VpcPeeringConnections @parametersDestinationRequester

        If ($peeringConnectionSourceRequester){
            Write-Verbose "Peering Connection is $($peeringConnectionSourceRequester.VpcPeeringConnectionId)"
        } elseif ($peeringConnectionDestinationRequester) {
            Write-Verbose "Peering Connection is $($peeringConnectionDestinationRequester.VpcPeeringConnectionId)"
        } else {
            throw "No corresponding peering connection between $SourceVPC and $DestinationVPC could be found"
        }
    }
    catch {
        throw "Failed to find peering connection between $SourceVPC and $DestinationVPC"
    }
}

function Test-RuleAlreadyExists {
    param(
        [parameter(Mandatory = $true)]
        [Amazon.EC2.Model.SecurityGroup]
        $SourceSecurityGroup,

        [parameter(Mandatory = $true)]
        [Amazon.EC2.Model.SecurityGroup]
        $DestinationSecurityGroup,

        [parameter(Mandatory = $true)]
        [String]
        $IpProtocol,

        [parameter(Mandatory = $true)]
        [String]
        $Port
    )
    Write-Verbose "Confirm if rule already exists"
    try {
        foreach ($IpPermission in $DestinationSecurityGroup.IpPermissions) {
            if ($IpPermission.FromPort -eq $Port -and
                $IpPermission.ToPort -eq $Port -and
                $IpPermission.IpProtocol -eq $IpProtocol) {
                foreach ($UserIdGroupPair in $IpPermission.UserIdGroupPairs) {
                    if ($UserIdGroupPair.GroupId -eq $SourceSecurityGroup.GroupId -and
                        $UserIdGroupPair.UserId -eq $SourceSecurityGroup.OwnerId) {
                        Write-Verbose "Cross Account Security Group Access Rule already exists. Exiting script"
                        return $true
                    }
                }
            }
        }
        Write-Verbose "Cross Account Security Group Access Rule needs to be created"
        return $false
    }
    catch {
        Throw "Failed to determine if Cross Account Security Group Access Rule already exists"
    }
}

function Revoke-StaleRulesOnDestinationSecurityGroup {
    param(
        [parameter(Mandatory = $true)]
        [Amazon.EC2.Model.SecurityGroup]
        $DestinationSecurityGroup,

        [parameter(Mandatory = $true)]
        [String]
        $AwsProfile
    )
    Write-Verbose "Checking for Stale secruity group Ingress rules"
    try {
        $VpcStaleRules = Get-EC2StaleSecurityGroup -VpcId $DestinationSecurityGroup.VpcId -ProfileName $AwsProfile
        foreach ($StaleRule in $VpcStaleRules) {
            if ($StaleRule.GroupId -eq $DestinationSecurityGroup.GroupId) {
                foreach ($StaleRuleIpPermission in $StaleRule.StaleIpPermissions) {
                    #Amazon.EC2.Model.IpPermission and Amazon.EC2.Model.StaleIpPermission cannot Cast to each other
                    $StaleIpPermission = New-Object Amazon.EC2.Model.IpPermission
                    $StaleIpPermission.FromPort = $StaleRuleIpPermission.FromPort
                    $StaleIpPermission.IpProtocol = $StaleRuleIpPermission.IpProtocol
                    $StaleIpPermission.ToPort = $StaleRuleIpPermission.ToPort
                    $StaleIpPermission.UserIdGroupPairs = $StaleRuleIpPermission.UserIdGroupPairs
                    Revoke-EC2SecurityGroupIngress -GroupId $DestinationSecurityGroup.GroupId -IpPermission $StaleIpPermission -ProfileName $AwsProfile
                }
                Write-Verbose "Stale security group Ingress rules removed from $($DestinationSecurityGroup.GroupId)"
            }
        }
    }
    catch {
        Throw "Failed to confirm or revoke Stale security group rules"
    }
}

function Add-IngressRule {
    param(
        [parameter(Mandatory = $true)]
        [Amazon.EC2.Model.SecurityGroup]
        $SourceSecurityGroup,

        [parameter(Mandatory = $true)]
        [Amazon.EC2.Model.SecurityGroup]
        $DestinationSecurityGroup,

        [parameter(Mandatory = $true)]
        [String]
        $IpProtocol,

        [parameter(Mandatory = $true)]
        [String]
        $Port,

        [parameter(Mandatory = $true)]
        [String]
        $AwsProfile
    )
    Write-Verbose "Creating cross account Ingress rule"
    try {
        $UserGroup = New-Object Amazon.EC2.Model.UserIdGroupPair
        $UserGroup.GroupId = $SourceSecurityGroup.GroupId
        $UserGroup.UserId = $SourceSecurityGroup.OwnerId
        $IngressParameters = @{
            GroupId = $DestinationSecurityGroup.GroupId;
            IpPermission = @(
                @{
                    IpProtocol = $IpProtocol;
                    FromPort = $Port;
                    ToPort = $Port;
                    UserIdGroupPairs = $UserGroup
                }
            );
            ProfileName = $AwsProfile
        }
        Grant-EC2SecurityGroupIngress @IngressParameters
        Write-Verbose "Cross account Ingress rule has been added"
    }
    catch {
        throw "Failed to create cross account Ingress rule"
    }
}

function Grant-CrossAccountSecurityGroupAccess {
    param(
        [CmdletBinding(PositionalBinding = $false)]
        [parameter(Mandatory = $true)]
        [String]
        $SourceProfile,

        [parameter(Mandatory = $true)]
        [String]
        $DestinationProfile,

        [parameter(Mandatory = $true)]
        [String]
        $SourceSecurityGroupName,

        [parameter(Mandatory = $true)]
        [String]
        $DestinationSecurityGroupName,

        [parameter(Mandatory = $true)]
        [String]
        $SourceCICDEnvironment,

        [parameter(Mandatory = $true)]
        [String]
        $DestinationCICDEnvironment,

        [parameter(Mandatory = $true)]
        [ValidateSet('tcp','udp','icmp',IgnoreCase = $true)] 
        [String]
        $IpProtocol,

        [parameter(Mandatory = $true)]
        [ValidateRange(-1,65535)] 
        [Int]
        $Port
    )

    try {
        $SourceSecurityGroupParameters = @{
            SecurityGroupName = $SourceSecurityGroupName;
            CICDEnvironment = $SourceCICDEnvironment;
            AwsProfile = $SourceProfile
        }
        $SourceSecurityGroup = Get-SecurityGroupByFilter @SourceSecurityGroupParameters

        $DestinationSecurityGroupParameters = @{
            SecurityGroupName = $DestinationSecurityGroupName;
            CICDEnvironment = $DestinationCICDEnvironment;
            AwsProfile = $DestinationProfile
        }
        $DestinationSecurityGroup = Get-SecurityGroupByFilter @DestinationSecurityGroupParameters

        $SourceVPC = $SourceSecurityGroup.VpcId
        $DestinationVPC = $DestinationSecurityGroup.VpcId

        $peerParameters = @{
            SourceVPC = $SourceVPC;
            DestinationVPC = $DestinationVPC;
            AwsProfile = $DestinationProfile
        }
        Test-PeerConnection @peerParameters

        $RevokeArguements = @{
            DestinationSecurityGroup = $DestinationSecurityGroup;
            AwsProfile = $DestinationProfile
        }
        Revoke-StaleRulesOnDestinationSecurityGroup @RevokeArguements

        $IngressArguments = @{
            SourceSecurityGroup = $SourceSecurityGroup;
            DestinationSecurityGroup = $DestinationSecurityGroup;
            IpProtocol = $IpProtocol;
            Port = $Port
        }
        if (!(Test-RuleAlreadyExists @IngressArguments)) {
            $IngressArguments.Add("AwsProfile", $DestinationProfile)
            Add-IngressRule @IngressArguments
        }
    }
    catch {
        Write-Verbose "Error: $($PSItem.Exception.Message)"
        throw $PSItem.Exception.Message
    }
}
