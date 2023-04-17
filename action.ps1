<#
    Title:          Template for GitHub Action
    Language:       PowerShell
    Version:        1.0
    Author:         Rogier Dijkman
    Last Modified:  04/07/2023

    DESCRIPTION
    This GitHub action is used to ...

#>

Import-Module "$($PSScriptRoot)/modules/HelperFunctions.psm1"

param (
    [Parameter(Mandatory = $true)]
    [string]$FilesPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
        
)

$data = YamlTo-Arm -FilesPath $FilesPath