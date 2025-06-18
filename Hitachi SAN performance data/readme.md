I wrote that because I was having issues with Hitachi SAN (G200, G350, etc...) and the built-in Flash based tool was very hard to use. I wanted to dump performance data into Zabbix and got cracking.

It uses Hitachi "export" tool to dump performance data into CSV and sends to to Zabbix using zabbix-sender. You can get export tool from Hitachi downloads for your array. Export tool connects to SVP service.

After dumping data using export, script parses the data and generates discovery data for each key. And then data is sent. It's basically the first version that worked, so it's ugly. Some valuable info in comments. I did start writing v2 for more reasonable behavior but as it was good enough, it never got anywhere.

No grouping, no logic, no triggers, no graphs. Just raw data dumped to Zabbix. I created interesting graphs manually in dashes or used Graphana but this is raw data dump only. 