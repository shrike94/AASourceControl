param  
(  
 [Parameter (Mandatory=$true)]  
 [object] $WebhookData  
)

#login to Azure:
$connectionName = "AzureRunAsConnection"
try
{
 # Get the connection "AzureRunAsConnection "
 $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

 "Logging in to Azure..."
 Add-AzureRmAccount `
     -ServicePrincipal `
     -TenantId $servicePrincipalConnection.TenantId `
     -ApplicationId $servicePrincipalConnection.ApplicationId `
     -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
 if (!$servicePrincipalConnection)
 {
     $ErrorMessage = "Connection $connectionName not found."
     throw $ErrorMessage
 } else{
     Write-Error -Message $_.Exception
     throw $_.Exception
 }
}

#Extract data from webhook
$SearchResults = (ConvertFrom-Json $WebhookData.RequestBody).SearchResult
Write-Output "Search Results $SearchResults"
$serviceName = $SearchResults.tables.rows[-2]
Write-Output "ServiceName: $servicename"
$computerName = $SearchResults.tables.rows[5]
Write-Output "Computername: $computername"

foreach ($computer in $computerName){
 #Get Server FQDN
 $vmResource = Find-AzureRmResource -ResourceNameContains $computer -ResourceType "Microsoft.Compute/virtualMachines"
 $vm = Get-AzureRMVM -ResourceGroupName $vmResource.ResourceGroupName -Name $vmResource.Name
 Write-Output "VM located: $($vm.Name)"
 $vm.NetworkProfile
 $vm.NetworkProfile.NetworkInterfaces.Id
 $nicRef = Get-AzureRMResource -ResourceId $vm.NetworkProfile.NetworkInterfaces.Id
 $nic = Get-AzureRmNetworkInterface -Name $nicRef.Name -ResourceGroupName $nicRef.ResourceGroupName
 $publicIpRef = Get-AzureRmResource -ResourceId $nic.IpConfigurations.PublicIpAddress.Id
 $publicIp = Get-AzureRmPublicIpAddress -Name $publicIpRef.Name -ResourceGroupName $publicIpRef.ResourceGroupName
 $fqdn = $publicIp.DnsSettings.Fqdn
 Write-Output "Connecting to VM: $($fqdn)"

 #set the winrm port
 $winrmPort = "5986"
 # Get the credentials of the machine
 $cred = Get-AutomationPSCredential -Name 'aa-admin'

 # Connect to the machine
 $soptions = New-PSSessionOption -SkipCACheck          
 Invoke-Command -ComputerName $fqdn -Credential $cred -Port $winrmPort -UseSSL -SessionOption $soptions -ScriptBlock {
     param($serviceDisplayName)
     $service = Get-Service -DisplayName $serviceDisplayName
     #if service isnt running, start it
     if ($service.Status -ne "Running"){
         $service | Start-Service
     }
 } -ArgumentList $serviceName
}