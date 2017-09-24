# Virten.net.VimAutomation
Virten.net.VimAutomation is a set of PowerShell function built for managing, troubleshooting and automating VMware based platforms.

## Install from PowerShell Gallery
The Virten.net PowerCLI Automation Module is available in the PowerShell Gallery.

`PS> Install-Module -Name Virten.net.VimAutomation`

If you've aready installed the module, use Update-Module to update it to the latest version.

`PS> Update-Module -Name Virten.net.VimAutomation`

## Manual Install
To manually install this module, copy the Virten.net.VimAutomation folder into you local module directory. There are various module directories, they can be identified with the `$env:PSModulePath` environment variable.
Activate the module with `Import-Module Virten.net.VimAutomation -Force -Verbose`.

|Function|Description|
|----|----|
|Get-VMHostVersion|Get detailed ESXi version information|
|Get-VMHostLatestVersion|Check if an ESXi update is available|
|<b>Convert-ScsiCode</b>(http://www.virten.net/2017/09/convert-scsicode-powershell-function/)|Decode SCSI Status Codes|

