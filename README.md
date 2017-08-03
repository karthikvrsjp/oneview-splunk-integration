# Splunk Integration with OneView
This script attaches to a OneView instance and extracts the Alerts, Tasks, and
Audit logs from the appliance.  It formats the log files in syslog format.  When
used in conjunction with a Splunk Universal Forwarder configured to monitor the
directory housing the extracted log files, these files are then forwarded to a
Splunk Indexer instance for analysis.

# Prerequisites
  1. Install `OneView POSH Library` (https://github.com/HewlettPackard/POSH-HPOneView.git)
  2. Python 3.5

# Supported OneView versions
OneView 1.2, 2.0, 3.0

# How To
1. Modify the "generate_syslogs_from_oneview.ps1" file to reflect the IP address of the OneView
   Appliance (ApplianceIP) and the Administrative user (UserName).  The authProvider can be left
   at "LOCAL" assuming local authentication methods are used.  The OneView appliance password
   can be hard-coded in the "Global.appPassword" field.  If left $null the script will prompt
   the user to enter the one-time password.  

Example:

```
   $ApplianceIP         = "10.10.10.1"
   $UserName            = "Administrator"
   $Global:authProvider = "LOCAL"
   $Global:appPassword  = $null
```

2. Configure a Splunk Universal Forwarder to monitor the directory housing the extracted
   log files.  These files are then pushed to the configured Splunk Indexer.

   Sample Splunk inputs.conf file:
```
   [default]
   host = <local hostname>
   [script://$SPLUNK_HOME\bin\scripts\splunk-wmi.path]
   disabled = 0
   [monitor:///<directory containing extracted syslog files>]
   disabled=false
   sourcetype=syslog
```

   Sample Splunk outputs.conf file:
```
   [tcpout]
   defaultGroup=my_indexers
   [tcpout:my_indexers]
   server=<splunk indexer hostname or IP>:9997
   [tcpout-server://<splunk indexer hostname or IP>:9997]
```

3. Configure a Splunk Enterprise instance and start a listener process on port 9997.

```   
   C:\>splunk enable listen 9997
   Listening for Splunk data on TCP port 9997.

   C:\>splunk display listen
   Receiving is enabled on port 9997.
```

Command-line to execute the script:

```
C:\Splunk_Integration\generate_syslogs_from_oneview.ps1
```
