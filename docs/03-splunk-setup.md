# 3. Splunk setup and verification

## Log in

```
terraform output splunk_web_url
```
Username `admin`, password whatever you set as `TF_VAR_splunk_admin_password`.

## Verify forwarders are connected

**Settings > Forwarder Management** (or run this SPL): you should see the
Windows victim, Ubuntu victim, and (if enabled) the Suricata sensor as
connected forwarding clients within a few minutes of them finishing their
first-boot script.

```spl
| metadata type=hosts index=main
```
should list all your forwarder hostnames with a recent `lastTime`.

## Verify data is arriving

```spl
index=main sourcetype="WinEventLog:Security" | head 5
index=main sourcetype="WinEventLog:Microsoft-Windows-PowerShell/Operational" | head 5
index=main sourcetype="WinEventLog:Microsoft-Windows-Sysmon/Operational" | head 5
index=main sourcetype="linux_secure" | head 5
index=main sourcetype="suricata" | head 5
```
If a sourcetype comes back empty after 10+ minutes, SSH/RDP to that box and
check the forwarder's own logs:
- Linux: `/opt/splunkforwarder/var/log/splunk/splunkd.log`
- Windows: `C:\Program Files\SplunkUniversalForwarder\var\log\splunk\splunkd.log`

Look for `TcpOutputProc` connection errors (usually a `pass4SymmKey` mismatch
or a security group blocking 9997 - shouldn't happen here since all boxes
share the `lab-internal` security group, but check if you've customized it).

## Verify the soc_lab app deployed

**Apps** (top nav) should list **SOC Lab**. Under it:
- **Searches, reports, and alerts** should show the 8 detections from
  `scripts/splunk/detections/savedsearches.conf`, each already scheduled
  (`*/5 * * * *`).
- **Dashboards** should show **SOC Overview** - open it, set the time range to
  "Last 24 hours"; panels will be empty until you generate some traffic (see
  [05-attack-scenarios.md](05-attack-scenarios.md)).
- **Lookups > Lookup table files** should show `threat_intel.csv`.

If the app isn't there, it means the Splunk box's user_data script failed
partway - check `/var/log/cloud-init-output.log` on that instance.

## Optional: better field extraction (recommended, not automated)

The detections use raw `EventCode=`/`Account_Name` style fields, which Splunk
extracts out of the box well enough for this lab. For real CIM compliance and
richer parsing, install these from Splunkbase (requires a free splunk.com
login, so not automated here):

- **Splunk Add-on for Microsoft Windows** (TA-windows)
- **Splunk Add-on for Sysmon**

Splunk Web > **Apps > Find More Apps**, search for each, install, restart.
