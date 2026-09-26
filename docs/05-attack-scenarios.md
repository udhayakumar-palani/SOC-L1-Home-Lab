# 5. Attack scenarios - walking the full alert lifecycle

Every scenario below maps to the "What happens to each alert" 9-step flow in
the diagram: **Collect -> Detect -> Triage -> Investigate -> Verdict ->
Escalate -> Contain -> Document -> Tune**. Run these from Kali against your
own lab boxes only.

## Scenario 1: SSH brute force (T1110) - Kali -> Ubuntu victim

```bash
# on Kali
ssh -i ~/.ssh/soc-lab-key.pem kali@<kali-public-ip>
sudo apt-get install -y hydra seclists 2>/dev/null || true

hydra -l ubuntu -P /usr/share/wordlists/rockyou.txt.gz \
  ssh://<ubuntu-victim-private-ip> -t 4 -f
```
(Private IP, not public - Kali and the victim talk to each other over the lab
subnet, exactly like the host-only network in the original diagram.)

**1-2 Collect/Detect**: within 5 minutes, the `T1110 - SSH Repeated Failed
Logons (Ubuntu)` scheduled search fires in Splunk (**Activity > Triggered
Alerts**).

**3 Triage**: open the alert, confirm it's `ssh_user=ubuntu` from Kali's
private IP with a high count in a short window - real, not noise. Severity:
high (it's a working credential attempt against a live host).

**4 Investigate**: pivot in Splunk -
```spl
index=main sourcetype="linux_secure" src_ip="<kali-private-ip>"
| table _time, ssh_user, src_ip
```
Check whether any attempt eventually succeeded (`Accepted password` in
auth.log) - that changes the verdict from "attempted" to "compromised".

**5 Verdict**: true positive.

**6 Escalate**: create a TheHive case (see
[04-thehive-servicenow.md](04-thehive-servicenow.md)) - the bridge script
turns it into a ServiceNow incident for L2.

**7 Contain**: (L2, but do it yourself to complete the loop) block the
attacker IP at the security-group level, or in a real environment this is
where pfSense/a firewall rule would go - here, tighten
`aws_security_group.lab_internal` or stop the Kali instance.

**8 Document**: timeline in the TheHive case - first failed attempt, count,
whether login succeeded, MITRE T1110.

**9 Tune**: if this generates too much noise in a real deployment, this is
where you'd raise the threshold in `savedsearches.conf` (currently `count >= 5`
in 5 minutes).

## Scenario 2: Port scan (T1046) - Kali -> both victims, seen by Suricata

```bash
# on Kali
nmap -sS -p- -T4 <windows-victim-private-ip>
nmap -sV <ubuntu-victim-private-ip>
```

This traffic is mirrored to the Suricata sensor via VPC Traffic Mirroring.
Check Suricata saw it directly first:
```bash
ssh -i ~/.ssh/soc-lab-key.pem ubuntu@<suricata-public-ip>
sudo tail -f /var/log/suricata/eve.json | jq 'select(.event_type=="alert")'
```
Then in Splunk, the `T1046 - Suricata Scan/Recon Alert` search should fire.
Walk the same 9 steps as Scenario 1.

If you see nothing in `eve.json` at all, the VXLAN decap interface likely
didn't come up - check `ip link show vxlan-mirror` on the Suricata box and
`sudo systemctl status suricata`.

## Scenario 3: Suspicious PowerShell + new admin account (T1059.001 / T1136.001) - Atomic Red Team on the Windows victim

RDP into the Windows victim (`terraform output windows_victim_public_ip` +
the decrypted Administrator password from
[02-deploy.md](02-deploy.md)). Invoke-AtomicRedTeam was installed by
user_data (`C:\AtomicRedTeam`). Open PowerShell **as Administrator**:

```powershell
Import-Module "C:\AtomicRedTeam\invoke-atomicredteam\Invoke-AtomicRedTeam.psd1" -Force

# T1136.001 - Create a local account, then add it to Administrators
Invoke-AtomicTest T1136.001 -GetPrereqs
Invoke-AtomicTest T1136.001

# T1059.001 - encoded PowerShell command (classic obfuscation pattern)
Invoke-AtomicTest T1059.001
```

**1-2 Collect/Detect**: `T1136.001 - New Local User Account Created` and
`T1098 - Account Added to Local Administrators` fire from the 4720/4732
events; `T1059.001 - Suspicious PowerShell Command` fires from the 4104
script-block-logging event.

**3-5 Triage/Investigate/Verdict**: pivot -
```spl
index=main sourcetype="WinEventLog:Security" (EventCode=4720 OR EventCode=4732)
| table _time, Account_Name, Member_Name, Caller_User_Name
```
Since this was you running Atomic Red Team, mark it true positive but
attributable to authorized testing when you document it - or leave it as a
genuine "unauthorized admin account" drill and run the full escalate/contain
loop as if it were real.

**6-9**: same as Scenario 1 - case in TheHive, incident in ServiceNow,
document the timeline, and note in "Tune" whether the detection's 5-minute
window/threshold need adjusting based on what you saw.

## Scenario 4: Threat intel match

The `threat_intel.csv` lookup ships with a few placeholder IPs
(`198.51.100.10` etc. - RFC 5737 documentation-range addresses, not real
hosts). To see the "Threat Intel Lookup Match" panel/alert actually fire
without attacking a real bad IP, temporarily add Kali's private IP to
`scripts/splunk/lookups/threat_intel.csv`, redeploy
(`terraform apply -replace=aws_instance.splunk`, or just edit the file
directly on the Splunk box under
`/opt/splunk/etc/apps/soc_lab/lookups/threat_intel.csv` for a quick test),
then re-run Scenario 1 or 2.
