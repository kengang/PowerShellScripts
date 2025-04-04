<#
Script to set registry key value remotely, if key does not exist, it will create it.
the output will print out before and after value.

Author: Ken Mei

 LEGAL DISCLAIMER
This Sample Code is provided for the purpose of illustration only and is not
intended to be used in a production environment.  THIS SAMPLE CODE AND ANY
RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  We grant You a
nonexclusive, royalty-free right to use and modify the Sample Code and to
reproduce and distribute the object code form of the Sample Code, provided
that You agree: (i) to not use Our name, logo, or trademarks to market Your
software product in which the Sample Code is embedded; (ii) to include a valid
copyright notice on Your software product in which the Sample Code is embedded;
and (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and
against any claims or lawsuits, including attorneys’ fees, that arise or result
from the use or distribution of the Sample Code.


Path: Specifies the path to the registry key.
Name: The name of the new property.
Value: The value to assign to the new property.
PropertyType: The type of the property, such as String, DWord, QWord, Binary, MultiString, or ExpandString.

input csv format file:

RegKeyPath	            KeyName	KeyValue	KeyType
HKLM:\SOFTWARE\keypath	test	1	        string
HKLM:\SOFTWARE\keypath	test    1		    string
HKLM:\SOFTWARE\keypath2	a	    1	        string
HKLM:\SOFTWARE\keypath5	b	    testvalue   dword


#>


#input server list
$Servers = Get-Content C:\psscripts\serverlist.txt

# input from command seperated csv file as input
$regkeys = Import-Csv -Path C:\psscripts\regkey-input.csv


#function to verify input server accessability
Function verify-server-connectivity-access {
  param(
    [array]$servers
  )


   $targetservers =@()
   $notaccessibleserver = @()
  foreach ($srv in $servers){
    
    if(Test-Path -Path "\\$srv\c$" -ErrorAction SilentlyContinue) {

      $targetservers += $srv

    } else {

       $notaccessibleserver += $srv
    }
  }

  #$notaccessibleserver | ForEach-Object {[PSCustomObject]@{NotAccessibleServerName = $_}} | Export-Csv -Path "C:\psscripts\output.csv" -NoTypeInformation 
  $notaccessibleserver | ForEach-Object {[PSCustomObject]@{NotAccessibleServerName = $_}} |Out-GridView
  return $targetservers
}


#function to make registry changes
Function update-registry-key-value {
  param(
   [array]$regkeys
  )

# check if the reg key path existed
$uniquekeypath = $regkeys.regkeypath |Select-Object -Unique

$uniqueRegkeyStatusarray = @()

foreach ($regkey in $uniquekeypath) {
    
    $uniqueRegkeyStatus = @{}

    $uniqueRegkeyStatus.RegKeyPath = $regkey

    #Check if registry entry named Status exists
    $regkeypathexists = Test-Path -Path $regkey -ErrorAction SilentlyContinue

    #Check if registry entry named Status exists
    if ($regkeypathexists) {
      
        $uniqueRegkeyStatus.keypathexist = "True"
    } else {
        $uniqueRegkeyStatus.keypathexist = "False"
    }

    $uniqueRegkeyStatusarray += $uniqueRegkeyStatus 

}


$RegkeyStats = @()

# going to through the entire input to update the key to a desired value, if the key path or key name not existed it will create it
foreach ($regkey in $regkeys) {
 
      
      $keystatus =  @{}
      
      $keystatus.RegKeyPath = $regkey.RegKeyPath
      $keystatus.keypathexist = "False"
      $keystatus.keyname = $regkey.KeyName
      $keystatus.keynameexist = "False"
      $keystatus.keyvaulecurrent = "null"
      $keystatus.keyvauleNew = $null

      #Check if registry entry named Status exists
      $regkeypathexists = Test-Path -Path $regkey.RegKeypath -ErrorAction SilentlyContinue

      foreach ($keypath in $uniqueRegkeyStatusarray) {

        if ($keypath.RegKeyPath -eq $regkey.RegKeypath) {
            $keystatus.keypathexist = $keypath.keypathexist
        }

      }

      #Check if registry entry named Status exists
      if ($regkeypathexists) {
      
        #If registry entry key named Status exists, then fetch its value
        $regkeynameexists = Get-ItemProperty -Path $regkey.RegKeypath -Name $regkey.KeyName -ErrorAction SilentlyContinue

        if ($regkeynameexists) {
            
                        
            $currentValue = Get-ItemProperty -Path $regkey.RegKeypath | Select-Object -ExpandProperty $regkey.KeyName -ErrorAction SilentlyContinue
            
            $keystatus.keyvaulecurrent = $currentValue
            $keystatus.keynameexist = "True"

            #Match Status registry entry value with requied value
            if ($currentValue -eq $regkey.KeyValue) {

                Write-Host "Reg value exists and matching the required value."
                $keystatus.keyvauleNew = $currentValue
        
            } else {
        
                Write-Host "Reg value exists, but does not match the required value."
                Write-host "updateing keyvalue from ${currentvalue} to $($regkey.KeyValue)"
                Set-ItemProperty -Path $regkey.RegKeyPath -Name $regkey.keyname -Value $regkey.KeyValue -Force
                $currentValue = Get-ItemProperty -Path $regkey.RegKeypath | Select-Object -ExpandProperty $regkey.KeyName -ErrorAction SilentlyContinue
                $keystatus.keyvauleNew = $currentValue
            }
        } 
         else {
        
            #create the regkey if not exists
            write-host "create the new key and set value "
            $keystatus.keynameexist = "False"
            $keystatus.keyvaulecurrent = "Null"
            New-ItemProperty -Path $regkey.RegKeyPath -Name $regkey.keyname -Value $regkey.KeyValue -PropertyType $regkey.keytype -force |Out-Null
            $currentValue = Get-ItemProperty -Path $regkey.RegKeypath | Select-Object -ExpandProperty $regkey.KeyName -ErrorAction SilentlyContinue
            $keystatus.keyvauleNew = $currentValue
        }
    } 
      else {
            Write-Host "Registry key does not exist."
            write-host "creating regkey Path"
            New-Item -Path $regkey.RegKeyPath |Out-Null
            New-ItemProperty -Path $regkey.RegKeyPath -Name $regkey.keyname -Value $regkey.KeyValue -PropertyType $regkey.keytype -force -ErrorAction SilentlyContinue |Out-Null
            $currentValue = Get-ItemProperty -Path $regkey.RegKeypath | Select-Object -ExpandProperty $regkey.KeyName -ErrorAction SilentlyContinue
            $keystatus.keyvauleNew = $currentValue
    }

    $RegkeyStats +=$keystatus


 }

 return $RegkeyStats

 }


#accessible servers to be processed
$targetservers = verify-server-connectivity-access -servers $Servers



$ServerKeyStatus = @()

foreach ($srv in $targetServers) {

    $result =Invoke-Command -ComputerName $srv -ScriptBlock ${function:update-registry-key-value} -ArgumentList (,$regkeys)
    $SrvRegKeyStatus = @{}
    $SrvRegKeyStatus.ServerName = $srv
    $SrvRegKeyStatus.KeyStatus = $result

    $ServerKeyStatus += $SrvRegKeyStatus
}


#output for reporting
$reports = @()
 foreach ($item in $ServerKeyStatus) {

    foreach ($key in $item.KeyStatus){

      $report = @{}
      $report.ServerName = $item.ServerName
      $report.RegKeyPath = $key.RegKeyPath
      $report.RegKeyPathExist = $key.keypathexist
      $report.RegKeyName = $key.keyname
      $report.RegKeyNameExist = $key.keynameexist
      $report.ReyKeyValueCurrent = $key.keyvaulecurrent
      $report.RegKeyValueNew = $key.keyvauleNew 
      $reports +=$report
   }

}

$(foreach ($ht in $reports) {new-object PSObject -Property $ht})| select -Property ServerName, RegKeyPath,RegKeyPathExist,RegKeyName,RegKeyNameExist,ReyKeyValueCurrent,RegKeyValueNew|Out-GridView
#$(foreach ($ht in $reports) {new-object PSObject -Property $ht})| select -Property ServerName, RegKeyPath,RegKeyPathExist,RegKeyName,RegKeyNameExist,ReyKeyValueCurrent,RegKeyValueNew | Export-Csv -NoTypeInformation -Path C:\psscripts\out.csv