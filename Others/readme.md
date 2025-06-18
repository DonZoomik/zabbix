# Windows Print Spooler

I had a problem where some queues would get stuck, effectively blocking any printing. This template alerts if it thinks that queue is stuck.

# HPE SSACLI Windows 

Alerts on HPE SmartArray (OEM MicroChip RAID controllers) errors. Uses ssacli utility and parses out some data

# Intel RSTe

Very simple, alerts if RSTe is not healthy.

# Template LSI JSON discovery

For Broadcom MegaRAID controllers. Gets a bunch of data and alerts on failures. There's another LSI template here but I don't remember why I created it.

NB! It does not get data for disks that are not connected to a backplane. Never bothered to fix it as I had only one server with such disks and it would alert via other means as well (Ctl or Vd health).

# Veeam

Basin stuff for Veeam Backup and Replication. Gets failed jobs and if a new session has not started for 24 hours - for example if job is stuck.

I wrote it because I had only Enterprise version that does not have REST API support and I wanted some better overview when jobs were failing or getting stuck for some reason.