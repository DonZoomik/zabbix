#some logging would be nice, even to console...

#Hitachi data collector
$ExportToolRoot = "C:\export"
$ExportToolOutout = $ExportToolRoot + '\out'
$ExportToolLog = $ExportToolRoot + '\log'
#All CSVs have this header that should be skipped
$HeaderLines = 5
#Value headers to skip for LLD
$CSVBlacklist = @('No.','time')

#If you have many, select first. presume same arch as OS
$ZabbixEXE = (Get-ChildItem -Path ($env:ProgramFiles) -Recurse -File -Filter 'zabbix_sender.exe')[0]
#use config from service instance
$ZabbixConfigFile = $ZabbixEXE.Directory.FullName + '\zabbix_agentd.conf'
Write-host $ZabbixConfigFile
#Cast config file to hashtable, skip comments and empty lines
#Escape backslashes
$ZabbixConfig = (Get-Content -Path $ZabbixConfigFile | Select-String -NotMatch '^#|^$').line.replace('\','\\')|ConvertFrom-StringData
$ZabbixServerActive = ($ZabbixConfig.ServerActive -split ',')[0]

#Clean up old perf data files, otherwise export will require input
Get-ChildItem -Path $ExportToolOutout -Recurse | Remove-Item -Force -Recurse
#clean up logs
Get-ChildItem -Path $ExportToolLog -Recurse | Where-Object -FilterScript {$_.LastWriteTime -lt (Get-Date).AddDays(-1)} | Remove-Item -Force -Recurse

#Collect performance data from utility
#remove "pause" from script
#edit command.txt to give only short amount of data (-0005 or something). parse algorithm is way too inefficient right now for 24h
#could also disable a few datagroups, most seem to be empty or just irrelevant
Start-Process -FilePath ($ExportToolRoot + "\RunWin.bat") -WorkingDirectory $ExportToolRoot -Wait

$ExportFiles = Get-ChildItem -Path $ExportToolOutout -Recurse -File 
$ItemKeys = @()
#$DataValues = @()

#parse
foreach ($ExportFile in $ExportFiles) {
    #Write-Host ('parsing file ' + $ExportFile.Basename)
    $ExportFileContent = Get-Content -Path $ExportFile.FullName
    #First N lines are header, rest is CSV
    $ExportFileHeader = $ExportFileContent | Select-Object -First $HeaderLines
    $ExportFileCSV = Get-Content -Path $ExportFile.FullName | Select-Object -Skip $HeaderLines | ConvertFrom-Csv -Delimiter ','
    #Get system name from header, we need that for item generation
    $HDSSystemID = ($ExportFileHeader | Select-String -Pattern 'Serial number').Line.Split(':')[1].Trim()
    #Cast file name to data type. For now we dont differentiate between object types
    $HDSDataType = $ExportFile.BaseName
    #All column headers from CSV, neede for discovery and later converting to key-values for zabbix sender
    $HDSDataInstances = ($ExportFileCSV | Get-Member -MemberType NoteProperty | Where-Object -FilterScript {$CSVBlacklist -notcontains $_.Name}).Name
    #Write-host ('file has columns ' + $HDSDataInstances.Length)
    #Write-host ('file has rows ' + $exportfilecsv.length)
    #items for discovery
    #(Measure-Command -Expression {
    ForEach ($HDSDataInstance in $HDSDataInstances) {
        #Maybe shorten...? Must be in sync with rows
        #system Id is not really required unless you're aggerateing several SAN datasets to one zabbix host
        $KeyName = $HDSSystemID + ':' + $HDSDataType  + ':' + $HDSDataInstance
        $ItemKeys += $KeyName
    }
    #}).totalseconds

    #$DataValues = @()

    #(Measure-Command -Expression {
    #Rows into unique values
    $DataValues = ForEach ($DataRow in $ExportFileCSV) {
        #Depending on locale, you might need to specify CSV time format for correct interpretation. Zabbix needs UNIX timestamp.
        #Local time seems fine (SVP exports local time), .Net converts it to UTC based on SVP timezone
        #You REALLY need timestamps as SVP data export is always ~3 minutes behind (newest data is not yet available).
        #If you don't do timestamps, values will be offset in zabbix by a few minutes, making data correlation much harder 
        $UnixTimeStamp = ([DateTimeOffset](Get-Date -Date ($DataRow.time))).ToUnixTimeSeconds()
        ForEach ($HDSDataInstance in $HDSDataInstances) {
            #Same key as in discovery
            $Key = $HDSSystemID + ':' + $HDSDataType  + ':' + $HDSDataInstance
            $Value = $DataRow.$HDSDataInstance
            #zabbix with timestamps format, all positions double quoted just in case
            #key in item value must be escaped with double quotes or sender/trap will not accept values for some reason. make sure that LLD in template is configured the same.
            #hostname could be changed to '-' to save memory, it's also set in sender cmd params
            #$DataValues += """$($ZabbixConfig.hostname)"" ""$('hitachi.storage.performance.item[\`"' + $Key + '\`"]')"" ""$UnixTimeStamp"" ""$Value"""
            #$DataValues += 
            Write-Output ("- ""$('hitachi.storage.performance.item[\`"' + $Key + '\`"]')"" ""$UnixTimeStamp"" ""$Value""")
        }
    }
    #$DataValues|&$ZabbixEXE.FullName -vv -z ""$($ZabbixConfig.Server)"" -s ""$($ZabbixConfig.hostname)"" -T -i ""$($DataValuesFile.FullName)" -"
    #$DataValues | &$ZabbixEXE.FullName -z ""$($ZabbixConfig.Server)"" -s ""$($ZabbixConfig.hostname)"" -T -i -
    $DataValues | &$ZabbixEXE.FullName -z ""$($ZabbixServerActive)"" -s ""$($ZabbixConfig.hostname)"" -T -i -
    #}).TotalSeconds
}
#this is currently quite inefficient. all values are collected to memory, then dumped to disk and then finally sent.
#with long timeseries this will consume significant CPU time, memory and IO. with a few minutes intervals, it's measureably high but acceptable.
#keeping hostname short and key short would also help significantly with memory - hostname changed to '-', sent in sender config
#+= operator is really slow on large arrays, stringbuilder would help - workaround with capturing loop output
#one workaround would be to collect values to memory per CSV and then pipe memory to zabbix sender, at least it'd do some work and then reset state - DONE

#we shouldn't send it each time but it really doesn't matter. even if we send empty discovery, items will be kept on zabbix side for some time so next run would re-enable them.
#maybe add filter to send it only if minute is 00 or something...
$LLDJSON = @{data=@($ItemKeys)|%{@{'{#I}'=$_}}}|ConvertTo-Json -Compress
#$LLDJSONTempFile = New-TemporaryFile
#we need host-key-value syntax. value is whole LLD json
#zabbix doc says that it need utf8, however default (default ASCII codepage?) seems to work better in practice.
#($($ZabbixConfig.hostname) + ' ' + "hitachi.storage.performance.discovery" + ' ' + $LLDJSON) | Out-File -FilePath $LLDJSONTempFile.FullName -Encoding default
#make sure that zabbix host discovery item and item prototype are configured to with "allowed hosts" or server will drop the data
#&$ZabbixEXE.FullName -vv -z ""$($ZabbixConfig.Server)"" -s ""$($ZabbixConfig.hostname)"" -i ""$($LLDJSONTempFile.FullName)""
#($($ZabbixConfig.hostname) + ' ' + "hitachi.storage.performance.discovery" + ' ' + $LLDJSON) | &$ZabbixEXE.FullName -z ""$($ZabbixConfig.Server)"" -s ""$($ZabbixConfig.hostname)"" -i -
($($ZabbixConfig.hostname) + ' ' + "hitachi.storage.performance.discovery" + ' ' + $LLDJSON) | &$ZabbixEXE.FullName -z ""$ZabbixServerActive"" -s ""$($ZabbixConfig.hostname)"" -i -

#Remove-Item -Path $LLDJSONTempFile.FullName -Force

#migrated to per-CSV in-memory pipeline
#$DataValuesFile = New-TemporaryFile
#$DataValues | Out-File -FilePath $DataValuesFile.FullName -Encoding default
#it'll take several minutes after sending discovery, until server starts accepting data, even it items have been already created.
#not sure why but probably some kind of caching on server side
#&$ZabbixEXE.FullName -vv -z ""$($ZabbixConfig.Server)"" -s ""$($ZabbixConfig.hostname)"" -T -i ""$($DataValuesFile.FullName)""
#Remove-Item -Path ($DataValuesFile.FullName) -Force