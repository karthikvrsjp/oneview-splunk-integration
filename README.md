# oneview-splunk-integration
Helps to send OneView audit logs and alerts data to Splunk.

Business Problem:

Most IT businesses requires auditing of your IT infrastructure. You need to store your infrastructure logs into Central logging system. 
HPE OneView stores audit logs and alerts data for the servers it is managing. You need a mechanism to send those logs and data 
into central log system like Splunk.

Solution OneView:

HPE OneView allows user to dowload audit logs and alerts data through REST APIs or through UI ( only audit logs). 
But these logs and data is in JSON format. If you are integrating with Splunk, your logs files should be in syslog format.

The standard log format is based the Syslog RFC 5424 http://tools.ietf.org/html/rfc5424
 
The basic format looks as follows:

<version> <timestamp> <log-level> <app-name> <procid> <msgid> <structured-data> <message>

The log record consists of several fields (enclosed in <>) which are all separated by a single space. The version identifier is used as record separator.

Here is an example record:

OV-1 2016-05-10T20:46:05.181+02:00 INFO HRApp – ABC-12345 [audit@5095 action="login" result="success" user="guest"] Login successful: guest user

High level architecture:

- Scripts will run on Windows VM and connect to OneView
- Scripts convert JSON data into syslog format
- Splunk agent will be configured on Windows VM to pick up the logs
- Splunk agent will push the logs to central Splunk server
- Scripts can be scheduled through scheduler

Pre-requisites to setup the integration environment:

- Windows VM
- Access to OneView appliance
- Splunk agent configured on Windows VM
- Splunk server to receive the logs
- Scripts

How to run scripts:

- Copy the scripts to a folder
- Run below command from Windows VM
  ./generate_syslogs_from_oneview.ps1

Notes about scripts:

All scripts are written in powershell langauge.
- generate_syslogs_from_oneview.ps1
  This is main script which takes user inputs and invokes library.
- OneViewJsonToSyslog.psm1
  This is library contains methods to convert JSON data to syslog format
- HPOneView.psm1
  This is core HPE OneView powershell library - which connect to OneView using REST APIs.

The scmb folder within repo is helpful if you are interested to listen on HPE OneView message bus ( SCMB )
instead of pulling alerts data from activity page.

