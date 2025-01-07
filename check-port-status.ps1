<#---
Script to check if port is opened to a server
  
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

---#>

#list of servers to be checked from/source server
$SrvLists = get-content ./servers.txt

#list of destination servers be checked against
$destinations_to_check = @("microsoft.com", "yahoo.com", "google.com")

#list of ports to be check on the destination servers

$ports_to_check = @(80, 443, 53)

# number of servers to run at once.
$Jobs =200


$Error.Clear()

$current_time = (get-date).ToUniversalTime().ToString("yyyyMMddTHHmmss")

$scriptblock = {
        param([array]$destinations_to_check, [array]$ports_to_check, $timeout=2000)
     
        $ports_status = @()
        foreach ($destination in $destinations_to_check) {
           
         
           foreach ($dport in $ports_to_check) {

                $port_status  = "" |select SourceServer, DestinationServer, DestinationPort, Status
                Try {
                        $tcpclient = New-Object -TypeName system.Net.Sockets.TcpClient
                        $iar = $tcpclient.BeginConnect($destination, $dport, $null,$null)
                        $wait = $iar.AsyncWaitHandle.WaitOne($timeout,$false)
                        if(!$wait)
                        {
                            $tcpclient.Close()
                            $status = "Fail"
                        }
                        else
                        {
                            # Close the connection and report the error if there is one
           
                            $null = $tcpclient.EndConnect($iar)
                            $tcpclient.Close()
                            $status = "Success"
                        }
                }
                catch {
                    $status = "Fail"
                }

                $port_status.SourceServer = $env:COMPUTERNAME
                $port_status.DestinationServer = $destination
                $port_status.DestinationPort = $dport
                $port_status.Status = $status
                $ports_status +=$port_status
             
            }
             
     
        }
       
        $ports_status
       
    }

$i = 0
$out = @()
$failed =@()
$failed_servers =@()
$faileddetails =@()
$detailerror = @()

foreach ($srv in $SrvLists) {
   
   
    Write-Progress -Activity "running port scanning job" -status $srv -PercentComplete ($i / $SrvLists.Length * 100)
    $i++

    do {
        $job = (Get-Job -State Running |measure).count
    } Until ($job -le $Jobs)
   
   
    Invoke-Command -ComputerName $srv -ScriptBlock $scriptblock -ArgumentList $destinations_to_check,$ports_to_check -ErrorAction stop -AsJob | Out-Null
   
    $out += Get-Job -State Completed | Receive-Job  -Wait -AutoRemoveJob
    $failed += Get-Job -State Failed
    Get-Job -State Failed | Receive-Job -wait -AutoRemoveJob -ErrorVariable +detailerror -ErrorAction SilentlyContinue

}


do {
   
    $still_running_jobs = (Get-Job -State Running |measure).count
   
    if ($still_running_jobs -gt 0) {
        Write-Host "$still_running_jobs jobs still running, please wait..."

        get-job |Wait-Job -Timeout 300 | Out-Null
    }

   
} Until ($still_running_jobs -lt 10)



$out +=Get-Job -State Completed | Receive-Job  -Wait -AutoRemoveJob
$failed += Get-Job -State Failed
Get-Job -State Failed | Receive-Job -wait -AutoRemoveJob -ErrorVariable +detailerror -ErrorAction SilentlyContinue


$current_time = (get-date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
$out | Select-Object SourceServer, DestinationServer, DestinationPort, Status |export-csv -NoTypeInformation result-$current_time.csv
$failed |select Location|Export-Csv -NoTypeInformation failedhost-$current_time.csv
$detailerror |Out-File detailerror.txt

$detailerror = $null
Get-Date