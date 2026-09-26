# 4. TheHive + ServiceNow

## First login to TheHive

```
terraform output thehive_web_url
```

TheHive's default docker image ships a default org/admin on first boot:
- Username: `admin@thehive.local`
- Password: `secret`

**Change this password immediately** (Administration > Users) - the UI is
reachable only from your IP thanks to the `hive_ui` security group, but don't
leave the default credential sitting there regardless.

If the login page doesn't load, give the box a few extra minutes -
Cassandra + Elasticsearch + TheHive all have to come up in order; check with:
```bash
ssh -i ~/.ssh/soc-lab-key.pem ubuntu@<thehive-public-ip>
sudo docker compose -f /opt/thehive/docker-compose.yml ps
sudo docker compose -f /opt/thehive/docker-compose.yml logs thehive --tail=100
```

## Generate an API key

Administration > Users > (your user) > **API Key** > Create. Copy it - this
goes into the bridge script's `THEHIVE_API_KEY`.

## Manually working a case (the diagram's flow)

When a Splunk alert is a confirmed true positive, the L1 analyst pivots here:
1. Create a **Case** - title it after the detection (e.g. "T1110 - SSH brute
   force from <ip>"), set severity, add a description with the pivot details
   (host, user, IP, time - step 4 "Investigate" in the diagram).
2. Add **Observables** for the IOCs (source IP, account name) and tag them.
3. This case is what the bridge script in this section picks up and turns
   into a ServiceNow incident (step 6 "Escalate").

## ServiceNow PDI

You already requested a free Personal Developer Instance in
[01-prerequisites.md](01-prerequisites.md). Confirm you can log into
`https://devXXXXXX.service-now.com` with the admin credentials from the
provisioning email.

No extra ServiceNow-side configuration is required for the bridge script - it
POSTs directly to the built-in Table API (`/api/now/table/incident`), which
every PDI has enabled by default.

## Run the bridge

On your Mac (or anywhere with network access to both TheHive and ServiceNow -
your Mac works fine since TheHive's port 9000 is open to `my_ip`):

```bash
cd scripts/integration
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # fill in THEHIVE_URL, THEHIVE_API_KEY, SNOW_INSTANCE, SNOW_USER, SNOW_PASS
export $(grep -v '^#' .env | xargs)
python3 thehive_to_servicenow.py
```

First run with no cases yet just prints "No new TheHive cases." Create a test
case in TheHive, re-run, and you should see a new Incident appear in
ServiceNow (**Incidents** module) with `[TheHive] <case title>` as the short
description.

To run it continuously, add it to cron every 5 minutes:
```bash
crontab -e
*/5 * * * * cd /path/to/soc-lab/scripts/integration && export $(grep -v '^#' .env | xargs) && python3 thehive_to_servicenow.py >> bridge.log 2>&1
```

If TheHive's API shape doesn't match what the script expects (TheHive's query
API has changed across versions before), the error will name the missing
field - see the NOTE at the top of `thehive_to_servicenow.py` for how to
adjust it.
