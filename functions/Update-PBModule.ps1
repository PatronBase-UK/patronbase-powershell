Function Update-PBModule {
<#
.SYNOPSIS
Exported function. Updates PatronBase PowerShell Module. Deletes current copy and replaces it with freshest copy.

.DESCRIPTION
Exported function. Updates PatronBase PowerShell Module. Deletes current copy and replaces it with freshest copy.

.NOTES 
PatronBase PowerShell module (https://github.com/mrthomsmith/patronbase-powershell, thom@patronbase.co.uk)
Copyright (C) 2017 Thom Smith

.LINK
https://github.com/mrthomsmith/patronbase-powershell

.EXAMPLE
Update-PBModule

Updates PatronBase PowerShell Module. Deletes current copy and replaces it with freshest copy.
	
#>	
    Invoke-Expression (Invoke-WebRequest -UseBasicParsing https://raw.githubusercontent.com/mrthomsmith/patronbase-powershell/master/install.ps1).Content

}