#Title: deploy-lin.ps1
#Version: 1.2 on Dec 14 2018 by Hanlin, dedicate for aviva-cofco.
#Description: Deploy mass VMs for Linux
param(
    [parameter(Mandatory = $true)]
    [string]$CSVname
    )
#Getting List of VMs from .csv
$OSspec = "powercli-linux"
$template = "linux-base"
$VMs = Import-CSV $CSVname -UseCulture
 
#Loop to Provision VMs
 ForEach($VM in $VMs){
 
#Selecting a Random hots to place the VM.
    $ClusterHost = Get-Cluster $VM.Cluster | Get-VMHost | Where{$_.ConnectionState -eq "Connected"} | Get-Random

    If($VM.IPaddress -gt 1){
    #Define OS Customization with IP Addressing
        If($VM.Template -eq $template){

           Get-OSCustomizationSpec $OSspec | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIp -IpAddress $VM.IPaddress -SubnetMask $VM.Netmask -DefaultGateway $VM.Gateway
        }
        Else{
         Write-Host Error: Template $VM.Template ~ is no the one specified in the file. Please make sure you are using the right template!!! -backgroundcolor "Yellow" -foregroundcolor "Black"
         Exit
     }  
 
    }
 
    #Creating the New VM. SDRS automatic
    New-vm -VMhost $ClusterHost -Name $VM.VMName -Location $VM.Location -Template $VM.Template -Description $VM.Description -DiskStorageFormat "Thick" -OScustomizationSpec $OSspec
 
    #Get-VM once for detail
    $gVM = Get-VM $VM.VMName
 
    #Setting the Memory
    $gVM | Set-VM -MemoryGB $VM.MemoryGB -NumCpu $VM.NumCpu -Confirm:$false
 
    #Setting the NetworkName of Network Adapter 1
    $gVM | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $VM.NetworkName -confirm:$false
    #Configuring OSdisk if more than template required
    If ([int]$VM.OSdisk -gt 1){       
        $VMdisk1 = $gVM | Get-HardDisk | ?{$_.Name -eq "Hard disk 1"}
        If ([int]$VM.OSdisk -gt $VMdisk1.CapacityGB){
            $gVM | Get-HardDisk | ?{$_.Name -eq "Hard disk 1"} | Set-HardDisk -CapacityGB $VM.OSdisk -Persistence persistent -confirm:$false
        }
    }
 
    #Adding HDD2 if exist
    If ([int]$VM.Disk2 -gt 1){
        $Disk2 = [int]$VM.Disk2
        $gVM | New-HardDisk -CapacityGB $Disk2 -Persistence persistent
    }
 
    #Adding HDD3 if exist
    If ([int]$VM.Disk3 -gt 1){
        $Disk3 = [int]$VM.Disk3
        $gVM | New-HardDisk -CapacityGB $Disk3 -Persistence persistent
    }
 
    #Adding second NIC and NetworkName if exist
    If ($VM.NetworkName2 -gt 1){
    $gVM | New-NetworkAdapter -Type vmxnet3 -NetworkName $VM.NetworkName2 -StartConnected -confirm:$false
    }
	
    #Reconfigure VM
    $gVM | Move-VM -Datastore $VM.clusterDatastore

    #PowerOn VM
    $gVM | Start-VM
 
#Next VM
}