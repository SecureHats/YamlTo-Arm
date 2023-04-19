function Convert-YamlToArm {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilesPath,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [switch]$SingleFile,

        [Parameter(Mandatory = $false)]
        [switch]$returnObject  
    )

    #Region Install Modules
    $modulesToInstall = @(
        'powershell-yaml'
    )

    $modulesToInstall | ForEach-Object {
        if (-not (Get-Module -ListAvailable -All $_)) {
            Write-Output "Module [$_] not found, INSTALLING..."
            Install-Module $_ -Force
            Import-Module $_ -Force
        }
    }
    #EndRegion Install Modules

    #Region Fetching AlertRules
    try {
        $analyticsRules = Get-ChildItem -Path $FilesPath -Include "*.yaml", "*.yml" -Recurse
    } catch {
        Write-Error $_.Exception.Message
        break
    }
    #EndRegion Fetching AlertRules

    #Region Processing AlertRules
    $result = @()
    if ($null -ne $analyticsRules) {
        foreach ($rule in $analyticsRules) {
            try {
                $ruleObject = get-content $rule | ConvertFrom-Yaml
                switch ($ruleObject.kind) {
                    "MicrosoftSecurityIncidentCreation" {  
                        $body = @{
                            "kind"       = "MicrosoftSecurityIncidentCreation"
                            "properties" = @{
                                "enabled"       = "true"
                                "productFilter" = $ruleObject.productFilter
                                "displayName"   = $ruleObject.displayName
                            }
                        }
                    }
                    "Scheduled" {
                        $body = [pscustomobject]@{
                            "kind"       = "Scheduled"
                            "properties" = @{
                                "displayName"              = $ruleObject.name
                                "description"              = $ruleObject.description
                                "severity"                 = $ruleObject.severity
                                "enabled"                  = $true
                                "query"                    = $ruleObject.query
                                "queryFrequency"           = ConvertTo-ISO8601 $ruleObject.queryFrequency
                                "queryPeriod"              = ConvertTo-ISO8601 $ruleObject.queryPeriod
                                "triggerOperator"          = Convert-TriggerOperator $ruleObject.triggerOperator
                                "triggerThreshold"         = $ruleObject.triggerThreshold
                                "suppressionDuration"      = "PT5M"
                                "suppressionEnabled"       = $false
                                "tactics"                  = $ruleObject.tactics
                                "techniques"               = $ruleObject.relevantTechniques
                                "alertRuleTemplateName"    = $ruleObject.id
                                "entityMappings"           = $ruleObject.entityMappings
                                "incidentConfiguration"    = $ruleObject.incidentConfiguration
                                "sentinelEntitiesMappings" = $ruleObject.sentinelEntitiesMappings
                                "eventGroupingSettings"    = $ruleObject.eventGroupingSettings
                                "templateVersion"          = $ruleObject.version
                            }
                        }
                        
                        # Update duration to ISO8601
                        if ($null -ne $ruleObject.incidentConfiguration) {
                            $body.properties.incidentConfiguration.groupingConfiguration.lookbackDuration = ConvertTo-ISO8601 $ruleObject.incidentConfiguration.groupingConfiguration.lookbackDuration
                        }
                    }
                    Default { }
                }
            } catch {
                Write-Error $_.Exception.Message
                break
            }
            if ($SingleFile) {
                $result += ConvertTo-ArmResource -value $body
            } else {
                ConvertTo-ARM -value $body -outputFile ('{0}/{1}.json' -f ($($rule.DirectoryName), $($rule.BaseName))) -returnObject $returnObject
            }
        }
        if ($SingleFile) {
            ConvertTo-ARM -value $result -outputFile ('{0}/{1}.json' -f ($($rule.DirectoryName), 'deployment')) -singleFile $true -returnObject $returnObject
        }
    }
    #EndRegion Processing AlertRules
}

#Region HelperFunctions
function Convert-TriggerOperator {
    param (
        [Parameter(Mandatory = $true)]
        [string]$value
    )

    switch ($value) {
        "gt" { $value = "GreaterThan" }
        "lt" { $value = "LessThan" }
        "eq" { $value = "Equal" }
        "ne" { $value = "NotEqual" }
        default { $value }
    }
    return $value
}

function ConvertTo-ISO8601 {
    param (
        [Parameter(Mandatory = $true)]
        [string]$value
    )

    switch -regEx ($value.ToUpper()) {
        '[hmHM]$' {
            return ('PT{0}' -f $value).ToUpper()
        }
        '[dD]$' {
            return ('P{0}' -f $value).ToUpper()
        }
        default {
            return $value.ToUpper()
        }
    }
}

function ConvertTo-ARM {
    param (
        [Parameter(Mandatory = $true)]
        [object]$value,

        [Parameter(Mandatory = $true)]
        [string]$outputFile,

        [Parameter(Mandatory = $false)]
        [bool]$returnObject,

        [Parameter(Mandatory = $false)]
        [bool]$singleFile = $false

    )

    if ($singleFile) {
        $template = [pscustomobject]@{
            '$schema'      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
            contentVersion = "1.0.0.0"
            parameters     = @{
                workspace     = @{
                    type = "string"
                }
                alertRuleName = [pscustomobject]@{
                    type         = "string"
                    defaultValue = "Multi-Rule deployment"
                }
            }
            resources = $value
        }
    } 
    else {
        $template = [pscustomobject]@{
            '$schema'      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
            contentVersion = "1.0.0.0"
            parameters     = @{
                workspace     = @{
                    type = "string"
                }
                alertRuleName = [pscustomobject]@{
                    type         = "string"
                    defaultValue = "$($value.properties.displayName)"
                }
            }
            resources      = @(
                [pscustomobject]@{
                    id         = "[format('{0}/alertRules/{1}', resourceId('Microsoft.OperationalInsights/workspaces/providers', parameters('workspace'), 'Microsoft.SecurityInsights'), guid(string(parameters('alertRuleName'))))]"
                    name       = "[format('{0}/{1}/{2}', parameters('workspace'), 'Microsoft.SecurityInsights', guid(string(parameters('alertRuleName'))))]"
                    type       = "Microsoft.OperationalInsights/workspaces/providers/alertRules"
                    kind       = "Scheduled"
                    apiVersion = "2021-03-01-preview"
                    properties = $value.properties
                }
            )
        }
    }
    
    if ($returnObject) {
        return $template
    } else {
        $template | ConvertTo-Json -Depth 20 | Out-File $outputFile -ErrorAction Stop
    }
}

function ConvertTo-ArmResource {
    param (
        [Parameter(Mandatory = $true)]
        [object]$value
    )
        $resourceObject      = @(
            [pscustomobject]@{
                id         = "[format('{0}/alertRules/{1}', resourceId('Microsoft.OperationalInsights/workspaces/providers', parameters('workspace'), 'Microsoft.SecurityInsights'), guid(string('$($value.properties.displayName)')))]"
                name       = "[format('{0}/{1}/{2}', parameters('workspace'), 'Microsoft.SecurityInsights', guid(string('$($value.properties.displayName)')))]"
                type       = "Microsoft.OperationalInsights/workspaces/providers/alertRules"
                kind       = "Scheduled"
                apiVersion = "2021-03-01-preview"
                properties = $value.properties
            }
        )
    
     return $resourceObject
}
#EndRegion HelperFunctions
