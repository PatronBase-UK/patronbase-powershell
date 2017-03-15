Function Update-PBAppStack {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True,
        ParameterSetName = "Named")] 
        [ValidateScript({$_ | Foreach-Object { "C:\PB-Releases\$_" } | Test-Path})]
        [string[]] $Stack,
        [ValidateSet("stable","beta","patch","rc")]
        [string]$Build = "stable",
        [switch] $Force,
        [parameter(Mandatory=$True,
        ValueFromPipeline = $True,
        ParameterSetName = "Pipeline")]
		[object]$PathPipeline
    )
    
    BEGIN {
        $pwd = ConvertTo-SecureString "patron" -AsPlainText -Force
        $cred = New-Object Management.Automation.PSCredential ('pb', $pwd)

        $buildpath = "C:\PB-Support\Updates\$($Build)"
        If(!(test-path "$($buildpath)\_zips")) {
            New-Item -ItemType Directory -Force -Path $path | Out-Null
        }

        $packages = @("!All","LayoutDesigner","Monitor","QuickPOS","Desktop")

        Foreach ($package in $packages) {

            "Downloading $build/$package build from SettCloud..."
            If ( $package -eq "Desktop" -and $build -eq "stable" ) {
                Invoke-Download -uri "http://pbbuild.settcloud.com/rc/$package.zip" -FilePath "$buildpath\_zips\$package.zip" -cred $cred
            } ElseIf ( $package -eq "Desktop" -and $build -eq "patch" ) {
                Invoke-Download -uri "http://pbbuild.settcloud.com/beta/$package.zip" -FilePath "$buildpath\_zips\$package.zip" -cred $cred
            } Else {
                Invoke-Download -uri "http://pbbuild.settcloud.com/$build/$package.zip" -FilePath "$buildpath\_zips\$package.zip" -cred $cred
            }

            Unblock-File -Path "$buildpath\_zips\$package.zip"

            If ( $package -eq "!All" ) {
                Expand-Archive -Path "$($buildpath)\_zips\$package.zip" -DestinationPath "$($buildpath)" -Force
            } Else {
                 New-Item -ItemType Directory -Force -Path "$($buildpath)\!All\$package"| Out-Null
                 Expand-Archive -Path "$($buildpath)\_zips\$package.zip" -DestinationPath "$($buildpath)\!All\$package" -Force
            }

        } #END Foreach ($package in $packages)
    } #END BEGIN

    PROCESS {
        
        If ($PSBoundParameters.ContainsKey('Stack')) {
            $Stacks = $psboundparameters.Stack
            }

        If ($PathPipeline.Length -gt 0) {
            $Stacks = $PathPipeline.name
            }

        
        $Paths = $Stacks | Foreach-Object { "C:\PB-Releases\$_" }

        
        Foreach ($Path in $Paths) {
            
            If ($Force ) { Invoke-Command -ComputerName PBUKRDS01, PBUKRDS02 -ScriptBlock {param($releasepath) Get-Process | Where-Object {$_.Path -like "$($releasepath)*"} | Stop-Process -Force} -Args $Path }

            $modules = (Get-ChildItem $path -Directory).Name

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

} #END Function Update-PBAppStack