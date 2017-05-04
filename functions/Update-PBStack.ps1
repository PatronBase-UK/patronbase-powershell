Function Update-PBStack {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True,
        ParameterSetName = "Named")] 
        [ValidateScript({Test-Path "C:\PB-Releases\$_" })]
        [string] $Stack,
        [Parameter(Mandatory=$True,
        ParameterSetName = "FolderPath")] 
        [ValidateScript({Test-Path $_})]
        [string] $FolderPath,
        [ValidateSet("stable","beta","patch","rc")]
        [string]$Build = "stable",
        [switch] $Force
    )
    
    BEGIN {

        $buildpath = "C:\PB-Support\Updates\$($Build)"
        If(!(test-path "$($buildpath)\_zips")) {
            $newdir = New-Item -ItemType Directory -Force -Path "$($buildpath)\_zips"
        }

        If ($Stack) {
            $FolderPath = "C:\PB-Releases\$stack\"

        }
        
        $modules = Get-ChildItem $FolderPath -Directory

        workflow pbbuildfetch {
            Param (
                $wfmodules,
                $wfBuild,
                $wfbuildpath
                )

            $pwd = ConvertTo-SecureString "patron" -AsPlainText -Force
            $cred = New-Object Management.Automation.PSCredential ('pb', $pwd)

            foreach -parallel ($module in $wfmodules ) {
            
            "Downloading $wfbuild/$module build from SettCloud..."
                If ( $module -eq "Desktop" -and $wfbuild -eq "stable" ) {
                    Invoke-Download -uri "http://pbbuild.settcloud.com/rc/$module.zip" -FilePath "$wfbuildpath\_zips\$module.zip" -cred $cred
                } ElseIf ( $module -eq "Desktop" -and $wfbuild -eq "patch" ) {
                    Invoke-Download -uri "http://pbbuild.settcloud.com/beta/$module.zip" -FilePath "$wfbuildpath\_zips\$module.zip" -cred $cred
                } Elseif ($module.name -like "Member*" ) {
                    Invoke-Download -uri "http://pbbuild.settcloud.com/$wfbuild/Membership.zip" -FilePath "$wfbuildpath\_zips\$module.zip" -cred $cred
                } Else {
                    Invoke-Download -uri "http://pbbuild.settcloud.com/$wfbuild/$module.zip" -FilePath "$wfbuildpath\_zips\$module.zip" -cred $cred
                }

                Unblock-File -Path "$wfbuildpath\_zips\$module.zip"

                $newdir = New-Item -ItemType Directory -Force -Path "$($wfbuildpath)\$module"
                Expand-Archive -Path "$($wfbuildpath)\_zips\$module.zip" -DestinationPath "$($wfbuildpath)\$module" -Force
            } #END foreach loop
        } #END workflow pbbuildfetch
    pbbuildfetch -wfmodules $modules -wfbuildpath $buildpath -wfBuild $Build
    } #END BEGIN

    PROCESS {
        
        If ($FolderPath) {
            $Paths = $FolderPath
        }

        
        Foreach ($Path in $Paths) {
            
            If ($Force ) { Invoke-Command -ComputerName PBUKRDS01, PBUKRDS02 -ScriptBlock {param($releasepath) Get-Process | Where-Object {$_.Path -like "$($releasepath)*"} | Stop-Process -Force} -Args $Path }

            Foreach ($module in $modules) {

                If ( $module -eq "Desktop") {
                    "Updating $module..."
                    xcopy /S /Y /Q "$($buildpath)\$module\Release\*.*" "$($Path)\$module\"
                } Else {
                    "Updating $module..."
                    xcopy /S /Y /Q "$($buildpath)\$module\*.*" "$($Path)\$module\"  
                }
            } #END Foreach ($module in $modules)

        } #END Foreach ($Path in $Paths)
    } #END PROCESS

    END {
        Get-ChildItem $buildpath -Recurse -File -Exclude "*.zip"  | Remove-Item -Force
        Get-ChildItem $buildpath -Recurse -Directory -Exclude "_zips" | Remove-Item -Force -Recurse
    } #END END

} #END Function Update-PBStack