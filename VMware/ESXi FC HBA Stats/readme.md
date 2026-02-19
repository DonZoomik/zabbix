For getting ESXi FC HBA error stats out as FC errors do not show up anywhere else (except eventually slowness or paths going down). These counters are not available in performance stats so esxcli is effectively the only way to get them out.

It is meant to piggyback Zabbix default vCenter + ESXi host prototype, add it as template to host prototype.

I removed some internal comments but I guess it still works.