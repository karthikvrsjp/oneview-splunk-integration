##############################################################################
# Name: generate_syslogs_from_oneview.ps1
# Description: main script to call syslog functions
#
# Date: Mar 2016
##############################################################################

Import-Module .\OneViewJsonToSyslog.psm1
Import-Module .\HPOneView.200.psm1

$ApplianceIP = "10.54.31.211"
$UserName = "Administrator"
$Global:authProvider    = "LOCAL"
$Global:appPassword     = $null


if($Global:appPassword -eq $null){
[System.Security.SecureString]$tempPassword = Read-Host "Enter onetime OneView Appliance Password to be connected! " -AsSecureString
$Global:appPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($tempPassword))
}

try
{
    $version=(Get-HPOVXApiVersion -appliance $ApplianceIP).currentVersion

   if($version -eq 300)
    {
        Remove-Module HPOneView.200
        Import-Module .\HPOneView.300.psm1
    }

}
catch
{
    $ErrorMessage = $_.Exception.Message
    Write-Host $ErrorMessage -ForegroundColor Red
    writeLog -message $ErrorMessage -debuglevel "ERROR"
    Remove-Module HPOneView.$version
    exit

}


#Mode = "batch" or "interactive"
#for splunk integration, mode should be set to batch mode.
#if set to interactive, user will be asked list of questions

#Alerts to Syslog
GetAlerts -ApplianceIP $ApplianceIP -UserName $UserName -password $Global:appPassword -mode "batch"

#Tasks to Syslog
GetTasks -ApplianceIP $ApplianceIP -UserName $UserName -password $Global:appPassword -mode "batch"

#Audits to syslogs
GetAuditlogs -ApplianceIP $ApplianceIP -UserName $UserName -password $Global:appPassword -mode "batch"

#Cleanup Modules
FinalCleanup
