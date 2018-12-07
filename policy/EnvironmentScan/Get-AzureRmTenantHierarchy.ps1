# Access Token Function grabbed from 'https://gallery.technet.microsoft.com/scriptcenter/Easily-obtain-AccessToken-3ba6e593'
Function Get-AzureRmCachedAccessToken() {
    $ErrorActionPreference = 'Stop'
  
    if (-not (Get-Module AzureRm.Profile)) {
        Import-Module AzureRm.Profile
    }
    $azureRmProfileModuleVersion = (Get-Module AzureRm.Profile).Version
    # refactoring performed in AzureRm.Profile v3.0 or later
    if ($azureRmProfileModuleVersion.Major -ge 3) {
        $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
        if (-not $azureRmProfile.Accounts.Count) {
            Write-Error "Ensure you have logged in before calling this function."    
        }
    }
    else {
        # AzureRm.Profile < v3.0
        $azureRmProfile = [Microsoft.WindowsAzure.Commands.Common.AzureRmProfileProvider]::Instance.Profile
        if (-not $azureRmProfile.Context.Account.Count) {
            Write-Error "Ensure you have logged in before calling this function."    
        }
    }
  
    $currentAzureContext = Get-AzureRmContext
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
    Write-Debug ("Getting access token for tenant" + $currentAzureContext.Subscription.TenantId)
    $token = $profileClient.AcquireAccessToken($currentAzureContext.Subscription.TenantId)
    $token.AccessToken
}

# Function for calling Management Group Details
Function Get-AzureRmManagementGroupDetails {
    Param(
        [Parameter(Mandatory = $false, HelpMessage = "The Management Group Name to grab details about. If empty, Tenant Root Group will be used.")]
        [String] $ManagementGroupName = '',
        
        [Parameter(Mandatory = $false, HelpMessage = "Set to true to include details about the Child scopes.")]
        [switch] $expandChildren = $false,

        [Parameter(Mandatory = $false, HelpMessage = "Set to true to include details about the Child scopes.")]
        [switch] $recurse = $false,

        [Parameter(Mandatory = $false, HelpMessage = "The API version for the REST Endpoint.")]
        [ValidateSet("2018-03-01-preview")] 
        [String] $apiVersion = '2018-03-01-preview',

        [Parameter(Mandatory = $false, HelpMessage = "Items to exclude from response.")]
        [ValidateSet('', 'subscriptions')]
        [String] $filter = '',

        [Parameter(Mandatory = $true, HelpMessage = "The bearer token to make the request.")]
        $accessToken
    )

    # Switch to Tenant Root Group if null
    If($ManagementGroupName -eq ''){
        Try{
            $context = Get-AzureRmContext
            $ManagementGroupName = $context.Tenant.Id
        }
        Catch{
            Throw "Context could not be found. Please use Connect-AzureRmAccount to authenticate."
        }
    }

    # Filter Maps
    $filterMap = @{
        "subscriptions" = 'children.childType ne Subscription'
    }

    # Translate Filter to Map
    $FilterQuery = $filterMap.$filter

    # Create Headers
    $headers = @{}
    $headers.Add("Authorization", "Bearer $accessToken")
    $headers.Add("Cache-Control", "no-cache")

    # Build URI
    $uri = 'https://management.azure.com/providers/Microsoft.Management/managementGroups/'
    $uri += $ManagementGroupName
    $uri += '?api-version='
    $uri += $apiVersion
    If($expandChildren){
        $uri += '&$expand=children'
    }
    If($recurse){
        $uri += '&$recurse=true'
    }
    If($null -ne $FilterQuery){
        $uri += '&$filter='
        $uri += "$FilterQuery"
    }

    # Make REST Call
    $body = Invoke-RestMethod -Method GET -Uri $uri -Headers $headers
    return $body
}