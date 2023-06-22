# README

## **Script: apiproxy-create-and-deploy.ps1**
### Prerequisites
This script assumes that you already have the tools gcloud, openapi2apigee and apigeecli installed and accessible via PowerShell.
* To install the gcloud CLI: [https://cloud.google.com/sdk/docs/install](https://cloud.google.com/sdk/docs/install)
* To install the openapi2apigee tool: [https://github.com/apigee/openapi2apigee](https://github.com/apigee/openapi2apigee)
* To install the apigeecli tool: [https://github.com/apigee/openapi2apigee](https://github.com/apigee/apigeecli)

### Usage
Download/Clone this repository and navigate to the ```apiproxy-create-and-deploy``` folder in your PowerShell. Then, to use the script, run:

```<path to script>/apiproxy-create-and-deploy.ps1 [Options]```


### Options:
```
  -help:                 [Optional] Displays a help message.

  -oasfile or -oasurl:   [Required] Absolute path to local file (.json or .yaml) or URL path
                                    to the Open API Spec for the API Proxy to be created.

  -org:                  [Required] Apigee X/Hybrid Organization where the API Proxy is to be created.

  -env:                  [Required] Apigee X/Hybrid Environment within an Organization where
                                    the API Proxy is to be created.

  -apiName:              [Required] Name of the API Proxy to be created.

  -basePath:             [Optional] URL Base Path of the API Proxy to be created. For example /v1/api.
                                    If this option is not provided, base path set according to details
                                    in Open API Spec provided.

  -oauth:                [Optional] When set to True will add a Verify Access Token OAuth 2 policy
                                    to the generated API proxy. When not provided, the openapi2apigee
                                    tool will determine whether or not to add the policy based on the
                                    Open API Spec provided.
```
