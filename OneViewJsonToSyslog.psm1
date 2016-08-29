##############################################################################
# Name: OVJsonToSyslog.psm1
# Description: - helper functions to convert JSON to syslog:
#              - for audit logs, alerts and tasks ( activity logs )
# Date: Mar 2016
# 
##############################################################################

Import-Module .\Utility.psm1
    
#----------------------------------------------------------------
# Global Variables
#----------------------------------------------------------------
$Global:TaskFile
$Global:AlertFile
$Global:AuditFile
#-----------------------------------------------------------------
# Global Variables of File Path
#-----------------------------------------------------------------

$Global:t                        = Get-Date -Format dd-MM-yyyy
$Global:rootPath                 = $pwd

$Global:SysLogFilePath_task      = "$rootPath\syslogs\Tasks_"
$Global:SysLogFilePath_alerts    = "$rootPath\syslogs\Alerts_"
$Global:SysLogFilePath_auditlogs = "$rootPath\syslogs\Audit_"
$Global:authProvider             = "LOCAL"


function ConvertJsonTasksToSyslog($taskID,$json_member,$ApplianceIP)
{
    <#
    Internal function called by GetTasks
    Converts JSON to Syslog format
    #>           
     
    Process 
    {
        $version=$taskID
        $ov_task="OV_task-"
        $date=$json_member.created
        $log_level=$json_member.taskState
        $app_name=$json_member.name
        $msg_id=$json_member.uri
        $stru_data1=$json_member.taskErrors.errorSource +" "+$json_member.taskErrors.message+" "+$json_member.taskErrors.nestedErrors+" "+$json_member.taskErrors.details +" "+$json_member.taskErrors.data +" "+$json_member.taskErrors.errorCode+" "+$json_member.taskErrors.recommendedActions
        $stru_data2 = $stru_data1+","+$json_member.associatedResource.resourceUri+" "+$json_member.associatedResource.resourceCategory+" "+$json_member.associatedResource.associationType +" "+$json_member.associatedResource.resourceName+","+$json_member.owner  
        $msg=$json_member.taskOutput +","+$json_member.expectedDuration                         
        $output = $ov_task+$version+" "+$date+" "+$log_level+" "+$app_name+" "+"-"+" "+$msg_id+" "+"["+$stru_data2+"]"+" "+"["+$msg+"]"
        $output | Out-File -FilePath $TaskFile -Append   
    }

}


function GetTasks
{
    <#
    Called by User, makes call to OneView
    Gets JSON response. Calls JSON to Syslog function
    Applies filters if any
    #>
        
    Param
    (
        [parameter(Mandatory = $true, HelpMessage = "Enter the IP ")]
        [ValidateNotNullOrEmpty()]
        [System.String]$ApplianceIP,

        [parameter(Mandatory = $true, HelpMessage = "Enter the username")]
        [ValidateNotNullOrEmpty()]
        [System.String]$UserName,

        [parameter(Mandatory = $true, HelpMessage = "Enter the password")]
        [ValidateNotNullOrEmpty()]
        [System.String]$Password,

        [parameter(Mandatory = $true, HelpMessage = "Enter the mode")]
        [ValidateNotNullOrEmpty()]
        $mode
    )
           
    Process 
    {
        $start_Date = ""
        $start_time = "00:00:01"
                
        $end_Date = ""
        $end_time = "23:59:59"
               
        writeLog "JsonToSyslog:GetTasksToSyslog: Started"
    
        $returnCode = connectFusion $ApplianceIP $UserName $Password $authProvider
        validateConnection $returnCode

        WriteLog "JsonToSyslog:GetTasksToSyslog: Connected to OneView: " -debuglevel "INFO"

        $Global:TaskFile = $Global:SysLogFilePath_task+$ApplianceIP+".log"
                
        if(!(Test-Path -Path $Global:TaskFile -PathType Any))
        {
            $taskfile=New-Item -ItemType File -Path $TaskFile
        }

        Clear-Content -Path $Global:TaskFile

        $totalalerts=75000;
        $count=0
        $taskID=0

        if ($mode -eq "interactive") 
        {
            Write-Host "`nIf the date and time is not entered,then it will give all tasks of that Appliance `n"
            [string]$cli_start_Date = Read-Host "Enter the start date(format yyyy-mm-dd)."
            if(!$cli_start_Date)
            {
            }
            else
            {
                $start_Date = validate_Date($cli_start_Date) 
            }                
                    
            Write-Host "`nIf start-time is not specified then it will take default start-time:00:00:01 `n"
            $cli_start_time = Read-Host "Enter the start time(format hh:mm:ss)."
            $start_time = validate_StartTime($cli_start_time)
            Write-Host ""
            
            
            if($start_Date)
            {        
               [string]$cli_end_Date = Read-Host "Enter the end date(format yyyy-mm-dd)."
               if(!$cli_end_Date)
                {
                    $cli_end_Date=Get-Date -format "yyyy-MM-dd"
                }
                else
                {
                    $end_Date = validate_Date($cli_end_Date)
                } 
            }
            
            if($start_time -ne "00:00:01")
            {     
                Write-Host "If end-time is not specified then it will take default end-time:23:59:59 `n"
                $cli_end_time = Read-Host "Enter the end time(format hh:mm:ss)."
                $end_time=validate_EndTime($cli_end_time)
                
            }
            
            if($end_Date -gt $start_Date)
            {
                Write-Host "`nThe end_date should be greater than the start_date" -ForegroundColor Red
                writeLog "The User has entered the end_date lesser than start_date" 
                cleanup      
            }            

                    
            $filter_option=Read-Host "Do you want to filter the Tasks? enter 'Y' or 'N'"
            if($filter_option -eq 'y' -or $filter_option -eq 'Y')
            {
                $choice=Read-Host "These are the Task state. `n 1.Completed `n 2.Error`n 3.Interrupted `n 4.Killed `n 5.New `n 6.Pending `n 7.Running`n 8.Starting`n 9.Stoping`n 10.Suspended `n 11.Terminated `n 12.Unknown `n 13.Warning `n Please Enter a number between 1 to 13"
                $taskstate=checkTaskChoice($choice)
            }
            elseif($filter_option -eq 'n' -or $filter_option -eq 'N')
            {
                write-Host "By default all Tasks state are choosen"
                writeLog "All Task state is selected"
            }
            else
            {
                write-Host "You have entered wrong filter option"
                writeLog  "User has entered wrong filter option"
                cleanup
                
            }
        }
                       
        $new_date1=$cli_start_Date+"T"+$start_time+".000"+"Z" #milisecond 000 and 999 is added for comparision purpose.
        $new_date2=$cli_end_Date+"T"+$end_time+".999"+"Z"
                
        try
        {
            writeLog -message "JsonToSyslog:ConvertJsonTasksToSyslog:started" -debuglevel "INFO"
            for($i=0;$i-le $totalalerts;$i=$i+100)
            {
                if($taskstate)
                {
                    $Global:tasks = "/rest/tasks?start=$i&count=100&filter=`"taskState=`'$taskstate`'`"" 
                }
                else
                {
                    $Global:tasks= "/rest/tasks?start=$i&count=100"
                }

                $ret_json = Send-HPOVRequest -uri $tasks GET 
                        
                if($new_date1 -eq "T00:00:01.000Z" -and $new_date2 -eq "T23:59:59.999Z")
                { 
                        
                    foreach($json_member in $ret_json.members.getEnumerator())
                    {
                        ConvertJsonTasksToSyslog $taskID $json_member $ApplianceIP 
                        $taskID++
                    }
                        
                }
                else
                {  
                    foreach($json_member in $ret_json.members.getEnumerator())
                    {
                        $date = $json_member.created
                        if(($date -ge $new_date1) -and ($date -le $new_date2))
                        {
                            ConvertJsonTasksToSyslog $taskID $json_member $ApplianceIP 
                            $taskID++
                        }
                    }
                         
                }
                if($i -gt $ret_json.total)
                {
                    break;
                }
            }
            writeLog -message "JsonToSyslog:ConvertJsonTasksToSyslog:Ended" -debuglevel "INFO"
        }
        catch
        {
            writeLog -message "Error in parsing the json_member" -debuglevel "ERROR"
            Write-Error $_.Exception.InnerException.Message
        }

        If ((Get-Content "$Global:TaskFile") -eq $Null) 
        {
            writeLog -message "You dont have any tasks for the specified date, time and taskstate"
            Write-Host "You dont have any tasks for the request" -ForegroundColor Cyan
        }
        else
        {
            writeLog -message "$taskID tasks successufully listed" -debuglevel "INFO" 
            Write-Host "Check $Global:TaskFile file for the output" -ForegroundColor DarkYellow
        }
               
        writeLog "JsonToSyslog:GetTasksToSyslog: Ended"
        cleanup
    }
             
}
              
function checkTaskChoice($choice) 
{
    $taskstate = ""
        
    switch($choice) #switch($choice -ne $null) doesn't work
    {
        1 {$taskstate="Completed"}
        2 {$taskstate="Error"}
        3 {$taskstate="Interrupted"}
        4 {$taskstate="Killed"}
        5 {$taskstate="New"}
        6 {$taskstate="Pending"}
        7 {$taskstate="Running"}
        8 {$taskstate="Starting"}
        9 {$taskstate="Stoping"}
        10{$taskstate="Suspended"}
        11{$taskstate="Terminated"}
        12{$taskstate="Unknown"}
        13{$taskstate="Warning"}
        default{ "you have entered a wrong choice"
                 cleanup
               }
    }      
    return $taskstate
}


function ConvertJsonAlertsToSyslog($alertID,$json_member,$ApplianceIP)
{
    <#
    Internal function called GetAlerts
    Converts JSON to Syslog format
                  
    #>
    Process 
    { 
        $version= $alertID
        $ov_alerts="OV_Alerts-"
        $date=$json_member.created
        $log_level=$json_member.severity
        $app_name=$json_member.resourceUri
        $msg_id=$json_member.uri
        $stru_data1=$json_member.associatedResource.associationType+" "+$json_member.associatedResource.resourceCategory+" "+$json_member.associatedResource.resourceName+" "+$json_member.associatedResource.resourceUri
        $stru_data2=$stru_data1+","+$json_member.alertState+","+$json_member.physicalResourceType
        $msg=$json_member.description+","+$json_member.correctiveAction
        $output = "$ov_alerts"+$version+" "+$date+" "+$log_level+" "+$app_name+" "+"-" +$msg_id+" "+"["+$stru_data2+"]"+" "+"["+$msg+"]"
        $output | Out-File -FilePath $Global:AlertFile -Append
    }
}

function GetAlerts
{
    <#
    Called by User.
    Gets the Alerts from OneView in JSON format.
    Return alerts in Syslog format back to user
    Applies filters if any
    #>
    Param
    (           
        [parameter(Mandatory = $true, HelpMessage = "Enter the IP ")]
        [ValidateNotNullOrEmpty()]
        [System.String]$ApplianceIP,

        [parameter(Mandatory = $true, HelpMessage = "Enter the username")]
        [ValidateNotNullOrEmpty()]
        [System.String]$UserName,

        [parameter(Mandatory = $true, HelpMessage = "Enter the password")]
        [ValidateNotNullOrEmpty()]
        [System.String]$Password,
                

        [parameter(Mandatory = $true, HelpMessage = "Enter the mode")]
        [ValidateNotNullOrEmpty()]
        $mode
    )
           
    Process 
    {
        $start_Date = ""
        $start_time = "00:00:01"
                
        $end_Date = ""
        $end_time = "23:59:59"

        writeLog "JsonToSyslog:GetAlertsToSyslog: Started"

        $returnCode = connectFusion $ApplianceIP $UserName $Password $authProvider
        validateConnection $returnCode
                
        WriteLog "JsonToSyslog:GetAlertsToSyslog: Connected to OneView: " -debuglevel "INFO"

        $Global:AlertFile=$Global:SysLogFilePath_alerts+$ApplianceIP+".log"

        if(! (Test-Path ($Global:AlertFile)))
        {
            $alertfile=New-Item  $Global:AlertFile -type file
        }
                
        Clear-Content -Path $Global:AlertFile
            
        $totalalerts=75000;
        $count=0
        $alertID=0

        if ($mode -eq "interactive") 
        {
            Write-Host "`nIf the date and time is not entered,then it will give all alerts of that Appliance `n"
            [string]$cli_start_Date = Read-Host "Enter the start date(format yyyy-mm-dd)."
            if(!$cli_start_Date)
            {
            }
            else
            {
                $start_Date = validate_Date($cli_start_Date) 
            }
                    
            Write-Host "`nIf start-time is not specified then it will take default start-time:00:00:01 `n"
            $cli_start_time = Read-Host "Enter the start time(format hh:mm:ss)."
            $start_time = validate_StartTime($cli_start_time)
            Write-Host ""
                    
            if($start_Date)
            {        
               [string]$cli_end_Date = Read-Host "Enter the end date(format yyyy-mm-dd)."
               if(!$cli_end_Date)
                {
                    $cli_end_Date=Get-Date -format "yyyy-MM-dd"
                }
                else
                {
                    $end_Date = validate_Date($cli_end_Date)
                } 
            }
            
            if($start_time -ne "00:00:01")
            {     
                Write-Host "If end-time is not specified then it will take default end-time:23:59:59 `n"
                $cli_end_time = Read-Host "Enter the end time(format hh:mm:ss)."
                $end_time=validate_EndTime($cli_end_time)
                
            }

            if($end_Date -gt $start_Date)
            {
                Write-Host "`nThe end_date should be greater than the start_date" -ForegroundColor Red
                writeLog "The User has entered the end_date lesser than start_date" 
                cleanup      
            }      

            $filter_option=Read-Host "`nDo you want to filter the Alerts? enter 'Y' or 'N'"
            if($filter_option -eq 'y' -or $filter_option -eq 'Y')
            {
                $choice=Read-Host "`nThese are the alert state. `n 1.Active `n 2.Cleared `n 3.Locked `n Please Enter a number between 1 to 3"
                $alertstate=checkAlertsChoice($choice)
            }
            elseif($filter_option -eq 'n' -or $filter_option -eq 'N')
            {
                write-Host "By default all alerts state are choosen" -ForegroundColor Yellow
                writeLog "All Alert state is selected"
            }
            else
            {
                write-Host "You have entered wrong filter option " -ForegroundColor Red
                writeLog "User has entered a wrong filter option"
                cleanup
            }
        }

        $new_date1=$cli_start_Date+"T"+$start_time+".000"+"Z" #milisecond 000 and 999 is added for comparision purpose.
        $new_date2=$cli_end_Date+"T"+$end_time+".999"+"Z"

        try{
                    
            writeLog -message "JsonTOSyslog:ConvertJsonAlertsToSyslog :Started " -debuglevel "INFO"
                    
            for($i=0;$i-le $totalalerts;$i=$i+100)
            {
                if($alertstate)
                {
                    $Global:alerts = "/rest/alerts?start=$i&count=100&filter=`"alertState=`'$alertstate`'`""  
                }  
                else
                {
                    $Global:alerts= "/rest/alerts?start=$i&count=100"
                }
                                                  
                $ret_json = Send-HPOVRequest -uri $alerts GET 

                if($new_date1 -eq "T00:00:01.000Z" -and $new_date2 -eq "T23:59:59.999Z")
                {                    
                    foreach($json_member in $ret_json.members.getEnumerator())
                    {
                        ConvertJsonAlertsToSyslog $alertID $json_member $ApplianceIP
                        $alertID++
                    }
                }
                else
                {                   
                    foreach($json_member in $ret_json.members.getEnumerator())
                    {
                        $date = $json_member.created
                        if(($date -ge $new_date1) -and ($date -le $new_date2))
                        {
                            ConvertJsonAlertsToSyslog $alertID $json_member $ApplianceIP
                            $alertID++
                        }
                    }                 
                }
                     
                if($i -gt $ret_json.total)
                {
                    break;
                }
            }
            writeLog -message "JsonTOSyslog:ConvertJsonAlertsToSyslog :Ended " -debuglevel "INFO"
        }
        catch
        {
            writeLog -message "Error in parsing the json_member" -debuglevel "ERROR"
            Write-Error $_.Exception.InnerException.Message
        }
        If ((Get-Content "$Global:AlertFile") -eq $Null) 
        {
            writeLog -message "You dont have any alerts for the specified date, time and alertstate"
            Write-Host "Dont have any alerts for the request" -ForegroundColor Cyan
        }
        else
        {
            writeLog -message "$alertID Alerts successufully listed" -debuglevel "INFO" 
            write-Host "Check $Global:AlertFile file for the output" -ForegroundColor DarkYellow
        }
        writeLog "JsonToSyslog:GetAlertsToSyslog: Ended"
        cleanup
        
    }
           
}


function checkAlertsChoice($choice) 
{
    $alertstate = ""
    switch($choice) #switch($choice -ne $null) does't work
    {
        1 {$alertstate="Active"}
        2 {$alertstate="Cleared"}
        3 {$alertstate="Locked"}  
        default{"you have entered a wrong choice"
                cleanup}
    }
    return $alertstate 

}


function ConvertJsonAuditlogsToSyslog($auditID,$json_member,$ApplianceIP)
{
    <#
    Internal function called GetAudits
    Converts JSON to Syslog format
    #>
    Process 
    { 
        $version=$auditID
        $ov_auditlogs="OV_Auditlogs-"
        $date=$json_member.dateTimeStamp
        $log_level=$json_member.severity
        $app_name=$json_member.objectType
        $msg_id=$json_member.userId
        $stru_data=$json_member.action+","+$json_member.componentId 
        $msg=$json_member.result+","+$json_member.domain+","+$json_member.msg              
        $output =$ov_auditlogs+$version+" "+$date+" "+$log_level+" "+$app_name+" "+"-"+$msg_id+" "+"["+$stru_data+"]"+" "+"["+$msg+"]"
        $output | Out-File -FilePath $Global:AuditFile -Append
    }
}
    
    

function GetAuditlogs
{
    <#
    Called by user. 
    Gets Audits from OneView in JSON format.
    Returns Audit logs in syslog format.
    Applies filters if any.
    #>
    Param
    (                        
        [parameter(Mandatory = $true, HelpMessage = "Enter the IP ")]
        [ValidateNotNullOrEmpty()]
        [System.String]$ApplianceIP,

        [parameter(Mandatory = $true, HelpMessage = "Enter the username")]
        [ValidateNotNullOrEmpty()]
        [System.String]$UserName,

        [parameter(Mandatory = $true, HelpMessage = "Enter the password")]
        [ValidateNotNullOrEmpty()]
        [System.String]$Password,

        [parameter(Mandatory = $true, HelpMessage = "Enter the mode")]
        [ValidateNotNullOrEmpty()]
        $mode
    )
           
    Process 
    {
        $start_Date = ""
        $start_time = "00:00:01"
                
        $end_Date = ""
        $end_time = "23:59:59"

        writeLog "JsonToSyslog:GetAuditlogsToSyslog: Started"

        $returnCode = connectFusion $ApplianceIP $UserName $Password $authProvider
        validateConnection $returnCode

        WriteLog "JsonToSyslog:GetAuditlogsToSyslog: Connected to OneView: " -debuglevel "INFO"

        $Global:AuditFile = $Global:SysLogFilePath_auditlogs+$ApplianceIP+".log"

        if(! (Test-Path($Global:AuditFile)))
        {
            $auditfile=New-Item $Global:AuditFile -type file
        }

        Clear-Content -Path $Global:AuditFile

        $totalalerts=75000;
        $count=0
        $auditID=0

        if ($mode -eq "interactive") 
        {
            Write-Host "`nIf the date and time is not entered,then it will give all audit-logs of that Appliance `n"
            [string]$cli_start_Date = Read-Host "Enter the start date(format yyyy-mm-dd)."
            if(!$cli_start_Date)
            {
            }
            else
            {
                $start_Date = validate_Date($cli_start_Date) 
            }
                    
            Write-Host "`nIf start-time is not specified then it will take default start-time:00:00:01 `n"
            $cli_start_time = Read-Host "Enter the start time(format hh:mm:ss)."
            $start_time = validate_StartTime($cli_start_time)
            Write-Host ""
                    
            if($start_Date)
            {        
               [string]$cli_end_Date = Read-Host "Enter the end date(format yyyy-mm-dd)."
               if(!$cli_end_Date)
                {
                    $cli_end_Date=Get-Date -format "yyyy-MM-dd"
                }
                else
                {
                    $end_Date = validate_Date($cli_end_Date)
                } 
            }
            
            if($start_time -ne "00:00:01")
            {     
                Write-Host "If end-time is not specified then it will take default end-time:23:59:59 `n"
                $cli_end_time = Read-Host "Enter the end time(format hh:mm:ss)."
                $end_time=validate_EndTime($cli_end_time)
                
            }

            if($end_Date -gt $start_Date)
            {
                Write-Host "`nThe end_date should be greater than the start_date" -ForegroundColor Red
                writeLog "The User has entered the end_date lesser than start_date" 
                cleanup      
            }      

            $filter_option=Read-Host "`nDo you want to filter the Audit-logs? enter 'Y' or 'N'"

            if($filter_option -eq 'y' -or $filter_option -eq 'Y')
            {
                
                $choice=Read-Host "These are the audit state.`n 1.success `n 2.failure `n Please Enter a number 1 or 2"
                switch($choice)
                {
                    1 {$audit_state="SUCCESS"}
                    2 {$audit_state="FAILURE"}
                    default{"you have entered a wrong choice"
                        cleanup}
                } 
            }
            elseif($filter_option -eq 'n' -or $filter_option -eq 'N')
            {
                write-Host "By default all audit-logs state are choosen" -ForegroundColor Cyan
                writeLog "All audit-log state has been selected"
            }
            else
            {
                write-Host "You have entered wrong filter option" -ForegroundColor Red
                writeLog "User has entered a wrong filter option"
                cleanup
            }
        }

        if($start_time -eq "00:00:01")
        {
            $cli_start_time=$start_time                  
        }
        if($end_time -eq "23:59:59")
        {
            $cli_end_time = $end_time    
        }

        $new_date1=$cli_start_Date+"T"+$cli_start_time+".000"+"Z" #milisecond 000 and 999 is added for comparision purpose.
        $new_date2=$cli_end_Date+"T"+$cli_end_time+".999"+"Z"

        try{
            writeLog -message "JsonTOSyslog:ConvertJsonAuditlogsToSyslog :Started " -debuglevel "INFO"           
            for($i=0;$i-le $totalalerts;$i=$i+100)
            {
                if($audit_state -and  ($cli_start_Date -and $cli_end_Date))
                {
                    $Global:auditlog = "/rest/audit-logs?start=$i&count=100&filter=`"date>=`'$cli_start_date`'`"&filter=`"date<=`'$cli_end_date`'`"&filter=`"result=`'$audit_state`'`""
                }  
                elseif(!$audit_state -and (!$cli_start_Date -and !$cli_end_Date))
                {
                    $Global:auditlog = "/rest/audit-logs?start=$i&count=100"
                }
                elseif($audit_state -and (!$cli_start_Date -and !$cli_end_Date))
                {
                    $Global:auditlog = "/rest/audit-logs?start=$i&count=100&filter=`"result=`'$audit_state`'`""
                }
                elseif(!$audit_state -and ($cli_start_Date -and $cli_end_Date))
                {
                    $Global:auditlog = "/rest/audit-logs?start=$i&count=100&filter=`"date>=`'$cli_start_date`'`"&filter=`"date<=`'$cli_end_date`'`""
                }
                elseif($audit_state -and ($cli_start_Date -and !$cli_end_Date))
                {
                    $Global:auditlog = "/rest/audit-logs?start=$i&count=100&filter=`"date>=`'$cli_start_date`'`""
                }
                elseif(!$audit_state -and (!$cli_start_Date -and $cli_end_Date))
                {
                    $Global:auditlog = "/rest/audit-logs?start=$i&count=100&filter=`"date<=`'$cli_end_date`'`""
                }
                elseif($audit_state -and (!$cli_start_Date -and $cli_end_Date))
                {
                    $Global:auditlog = "/rest/audit-logs?start=$i&count=100&filter=`"date<=`'$cli_end_date`'`"&filter=`"result=`'$audit_state`'`""
                }
                elseif(!$audit_state -and ($cli_start_Date -and !$cli_end_Date))
                {
                    Global:auditlog = "/rest/audit-logs?start=$i&count=100&filter=`"date>=`'$cli_start_date`'`""
                }
                         
                $ret_json = Send-HPOVRequest -uri $auditlog GET 
                         
                if($new_date1 -eq "T00:00:01.000Z" -and $new_date2 -eq "T23:59:59.999Z")
                {                      
                    foreach($json_member in $ret_json.members.getEnumerator())
                    {
                        ConvertJsonAuditlogsToSyslog $auditID $json_member $ApplianceIP
                        $auditID++
                    }                     
                }
                else
                { 
                    foreach($json_member in $ret_json.members.getEnumerator())
                    {
                        $date = $json_member.dateTimeStamp
                                
                        if(($date -ge $new_date1) -and ($date -le $new_date2))
                        {
                            ConvertJsonAuditlogsToSyslog $auditID $json_member $ApplianceIP
                            $auditID++
                        }
                    }                     
                }
                if($i -gt $ret_json.total)
                {
                    break;
                }
            }
            writeLog -message "JsonTOSyslog:ConvertJsonAuditlogsToSyslog:Ended " -debuglevel "INFO"
        }
        catch
        {
            Write-Error $_.Exception.InnerException.Message 
            writeLog -message "Error in parsing the json_member" -debuglevel "ERROR"
        }
        If ((Get-Content "$Global:AuditFile") -eq $Null) 
        {
            writeLog -message "You dont have any auditlogs for the specified date, time and auditstate"
            Write-Host "Dont have any auditlogs for the request" -ForegroundColor Cyan
        }
        else
        {
            writeLog -message "$auditID audit_logs successufully listed" -debuglevel "INFO"
            Write-Host "Check $Global:AuditFile file for the output" -ForegroundColor DarkYellow
        }
        writeLog "JsonToSyslog:GetAuditlogsToSyslog: Ended"        
        cleanup
    }
}


     
<#function cleanup ($returncode) 
{        
    if ($returncode -ne "" -or $returncode -ne $null)
    {
        Disconnect-HPOVMgmt
        Remove-Module OneViewJsonToSyslog
        Remove-Module HPOneView.$Global:version
    }
    exit
}#>
            