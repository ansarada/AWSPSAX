#requires -Version 3 -Modules AWSPowerShell

$currentDirectory = Split-Path -Parent $PSCommandPath
$sourceFile = (Split-Path -Leaf $PSCommandPath).Replace(".Tests.", ".")
. "$currentDirectory\$sourceFile"


Describe "Edit-VolimeTagsOfInstance" {

    Context "Testing parameters validation" {

        $emptyArray = @('')
        $fakeArray = @('a')
        Write-Host "Context initialisation completed"
        
         It "Passing mandatory parameter null and empty should throw exception" {

            { Edit-VolimeTagsOfInstance -InstanceID $null -Tags $null } | Should Throw
            { Edit-VolimeTagsOfInstance -InstanceID $null -Tags $fakeArray } | Should Throw
            { Edit-VolimeTagsOfInstance -InstanceID '' -Tags $fakeArray } | Should Throw
            { Edit-VolimeTagsOfInstance -InstanceID 'abcd' -Tags $emptyArray } | Should Throw
            
        }

    }

    Context "Testing different situations when both parameters are passed" {

        $fakeInstanceID = 'abcd'
        $fakeTags = @('a')
        Write-Host "Context initialisation completed"

        It "When Get-EC2InstanceAttribute throws exception this method should throw exception" {

            Mock -CommandName Get-EC2InstanceAttribute -MockWith {throw}

            { Edit-VolimeTagsOfInstance -InstanceID $fakeInstanceID -Tags $fakeTags } | Should Throw
            
        }

         It "When Get-EC2InstanceAttribute returns null this method should throw exception" {

            Mock -CommandName Get-EC2InstanceAttribute -MockWith {$null}

            { Edit-VolimeTagsOfInstance -InstanceID $fakeInstanceID -Tags $fakeTags } | Should Throw
            
        }

        It "When Get-EC2InstanceAttribute returns an empty image object this method should not throw exception" {

            $fakeInstanceAttribute = New-Object -TypeName Amazon.EC2.Model.InstanceAttribute

            Mock -CommandName Get-EC2InstanceAttribute -MockWith {$fakeInstanceAttribute}
            Mock -CommandName New-EC2Tag -MockWith {$null}
            
            $new_EC2Tag_Call_Counter = 0

            { Edit-VolimeTagsOfInstance -InstanceID $fakeInstanceID -tags $fakeTags} | Should not Throw

            Assert-MockCalled -CommandName New-EC2Tag -time $new_EC2Tag_Call_Counter -Scope It -Exactly  
        }

        It "When Get-EC2InstanceAttribute returns a propoerly mocked ec2 object which contains 1 ebs volume. this method should call AWS tag methods 1 time only" {

            $fakeInstanceAttribute = New-Object -TypeName Amazon.EC2.Model.InstanceAttribute

            $fakeVolume = New-Object Amazon.EC2.Model.EbsInstanceBlockDevice
            $fakeVolume.VolumeId = "test123"

            $fakeBlockDeviceMapping = New-Object -TypeName Amazon.EC2.Model.InstanceBlockDeviceMapping
            $fakeBlockDeviceMapping.Ebs = $fakeVolume

            $fakeInstanceAttribute.BlockDeviceMappings = $fakeBlockDeviceMapping

            Mock -CommandName Get-EC2InstanceAttribute -MockWith {$fakeInstanceAttribute}
            Mock -CommandName New-EC2Tag -MockWith {$null}
            
            $new_EC2Tag_Call_Counter = 1

            { Edit-VolimeTagsOfInstance -InstanceID $fakeInstanceID -tags $fakeTags} | Should not Throw

            Assert-MockCalled -CommandName New-EC2Tag -time $new_EC2Tag_Call_Counter -Scope It -Exactly

        }

        It "When Get-EC2InstanceAttribute returns a propoerly mocked ec2 object which contains 2 ebs volumes. this method should call AWS tag methods 2 time only" {

            $fakeInstanceAttribute = New-Object -TypeName Amazon.EC2.Model.InstanceAttribute

            $fakeVolume1 = New-Object Amazon.EC2.Model.EbsInstanceBlockDevice
            $fakeVolume1.VolumeId = "test123"
            $fakeVolume2 = New-Object Amazon.EC2.Model.EbsInstanceBlockDevice
            $fakeVolume2.VolumeId = "test456"

            $fakeBlockDeviceMapping1 = New-Object -TypeName Amazon.EC2.Model.InstanceBlockDeviceMapping
            $fakeBlockDeviceMapping1.Ebs = $fakeVolume1
            $fakeBlockDeviceMapping2 = New-Object -TypeName Amazon.EC2.Model.InstanceBlockDeviceMapping
            $fakeBlockDeviceMapping2.Ebs = $fakeVolume2

            $fakeInstanceAttribute.BlockDeviceMappings = @($fakeBlockDeviceMapping1, $fakeBlockDeviceMapping2)

            Mock -CommandName Get-EC2InstanceAttribute -MockWith {$fakeInstanceAttribute}
            Mock -CommandName New-EC2Tag -MockWith {$null}
            
            $new_EC2Tag_Call_Counter = 2

            { Edit-VolimeTagsOfInstance -InstanceID $fakeInstanceID -tags $fakeTags} | Should not Throw

            Assert-MockCalled -CommandName New-EC2Tag -time $new_EC2Tag_Call_Counter -Scope It -Exactly

        }

    }

    context "If passed array is not of type [ Amazon.EC2.Model.Tag] then the method returns error" {

        $fakeInstanceID = 'abcd'
        $fakeTags = @('a')
        Write-Host "Context initialisation completed"
        
        It "If passed array is not of type [ Amazon.EC2.Model.Tag] then the method returns error" {
        
            $fakeInstanceAttribute = New-Object -TypeName Amazon.EC2.Model.InstanceAttribute

            $fakeVolume = New-Object Amazon.EC2.Model.EbsInstanceBlockDevice
            $fakeVolume.VolumeId = "vol-test1111"

            $fakeBlockDeviceMapping = New-Object -TypeName Amazon.EC2.Model.InstanceBlockDeviceMapping
            $fakeBlockDeviceMapping.Ebs = $fakeVolume

            $fakeInstanceAttribute.BlockDeviceMappings = $fakeBlockDeviceMapping

            Mock -CommandName Get-EC2InstanceAttribute -MockWith {$fakeInstanceAttribute}

            { Edit-VolimeTagsOfInstance -InstanceID $fakeInstanceID -tags $fakeTags} | Should Throw

        }    

    }

    Context "Testing different situations when both parameters are not passed"{

        It "When invoke-restmethod throws exception this method should throw exception" {

             Mock -CommandName invoke-restmethod -MockWith {throw}

            { Edit-VolimeTagsOfInstance } | Should Throw
            

        }

        It "When invoke-restmethod returns null this method should throw exception" {

             Mock -CommandName invoke-restmethod -MockWith {$null}

            { Edit-VolimeTagsOfInstance } | Should Throw 

        }

        It "When Get-EC2Tag throws exception this method should throw exception" {

             Mock -CommandName invoke-restmethod -MockWith {"i-12345"}
             Mock -CommandName Get-EC2Tag -MockWith {throws}

            { Edit-VolimeTagsOfInstance } | Should Throw 

        }

        It "When Get-EC2Tag returns null this method should not throw exception and gracefully returns" {

             Mock -CommandName invoke-restmethod -MockWith {"i-12345"}
             Mock -CommandName Get-EC2Tag -MockWith {$null}
             Mock -CommandName Get-EC2InstanceAttribute -MockWith {$null}

             $get_EC2InstanceAttribute_Call_Counter = 0

            { Edit-VolimeTagsOfInstance } | Should not Throw 

             Assert-MockCalled -CommandName Get-EC2InstanceAttribute -time $get_EC2InstanceAttribute_Call_Counter -Scope It -Exactly

             # this test case also tests that if any case, $actualTags contains no tags then this happens

        }

        It "When Get-EC2Tag returns tags that only contains keys starting with 'aws' this method should not throw exception and gracefully returns" {

            $testTags = @(
                @{
                    Key   = 'awsName'
                    Value = "test"
                },
                @{
                    Key   = 'awsApplication'
                    Value = 'DataRoom'
                }
            )

            Mock -CommandName invoke-restmethod -MockWith {"i-12345"}
            Mock -CommandName Get-EC2Tag -MockWith {$testTags}
            Mock -CommandName Get-EC2InstanceAttribute -MockWith {$null}

            $get_EC2InstanceAttribute_Call_Counter = 0

            { Edit-VolimeTagsOfInstance } | Should not Throw 

            Assert-MockCalled -CommandName Get-EC2InstanceAttribute -time $get_EC2InstanceAttribute_Call_Counter -Scope It -Exactly


        }

        It "When Get-EC2InstanceAttribute returns a propoerly mocked ec2 object which contains 1 ebs volume. this method should call AWS tag methods 1 time only" {

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


            $fakeInstanceAttribute = New-Object -TypeName Amazon.EC2.Model.InstanceAttribute

            $fakeVolume = New-Object Amazon.EC2.Model.EbsInstanceBlockDevice
            $fakeVolume.VolumeId = "test123"

            $fakeBlockDeviceMapping = New-Object -TypeName Amazon.EC2.Model.InstanceBlockDeviceMapping
            $fakeBlockDeviceMapping.Ebs = $fakeVolume

            $fakeInstanceAttribute.BlockDeviceMappings = $fakeBlockDeviceMapping

            Mock -CommandName invoke-restmethod -MockWith {"i-12345"}
            Mock -CommandName Get-EC2Tag -MockWith {$testTags}
            Mock -CommandName Get-EC2InstanceAttribute -MockWith {$fakeInstanceAttribute}
            Mock -CommandName New-EC2Tag -MockWith {$null}
            
            $new_EC2Tag_Call_Counter = 1

            { Edit-VolimeTagsOfInstance} | Should not Throw

            Assert-MockCalled -CommandName New-EC2Tag -time $new_EC2Tag_Call_Counter -Scope It -Exactly

        }
       
        It "When Get-EC2InstanceAttribute returns a propoerly mocked ec2 object which contains 2 ebs volume. this method should call AWS tag methods 2 time only" {

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


            $fakeInstanceAttribute = New-Object -TypeName Amazon.EC2.Model.InstanceAttribute

            $fakeVolume1 = New-Object Amazon.EC2.Model.EbsInstanceBlockDevice
            $fakeVolume1.VolumeId = "test123"
            $fakeVolume2 = New-Object Amazon.EC2.Model.EbsInstanceBlockDevice
            $fakeVolume2.VolumeId = "test456"

            $fakeBlockDeviceMapping1 = New-Object -TypeName Amazon.EC2.Model.InstanceBlockDeviceMapping
            $fakeBlockDeviceMapping1.Ebs = $fakeVolume1
            $fakeBlockDeviceMapping2 = New-Object -TypeName Amazon.EC2.Model.InstanceBlockDeviceMapping
            $fakeBlockDeviceMapping2.Ebs = $fakeVolume2

            $fakeInstanceAttribute.BlockDeviceMappings = @($fakeBlockDeviceMapping1, $fakeBlockDeviceMapping2)

            Mock -CommandName invoke-restmethod -MockWith {"i-12345"}
            Mock -CommandName Get-EC2Tag -MockWith {$testTags}
            Mock -CommandName Get-EC2InstanceAttribute -MockWith {$fakeInstanceAttribute}
            Mock -CommandName New-EC2Tag -MockWith {$null}
            
            $new_EC2Tag_Call_Counter = 2

            { Edit-VolimeTagsOfInstance} | Should not Throw

            Assert-MockCalled -CommandName New-EC2Tag -time $new_EC2Tag_Call_Counter -Scope It -Exactly

        }


    }
}