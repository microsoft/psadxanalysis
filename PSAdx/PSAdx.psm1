[System.Reflection.Assembly]::LoadFrom( $(Join-Path -Path $PSScriptRoot -ChildPath "\bin\Kusto.Data.dll")) | Out-Null

function Invoke-PSAdxQuery {
    [CmdletBinding(DefaultParametersetName="Command")]
    param (
        [string]$ConnectionString
        ,[string]$DatabaseName
        ,[string]$Query
        ,$QueryParameters
    )
    begin {
        try {
            $kcsb = New-Object Kusto.Data.KustoConnectionStringBuilder ($ConnectionString, $(($ConnectionString | Select-String -Pattern "Catalog\=(\w*)").Matches.Groups[1].Value))
            $queryProvider = [Kusto.Data.Net.Client.KustoClientFactory]::CreateCslQueryProvider($kcsb);
        }
        catch {
            Write-Error -Message "Error connecting to cluster.  Please try again."
        }
    }
    
    process {
        try {
            
            # Configure properties
            $crp = New-Object Kusto.Data.Common.ClientRequestProperties;
            $crp.ClientRequestId = "MyPowershellScript.ExecuteQuery." + [Guid]::NewGuid().ToString();
            $crp.SetOption([Kusto.Data.Common.ClientRequestProperties]::OptionServerTimeout, [TimeSpan]::FromSeconds(300));
            foreach($key in $QueryParameters.keys) {
                $crp.SetParameter($key, $QueryParameters[$key])
            };

            #Execute the query
            $reader = $queryProvider.ExecuteQuery($Query, $crp)
            $dataTable = [Kusto.Cloud.Platform.Data.ExtendedDataReader]::ToDataSet($reader).Tables

            return $dataTable
        }
        catch {
            Throw $_.Exception.Message
        }
    }
    end {
    }
}

#Function to get the parameters needed in an analysis pack CSL file
function Get-PSAdxCSLParameter {
    param (
        # Path to the CSL file
        [Parameter(Mandatory=$true)]
        [string]
        $Path
    )

    begin {
        $foundParams = New-Object -TypeName System.Collections.ArrayList
        if (-Not (Test-Path -Path $Path -PathType Leaf)) {
            return $foundParams;
        }
    }

    process{
        try {
            $regMatches = ((Get-Content -Path $Path | Select-String "^declare query_parameters.*").Matches[0].Value | Select-String -Pattern "(\w*):\w*" -AllMatches -ErrorAction SilentlyContinue)
            foreach ($item in $regMatches.Matches.Groups)
            {
                if ($item.Value -notmatch "(\(|\)|\,|\:|\^|\"")") 
                {
                    $foundParams.Add([string]($item.Value).Trim()) | Out-Null   
                }
            }
        }
        catch
        {}
        return $foundParams
    }

    end{
    }
}
