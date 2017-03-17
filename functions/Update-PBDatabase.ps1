Function Update-PBDatabase { 
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True,
        ParameterSetName = "DBNamed")]
        [string[]] $Database,
        [ValidateSet("stable","beta")]
        [string]$Stream = "stable",
        [switch] $SkipBackup,
        [string] $BackupPath = "F:\AutoUpdate",
        [object] $ServerInstance = "PBUKSQLMAIN01",
        [switch] $Silent,
        [parameter(Mandatory=$True,
        ValueFromPipeline = $True,
        ParameterSetName = "DBPipeline")]
		[object]$DbPipeline
    )
    
    BEGIN {}

    PROCESS {
        
        If ($PSBoundParameters.ContainsKey('Database')) {
            $Databases = $psboundparameters.Database
            }

        If ($DbPipeline.Length -gt 0) {
            $Databases = $DbPipeline.name
            }

        if ($databases -contains "master" -or $databases -contains "msdb" -or $databases -contains "tempdb") { throw "Migrating system databases is not currently supported." }
        
        
        Foreach ($dbname in $Databases) {

            # Log file setup
            $dt = (Get-Date).ToString("yyyy-MM-dd HH-mm")
            $Stamp = (Get-Date).toString("yyyy-MM-dd HH:mm:ss")
            $uStamp = get-date -uformat %s
            $logfile = "C:\PB-Support\Scripts\AutoUpdate\AutoUpdate - $($dbname) - $($dt).log"


            [int] $currentAU = (Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $dbname -Query "SELECT dbo.fn_getPropertyInt('AutoUpdate_LastVersion') CurrentAU" -SuppressProviderContextWarning).CurrentAU
            $baseUrl = (Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $dbname -Query "SELECT dbo.fn_getPropertyString('AutoUpdate_baseUrl') baseUrl" -SuppressProviderContextWarning).baseUrl
            $auUsername = (Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $dbname -Query "SELECT dbo.fn_getPropertyString('AutoUpdate_Username') username" -SuppressProviderContextWarning).username
            $auPassword = ConvertTo-SecureString (Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $dbname -Query "SELECT dbo.fn_getPropertyString('AutoUpdate_Password') password" -SuppressProviderContextWarning).password -AsPlainText -Force
            $auCred = New-Object Management.Automation.PSCredential ($auUsername, $auPassword)

            If ( $Stream -eq 'beta' ) {
                Invoke-RestMethod "$($baseURl)BetaUpdates?module=PatronBase ®&version=$($currentAU)" -cred $auCred -OutFile "C:\PB-Support\Scripts\AutoUpdate\au.xml"
                Write-Log -Path $logfile -Message "Download File: $($baseURl)BetaUpdates?module=PatronBase ®&version=$($currentAU)" 
            } Else {
                Invoke-RestMethod "$($baseURl)?module=PatronBase ®&version=$($currentAU)" -cred $auCred -OutFile "C:\PB-Support\Scripts\AutoUpdate\au.xml"
                Write-Log -Path $logfile -Message "Download File: $($baseURl)?module=PatronBase ®&version=$($currentAU)"
            }

            [xml]$auList = [xml](Get-Content -Path C:\PB-Support\Scripts\AutoUpdate\au.xml)
            [System.Xml.XmlElement]$scripts = $auList.update.module
            [System.Xml.XmlElement]$script = $null

            foreach( $script in $scripts.script) {
                If (Test-Path -Path "C:\PB-Support\Scripts\AutoUpdate\$($script.Name).sql" -PathType Leaf) {
        
                    Write-Log -Path $logfile -Message "$($baseURl)$($script.Name).sql already exists, skipping"

                } Else {

                    Try {
                        Invoke-RestMethod "$($baseURl)$($script.Name)" -cred $auCred -OutFile "C:\PB-Support\Scripts\AutoUpdate\$($script.Name).sql"
                        Write-Log -Path $logfile -Message "Download File: $($baseURl)$($script.Name).sql"
                    } Catch {
                        Invoke-RestMethod "$($baseURl)$($script.Name).sql" -cred $auCred -OutFile "C:\PB-Support\Scripts\AutoUpdate\$($script.Name).sql"
                        Write-Log -Path $logfile -Message "Download File: $($baseURl)$($script.Name).sql"
                    }
    
                }
            }

            [int]$newAU = $scripts.version.version

            If ( $newAU -gt $currentAU ) {
 
                If ( -Not $SkipBackup) {
                    Backup-SqlDatabase -ServerInstance $ServerInstance -Database $dbname -BackupAction Database -BackupFile "$($BackupPath)\AutoUpdate - $($dbname) - $($dt).bak"
                    Write-Log -Path $logfile -Message "Backing up database $($dbname)..."
                }

                Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $dbname -Query "EXEC dbo.up_au_flagUpdate @reconnectSeconds = 300"

                foreach( $script in $scripts.script) {
                    Try {
                        Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $dbname -InputFile "C:\PB-Support\Scripts\AutoUpdate\$($script.Name).sql" -SuppressProviderContextWarning -AbortOnError -ErrorAction Stop
                        Write-Log -Path $logfile -Message "Applying $($script.Name)..."
                        $updateResult = $true
                    } Catch {
                        $ErrorMessage = $_.Exception.Message
                        Write-Log -Path $logfile -Message "Error applying $($script.Name) with $($ErrorMessage)"
            
                        If ( -Not $skipBackup) {
                            Write-Log -Path $logfile -Message "Restoring database $($dbname)..."
                            Restore-SqlDatabase -ServerInstance $ServerInstance -Database $dbname -BackupFile "$($BackupPath)\AutoUpdate - $($dbname) - $($dt).bak" -ReplaceDatabase
                        }

                        If ( -Not $Silent) {
                            Invoke-RestMethod -Uri https://hooks.slack.com/services/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 -Body "{	
                            `"attachments`": [
                                {
                                    `"fallback`": `"Database update failed on $($dbname)`",
                                    `"color`": `"danger`",
                                    `"pretext`": `"Database update failed on ``$($dbname)```",
                                    `"fields`": [
                                        {
                                            `"title`": `"AutoUpdate Script`",
                                            `"value`": `"$($script)`"
                                        },
                                        {
                                            `"title`": `"Error Message`",
                                            `"value`": `"$($ErrorMessage)`"
                                        }
                                    ],
                                    `"footer`": `"POSH AutoUpdate`",
                                    `"ts`": $($uStamp),
                                    `"mrkdwn_in`": [`"text`", `"pretext`"]

                                }
                            ]
                        }" -ContentType application/json -Method POST
                        }

                        $updateResult = $false
                        Break
                    }
                }
    
                If ($updateResult -eq $true ) {

                    Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $dbname -Query "UPDATE dbo.tblProperty SET intValue = $($newAU) WHERE propertyName = 'AutoUpdate_LastVersion'" -SuppressProviderContextWarning
                    Write-Log -Path $logfile -Message "Database updated to $($newAU)"

                    If ( -Not $Silent) {
                        Invoke-RestMethod -Uri https://hooks.slack.com/services/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 -Body "{	
                            `"attachments`": [
                                {
                                    `"fallback`": `"Database $($dbname) updated to $($newAU)`",
                                    `"color`": `"good`",
                                    `"pretext`": `"Database ``$($dbname)`` updated`",
                                    `"fields`": [
                                        {
                                            `"title`": `"Old DB Version`",
                                            `"value`": $($currentAU),
                                            `"short`": true
                                        },
                                        {
                                            `"title`": `"New DB Version`",
                                            `"value`": $($newAU),
                                            `"short`": true
                                        }
                                    ],
                                    `"footer`": `"POSH AutoUpdate`",
                                    `"ts`": $($uStamp),
                                    `"mrkdwn_in`": [`"text`", `"pretext`"]

                                }
                            ]
                        }" -ContentType application/json -Method POST
                    }
                }
                
                Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $dbname -Query "EXEC dbo.up_au_flagUpdate @reconnectSeconds = 0"
                

            } Else {
                Write-Log -Path $logfile -Message "No updates available for $($dbname)"
            }
        }
    }

    END {}
}