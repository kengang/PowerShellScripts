<#
author: Ken Mei

scim throught all eventlogs on the server to find events that match a Keyword and return the LogName and events
so that you can go directly to event viewer and exame the log in more details

it takes two input, one is how far back in time you want to check;  second is the keyword you can find.

#>
function scan-eventlogs {
    param(
        [string]$numDaysAgo = 1,
        [string]$keyword="error"
        )

    $currenttime= get-date
    $endtime = [datetime]::Parse($currenttime)
    $starttime = [datetime]::Parse($currenttime.addDays(-$numDaysAgo))

    $lognames = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | Where RecordCount -gt 0 |select logname

    foreach ($logname in $lognames.logname){

          $hashtable = @{
                        LogName = $logname
                        StartTime = $starttime
                        EndTime = $endtime
          }
        
         
         if (Get-WinEvent -FilterHashtable $hashtable -ErrorAction SilentlyContinue | Where-Object {$_.message -match $keyword} -ErrorAction SilentlyContinue ) {

            write-host "***************$logname*****************"
            Get-WinEvent -FilterHashtable $hashtable -ErrorAction SilentlyContinue | Where-Object {$_.message -match $keyword} -ErrorAction SilentlyContinue
         }

    }

 }

 scan-eventlogs -numDaysAgo 0.9 -keyword "errors"