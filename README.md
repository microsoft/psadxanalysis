# PSAdx Module
The PSAdx module will allow one to automate the extraction, analysis, and output formatting of data stored in Azure Data Explorer (ADX).

## Installation
For this 

## Concepts
Though you can merely use the module to execute KQL queries via PowerShell, concepts have been created to allow you to create custom output of multiple queries in a single call.  This is achieved via the concept of an AnalysisPack which is instantiated by calling the cmdlet `Invoke-PSAdxAnalysisPack`.
### AnalysisPack
The AnalysisPack is the primary object with which you will interact.  The AnalysisPack is technically a specific folder structure that contains the queries, templates, and custom script to process the data.
### Query
A Query is the lifeblood of the AnalysisPack.  Practically, the Query is simply a Kusto Query Language (KQL) query file stored in the "queries" subfolder of the AnalysisPack as a .csl file.  A query can have parameters passed to it by utilizing `declare query_parameters(<variable_name>:<data_type>);` at the beginning of the query.
### Template
A Template is an optional feature of an AnalysisPack which can be utilized when creating your the output.  Templates would typically be used for output types for which a formatted, baseline template has been created for which only data sets need to be injected to create the final output.  Excel output is the primary example for utilizing a Template, but
### Connection
Inside the AnalysisPack, you must define the full list of possible connections available to the analysis pack.  When a user calls Invoke-PSAdxAnalysisPack cmdlet, the optional -TargetConnection parameter is pulled from and validated against this definition.  You can then use the the -TargetConnection in your custom analysis script to only run scripts against a particular connection(s).  If no parameter is specified, Invoke-PSAdxAnalysisPack will pass all connections defined in the AnalysisPack.
### Custom analysis
The power of the AnalysisPack is in the ability for you, as an AnalysisPack author, to create a custom extension by which to process the queries, utilize templates, and generate the output desired.  This capability is exposed via the Analyze method of the AnalysisPack object.  This method is automatically called upon execution of Invoke-PSAdxAnalysisPack, but can be called again if the returned object is stored in a variable.

## Create your own AnalysisPack
Coming soon . . .

# Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
