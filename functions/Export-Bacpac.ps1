Function Export-Bacpac {
    Param (
        [Parameter(Mandatory=$True )] [string]$ServerInstance,
        [Parameter(Mandatory=$True)] [string[]]$Database,
        [string]$Path
    )

    BEGIN {

        Add-Type -path "C:\Program Files (x86)\Microsoft SQL Server\120\DAC\bin\Microsoft.SqlServer.Dac.dll";

        $ConnectString = "Server=$($ServerInstance); Integrated Security=True;"
        $dacService = new-object Microsoft.SqlServer.Dac.DacServices $ConnectString

        register-objectevent -in $dacService -eventname Message -source "dacmsg" -action { out-host -in $Event.SourceArgs[1].Message.Message }
    }

    PROCESS {

        foreach ($dbname in $Database){
            
            [int] $currentAU = (Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $dbname.Name -Query "SELECT dbo.fn_getPropertyInt('AutoUpdate_LastVersion') CurrentAU" -SuppressProviderContextWarning).CurrentAU

            $bacpac  = "{0}\{1}.bacpac" -f $Path, ($dbname+"-"+$currentAU.ToString())

            if (Test-Path $bacpac) {
                Remove-Item $bacpac 
            }

            $dacService.exportBacpac($bacpac, $dbname)

        }
    }

    END {
        unregister-event -source "dacmsg"
    }
    

}