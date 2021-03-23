<#
	.SYNOPSIS
        1. Script to be run in pipeline or manual to create a standaard image based on JSON parameter in a specific directory
        2. Based on Windows host to start this. (Support any image building)
        3. Scripts try to download packer.exe and windows update packer file 
        4. Packer need a Service Prinsiple this is created or use a service principle stored in the keyvault parameters. 
        5. First time run require an Owner account as the service principle get on the resourcegroup contributor rights.
    
    



	.DESCRIPTION

         
     Build with Packer an image in Azure
     Tested in PowerShell core 
     When run in pipeline run it task: AzurePowerShell@5 with pwsh: true'

	.EXAMPLE
	   .\createImageRunPacker.ps1 -SubscriptionId "xxxxxx-xxxxx-xxxx-xxxxxx" -ResourceGroupName "my-packer-build" -location "WestEurope" -KeyVaultName "kv-packermri-we" -PackerServicePrincipale "sp-mripacker001" -DirectoryImageConfiguration "standaardimage"
	   
	.LINK

	.Notes
		NAME:      createImageRunPacker
		AUTHOR(s): Mathieu Rietman <marietma@microsoft.com>
		LASTEDIT:  16-03-2022
		KEYWORDS:  Packer Image Management
#>

Param (

    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId ,
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName ,
    [Parameter(Mandatory = $false)]
    [string]$location = "westEurope",
    [Parameter(Mandatory = $true)]
    [string]$KeyVaultName ,
    [Parameter(Mandatory = $true)]
    [string]$PackerServicePrincipale ,
    [Parameter(Mandatory = $true)]
    [string]$DirectoryImageConfiguration = "standaardimage",
    [Parameter(Mandatory = $false)]
    [string]$image_name = "standaardimage2"

)

#First set our working directory

if (![string]::IsNullOrEmpty($WorkingDirectory)) {

}
else {
    $WorkingDirectory = $PSScriptRoot
}
write-host "starting using working directory $($WorkingDirectory)"


# Check Folder exist
If (!(Test-Path -Path "$($WorkingDirectory)/$($DirectoryImageConfiguration)")) { 
    write-Host "Directory does not exist $($WorkingDirectory)/$($DirectoryImageConfiguration)`n" -ForegroundColor Red

} 
else {
 
    #First download packer 1.7
    If (!(Test-Path -Path "$($WorkingDirectory)/packer.exe")) {
        $Zipfile = "$($WorkingDirectory)/packer.zip" 
        write-host "Start packer download"
        Invoke-WebRequest -Uri "https://releases.hashicorp.com/packer/1.7.0/packer_1.7.0_windows_amd64.zip" -OutFile $Zipfile 
        Expand-Archive -LiteralPath $Zipfile -DestinationPath $WorkingDirectory
        Remove-Item -Path $Zipfile 
    }


    If (!(Test-Path -Path "$($WorkingDirectory)/packer-provisioner-windows-update.exe")) {

        $Zipfile = "$($WorkingDirectory)/packerupdatewindows.zip" 
        write-host "Start packer windows update download"
        Invoke-WebRequest -Uri "https://github.com/rgl/packer-provisioner-windows-update/releases/download/v0.11.0/packer-provisioner-windows-update_0.11.0_windows_amd64.zip" -OutFile $Zipfile 
        Expand-Archive -LiteralPath $Zipfile  -DestinationPath $WorkingDirectory -force
        Remove-Item -Path $Zipfile 
    }


    write-Host "Running Packer build of template *.json in directory $($WorkingDirectory)/$($DirectoryImageConfiguration)`n"
    write-Host "Subscription :$($SubscriptionId)`n"
    write-Host "Resourcegroup :$($ResourceGroupName) used for keyvault named:$($KeyVaultName) `n"

    #Check Subscription

    $currentAzContext = Get-AzContext

    if ( $currentAzContext.Subscription.Id -ne $SubscriptionId  ) {
        Set-AzContext -SubscriptionId $SubscriptionId 
    }           

    #Check  and create ResourceGroup

    $Tags = @{application = "Bacth"; type = "p"; costcenter = "myOwn" }
    $RG = Get-AzResourceGroup -Name $ResourceGroupName  -ev notPresent -ea 0 
    if ($notPresent) { 
         
        New-AzResourceGroup -Name $ResourceGroupName  -Location $location  -Tags $Tags 
        write-Host "Created Resource Group "
    }
    else { write-Host "Resource Group already exists" } 



    #Get Keyvault secrets for packer Service Principle if not found in Resourcegroup create based on parameters
    $packer_client_id = $null
    $KeyVault = Get-AzKeyVault -ResourceGroupName  $ResourceGroupName -VaultName $KeyVaultName -ErrorAction SilentlyContinue
    If (!$keyvault) {

        New-AzKeyVault -ResourceGroupName  $ResourceGroupName -VaultName $KeyVaultName -Location $location 
    }
    else {  
        write-Host "KeyVault already exists, try to get SPN - secrets" 
        $secret = (Get-AzKeyVaultSecret -VaultName $keyVaultName -Name "packer-client-id" -ErrorAction SilentlyContinue)
        if ($secret) {
            $ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret.SecretValue)
            try {
                $packer_client_id = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)
            }
            finally {
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)
            }

        }

        $secret = (Get-AzKeyVaultSecret -VaultName $keyVaultName -Name "packer-client-secret" -ErrorAction SilentlyContinue)
        if ($secret) {
            $ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret.SecretValue)
            try {
                $packer_client_secret = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)
            }
            finally {
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)
            }
        }
  
    }

    If (!$packer_client_id) {

        $sp = Get-AzADServicePrincipal -DisplayName $PackerServicePrincipale

        if (!$sp) {
            write-host "creating service principle $($PackerServicePrincipale) for scope /subscriptions/$($subscriptionId)/resourceGroups/$($ResourceGroupName)"
            $sp = New-AzADServicePrincipal -DisplayName $PackerServicePrincipale -Scope "/subscriptions/$($subscriptionId)/resourceGroups/$($ResourceGroupName)"
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sp.Secret)
            $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            $sp = $null
            $sp = Get-AzADServicePrincipal -DisplayName $PackerServicePrincipale     
            write-Host "Created Service Principle $($sp.ApplicationId.guid)"
            if (!$sp) {
                $count = 0
                DO {
                    Write-Host "waiting until sp is create $count of 15"                  
                    start-sleep 1
                    $count++
                }                 
                Until ((Get-AzADServicePrincipal  -DisplayName $PackerServicePrincipale   ) -or ($count -ge 15) )                     
            }
            $sp = Get-AzADServicePrincipal -DisplayName $PackerServicePrincipale     
            # we check to see if the role assignement is already available this will result in error but because else packer wil fail as it does not have the role assignment propagated
            write-Host "Check role on resourcegrup for principle $($sp.ApplicationId.guid)"
            $spId = $sp.ApplicationId.guid
            $role = Get-AzRoleAssignment -ServicePrincipalName $spId -RoleDefinitionName "Contributor" -ResourceGroupName  $ResourceGroupName
            $role
            if (!$role ) { 
    
                $count = 0
                DO {
                    
                    try {
                        New-AzRoleAssignment -ServicePrincipalName $spId -RoleDefinitionName "Contributor" -ResourceGroupName  $ResourceGroupName
                    }
                    catch {
                      
                    }
                    Write-Host "waiting until role is assigned $count of 20"                  
                    start-sleep 1
                    $count++
                    $role = Get-AzRoleAssignment -ServicePrincipalName $spId -RoleDefinitionName "Contributor" -ResourceGroupName  $ResourceGroupName
                }                 
                Until (($role   ) -or ($count -ge 20) )          
                write-Host "Created contributor role for service principle "
            }
            elseif ($role.Scope -match $ResourceGroupName ) { 
                write-Host "Role assignment already exists" 
            }
         
        }
        else {
            $newCredential = New-AzADSpCredential -ServicePrincipalName  $sp.ApplicationId
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($newCredential.Secret)
            $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

        }
        $secretServiceClientIdS = ConvertTo-SecureString $sp.ApplicationId.guid -AsPlainText -Force
        $secretplainPasswordS = ConvertTo-SecureString $plainPassword -AsPlainText -Force
        Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name "packer-client-id" -SecretValue  $secretServiceClientIdS | Out-Null
        Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name "packer-client-secret" -SecretValue $secretplainPasswordS 
        Set-AzKeyVaultAccessPolicy -VaultName $KeyVaultName -ObjectId $sp.Id -PermissionsToSecrets Get
        $packer_client_id = $sp.ApplicationId
        [string]$packer_client_secret = $plainPassword
    }
 


}


# Set environment variables used by templates

$env:PACKER_CLIENT_ID = $packer_client_id 
$env:PACKER_CLIENT_SECRET = $packer_client_secret
$env:tenant_id = $currentAzContext.Tenant.Id
$env:subscription_id = $currentAzContext.Subscription.Id
$env:Path += ";$($WorkingDirectory)"  
$env:resource_group = $ResourceGroupName
$env:image_name = $image_name
$folder = "$($WorkingDirectory)/$($DirectoryImageConfiguration)"
$jsonfiles = Get-ChildItem -Path $folder -Filter *.json -Recurse -File -Name
if (!$jsonfiles) {
    write-Host "No JSON found in Directory  $($WorkingDirectory)$($DirectoryImageConfiguration)`n" -ForegroundColor Red

}
else {
    foreach ($File in $jsonfiles) {
        $startTime = Get-Date

        Set-Location  $folder
        write-Host "$($startTime.ToString("dd-mm-yyyy hh:mm:ss")) ;  starting packer.exe build -force $($file) "
        & "$($WorkingDirectory)/packer.exe" "build" "-force" "$($file)"
           
        $endTime = Get-Date
        $minutes = $endTime - $startTime
        write-Host "$($endTime.ToString("dd-mm-yyyy hh:mm:ss")) ;  Finished  $($file) total minutes run $($minutes.ToString("mm"))"
             
            
    }
    Set-Location $WorkingDirectory 
}

                  