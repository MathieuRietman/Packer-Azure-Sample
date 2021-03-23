## Packer binaries

Download packer via choco install packer or via website. Is included in sample script 

Azure image builder use different configuration option example [Powershell] - [powershell]  [WindowsRestart] [windows-restart]


Windows update is seperate packe that not available needing download the windows update plugin download https://github.com/rgl/packer-provisioner-windows-update/releases and place in path

## Restricting Contributor to resourcegroup

To restrict to specific resource group Contributor right use  "build_resource_group_name" and not use location in JSON, else packer will create an additional resource group to build image and need also rights on subscription level.

When doing build_resource_group_name then remove location from packer json else get access error or error below:
```error
 Specify either a location to create the resource group in or an existing
build_resource_group_name, but not both.
```
https://coding-stream-of-consciousness.com/2019/01/02/azure-packer-create-image-with-only-access-to-resource-group-not-subscription/


It seems that the disk is not removed  with this property set, it is in the resourcegroup after the rest is cleaned.