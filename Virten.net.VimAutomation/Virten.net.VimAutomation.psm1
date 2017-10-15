Function Get-VMHostVersion {
<#
.SYNOPSIS
	Get detailed ESXi version information.
.DESCRIPTION
	This function provides detailed ESXi Version information.
	It uses an inofficial JSON based ESXi release database provided by www.virten.net

	The function returns:
	- ESXi Build Number
	- Version (Unambiguous friendly name used in Release Notes and https://kb.vmware.com/kb/2143832)
	- Release Date (When the installed verison has been published)
	- Minor Release (eg. 5.0, 5.1, 6.0 - https://www.vmware.com/support/policies/upgrade.html)
	- Update Release (eg. 6.0, 6.0 U1, 6.0 U2 - https://www.vmware.com/support/policies/upgrade.html)
	
.PARAMETER VMHost
	Name of the ESXi Host (returned by Get-VMHost cmdlet)
.EXAMPLE
	Get-VMHostVersion
.EXAMPLE
	Get-VMHostVersion -VMHost esx4.virten.lab
.EXAMPLE
	Get-Cluster Cluster | Get-VMHost | Get-VMHostVersion
.NOTES
	Author:   Florian Grehl
	Twitter:  @virten
	Website:  www.virten.net
	
	Changelog:
	2017-09-04 - v1.0 - Initial Release

.LINK
	http://www.virten.net/2017/09/get-vmhostversion-and-get-vmhostlatestversion-powershell-function/
#>
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$false,ValueFromPipeline=$true)]$VMHosts
	)
	
	Begin
	{
		$ErrorActionPreference = 'Stop'
		$WarningPreference = 'SilentlyContinue'
		$esxiReleases = Invoke-WebRequest -Uri http://www.virten.net/repo/esxiReleasesV2.json | ConvertFrom-Json
	}

	Process
	{
		if (-not $VMHosts) {
			$vmHosts = Get-VMHost
		} else {
			$vmHosts = Get-VMHost -Name $VMHosts
		}
	
		Foreach ($vmHost in $vmHosts) {   
			if ($VMHost.Build){
				$release = $esxiReleases.data.esxiReleases.($vmHost.Build)
				if ($release){
					[pscustomobject] @{
						VMHost = $VMHost.Name
						Build = $VMHost.Build
						Version = $release.friendlyName
						ReleaseDate =  $release.releaseDate
						MinorRelease = "ESXi $($release.minorRelease)"
						UpdateRelease = $release.updateRelease
					}
				} else {
					Write-Verbose "ESXi Host $($VMHost.Name): Build number ($($vmHost.Build)) not found in database."
					[pscustomobject] @{
						VMHost = $VMHost.Name
						Build = $VMHost.Build
						Version = 'Unknown'
						ReleaseDate =  'Unknown'
						MinorRelease = 'Unknown'
						UpdateRelease = 'Unknown'
					}
				}
			} 
		}
	}
}


Function Get-VMHostLatestVersion {
<#
.SYNOPSIS
	Check if an ESXi update is available.
.DESCRIPTION
	This function checks if an ESXi update is available and displays information about the latest 
	version in the current Minor Release. (Minor releases are for example 5.5, 6.0 or 6.5)
	It uses an inofficial JSON based ESXi release database provided by www.virten.net
	The function returns:
	- Current ESXi Build Number
	- Current ESXi Version (Unambiguous friendly name used in Release Notes and https://kb.vmware.com/kb/2143832)
	- Current Version Release Date (When the installed verison has been published)
	- Update Available (True or False)
	- Latest available ESXi build number for that Minor Release
	- Latest available ESXi version 
	- Latest available ESXi release date
	
.PARAMETER VMHost
	Name of the ESXi Host (returned by Get-VMHost cmdlet)
.EXAMPLE
	Get-VMHostLatestVersion
.EXAMPLE
	Get-VMHostLatestVersion -VMHost esx4.virten.lab
.EXAMPLE
	Get-VMHostLatestVersion -Verbose |ft -AutoSize
.NOTES
	Author:   Florian Grehl
	Twitter:  @virten
	Website:  www.virten.net
	
	Changelog:
	2017-09-24 - v1.0 - Initial Release
.LINK
	http://www.virten.net/2017/09/get-vmhostversion-and-get-vmhostlatestversion-powershell-function/
#>
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$false,ValueFromPipeline=$true)]$VMHosts
	)
	
	Begin
	{
		$ErrorActionPreference = 'Stop'
		$WarningPreference = 'SilentlyContinue'
		$esxiReleases = Invoke-WebRequest -Uri http://www.virten.net/repo/esxiReleases.json | ConvertFrom-Json
	}

	Process
	{
		if (-not $VMHosts) {
			$vmHosts = Get-VMHost
		} else {
			$vmHosts = Get-VMHost -Name $VMHosts
		}
	
		Foreach ($vmHost in $vmHosts) {   
			if ($VMHost.Build){
				$buildFound = $false
				Foreach ($release in $esxiReleases.data.esxiReleases) {
					If ($vmHost.Build -eq $release.Build) {
						Foreach ($rel in $esxiReleases.data.esxiReleases) {
							If ($release.minorRelease -eq $rel.minorRelease) {
								$latestBuild = $rel
								break
							}
						}
						if($VMHost.Build -eq $latestBuild.Build){
							$updateAvailable = $false
							Write-Verbose "ESXi Host $($VMHost.Name) (Build: $($vmHost.Build)): running on latest version..."
						}else {
							$updateAvailable = $true
							Write-Verbose "ESXi Host $($VMHost.Name) (Build: $($vmHost.Build)): Update to $($latestBuild.friendlyName) available! (Image Profile: $($latestBuild.imageProfile))"
						}
						[pscustomobject] @{
							VMHost = $VMHost.Name
							currentBuild = $VMHost.Build
							currentVersion = $release.friendlyName
							currentReleaseDate =  $release.releaseDate
							updateAvailable = $updateAvailable
							latestBuild = $latestBuild.Build
							latestVersion = $latestBuild.friendlyName
							latestReleaseDate = $latestBuild.releaseDate
						}
						$buildFound = $true
					} 
				}
				if (-Not $buildFound) {
					Write-Verbose "ESXi Host $($VMHost.Name) (Build: $($vmHost.Build)): Version not found in JSON database. Please contact www.virten.net/about/"
					[pscustomobject] @{
						VMHost = $VMHost.Name
						currentBuild = $VMHost.Build
						currentVersion = ''
						currentReleaseDate = ''
						updateAvailable = ''
						latestBuild = ''
						latestVersion = ''
						latestReleaseDate = ''
					}
				}
			}
		}
	}
}


Function Convert-ScsiCode {
<#
.SYNOPSIS
	Decode SCSI Status Codes
.DESCRIPTION
	Decodes SCSI Sense Codes found in the vmkernel.log from ESXi hosts.
	It uses a JSON based SCSI Code database provided by www.virten.net
	
	vmkernel.log Example:
	ScsiDeviceIO: [...] Cmd 0xG [...] to dev "naa.x" failed H:0xA D:0xB P:0xC Valid sense data: 0xD 0xE 0xF.

	- A: Host Status Code
	- B: Device Status Code
	- C: Plugin Status Code
	- D: Sense Key
	- E: Additional Sense Code (ASC)
	- F: Additional Sense Code Qualifier (ASCQ)
	- G: Operational Code (Command)
	
.PARAMETER HostStatus
	Host Status Code
.PARAMETER DeviceStatus
	Device Status Code
.PARAMETER PluginStatus
	Plugin Status Code
.PARAMETER SenseKey
	Sense Key
.PARAMETER ASC
	Additional Sense Code (ASC)
.PARAMETER ASCQ
	Additional Sense Code Qualifier (ASCQ)
.PARAMETER OpCode
	Operational Code (Command)
.EXAMPLE
	Convert-ScsiCode -HostStatus 1
.EXAMPLE
	Convert-ScsiCode -HostStatus 0 -DeviceStatus 2 -PluginStatus 4 |ft -AutoSize -Wrap
.EXAMPLE
	Convert-ScsiCode 0 2 0 5 24 0 1a  |ft -AutoSize -Wrap
.NOTES
	Author:   Florian Grehl
	Twitter:  @virten
	Website:  www.virten.net
	
	Changelog:
	2017-09-04 - v1.0 - Initial Release

.LINK
	http://www.virten.net/2017/09/convert-scsicode-powershell-function/
#>
	Param(
	[Parameter(Mandatory=$false)][String]$HostStatus,
	[Parameter(Mandatory=$false)][String]$DeviceStatus,
	[Parameter(Mandatory=$false)][String]$PluginStatus,
	[Parameter(Mandatory=$false)][String]$SenseKey,
	[Parameter(Mandatory=$false)][String]$ASC,
	[Parameter(Mandatory=$false)][String]$ASCQ,
	[Parameter(Mandatory=$false)][String]$OpCode
	)

	Begin
	{
		$ErrorActionPreference = 'Stop'
		$scsiCodes = Invoke-WebRequest -Uri http://www.virten.net/repo/scsicodesV2.json | ConvertFrom-Json
	}

	Process
	{
		$results = @()

		if ($HostStatus){
			$HostStatus = $HostStatus.PadLeft(2, '0');
			$HS = $scsiCodes.data.hostCode.($HostStatus)
			if ($HS){
				Write-Verbose "Host Status 0x$($HostStatus): $($HS.name) ($($HS.description))"
				$info = [pscustomobject] @{
					Type = "Host Status"
					Code = "0x$($HostStatus)"
					Name = $HS.name;
					Description = $HS.description;
				} 
			} else {
				Write-Verbose "Host Status 0x$($HostStatus): Unknown"
				$info = [pscustomobject] @{
					Type = "Host Status"
					Code = "0x$($HostStatus)"
					Name = "UNKNOWN";
					Description = "Host status code unknown.";
				} 
						
			}
			$results+=$info
		}

		if ($DeviceStatus){
			$DeviceStatus = $DeviceStatus.PadLeft(2, '0');
			$DS = $scsiCodes.data.deviceCode.($DeviceStatus)
			if ($DS){
				Write-Verbose "Device Status 0x$($DeviceStatus): $($DS.name) ($($DS.description))" 
				$info = [pscustomobject] @{
					Type = "Device Status"
					Code = "0x$($DeviceStatus)"
					Name = $DS.name;
					Description = $DS.description;
				}
			} else {
				Write-Verbose "Device Status 0x$($DeviceStatus): Unknown"
				$info = [pscustomobject] @{
					Type = "Device Status"
					Code = "0x$($DeviceStatus)"
					Name = "UNKNOWN";
					Description = "Device status code unknown.";
				} 

			}
			$results+=$info
		}

		if ($PluginStatus){
			$PluginStatus = $PluginStatus.PadLeft(2, '0');
			$PS = $scsiCodes.data.pluginCode.($PluginStatus)
			if ($PS){
				Write-Verbose "Plugin Status 0x$($PluginStatus): $($PS.name) ($($PS.description))"
				$info = [pscustomobject] @{
					Type = "Plugin Status"
					Code = "0x$($PluginStatus)"
					Name = $PS.name;
					Description = $PS.description;
				}
			} else {
				Write-Verbose "Plugin Status 0x$($DeviceStatus): Unknown"
				$info = [pscustomobject] @{
					Type = "Plugin Status"
					Code = "0x$($PluginStatus)"
					Name = "UNKNOWN";
					Description = "Plugin status code unknown.";
				} 
			}
			$results+=$info
		}
		
		if ($SenseKey){
			$SenseKey = $SenseKey.PadLeft(2, '0');
			$SK = $scsiCodes.data.senseKey.($SenseKey)
			if ($SK){
				Write-Verbose "Sense Key 0x$($SenseKey): $($SK.name)"
				$info = [pscustomobject] @{
					Type = "Sense Key"
					Code = "0x$($SenseKey)"
					Name = $SK.name;
					Description = $SK.description;
				}
			} else {
				Write-Verbose "Sense Key 0x$($SenseKey): Unknown"
				$info = [pscustomobject] @{
					Type = "Plugin Status"
					Code = "0x$($SenseKey)"
					Name = "UNKNOWN";
					Description = "Sense key unknown.";
				} 
			}
			$results+=$info
		}

		if ($ASC -and $ASCQ){
			$ASC = $ASC.PadLeft(2, '0');
			$ASCQ = $ASCQ.PadLeft(2, '0'); 
			$ASD = $scsiCodes.data.asd.($ASC).($ASCQ)
		   
			if ($ASD){
				Write-Verbose "Additional sense data $($ASC)/$($ASCQ): $($ASD.name)"
				$info = [pscustomobject] @{
					Type = "Additional Sense Data"
					Code = "$($ASC)/$($ASCQ)"
					Name = $ASD.name;
					Description = $ASD.description;
				}
			} else {
				Write-Verbose "Additional sense data $($ASC)/$($ASCQ): Unknown"
				$info = [pscustomobject] @{
					Type = "Additional Sense Data"
					Code = "$($ASC)/$($ASCQ)"
					Name = "UNKNOWN";
					Description = "Additional Sense Data unknown";
				}
			}
			$results+=$info
		}

		if ($OpCode){
			$OpCode = $OpCode.PadLeft(2, '0');
			$OC = $scsiCodes.data.opCode.($OpCode)
			if ($OC){
				Write-Verbose "Op Code 0x$($OpCode): $($OC.name)"
				$info = [pscustomobject] @{
					Type = "OP Code"
					Code = "0x$($OpCode)"
					Name = $OC.name;
					Description = $OC.description;
				}
			} else {
				Write-Verbose "Op Code 0x$($OpCode): Unknown"
				$info = [pscustomobject] @{
					Type = "OP Code"
					Code = "0x$($OpCode)"
					Name = "UNKNOWN";
					Description = "OP Code unknown.";
				} 
			}
			$results+=$info
		}
	}
   	End
	{
		$results
	}
}


Function Get-VMLatencySensitivity {
<#
.SYNOPSIS
	Get virtual machine latency sensitivity level.
.DESCRIPTION
	This function returns the latency sensitivity level of a virtual machine.
	You can adjust the latency sensitivity of a virtual machine to optimize the scheduling delay 
	for latency sensitive applications.
	
	For large inventories, consider the Get-VMLatencySensitivityBulk function.
	
	When the function is called without parameters it will return all Virtual Machines.
.PARAMETER VM
	Virtual Machine Object returned by the Get-VM cmdlet
.EXAMPLE
	Get-VMLatencySensitivity
.EXAMPLE
	Get-VM app01 | Get-VMLatencySensitivity
.EXAMPLE
	Get-VMLatencySensitivity |? {$_.LatencySensitivity -notmatch "normal"}
.NOTES
	Author:   Florian Grehl
	Twitter:  @virten
	Website:  www.virten.net
	
	Changelog:
	2017-10-15 - v1.0 - Initial Release

.LINK
	http://www.virten.net/2017/10/get-and-set-vmlatencysensitivity-powershell-function/
#>
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$false,ValueFromPipeline=$true)]$VM = (Get-VM)
	)
	
	Process
	{
		$result = $VM | Get-View  -Property Name,Config.LatencySensitivity |
		Select Name,@{N='LatencySensitivity';E={$_.Config.LatencySensitivity.Level}} 
		$result
	}
}


Function Get-VMLatencySensitivityBulk {
<#
.SYNOPSIS
	Get virtual machine latency sensitivity level.
.DESCRIPTION
	This function returns the latency sensitivity level of all virtual machine in the inventory.
	You can adjust the latency sensitivity of a virtual machine to optimize the scheduling delay 
	for latency sensitive applications.
	
	This function is suitable for a large inventory.
	
	When the function is called without parameters it will return all Virtual Machines.
.PARAMETER hidenormal
	Hide Virtual Machines with default latancy sensitivity (normal)
.EXAMPLE
	Get-VMLatencySensitivityBulk
.EXAMPLE
	Get-VMLatencySensitivityBulk -hideNormal |Set-VMLatencySensitivity -Level normal
.NOTES
	Author:   Florian Grehl
	Twitter:  @virten
	Website:  www.virten.net
	
	Changelog:
	2017-10-15 - v1.0 - Initial Release

.LINK
	http://www.virten.net/2017/10/get-and-set-vmlatencysensitivity-powershell-function/
#>
	[CmdletBinding()]
	Param(
		[switch]$hideNormal
	)
	
	Process
	{
		$result = Get-View -ViewType VirtualMachine -Property Name,Config.LatencySensitivity |
		Select Name,@{N='LatencySensitivity';E={$_.Config.LatencySensitivity.Level}} 

		if ($hideNormal){
			$result |? {$_."LatencySensitivity" -notcontains "normal"}
		}else{
			$result
		}
	}
}


Function Set-VMLatencySensitivity {
<#
.SYNOPSIS
	Set virtual machine latency sensitivity level.
.DESCRIPTION
	This function returns the latency sensitivity level of a virtual machine.
	You can adjust the latency sensitivity of a virtual machine to optimize the scheduling delay 
	for latency sensitive applications.
	
	When the function is called without parameters it will return all Virtual Machines.
.PARAMETER VM
	Virtual Machine Object returned by the Get-VM cmdlet
.PARAMETER Level
	Latency Sensitivity level to configure ("low","normal","medium" or "high")
.EXAMPLE
	Get-VM app01 | Set-VMLatencySensitivity -Level low
.EXAMPLE
	Get-VMLatencySensitivity |? {$_.LatencySensitivity -notmatch "normal"} |Set-VMLatencySensitivity -Level normal
.NOTES
	Author:   Florian Grehl
	Twitter:  @virten
	Website:  www.virten.net
	
	Changelog:
	2017-10-15 - v1.0 - Initial Release

.LINK
	http://www.virten.net/2017/10/get-and-set-vmlatencysensitivity-powershell-function/
#>
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)]$VM,
		[Parameter(Mandatory=$true)][ValidateSet("low","normal","medium","high")]$Level
	)

    Process
	{
		try{
			$ObjVm = Get-VM -Name $VM.Name
		}catch{
			Write-Verbose "VM Value from interactive input"
			$ObjVm = Get-VM -Name $VM    
		}

		$VirtualMachineConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
		$VirtualMachineConfigSpec.LatencySensitivity = New-Object VMware.Vim.LatencySensitivity
		$VirtualMachineConfigSpec.LatencySensitivity.Level = [VMware.Vim.LatencySensitivitySensitivityLevel]::$Level
		Write-Verbose "Virtual Machine $($VM.Name): Setting Latency Sensitivity to $($Level)"
		$ObjVm.ExtensionData.ReconfigVM($VirtualMachineConfigSpec)
	}
}