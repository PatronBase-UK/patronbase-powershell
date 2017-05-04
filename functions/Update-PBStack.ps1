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
        $pwd = ConvertTo-SecureString "patron" -AsPlainText -Force
        $cred = New-Object Management.Automation.PSCredential ('pb', $pwd)

        $buildpath = "C:\PB-Support\Updates\$($Build)"
        If(!(test-path "$($buildpath)\_zips")) {
            New-Item -ItemType Directory -Force -Path $path | Out-Null
        }

        If ($Stack) {
            $FolderPath = "C:\PB-Releases\$stack\"

        }
        
        $modules = Get-ChildItem $FolderPath -Directory

        workflow pbbuildfetch {

            foreach -parallel ($module in $modules ) {
            
            "Downloading $build/$module build from SettCloud..."
                If ( $module -eq "Desktop" -and $build -eq "stable" ) {
                    Invoke-Download -uri "http://pbbuild.settcloud.com/rc/$module.zip" -FilePath "$buildpath\_zips\$module.zip" -cred $cred
                } ElseIf ( $module -eq "Desktop" -and $build -eq "patch" ) {
                    Invoke-Download -uri "http://pbbuild.settcloud.com/beta/$module.zip" -FilePath "$buildpath\_zips\$module.zip" -cred $cred
                } Elseif ($module.name -like "Member*" ) {
                    Invoke-Download -uri "http://pbbuild.settcloud.com/$build/Membership.zip" -FilePath "$buildpath\_zips\$module.zip" -cred $cred
                } Else {
                    Invoke-Download -uri "http://pbbuild.settcloud.com/$build/$module.zip" -FilePath "$buildpath\_zips\$module.zip" -cred $cred
                }

                Unblock-File -Path "$buildpath\_zips\$module.zip"

                New-Item -ItemType Directory -Force -Path "$($buildpath)\$module"
                Expand-Archive -Path "$($buildpath)\_zips\$module.zip" -DestinationPath "$($buildpath)\$module" -Force
            } #END foreach loop
        } #END workflow pbbuildfetch
    pbbuildfetch
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
                    xcopy /S /Y /Q "$($buildpath)\!All\$module\Release\*.*" "$($Path)\$module\"
                } Else {
                    "Updating $module..."
                    xcopy /S /Y /Q "$($buildpath)\!All\$module\*.*" "$($Path)\$module\"  
                }
            } #END Foreach ($module in $modules)

        } #END Foreach ($Path in $Paths)
    } #END PROCESS

    END {
        Get-ChildItem "$($buildpath)\!All" -Recurse -File | Remove-Item -Force
        Get-ChildItem "$($buildpath)\!All" -Recurse -Directory | Remove-Item -Force -Recurse
    } #END END

} #END Function Update-PBStack