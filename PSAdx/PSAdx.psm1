[System.Reflection.Assembly]::LoadFrom( $(Join-Path -Path $PSScriptRoot -ChildPath "\bin\Kusto.Data.dll")) | Out-Null

class AnalysisPack {
    [string]$AnalysisPackPath
    [string]$ReferenceId
    [AdxTarget[]]$AvailableConnection
    [AnalysisPackDataSet[]]$DataSet
    [string]$ConnectionFilePath
    [string[]]$AvailableTemplate
    [string]$TemplateFolderPath
    [string]$QueryFolderPath

    AnalysisPack([string]$Path, [string]$Reference, [string[]]$Parameter) {
        #Set Initials
        $this.AnalysisPackPath = $Path
        $this.TemplateFolderPath = Join-Path -Path $this.AnalysisPackPath -ChildPath "templates"
        $this.QueryFolderPath = Join-Path -Path $this.AnalysisPackPath -ChildPath "queries"
        $this.ConnectionFilePath = Join-Path -Path $this.AnalysisPackPath -ChildPath "userconnections.xml"

        $this.ReadConnectionFile()
        $this.ReadTemplateFolder()
        $this.ReadQueryFolder()
    }

    [void]ReadConnectionFile() {
        $FoundConnections = New-Object -TypeName System.Collections.ArrayList
        try {
            foreach ($item in ([xml](Get-Content -Raw -Path $this.AnalysisPackPath -ErrorAction Stop).ArrayOfServerDescriptionBase.ServerDescriptionBase)) {
                $Connection = New-Object -TypeName AdxTarget($item.Name, $item.ConnectionString)
                $FoundConnections.Add($Connection) | Out-Null
            }
            this.$AvailableConnection = $FoundConnections.ToArray()
        }
        catch {
            Write-Error "Unable to process connections file $($this.ConnectionsFilePath)"
        }
        Remove-Variable -Name FoundConnections -Force -ErrorAction SilentlyContinue
    }

    [void]ReadTemplateFolder() {
        $FoundTemplates = New-Object -TypeName System.Collections.ArrayList
        try {
            foreach ($item in (Get-ChildItem -Path $this.TemplateFolderPath)) {
                $FoundTemplates.Add($item.FullName) | Out-Null
            }
            $this.AvailableTemplate = $FoundTemplates.ToArray()
        }
        Catch {
            Write-Error "Unable to get templates in folder $($this.TemplateFolderPath)"
        }
        Remove-Variable -Name FoundTemplates -ErrorAction SilentlyContinue
    }

    [void]ReadQueryFolder() {
        $FoundQueries = New-Object -TypeName System.Collections.ArrayList
        try {
            foreach ($item in (Get-ChildItem -Path $this.QueryFolderPath)) {
                $CslFile = New-Object -TypeName AnalysisPackDataSet($item.FullName)
                $FoundQueries.Add($CslFile) | Out-Null
            }
            $this.DataSet = $FoundQueries.ToArray()
        }
        Catch {
            Write-Error "Unable to get templates in folder $($this.QueryFolderPath)"
        }
        Remove-Variable -Name FoundQueries -ErrorAction SilentlyContinue
    }

}

class AdxTarget {
    [string]$Name
    [string]$ConnectionString
    [string]$Catalog

    AdxTarget([string]$N, [string]$C) {
        $this.Name = $N
        $this.ConnectionString = $C
        $this.Catalog = (this.ConnectionString | Select-String -Pattern "Catalog\=(\w*)").Matches.Groups[1].Value
    }
}

class AnalysisPackDataSet {
    [string]$Name
    [AnalysisParameter[]]$Parameter
    [string]$Content
    [string]$Path

    AnalysisPackDataSet([string]$CslPath) {
        $Parameters = New-Object -TypeName System.Collections.ArrayList
        $this.Content = Get-Content -Raw -Path $CslPath -ErrorAction Stop
        $this.Path = (Resolve-Path -Path $CslPath).Path
        $this.Name = (Get-Item -Path $this.Path).BaseName
        $regMatches = ((Get-Content -Path $this.Path | Select-String "^declare query_parameters.*").Matches[0].Value | Select-String -Pattern "(\w*):\w*" -AllMatches -ErrorAction SilentlyContinue)
        foreach ($item in $regMatches.Matches.Groups) {
            if ($item.Value -notmatch "(\(|\)|\,|\:|\^|\"")") {
                $Param = New-Object -TypeName AnalysisParameter
                $Param.Name = [string]($item.Value).Trim()
                $Parameters.Add($Param) | Out-Null   
            }
        }
        Remove-Variable -Name Parameters, regMatches -Force -ErrorAction SilentlyContinue
    }

    [Kusto.Cloud.Platform.Data.ExtendedDataReader] ExecuteQuery([AdxTarget] $Target) {
        return = InvokeQuery($Target, $this.Parameters)
    }

    [Kusto.Cloud.Platform.Data.ExtendedDataReader] ExecuteQuery([AdxTarget] $Target, [AnalysisParameter[]]$Parameters) {
        return = InvokeQuery($Target, $Parameters)
    }

    hidden [string] InvokeQuery([AdxTarget]$Target, [AnalysisParameter]$Parameters) {
        $kcsb = New-Object Kusto.Data.KustoConnectionStringBuilder ($ConnectionString, $(($ConnectionString | Select-String -Pattern "Catalog\=(\w*)").Matches.Groups[1].Value))
        $queryProvider = [Kusto.Data.Net.Client.KustoClientFactory]::CreateCslQueryProvider($kcsb);
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

        #return $dataTable
        return ""
    }
}

class AnalysisParameter {
    [string]$Name
    [string]$Value
}

function PSLogger {
    param (
        # The file that will recieve the log event
        [Parameter(Mandatory=$true)]
        $LogFile,
        # Strings that needs to be logged, allowing array for multi-line entries/batch
        [Parameter(Mandatory=$true)]
        [String[]]
        $LogText
    )  
        #Simple now but allowing for more later if needed
        $LogText | Out-File -FilePath $LogFile -NoClobber -Force
  
}


##############################
#.SYNOPSIS
#Returns an object that represents an AnalysisPack
#
#.DESCRIPTION
#The Invoke-PSAdxAnalysisPack cmdlet will return an object which contains the templates, queries, and connections of an analysis pack.
#
#.PARAMETER AnalysisPackPath
#Full or relatice path to the Analysis Pack you wish to invoke.
#
#.PARAMETER ReferenceNumber
#Optional.  A reference number which you wish to associate the instantiation of the Analysis Pack.
#
#.EXAMPLE
#$x = Import-PSAdxAnalysisPack -AnalysisPackPath C:\Users\scepperl\Documents\CssAdx\analysispacks\AzureSqlDw -ReferenceId 123456 -TargetConnection MyConnectionName -Template "default.xlsx" -MyCustomParam "custom_value";
#
#.EXAMPLE
#$x = Import-PSAdxAnalysisPack -AnalysisPackPath C:\Users\scepperl\Documents\CssAdx\analysispacks\AzureSqlDw -ReferenceId 123456 -TargetConnection MyConnectionName -Template "default.xlsx" -MyCustomParam "custom_value";
#$x.Analyze();
##############################
function Invoke-PSAdxAnalysisPack {
    [CmdletBinding()]
    param (
        [string]$AnalysisPackPath
        ,[string]$ReferenceId
    )

    DynamicParam {
        $dyParams = Test-PSAdxAnalysisPack -Path $AnalysisPackPath
        $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        if($dyParams.Parameters.Count -gt 0)
        {
            foreach ($Item in $dyParams.Parameters)
            {
                $Attribute = New-Object System.Management.Automation.ParameterAttribute
                $Attribute.Mandatory = $true
                $attributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                $attributeCollection.Add($Attribute)
                $ParamItem = New-Object System.Management.Automation.RuntimeDefinedParameter($Item, [string], $attributeCollection)
                $paramDictionary.Add($Item, $ParamItem)
            }
        }
        #Region Parameter
        $RegionAttribute = New-Object System.Management.Automation.ParameterAttribute
        $RegionAttribute.Mandatory = $true
        $regionAttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $regionAttributeCollection.Add($RegionAttribute)
        # Generate and set the ValidateSet
        $regionSet = New-Object -TypeName System.Collections.ArrayList
        foreach ($item in ([xml](Get-Content -Raw -Path (Join-Path -Path $AnalysisPackPath -Child "userconnections.xml"))).ArrayOfServerDescriptionBase.ServerDescriptionBase)
        {$regionSet.Add($item.Name) | Out-Null}
        $regionValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($regionSet.ToArray())
        $regionAttributeCollection.Add($regionValidateSetAttribute)
        $regionParamItem = New-Object System.Management.Automation.RuntimeDefinedParameter('TargetConnection', [string], $regionAttributeCollection)
        $paramDictionary.Add('TargetConnection', $regionParamItem)

        #Template Parameter
        if ($dyParams.TemplateFile)
        {
            $TemplateAttribute = New-Object System.Management.Automation.ParameterAttribute
            $templateAttribute.Mandatory = $false
            $templateAttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $templateAttributeCollection.Add($TemplateAttribute)
            # Generate and set the ValidateSet
            $templateSet = Get-ChildItem (Join-Path -Path $AnalysisPackPath -Child "templates");
            $templateValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($templateSet)
            $templateAttributeCollection.Add($templateValidateSetAttribute)
            $templateParamItem = New-Object System.Management.Automation.RuntimeDefinedParameter('Template', [string[]], $templateAttributeCollection)
            $paramDictionary.Add('Template', $templateParamItem)
        }
        return $paramDictionary
    }

    process {
        $cslParams = New-Object -TypeName PSObject;
        $BaseTemplates = "";
        #Testing the pack
        try {
            $TestResult = Test-PSAdxAnalysisPack -Path $AnalysisPackPath -ErrorAction Stop; 
            $cslParams = $TestResult.Parameters
            if ($TestResult.TemplateFile)
            {
                $BaseTemplates = Get-ChildItem -Path (Join-Path -Path $AnalysisPackPath -Child "templates");
            }
        }
        catch {
            #Pack not valid
        }

        #Import analyze method from analysis pack
        . (Join-Path -Path $AnalysisPackPath -Child "analyze.ps1" -Resolve);

        # Ensure output folder exists
        $OutputPath = Join-Path -Path $AnalysisPackPath -ChildPath "Output";
        if (-Not (Test-Path -Path $OutputPath -PathType Container)) {New-Item -Path $OutputPath -ItemType Directory -Force -ErrorAction SilentlyContinue};

        $cleanOuputFolder = {
            Param 
            (
                [int]$DaysToRetain
            )
            $dateToDelete = (Get-Date).AddDays($DaysToRetain * -1);
            Get-ChildItem (Join-Path -Path $AnalysisPackPath -Child "output") | Where-Object{$_.LastWriteTime -lt $dateToDelete} | Remove-Item -ErrorAction SilentlyContinue;
        }
        #Get all connections for population
        $AllConnections = ([xml](Get-Content -Raw -Path (Join-Path -Path $AnalysisPackPath -Child "userconnections.xml"))).ArrayOfServerDescriptionBase.ServerDescriptionBase;
        $queryTargetConnection = $PSBoundParameters.TargetConnection;
        $passingParam = @{};
        foreach ($item in $cslParams)
        {
            if ($PSBoundParameters.ContainsKey($item))
            {$passingParam.Add($item, $PSBoundParameters.Item($item))}
        }
        $ExecuteQuery = {
            Param (
                $ConnectionName
            )
            $FullConnectionString = ($this.Connections | Where-Object {$_.Name -eq $ConnectionName}).ConnectionString
            Invoke-PSAdxQuery -ConnectionString $FullConnectionString -DatabaseName ($FullConnectionString | Select-String -Pattern "Catalog\=(\w*)").Matches.Groups[1].Value -Query $this.QueryText -QueryParameters $this.Parameters;
        };

        $props = @{
            AnalysisPackPath = $AnalysisPackPath;
            ReferenceId = $ReferenceId;
            OutputPath = "$OutputPath";
            Template = $(try {$PSBoundParameters.Template} catch {});
            Templates = $BaseTemplates;
            Connections = $AllConnections;
            TargetConnection = $queryTargetConnection;
            Queries = Get-ChildItem (Join-Path -Path $AnalysisPackPath -Child "queries") | ForEach-Object {
                $props = @{
                    Name = $_.BaseName;
                    QueryText = Get-Content -Raw -Path $_.FullName;
                    Connections = $AllConnections;
                    TargetConnection = $queryTargetConnection;
                    Parameters = $passingParam
                };
                $queryObject = New-Object -TypeName PSObject -Property $props;
                $queryObject | Add-Member -Name Execute -MemberType ScriptMethod -Value $ExecuteQuery;
                #Setting visiable properties.
                $visibleproperties = @('Name', 'QueryText');
                $defaultDisplayPropertySet = New-Object -TypeName System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]$visibleproperties);
                $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet);
                $queryObject | Add-Member -MemberType MemberSet -Name PSStandardMembers -Value $PSStandardMembers;
                return $queryObject;
                };
        }
        $outObject = New-Object -TypeName PSObject -Property $props;
        $outObject | Add-Member -Name Parameters -MemberType NoteProperty -Value $passingParam;
        $outObject | Add-Member -Name Analyze -MemberType ScriptMethod -Value $analyze;
        $outObject | Add-Member -Name CleanOuputFolder -MemberType ScriptMethod -Value $cleanOuputFolder;
        
        #Remove old items from the output folder (doing this for the user every time)
        $outObject.CleanOuputFolder(90);

        #Run the analysis
        $outObject.Analyze()

        return $outObject;
    }
}


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

#Function to validate an analysis pack
function Test-PSAdxAnalysisPack {
    [CmdletBinding()]
    param (
        # Path to the analysis pack
        [Parameter(Mandatory=$true)]
        [String]$Path
    )
    
    begin {
        #Validate that the path exist and is a folder
        if (-Not (Test-Path -Path $Path -PathType Container)) {
            Write-Error -Message "Path to analysis pack invalid. The provided path must be a valid folder/directory." -ErrorAction Stop
        }
        $outputObject = New-Object -TypeName PSObject -Property @{};
    }
    
    process {

        #region Critical Items
        #Validate the analyze.ps1 script exist in the root of the analysis pack.
        if (Test-Path -Path (Join-Path -Path $Path -ChildPath "analyze.ps1") -PathType Leaf) {
            $outputObject | Add-Member -NotePropertyName "AnalyzeScript" -NotePropertyValue $true;
        }
        else {
            $outputObject | Add-Member -NotePropertyName "AnalysisScript" -NotePropertyValue $false;
        }

        #Valdate that userconnections.xml exists
        if (Test-Path -Path (Join-Path -Path $Path -ChildPath "userconnections.xml") -PathType Leaf) {
            $outputObject | Add-Member -NotePropertyName "UserConnections" -NotePropertyValue $true;
        }
        else {
            $outputObject | Add-Member -NotePropertyName "UserConnections" -NotePropertyValue $false;
        }

        #Validate that the Queries folder exist in the pack.
        if (Test-Path -Path (Join-Path -Path $Path -ChildPath "queries") -PathType Container) {
            $outputObject | Add-Member -NotePropertyName "QueriesFolder" -NotePropertyValue $true;
        }
        else {
            $outputObject | Add-Member -NotePropertyName "QueriesFolder" -NotePropertyValue $false;
        }
        
        #Validate that at least one csl script exist in the Queries folder.
        try 
        {
            if ((Get-ChildItem -Path (Join-Path -Path $Path -ChildPath "queries") -Name *.csl -ErrorAction Stop).Count -gt 0) {
                $outputObject | Add-Member -NotePropertyName "CSLFile" -NotePropertyValue $true;
            }
            else {
                $outputObject | Add-Member -NotePropertyName "CSLFile" -NotePropertyValue $false;
            }
        }
        catch {$outputObject | Add-Member -NotePropertyName "CSLFile" -NotePropertyValue $false;}   

        #endregion

        #region Non-Critical Items
        #Validate Templates folder exists
        if (Test-Path -Path (Join-Path -Path $Path -ChildPath "templates") -PathType Container) {
            $outputObject | Add-Member -NotePropertyName "TemplatesFolder" -NotePropertyValue $true;
        }
        else {
            $outputObject | Add-Member -NotePropertyName "TemplatesFolder" -NotePropertyValue $false;
        }

        #Validate that there is at least one template (any file)
        try 
        {
            if ((Get-ChildItem -Path (Join-Path -Path $Path -ChildPath "templates") -Name *.* -ErrorAction Stop).Count -gt 0) {
                $outputObject | Add-Member -NotePropertyName "TemplateFile" -NotePropertyValue $true;
            }
            else {
                $outputObject | Add-Member -NotePropertyName "TemplateFile" -NotePropertyValue $false;
            }
        }
        catch {$outputObject | Add-Member -NotePropertyName "TemplateFile" -NotePropertyValue $false;}

        #endregion

        #region Additional Items
        #List Required Parameters in CSL queries
        if ($outputObject.CSLFile)
        {
            $foundParams = New-Object -TypeName System.Collections.ArrayList
            foreach ($item in Get-ChildItem -Path (Join-Path -Path $Path -ChildPath "queries") -Name *.csl -ErrorAction Stop)
            {
                ## Regex to get parameters from file
                foreach ($paramater in (Get-PSAdxCSLParameter -Path $item.PSPath))
                {
                    $foundParams.Add($paramater) | Out-Null;
                }
            }
            $outputObject | Add-Member -NotePropertyName "Parameters" -NotePropertyValue ($foundParams | Select-Object -Unique);
        }
        else {
            $outputObject | Add-Member -NotePropertyName "Parameters" -NotePropertyValue "None";
        }

        #endregion
    }
    
    end {
        if ($outputObject.AnalyzeScript -eq $false -OR $outputObject.UserConnections -eq $false -OR $outputObject.QueriesFolder -eq $false -OR $outputObject.CSLFile -eq $false)
        {
            $outputObject | Add-Member -NotePropertyName "Result" -NotePropertyValue $false;
            Write-Error -Message "The provided analysis pack at $($PSBoundParameters.Path.ToString()) is not valid."
        }
        else {$outputObject | Add-Member -NotePropertyName "Result" -NotePropertyValue $true;}
        return $outputObject;
    }
}