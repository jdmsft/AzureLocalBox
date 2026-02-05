# Azure Local Box

*Azure Local = Azure Stack HCI*

## My goal

*Reminder: COMPUTERNAME should not exceed 15 chars*

````text
ONPREMSIMULATOR (Azure VM)
├─ ONPREM-HYPERV (Hyper-V VM running Hyper-V VMs)
│  ├─ ONPREM-DC (ADDS DC VM)
├─ ONPREM-AZLOCAL1 (Hyper-V VM runnning Azure Stack HCI OS aka. Azure Local)
├─ ONPREM-AZLOCAL2 (Hyper-V VM runnning Azure Stack HCI OS aka. Azure Local)
````

## Azure Local Box Reverse engineering

### Price 

We use a Standard_E32s_v6 standalone VM (32 vCPUs / 256 GiB RAM).

Windows Server 2025 Datacenter 24H2

USE SPOT VM !!! (see below)

VM Size          | PAYG      | Spot
-----------------|-----------|--------------
Standard_E32s_v6 | $2,889.34 | $533.95 (82%)

### Repository analysis

GitHub repository: https://github.com/microsoft/azure_arc

Subset of files involved in Azure Local deployment at **at deployment time** (via `main.bicepparam`):

````text
artifacts/
├─ PowerShell/
│  ├─ Bootstrap.ps1
│  ├─ 
bicep/
├─ main.bicep
├─ main.bicepparam
````

Subset of files involved in Azure Local deployment **at post-deployment time** (via VM CustomScriptExtension running `Bootstrap.ps1`):

````text
artifacts/
├─ PowerShell/
│  ├─ PSProfile.ps1
│  ├─ LocalBox-Config.psd1
│  ├─ LocalBoxLogonScript.ps1
│  ├─ New-LocalBoxCluster.ps1
│  ├─ Configure-AKSWorkloadCluster.ps1
│  ├─ Configure-VMLogicalNetwork.ps1
│  ├─ Generate-ARM-Template.ps1
│  ├─ WinGet.ps1
│  ├─ Configure-SQLManagedInstance.ps1
│  │  ├─ dsc/
│  │  │  ├─ packages.dsc.yml
│  │  │  ├─ hyper-v.dsc.yml
│  │  ├─ test/
│  │  │  ├─ common.tests.ps1
│  │  │  ├─ azlocal.tests.ps1
│  │  │  ├─ localbox-bginfo.bgi
│  │  │  ├─ Invoke-Test.ps1
├─ LogInstructions.txt
├─ jumpstart-user-secret.yaml
├─ azlocal.json
├─ azlocal.parameters.json
├─ sqlmi.json
├─ sqlmi.parameters.json
├─ dataController.json
├─ dataController.parameters.json
````

### Deployment process

*Deployment time: ~13 min*

1. Get "Azure Stack HCI" Service Principal Object Id with `(Get-AzADServicePrincipal -DisplayName "Microsoft.AzureStackHCI Resource Provider").Id`
2. Edit `azure_jumpstart_localbox\bicep\main.bicepparam` (referencing `azure_jumpstart_localbox\bicep\main.bicep`)
3. Create RG and deploy deploy LocalBox in this RG:

````powershell
New-AzResourceGroup -Name 'LocalBox' -Location 'francecentral'
New-AzResourceGroupDeployment -ResourceGroupName 'LocalBox' -Name 'LocalBox' -Location 'francecentral' -TemplateParameterFile 'D:\Local\TEMP\LocalBox\azure_arc\azure_jumpstart_localbox\bicep\main.bicepparam' -Verbose
````

At this deployment stage, a standalone `Standard_E32s_v6` VM is deployed in Azure with these following settings:
* 1 OS disk Premium LRS of 1 TiB
* 8 data disks Premium LRS of 256 GiB each (no host caching defined) all part of the same Windows Storage Pool on OS side (so 1 Storage Pool of 2 TiB)
* 1 NIC with 1 Public IP
* 1 VNET with 1 Subnet associated to 1 NSG (default rules)

And some addtional resources not used yet:

* 1 Storage Account (empty at this stage - will be referenced in `artifacts/PowerShell/Bootstrap.ps1`)
* 1 Log Analytics workspace (empty at this stage - will be referenced in `artifacts/PowerShell/Bootstrap.ps1`)

Once VM deployed, we can connect directly through Public IP address (when Bastion was not specified) and we can directly see the PowerShell script running (a PowerShell console is open and visible from the remote desktop session).

Post-deploy `Bootstrap.ps1` script logs are accessible in `C:\LocalBox\Logs\Bootstrap.ps1`.

#### Content of the `main.bicep`

Bicep module                | Description
----------------------------|---------------------------------------------------------------------------------------------------------------
`mgmt/mgmtArtifacts.bicep`  | Deploy Log Analytics workspace
`network/network.bicep`     | Deploy VNET (and Bastion if specified)
`mgmt/storageAccount.bicep` | Deploy a GPv2 SA
`host/host.bicep`           | Deploy the VMs used as Hyper-V host + VM CustomScriptExtension located in `artifacts/PowerShell/Bootstrap.ps1`

#### Arguments of VM CustomScriptExtension `artifacts/PowerShell/Bootstrap.ps1`

````bicep
fileUris: [
uri(templateBaseUrl, 'artifacts/PowerShell/Bootstrap.ps1')
]
commandToExecute: 'powershell.exe -ExecutionPolicy Bypass -File Bootstrap.ps1 -adminUsername ${windowsAdminUsername} -adminPassword ${encodedPassword} -tenantId ${tenantId} -subscriptionId ${subscription().subscriptionId} -spnProviderId ${spnProviderId} -resourceGroup ${resourceGroup().name} -azureLocation ${azureLocalInstanceLocation} -stagingStorageAccountName ${stagingStorageAccountName} -workspaceName ${workspaceName} -templateBaseUrl ${templateBaseUrl} -registerCluster ${registerCluster} -deployAKSArc ${deployAKSArc} -deployResourceBridge ${deployResourceBridge} -natDNS ${natDNS} -rdpPort ${rdpPort} -autoDeployClusterResource ${autoDeployClusterResource} -autoUpgradeClusterResource ${autoUpgradeClusterResource} -vmAutologon ${vmAutologon}'
````

### Post-deployment process

*Deployment time: ~1h10*

`Bootstrap.ps1` --> `LocalBoxLogonScript.ps1` (as scheduled task) --> `New-LocalBoxCluster.ps1` --> download and install following VHD files for nested VMs:
 * `https://jumpstartprodsg.blob.core.windows.net/jslocal/localbox/prod/AzLocal2509.vhdx` as `AzL-node.vhdx`
 * `https://jumpstartprodsg.blob.core.windows.net/hcibox23h2/WinServerApril2024.vhdx` as `GUI.vhdx`

3 nested VM are created:

Nested VM | Role                | Template VHD used | vCPU | RAM
----------|---------------------|-------------------|------|------
AzLMGMT   | Managemenet VM      | `GUI.vhdx`        | 20   | 28 GB
AzLHOST1  | Azure Local node VM | `AzL-node.vhdx`   | 20   | 98 GB
AzLHOST2  | Azure Local node VM | `AzL-node.vhdx`   | 20   | 98 GB

At this stage nested VM `AzLHOST1` and `AzLHOST1` are onboarded in Azure Arc (Azure Arc resource added to the initial RG).

Nested VM use the same password as the one provided in `main.bicepparam`.

````text
LocalBox (Azure VM)
├─ AzLMGMT (Hyper-V VM running Hyper-V VMs)
│  ├─ JumpstartDC
│  ├─ Vm-Router
├─ AzLHOST1 (Hyper-V VM runnning Azure Stack HCI OS)
├─ AzLHOST2 (Hyper-V VM runnning Azure Stack HCI OS)
````

#### Error 500 with Install-PSResource

````text
Install-PSResource: 'Response status code does not indicate success: 500 (Internal Server Error)
````

Workaround:

````powershell
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name Az -Scope AllUsers -Force
````