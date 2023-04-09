Function Set-LogAnalyticsData {
    param (
        [Parameter(Mandatory = $true)]
        [string]$workspaceId,

        [Parameter(Mandatory = $true)]
        [securestring]$workspaceKey,

        [Parameter(Mandatory = $true)]
        [array]$body,

        [Parameter(Mandatory = $true)]
        [string]$logType,

        [Parameter(Mandatory = $true)]
        [string]$timestamp
    )

    $properties = @{
        "WorkspaceId"   = $workspaceId
        "WorkspaceKey"  = $workspaceKey
        "contentLength" = $body.Length
        "timestamp"     = $timestamp
    }

    $payload = @{
        "Headers"     = @{
            "Authorization" = Build-Signature @properties
            "Log-Type"      = $logType
            "x-ms-date"     = $timestamp
        }
        "method"      = "POST"
        "contentType" = "application/json"
        "uri"         = "https://{0}.ods.opinsights.azure.com/api/logs?api-version=2016-04-01" -f $workspaceId
        "body"        = $body
    }

    $response = Invoke-WebRequest @payload -UseBasicParsing

    if (-not($response.StatusCode -eq 200)) {
        Write-Warning "Unable to send data to Data Log Collector table"
        break
    }
    else {
        Write-Output "Uploaded to Data Log Collector table [$($logType + '_CL')] at [$timestamp]"
    }
}

Function Build-Signature {
    param (
        [Parameter(Mandatory = $true)]
        [string]$workspaceId,

        [Parameter(Mandatory = $true)]
        [securestring]$workspaceKey,

        [Parameter(Mandatory = $true)]
        [int32]$contentLength,

        [Parameter(Mandatory = $true)]
        [string]$timestamp
    )

        $xHeaders       = "x-ms-date:" + $timestamp
        $stringToHash   = "POST" + "`n" + $contentLength + "`n" + "application/json" + "`n" + $xHeaders + "`n" + "/api/logs"
        $bytesToHash    = [Text.Encoding]::UTF8.GetBytes($stringToHash)
        $keyBytes       = [Convert]::FromBase64String((ConvertFrom-SecureString -SecureString $workspaceKey -AsPlainText))
        $sha256         = New-Object System.Security.Cryptography.HMACSHA256
        $sha256.Key     = $keyBytes
        $calculatedHash = $sha256.ComputeHash($bytesToHash)
        $encodedHash    = [Convert]::ToBase64String($calculatedHash)
        $authorization  = 'SharedKey {0}:{1}' -f $workspaceId, $encodedHash

    return $authorization
}

Function Get-Workspace {
    param (
        [Parameter(Mandatory = $false)]
        [string]$workspaceName
    )

    if (-not([string]::IsNullOrEmpty($workspaceName))) {
        try {
            $workspaceObject = @{
                workspaceId  = ''
                workspaceKey = ''
            }

            Write-Verbose "Connecting to workspace"
            $workspace = Get-AzResource `
                -Name "$workspaceName" `
                -ResourceType 'Microsoft.OperationalInsights/workspaces'

            $ResourceGroupName = $workspace.ResourceGroupName
            $workspaceName = $workspace.Name

            $workspaceObject.workspaceId = (Get-AzOperationalInsightsWorkspace -ResourceGroupName $resourceGroupName -Name $workspaceName).CustomerId.Guid

            Write-Host "Workspace Name: $($workspaceName)"
            Write-Host "Workspace Id: $(workspaceObject.$workspaceId)"

            if ($null -ne $workspace) {
                try {
                    Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

                    $workspaceObject.workspaceKey = `
                    (Get-AzOperationalInsightsWorkspaceSharedKeys `
                            -ResourceGroupName $resourceGroupName `
                            -Name $workspaceName).PrimarySharedKey `
                    | ConvertTo-SecureString -AsPlainText -Force
                }
                catch {
                    Write-Warning -Message "Log Analytics workspace key for [$($workspaceName)] not found."
                    break
                }
            }
            return $workspaceObject
        }
        catch {
            Write-Warning -Message "Log Analytics workspace [$($workspaceName)] not found in the current context"
            break
        }
    }
}

function Send-CustomLogs {
    param (
        [Parameter(Mandatory = $true)]
        [String]$workspaceId,

        [Parameter(Mandatory = $true)]
        [SecureString]$workspaceKey,

        [Parameter(Mandatory = $true)]
        [string]$tableName,

        [Parameter(Mandatory = $true)]
        [array]$dataInput
    )

    $postObject = @{
        "workspaceId"  = $workspaceId
        "WorkspaceKey" = $workspaceKey
        "logType"      = $tableName
        "body"         = ''
        "timestamp"    = ''
    }

    $tempdata = @()
    $tempDataSize = 0

    if ((($dataInput | ConvertTo-Json -depth 20).Length) -gt 25MB) {
        foreach ($record in $dataInput) {
            $tempdata += $record
            $tempDataSize += ($record | ConvertTo-Json -depth 20).Length
            if ($tempDataSize -gt 25MB) {
                $postObject.body = ([System.Text.Encoding]::UTF8.GetBytes(($tempdata | ConvertTo-Json)))
                $postObject.timestamp = [DateTime]::UtcNow.ToString("r")

                Write-Host "Sending block data = $TempDataSize"
                Set-LogAnalyticsData @postObject

                $tempdata = $null
                $tempdata = @()
                $tempDataSize = 0
            }
        }
        $postObject.body = ([System.Text.Encoding]::UTF8.GetBytes(($tempdata | ConvertTo-Json -depth 20)))
        $postObject.timestamp = [DateTime]::UtcNow.ToString("r")

        Write-Host "Sending left over data = $Tempdatasize"
        Set-LogAnalyticsData @postObject

        $tempdata = $null
        $tempdata = @()
        $tempDataSize = 0
    } else {
        $postObject.body = ([System.Text.Encoding]::UTF8.GetBytes(($dataInput | ConvertTo-Json -depth 20)))
        $postObject.timestamp = [DateTime]::UtcNow.ToString("r")
    }

    Write-Host "Sending data to [$($tableName + '_CL')]"
    Set-LogAnalyticsData @postObject
}
