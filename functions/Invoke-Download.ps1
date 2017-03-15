Function Invoke-Download {
    Param (
        [Parameter(Mandatory=$True)] [System.Uri]$uri,
        [Parameter(Mandatory=$True )] [string]$FilePath,
        [Management.Automation.PSCredential]$cred
    )

    #Make sure the destination directory exists
    #System.IO.FileInfo works even if the file/dir doesn't exist, which is better then get-item which requires the file to exist
    If (! ( Test-Path ([System.IO.FileInfo]$FilePath).DirectoryName ) ) { [void](New-Item ([System.IO.FileInfo]$FilePath).DirectoryName -force -type directory)}

    #see if this file exists
    if ( -not (Test-Path $FilePath) ) {
        #use simple download
        Invoke-RestMethod $uri -cred $cred -OutFile $FilePath
    } else {
        try {

            $localModified = (Get-Item $FilePath).LastWriteTime
            Invoke-RestMethod $uri -cred $cred -OutFile $FilePath -Headers @{"If-Modified-Since"="$localModified"}

        } catch [System.Net.WebException] {
            #Check for a 304
            if ($_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::NotModified) {
                Write-Host "  $FilePath not modified, not downloading..."
            } else {
                #Unexpected error
                $Status = $_.Exception.Response.StatusCode
                $msg = $_.Exception
                Write-Host "  Error dowloading $FilePath, Status code: $Status - $msg"
            }
        }
    }
}