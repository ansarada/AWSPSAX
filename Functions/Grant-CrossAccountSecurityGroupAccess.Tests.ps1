#requires -Version 3 -Modules AWSPowerShell

$currentDirectory = Split-Path -Parent $PSCommandPath
$sourceFile = (Split-Path -Leaf $PSCommandPath).Replace(".Tests.", ".")
. "$currentDirectory\$sourceFile"

Describe 'Grant-CrossAccountSecurityGroupAccess' {

    Context "Invalid Security Group Requests" {
        It 'Invalid AWS Profile should throw an exception' {
            $paramsSecurityGroup = @{
                securityGroupName = 'FalseSecurityGroupName';
                environment = 'FalseEnvironment';
                awsProfile = 'FalseProfile'
            }
            Mock Get-EC2SecurityGroup { throw 'No credentials specified or obtained from persisted/shell defaults.'}
            { Get-SecurityGroupByFilter @paramsSecurityGroup } | Should Throw
        }

        It 'Non-existent Security Group should throw exception' {
            $paramsSecurityGroup = @{
                securityGroupName = 'FalseSecurityGroupName';
                environment = 'FalseEnvironment';
                awsProfile = 'FalseProfile'
            }
            Mock Get-EC2SecurityGroup { return $null }
            { Get-SecurityGroupByFilter @paramsSecurityGroup } | Should Throw
        }
    }

    Context "Invalid Rule Parameters" {
        It 'Invalid Protocol should throw exception' {
            { Test-ValidProtocol -protocol 'falseProtocol' } | Should Throw
        }

        It 'Invalid TCP Port should throw exception' {
            { Test-ValidTcpUdpPorts -port 0 } | Should Throw
        }
    }

    Context "Peering Issues" {
        It 'Peering does not Exist throws exception' {
            $paramsPeering = @{
                sourceVPC = 'FalseVPC';
                destinationVPC = 'FalseVPC';
                awsProfile = 'FalseProfile'
            }
            Mock Get-EC2VpcPeeringConnections {return $null}
            { Test-PeerConnection @paramsPeering } | Should Throw
        }
    }

    Context "Success states" {
        It 'Rule already exists completes cleanly' {
            $sourceSecurityGroup = New-Object Amazon.EC2.Model.SecurityGroup
            $sourceSecurityGroup.GroupId = 'FalseGroupId'
            $sourceSecurityGroup.OwnerId = 'FalseUserId'

            $destinationUserGroup = New-Object Amazon.EC2.Model.UserIdGroupPair
            $destinationUserGroup.GroupId = 'FalseGroupId'
            $destinationUserGroup.UserId = 'FalseUserId'
            $destinationIpPermission = New-Object Amazon.EC2.Model.IpPermission
            $destinationIpPermission.FromPort = '1234'
            $destinationIpPermission.ToPort = '1234'
            $destinationIpPermission.IpProtocol = 'FalseProtocol'
            $destinationIpPermission.UserIdGroupPairs.Add($destinationUserGroup)
            $destinationSecurityGroup = New-Object Amazon.EC2.Model.SecurityGroup
            $destinationSecurityGroup.IpPermissions.Add($destinationIpPermission)

            $paramsExist = @{
                sourceSecurityGroup = $sourceSecurityGroup;
                destinationSecurityGroup = $destinationSecurityGroup;
                ipProtocol = 'FalseProtocol';
                Port = '1234'
            }
            Test-RuleAlreadyExists @paramsExist | Should Be $true
        }

        It 'Stale rule exists completes cleanly' {
            $destinationSecurityGroup = New-Object Amazon.EC2.Model.SecurityGroup
            $destinationSecurityGroup.VpcId = 'FalseVPC'
            $destinationSecurityGroup.GroupId = 'FalseGroup'
            $paramsStale = @{
                destinationSecurityGroup = $destinationSecurityGroup;
                awsProfile = 'FalseProfile'
            }
            Mock Get-EC2StaleSecurityGroup {
                $staleSecurityGroup = New-Object Amazon.EC2.Model.StaleSecurityGroup
                $staleSecurityGroup.GroupId = $destinationSecurityGroup.GroupId
                return $staleSecurityGroup
            }
            # to return Amazon.EC2.Model.StaleSecurityGroup
            Mock Revoke-EC2SecurityGroupIngress {}
            #Runs script
            #Expects 
            Revoke-StaleRulesOnDestinationSecurityGroup @paramsStale | Should BeNullOrEmpty
        }

        It 'Adds new ingress rule cleanly' {
            $sourceSecurityGroup = New-Object Amazon.EC2.Model.SecurityGroup
            $sourceSecurityGroup.GroupId = 'FalseGroupId'
            $sourceSecurityGroup.OwnerId = 'FalseUserId'
            $destinationSecurityGroup = New-Object Amazon.EC2.Model.SecurityGroup
            $destinationSecurityGroup.GroupId = 'FalseGroupId'

            $paramsNew = @{
                sourceSecurityGroup = $sourceSecurityGroup;
                destinationSecurityGroup = $destinationSecurityGroup;
                ipProtocol = 'FalseProtocol';
                Port = '1234';
                awsProfile = 'FalseProfile'
            }
            Mock Grant-EC2SecurityGroupIngress {}

            Add-IngressRule @paramsNew | Should BeNullOrEmpty
        }
    }
}