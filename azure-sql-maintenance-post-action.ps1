[OutputType("PSAzureOperationResponse")]
param
(
    [Parameter (Mandatory=$false)]
    [object] $WebhookData
)

#$WebhookData = @{
#    RequestBody = '{
#        "data": {
#            "context": {
#                "activityLog": {
#                    "operationName": "Microsoft.ServiceHealth/maintenance/action",
#                    "properties": {
#                        "region": "eastus",
#                        "argQuery": "maintenanceresources | where type == \"microsoft.maintenance/updates\" | extend p = parse_json(properties) | mvexpand d = p.value | where d has \"notificationId\" and d.notificationId == \"9L34-T_8\" | extend targetResourceId = tolower(name), status = d.status, plannedMaintenanceId = d.notificationId | join kind=inner (resources | extend targetRegion = location, targetResourceId = tolower(id), targetResourceName = name, targetResourceGroup = resourceGroup, subscriptionId, targetResourceType = type) on targetResourceId"
#                   },
#                    "authorization": {
#                        "action": "Microsoft.ServiceHealth/maintenance/action"
#                    }
#                }
#            }
#        }
#    }'
#}

Import-Module Az.Accounts
Import-Module Az.ResourceGraph

function ConnectWithManagedIdentity {
    Write-Verbose "ConnectWithManagedIdentity function has been initiated."
    # Define the managed identity client ID as a fixed variable
    $identityClientId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx" # Replace with the actual client ID

    try {
        Connect-AzAccount -Identity -AccountId $identityClientId
        Write-Verbose "Successfully connected to Azure using managed identity."
    } catch {
        Write-Verbose "Failed to connect to Azure: $_"
        exit 1
    }

    # Get the current Azure context
    $context = Get-AzContext

    # Check if the context is retrieved correctly
    if ($null -eq $context) {
        Write-Verbose "Failed to retrieve Azure context."
        exit 1
    } else {
        # Retrieve the subscription ID and name
        $subscriptionId = $context.Subscription.Id
        $subscriptionName = $context.Subscription.Name

        # Output the current context
        Write-Verbose "Current context: Subscription ID [$subscriptionId], Subscription Name [$subscriptionName]"
    }

    return $context
}

if ($WebhookData)
{

    # Connect to Azure using the managed identity
    $scriptContext = ConnectWithManagedIdentity
    if ($scriptContext) {
        Write-Output "Successfully connected to account."
    }
    else {
        Write-Output "Failed to retrieve GUID for the account."
    }

    # Get the data object from WebhookData
    $WebhookBody = (ConvertFrom-Json -InputObject $WebhookData.RequestBody)
    $operationName = $WebhookBody.data.context.activityLog.operationName
    $region = $WebhookBody.data.context.activityLog.properties.region
    $argQuery = $WebhookBody.data.context.activityLog.properties.argQuery
    
    if ($operationName -eq "Microsoft.ServiceHealth/maintenance/action") {
        Write-Output "Region: $region"
        Write-Output "ARG Query: $argQuery"

        if (-not $argQuery) {
            Write-Error "ARG Query is not provided in the webhook data."
            exit
        }
        
        # Execute the ARG query
        $results = Search-AzGraph -Query $argQuery

        # Output the impacted resources
        $results | ForEach-Object {
            Write-Output "Resource Object: $_"
            Write-Output "Subscription ID: $($_.subscriptionId)"
            Write-Output "Target Resource Group: $($_.resourceGroup)"
            Write-Output "Target Resource Name: $($_.targetResourceName)"
            Write-Output "Target Resource ID: $($_.targetResourceId)"
            Write-Output "Resource Location: $($_.location)"
            Write-Output "-----------------------------------"
        }
    } else {
        $action = $WebhookBody.data.context.activityLog.authorization.action
        Write-Output "Action: $action"
    }
} else {
    # Error
    Write-Error "This runbook is meant to be started from a Service health alert webhook only."
}