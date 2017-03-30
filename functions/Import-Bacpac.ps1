Function Import-Bacpac {
    Param (
        [Parameter(Mandatory=$True )] [string]$ServerInstance,
        [Parameter(Mandatory=$True)] [string]$Database,
        [Parameter(Mandatory=$True)] [string]$Path
    )

    BEGIN {

        Add-Type -path "C:\Program Files (x86)\Microsoft SQL Server\120\DAC\bin\Microsoft.SqlServer.Dac.dll";

        $ConnectString = "Server=$($ServerInstance); Integrated Security=True;"
        $dacService = new-object Microsoft.SqlServer.Dac.DacServices $ConnectString

        register-objectevent -in $dacService -eventname Message -source "dacmsg" -action { out-host -in $Event.SourceArgs[1].Message.Message }
    }

    PROCESS {

        $bacpac  = [Microsoft.SqlServer.Dac.DacPackage]::Load($Path)

        $dacService.Deploy($bacpac, $Database, "True")

    }

    END {
        unregister-event -source "msg"
    }
    
}