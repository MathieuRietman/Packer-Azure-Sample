# Some Packer Azure Samples

Repository with Packer examples on Azure. [HashiCorp Packer ](https://www.packer.io/) automates the creation of any type of machine image, Packer has standard integration with Azure.

Some use cases for building your own images in Azure are:
- Windows Virtual Desktop Images. Golden image with applicatons installed and custom configuration.
- Linux or Windows machines that are used in Azure Batch or any other HPC scenario.
- Create images for classroom lab for azure Azure Lab Services


<br>
<br>

In this repository there are two sample scripts that are ready to run to automate the creation of images and that can be used in pipelines. When using in pipelines consider the first run manual as this is creating an service principle and assign the rights to the resource group, key vault secrets etc. the pipeline either needs these rights or the first run is manual run that does this. Please also make sure to execute the [deprovision](https://www.packer.io/docs/builders/azure/arm#deprovision) action the image for being able to reuse the image.<br>
<br>
Packer need contributor rights to create images in the resourcegroup specified, via property "build_resource_group_name", or need subscription contributor rights when no resourcegroup is specified as it then creates a resourcegroup to deploy the virtual machine in to create the image from.


<br>


|Script | Explanation |
|-------------|-----------------|
|[./CreateImagePacker/createImageRunPacker.ps1](./CreateImagePacker/createImageRunPacker.ps1)| Script create target image resource, create SP and put it in keyVault for future use and create image based on parameters provide | 
|[./CreateImagePacker/linuxImage/createImageGalleryRunPacker.ps1](./CreateImagePacker/linuxImage/createImageGalleryRunPacker.ps1)| Script create target Resource group, Image Gallary image, create SP and put it in keyVault for future use and create image based on parameters provide |

<br>

### Sample Packer configs 

|Folder | Explanation |
|----------------|-----------------|
|[LinuxImage](./CreateImagePacker/linuxImage/)| Linux sample that install some Python and Conda | 
|[StandaardImage](./CreateImagePacker/standaardimage/)| Windows sample that install some FsLogix, Teams etc  see ps1 script for parameters | 
|[StandaardImage-Update](./CreateImagePacker/standaardimage/)| Windows sample with Update and install some FsLogix, Teams etc  see ps1 script for parameters | 

<br>

## Example createImageRunPacker

```bash
createImageRunPacker.ps1 -SubscriptionId "80000000-0000-0000-0000000" -ResourceGroupName "my-packer-build" -location "WestEurope" -KeyVaultName "kv-packeruniek1-we" -PackerServicePrincipale "sp-mripacker1" -DirectoryImageConfiguration "standaardimage" -image "image2"
```
This creates a resourcegroup "my-packer-build" in location "WestEurope".<br>
Creates a keyvault in resoucegroup called "kv-packeruniek1-we" and creates a service principle and change the rights contributor to that resource group, set the keyvault access policy for secrets to get for the service principle and stores the secrets information in the keyvault to be used by Packer config.<br>
The script then calls the Packer executable use all the json files found based on [script folder]/[folder is name of the DirectoryImageConfiguration parameter]/[any json found in this folder] and passes the variables via environment see packer json in sample. <br>


see sample json [./CreateImagePacker/standaardimage/windowsstandaard.json](./CreateImagePacker/standaardimage/windowsstandaard.json)

```json
    "variables": {
        "client_id": "{{env `PACKER_CLIENT_ID`}}",
        "client_secret": "{{env `PACKER_CLIENT_SECRET`}}",
        "tenant_id": "{{env `tenant_id`}}",  
        "subscription_id": "{{env `subscription_id`}}", 
        "resource_group": "{{env `resource_group`}}",
        "image_name": "{{env `image_name`}}" 

      },
```
The end result.

<img src="./media/imagebuild.png" alt="drawing" width="80%"/>


## Example createImageGalleryRunPacker

```bash
./CreateImagePacker/linuxImage/CreateImageGalleryRunPacker.ps1 -SubscriptionId "xxxxxx-xxxxx-xxxx-xxxxxx"  -ResourceGroupName "my-packer-build-imange" -location "WestEurope" -KeyVaultName "kv-packermrimage-we" -PackerServicePrincipale "sp-mripacker009"  -gallery_name "gallary-packer" -image_name "linux_sw1" -image_version "1.0.0" -osType "linux"
	   
```
This creates a resourcegroup "my-packer-build" in location "WestEurope"<br>
Creates a Image Gallary. And an image definition based on parameters.  Take the galleries strict naming convention into account.<br>
Creates a keyvault in resoucegroup called "kv-packermrimage-we" and creates a service principle and change the rights contributor to that resource group, set the keyvault access policy for secrets to get for the service principle and stores the secrets information in the keyvault to be used by Packer config.<br>
Call packer and passes the json based on [script folder]/[any json found in this folder] and passes the variables via environment see packer json in sample. 
```json
    "variables": {
        "client_id": "{{env `PACKER_CLIENT_ID`}}",
        "client_secret": "{{env `PACKER_CLIENT_SECRET`}}",
        "tenant_id": "{{env `tenant_id`}}",  
        "subscription_id": "{{env `subscription_id`}}",
        "resource_group": "{{env `resource_group`}}",  
        "gallery_name": "{{env `gallery_name`}}", 
        "image_name": "{{env `image_name`}}",
        "image_version": "{{env `image_version`}}"
      },
```
The end result.

<img src="./media/gallaryImageBuild.png" alt="drawing" width="80%"/>

<br>
<br>

## Example DevOps YAML

This is a simple YAML. The setup in [azure-pipeline.yml](./Pipelines/StandaardImage/azure-pipeline.yml) uses variables now but can be changed to use default parameters or direct variables.
You can use the created principle, to create an Azure ARM Service connection but then the first run must be manual that creates the serviceprinciple, keyvault and store the service principle and password as secret create an access policy for the SP.

You can choose to add the packer.exe in the repository as it will be now downloaded.

Tested with powershell core so  use 
```YAML
- task: AzurePowerShell@5 
```
and pwsh variable set


```YAML
# Minimum Yaml start file will be used as start template for build the complete azure-pipeline.yml in config environment Directory
# Either add variables to your Azure DevOps Pipeline or change the variable to parameters or fill in when run
parameters:
- name: Subscription
  type: string
  default: $(Subscription)
- name: SubscriptionId
  type: string
  default: $(SubscriptionId)
- name: ResourceGroupName
  type: string
  default: $(ResourceGroupName)
- name: DirectoryImageConfiguration
  type: string
  default: $(DirectoryImageConfiguration)
- name: KeyVaultName
  type: string
  default: $(KeyVaultName)
- name: PackerServicePrincipale
  type: string
  default: $(PackerServicePrincipale)
- name: image_name
  type: string
  default: $(image_name)

```

### Timing information 

Just for reference pipeline timing 
- Sample create Standaard Windows Image between 24 - 29,5 minutes
- Sample create Linux in Gallary Image Repository 25 - 29 minutes


## Resources

- [https://www.packer.io/docs/builders/azure](https://www.packer.io/docs/builders/azure)
- [https://docs.microsoft.com/en-us/azure/virtual-machines/windows/build-image-with-packer](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/build-image-with-packer)
- [https://docs.microsoft.com/en-us/azure/virtual-machines/image-builder-overview](https://docs.microsoft.com/en-us/azure/virtual-machines/image-builder-overview)
- [https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool](https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool)
- [https://github.com/RoelDU/WVDImaging](https://github.com/RoelDU/WVDImaging)
- [https://github.com/danielsollondon/azvmimagebuilder/tree/master/quickquickstarts](https://github.com/danielsollondon/azvmimagebuilder/tree/master/quickquickstarts)

## Disclaimer

This project is provided as-is, and is not intended as a blueprint how images should be created. It is merely an example on how you can use the technology. The project creates a number of Azure resources, you are responsible for monitoring and managing cost. I any welcome any contribution via a pull request.

