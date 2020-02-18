# PSAdx Module
PowerShell module for accessing data stored in Azure Data Explorer (ADX).

## Usage
```PowerShell
Invoke-PSAdxQuery
        -ConnectionString <string>
        -DatabaseName <string>
        -Query <string>
        -QueryParameters <hashtable>

Get-PSAdxCSLParameter -Path <string>
```

## Where to get it
PSAdx is published to the [PowerShell Gallery](https://www.powershellgallery.com/packages/PSAdx/)

## Changelog
v0.2
This release should be considered the new baseline for the module as much of the original functionality has been moved to a new project, AutoReport (coming soon).