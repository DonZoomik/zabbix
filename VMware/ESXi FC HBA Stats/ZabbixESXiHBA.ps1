Import-Module -Name 'VMware.PowerCLI'
$zabbixpath = "C:\ZabbixESXiHBA\zabbix_sender.exe"
$zabbixserver = 'my.zabbix.proxy'
$VcenterServerUris = @('my.vcenter1','my.vcenter2')
Foreach ($VcenterServerUri in $VcenterServerUris) {
    $VcenterServerUriCredentialFile = ('C:\ZabbixESXiHBA\',$VcenterServerUri,'.',$env:USERNAME,'.credentials') -join ''
    $VcenterServerUriCredential = Import-Clixml -Path $VcenterServerUriCredentialFile
    #To update credentials, you must perform the following task under user account that the scheduled task runs with, for each vcenter. Credentials are stored as securestring, only the same user can decrypt it.
    #For SYSTEM and similar, USERNAME is <computername>$
    #$VcenterServerUriCredentialFile = "C:\ZabbixESXiHBA\my.vcenter1.myuser.credentials"
    #Get-Credential | Export-Clixml -Path $VcenterServerUriCredentialFile
    $VcenterServer = connect-viserver -Server $VcenterServerUri -Credential $VcenterServerUriCredential
    foreach ($VMHost in (Get-VMHost -Server $VcenterServer | Where-Object -FilterScript {$_.ConnectionState -in ('Maintenance','Connected')})) {
        $HostUUID = $VMHost.ExtensionData.Hardware.SystemInfo.Uuid
        $esxcli = Get-EsxCli -VMhost $VMHost -V2 -Server $VcenterServer
        $fcstats = $esxcli.storage.san.fc.stats.get.Invoke()
        $fcstatsjson = $fcstats | ConvertTo-Json -Compress
        $fcstatsjson = $fcstatsjson -replace '"','"""' #Need to escape quotes being lost
        $result = Start-Process -FilePath $zabbixpath -ArgumentList '-z',$zabbixserver,'-p','10051','-s',$HostUUID,'-k','esxclifcstats','-o',"$fcstatsjson" -Wait -PassThru -NoNewWindow
        write-host $result.ExitCode
    }
    Disconnect-VIServer -Server $VcenterServer -Confirm:$false
}