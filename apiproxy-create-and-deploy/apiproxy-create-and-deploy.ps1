param(
  [switch]$help,
  [string]$oasfile,
  [string]$oasurl,
  [string]$org,
  [string]$env,
  [string]$apiName,
  [string]$basePath,
  [bool]$oauth
)

# -help option for this script
if ($help) {
    Write-Host ""
    Write-Host ""
    Write-Host "Usage: <path to script>/apiproxy-create-and-deploy.ps1 [options]"
    Write-Host ""
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -help:                 [Optional] Displays this help message."
    Write-Host ""
    Write-Host "  -oasfile or -oasurl:   [Required] Absolute path to local file (.json or .yaml) or URL path"
    Write-Host "                                    to the Open API Spec for the API Proxy to be created."
    Write-Host ""
    Write-Host "  -org:                  [Required] Apigee X/Hybrid Organization where the API Proxy is to be created."
    Write-Host ""
    Write-Host "  -env:                  [Required] Apigee X/Hybrid Environment within an Organization where"
    Write-Host "                                    the API Proxy is to be created."
    Write-Host ""
    Write-Host "  -apiName:              [Required] Name of the API Proxy to be created."
    Write-Host ""
    Write-Host "  -basePath:             [Optional] URL Base Path of the API Proxy to be created. For example /v1/api." 
    Write-Host "                                    If this option is not provided, base path set according to details"
    Write-Host "                                    in Open API Spec provided."
    Write-Host ""
    Write-Host "  -oauth:                [Optional] When set to $true will add a Verify Access Token OAuth 2 policy" 
    Write-Host "                                    to the generated API proxy. When not provided, the openapi2apigee"
    Write-Host "                                    tool will determine whether or not to add the policy based on the"
    Write-Host "                                    Open API Spec provided."
    Write-Host ""
    Write-Host ""
    Write-Host "Note: If you would like to register this script as a command, use:"
    Write-Host ""
    Write-Host "            Register-Script -Name <script_name> -Path <script_path>"
    Write-Host ""
    exit
}

Write-Host "Starting script..."

# Check if gcloud is installed
Write-Host "Checking if gcloud is installed..."
$gcloudCmd = "gcloud"
if (!(Get-Command $gcloudCmd)) {
    Write-Error "The gcloud command is not installed! To install please execute: Install-Module GoogleCloud"
    exit
}

# Check if the latest openapi2apigee tool is installed
Write-Host "Checking if openapi2apigee is installed..."
$openapi2apigeeCmd = "openapi2apigee"
if (!(Get-Command $openapi2apigeeCmd)) {
    Write-Error "The openapi2apigee tool is not installed! To install please execute: npm install -g openapi2apigee"
    exit
}

# Check if the latest apigeecli tool is installed
Write-Host "Checking if apigeecli is installed..."
$apigeecliCmd = "apigeecli"
if (!(Get-Command $apigeecliCmd)) {
    Write-Error "The apigeecli tool is not installed! To install, please download the appropriate binary for your OS here: https://github.com/apigee/apigeecli/releases. Then, extract the .zip and append the extracted folder to your powershell PATH."
    exit
}

# Check that at least one of -oasurl or -oasfile is provided
if (($oasfile -eq "" -or $oasfile -eq $null) -and ($oasurl -eq "" -or $oasurl -eq $null)) {
    Write-Error "Please provide -oasfile or -oasurl!"
    exit
}

#Check to see if spec exists at provided -oasurl or -oasfile
if (($oasfile -ne "" -and $oasfile -ne $null)) {
    if (!(Test-Path -Path $oasfile)) {
        Write-Error "Open API Spec not found at $oasfile! Please provide the correct Open API Spec file path."
        exit
    }
} else {
    $oasUrlResponse = curl $oasurl -o /dev/null -w "%{http_code}"
    $oasUrlResponseStatusCode = $oasUrlResponse.Trim()

    if ($oasUrlResponseStatusCode -eq "200") {
        Write-Host "Open API Spec found at $oasurl ..."
    } else {
        Write-Error "Open API Spec not found at $oasurl! The request failed with status code $statusCode. Please provide the correct Open API Spec URL."
        exit
    }
}

# Check if -org is provided
if ($org -eq "" -or $org -eq $null) {
    Write-Error "-org script param missing!"
    exit
}
Write-Host "The Apigee Organization ID set to: $org"

# Check if -env is provided
if ($env -eq "" -or $env -eq $null) {
    Write-Error "-env script param missing!"
    exit
}

# Check if -apiName is provided
if ($apiName -eq "" -or $apiName -eq $null) {
    Write-Error "-apiName script param missing!"
    exit
}


try {
    Write-Host "Logging into gcloud..."
    gcloud auth login

    # Write-Host "Initializing gcloud..."
    # gcloud init

    Write-Host "Generating gcloud access token..."
    $token=$(gcloud auth print-access-token)
    # apigeecli token cache -t $token
    Write-Host "gcloud access token generated: $token"

    # Setting correct environment
    $okayToDeploy = $false
    while ($okayToDeploy -eq $false) {
        Write-Host ""
        $envReplicasExist = Read-Host -Prompt "Are there multiple $env environments in your Apigee Organization $org? [Y/N]"
        Write-Host ""
        if ($envReplicasExist -eq "N") {
            $envSet = $env
            [String]$envAPIListOutput = curl -X GET https://apigee.googleapis.com/v1/organizations/$org/environments/$envSet/deployments -H "Authorization: Bearer $token"
            $envAPIListOutputJson = ConvertFrom-Json $envAPIListOutput
            [String]$envSFListOutput = curl -X GET https://apigee.googleapis.com/v1/organizations/$org/environments/$envSet/deployments?sharedFlows=true -H "Authorization: Bearer $token"
            $envSFListOutputJson = ConvertFrom-Json $envSFListOutput
            $totalEnvDeploymentsCount = $envAPIListOutputJson.deployments.Count + $envSFListOutputJson.deployments.Count
            if ($totalEnvDeploymentsCount -lt 60) {
                    $okayToDeploy = $true
            } else {
                Write-Error "Sorry, 60 deployment limit exhausted in environment $envSet. Please try another environment."
                exit
            }
        } elseif ($envReplicasExist -eq "Y") {
            $envNumber = [int]0
            while ($okayToDeploy -eq $false) {
                $envNumber++
                $envSet = $env + "-" + $envNumber
                [String]$envAPIListOutput = curl -X GET https://apigee.googleapis.com/v1/organizations/$org/environments/$envSet/deployments -H "Authorization: Bearer $token"
                $envAPIListOutputJson = ConvertFrom-Json $envAPIListOutput
                [String]$envSFListOutput = curl -X GET https://apigee.googleapis.com/v1/organizations/$org/environments/$envSet/deployments?sharedFlows=true -H "Authorization: Bearer $token"
                $envSFListOutputJson = ConvertFrom-Json $envSFListOutput
                $totalEnvDeploymentsCount = $envAPIListOutputJson.deployments.Count + $envSFListOutputJson.deployments.Count
                if ($totalEnvDeploymentsCount -lt 60) {
                    $okayToDeploy = $true
                }
            }
        } else {
            Write-Error "Please enter [Y/N] only!"
        }
    }
    
    Write-Host "The Apigee Environment is set to: $envSet"
} catch {
    Write-Error "Something went wrong!"
    exit
}

try {
    # <current folder>/$apiName/apiproxy.zip
    $apiBundlePath = "./" + $apiName + "/apiproxy.zip"
    Write-Host "Creating API Proxy bundle locally at: $apiBundlePath ..."
    if ($oasurl -ne "" -and $oasurl -ne $null) {
        
        Write-Host "Open API Spec located at: $oasurl"
        
        # Generates apiproxy.zip bundle at <current folder>/$apiName/apiproxy.zip
        if ($basePath -ne "" -and $basePath -ne $null) {
            if ($oauth) {
                openapi2apigee generateApi $apiName -s $oasurl -d . --oauth=true -B $basePath
            } else {
                openapi2apigee generateApi $apiName -s $oasurl -d . -B $basePath
            }
        } else {
            if ($oauth) {
                openapi2apigee generateApi $apiName -s $oasurl -d . --oauth=true 
            } else {
                openapi2apigee generateApi $apiName -s $oasurl -d . 
            }
        }
    } else {
       
        Write-Host "Open API Spec located at: $oasfile"
        
        # Generates apiproxy.zip bundle at <current folder>/$apiName/apiproxy.zip
        if ($basePath -ne "" -and $basePath -ne $null) {
            if ($oauth) {
                openapi2apigee generateApi $apiName -s $oasfile -d . --oauth=true -B $basePath
            } else {
                openapi2apigee generateApi $apiName -s $oasfile -d . -B $basePath
            }
        } else {
            if ($oauth) {
                openapi2apigee generateApi $apiName -s $oasfile -d . --oauth=true 
            } else {
                openapi2apigee generateApi $apiName -s $oasfile -d . 
            }
        }
    }
            
    Write-Host "Creating API Proxy $apiName in Apigee Organization $org ..."
    # Create the API Proxy in the organization specified
    apigeecli apis create bundle -n $apiName -p $apiBundlePath -o $org -t $token

    Write-Host "Attempting to deploy the latest revision of API proxy $apiName to Apigee Environment $envSet ..."
            
    # Deploy the API proxy to the environment
    apigeecli apis deploy -o $org -e $envSet -n $apiName -t $token   
    # apigeecli apis deploy -o $org -e prod -n $apiName -t $token   
    
}
catch {
    Write-Error "Something went wrong!"
    exit
}

Write-Host "Script complete!"