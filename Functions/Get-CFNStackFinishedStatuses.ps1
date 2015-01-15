<#
	.Synopsis
	Returns list of CloudFormation stack finishing statuses, i.e. not in progress
#>

function Get-CFNStackFinishedStatuses {
    return @(
        [Amazon.CloudFormation.StackStatus]::CREATE_COMPLETE,
        [Amazon.CloudFormation.StackStatus]::CREATE_FAILED,
        [Amazon.CloudFormation.StackStatus]::DELETE_COMPLETE,
        [Amazon.CloudFormation.StackStatus]::DELETE_FAILED,
        [Amazon.CloudFormation.StackStatus]::ROLLBACK_COMPLETE,
        [Amazon.CloudFormation.StackStatus]::ROLLBACK_FAILED,
        [Amazon.CloudFormation.StackStatus]::UPDATE_COMPLETE,
        [Amazon.CloudFormation.StackStatus]::UPDATE_ROLLBACK_COMPLETE,
        [Amazon.CloudFormation.StackStatus]::UPDATE_ROLLBACK_FAILED
    )
}
