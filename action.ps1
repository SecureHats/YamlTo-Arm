<#
    Title:          YamlTo-ARM Converter
    Language:       PowerShell
    Version:        1.0
    Author:         Rogier Dijkman
    Last Modified:  04/07/2023

    DESCRIPTION
    This GitHub action is used to convert Yaml Sentinel Detections to deployable ARM templates.

#>

param (
    [Parameter(Mandatory = $true)]
    [string]$FilesPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [string]$SingleFile,

    [Parameter(Mandatory = $false)]
    [string]$returnObject
        
)

try {
    Write-Verbose "Importing Helper Module"
    Import-Module "$($PSScriptRoot)/modules/HelperFunctions.psm1"
} catch {
    Write-Error $_.Exception.Message
    break
}

#Type casting required because of limitation GitHub action input

if ($SingleFile -eq 'true'){ $singleFile = $true }
if ($ReturnObject -eq 'true'){ $returnObject = $true }

# Starting Conversion of files
$hashTable = @{
    FilesPath    = $FilesPath
    OutputPath   = $OutputPath
    SingleFile   = $singleFile
    ReturnObject = $returnObject
}

Convert-YamlToArm @hashTable
