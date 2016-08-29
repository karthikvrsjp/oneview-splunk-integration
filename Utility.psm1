##############################################################################
# Name: Utility.psm1 
# Description: Utility functions
# 
# Date: Mar 2016 
##############################################################################
$Global:root        = ".\"
$t = Get-Date -Format dd-MM-yyyy
$Global:LogFilePath = "$Global:root\Logs" +'\Logfile_' +$t +'.'+ "log"

#Regural expression for checking data format
$Global:regex =[regex]'^(19|20)\d\d[-](0[1-9]|1[012])[-](0[1-9]|[12][0-9]|3[01])$'     
$Global:regex2=[regex]'^(0[0-9]|1[0-9]|2[0-3])[:](0[0-9]|1[0-9]|2[0-9]|3[0-9]|4[0-9]|5[0-9])[:](0[0-9]|1[0-9]|2[0-9]|3[0-9]|4[0-9]|5[0-9])$'


function writeLog 
{
	<#
      Log informational messages.Function will output log messages to assist with debugging
    #>

	Param (
		[parameter (ValueFromPipeline = $true)]
		[System.Object]$message,
		[System.String]$debuglevel = "INFO"
	)
	Begin 
    {
		# Test for existence of log directory
		if(!(Test-Path -Path $Global:LogFilePath))
		{
			New-Item $Global:LogFilePath -ItemType file
		}
	}
	Process 
    {
		$date = Get-Date -format MM:dd:yyyy-HH:mm:ss	
	
		if ($debuglevel -eq "INFO")
		{
			Write-Output "$date INFO: $message" | Out-File $Global:LogFilePath -append
		}
		elseif ($debuglevel -eq "DEBUG")
		{
			Write-Output "$date DEBUG: $message" | Out-File $Global:LogFilePath -append
		}
		elseif ($debuglevel -eq "WARNING")
		{
			Write-Output "$date WARNING: $message" | Out-File $Global:LogFilePath -append
		}
		elseif ($debuglevel -eq "ERROR")
		{
			Write-Output "$date ERROR: $message" | Out-File $Global:LogFilePath -append
		}
	}
}

function cleanup{
    try
    {
        $modules= Get-Module 
        $i=0
        if ($returncode -ne "" -or $returncode -ne $null)
        {
            Disconnect-HPOVMgmt
            for($i -eq 0;$i -lt $modules.Name.Length;$i=$i+1)
            {
                if(($modules.Name[$i] -ne "Microsoft.PowerShell.Management") -and ($modules.Name[$i] -ne "ISE") -and ($modules.Name[$i] -ne "Microsoft.PowerShell.Utility") )
                {
                    Remove-Module $modules.Name[$i]
                }
            }
        }
        exit(1)
    }
    catch
    {
        exit(1)
    }
}

function connectFusion([string]$ipAddress, [string]$appUname, [string]$appPwd, [string]$authProvider)
{
    <#
	  function Connects to HPOV Appliance.       
    #>
	
	writeLog "FUNCTION BEGIN connectFusion"
    $script:returnCode = Connect-HPOVMgmt -appliance $ipAddress -user $appUname -password $appPwd -authProvider $authProvider  
    return $script:returnCode
    cleanup
    writeLog "FUNCTION END connectFusion"
}

function validateConnection ( $returnCode )
{
    writeLog "FUNCTION BEGIN validateConnection"
    if($returnCode)
    {      
        
	    Write-Host
	    Write-Host "ERROR: Incorrect username or password supplied to $ApplianceIP " -ForegroundColor Yellow -BackgroundColor Black 
	    
    }
    writeLog "FUNCTION END validateConnection"
}

function validate_Date($Dates)
{
    if($Dates –match $regex )
    {   
        $Date=$Dates.Split("{'-'}")
        $leapY = ($Date[0]%4 -eq 0 -and $Date[0]%100 -ne 0 -or $Date[0]%400 -eq 0)
        if (($Date[1] -eq '01' -or $Date[1] -eq '03' -or $Date -eq '05' -or $Date[1] -eq '07' -or $Date[1] -eq '08' -or $Date[1] -eq '10' -or $Date[1] -eq '12') -and ($Date[2] > '31'))
        {
            Write-Host "no. of days should not exceed 31"-ForegroundColor Red
            cleanup
        }
        elseif (($Date[1] -eq '04' -or $Date[1] -eq '06' -or $Date[1] -eq '09' -or $Date[1] -eq '11' ) -and ($Date[2] -gt '30'))
        {
            Write-Host "no. of days should not exceed 30" -ForegroundColor Red
            cleanup
        }
        elseif ($Date[1] -eq '02')
        {
            if( $leapY -eq $true  -and $Date[2] -gt '29')
            {
                Write-Host "no. of days should not exceed 29" -ForegroundColor Red
                cleanup
            }
            elseif($leapY -eq $false -and $Date[2] -gt '28')
            {
                Write-Host "no. of days should not exceed 28" -ForegroundColor Red
                cleanup
            }
            
        }
        return $Date[0]-$Date[1]-$Date[2]
    }
    else
    {
        Write-Host "Invalid Date!!`n" -ForegroundColor Red
        cleanup
    }
}

function validate_StartTime($start_time)
 {           
    if(!$start_time)
    {
        [system.string]$start_time="00:00:01"
       
    }
    elseif($start_time –notmatch $regex2 )
    {
        write-Host "You have entered a wrong time" -ForegroundColor Red
        cleanup
    }     

    return $start_time
 } 

 function validate_EndTime($end_time)
 {          
    if(!$end_time)
    {
        [system.string]$end_time="23:59:59"
       
    }
    elseif($end_time –notmatch $regex2)
    {
        write-Host "You have entered a wrong time" -ForegroundColor Red
        cleanup
    }
        
    return $end_time
} 

function taskCompletionCheck([hashtable]$hashtable, $ErrorFile, $SuccessFile , $state)
{
    <#
      Function to check for the completion of tasks
    #>

    if ($hashtable.Count -ge 1)
    {
        foreach($task in $hashtable.GetEnumerator())
        {
            $taskUri = $task.key
            $taskResourceName = $task.Value

            $taskStatus = Wait-HPOVTaskComplete $taskUri -timeout (New-TimeSpan -Minutes 10)

            if($taskStatus.taskErrors -ne "null")
            {                                
                writeLog $taskStatus.taskErrors.message -debuglevel "ERROR"
                $taskResourceName + "," + $taskStatus.taskErrors.errorCode | Add-Content $ErrorFile -Force
                Write-Host " Failed:"  $taskResourceName "!" "  " -ForegroundColor Red 
            }
            elseif($taskStatus.taskState -eq "Completed" -or $taskStatus.taskState -eq "Running" -or $taskStatus.taskState -eq "Applying" -or $taskStatus.taskState -eq "Starting")
            {
                $resourceName = $taskStatus.associatedResource.resourceName
                writeLog -message " $taskResourceName is $state"
                Write-Host  $taskResourceName "$state!" -ForegroundColor Yellow
                $taskResourceName + "," + $state | Add-Content $SuccessFile -Force 
            }
        }
    }
}

function CreateNewFile($successFile, $ErrorFile)
{
    <#
      Function creates output files for OneViewServerManagementModule.psm1
    #>

    if(! (Test-Path -Path $successFile  -PathType Any))
    {
        New-Item -ItemType File -Path  $successFile
    }
    if(! (Test-Path -Path  $ErrorFile -PathType Any))
    {
        New-Item -ItemType File -Path  $ErrorFile
    }
    Clear-Content -Path  $successFile
    Clear-Content -Path  $ErrorFile
}

function CreateNewGetFile($outputFile)
{
    <#
      Function creates output files for OneViewServerReportsModule.psm1
    #>

    if(! (Test-Path -Path $outputFile  -PathType Any))
    {
        New-Item -ItemType File -Path  $outputFile
    }
    Clear-Content -Path  $outputFile
}


