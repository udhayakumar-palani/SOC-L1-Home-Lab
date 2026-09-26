#!/usr/bin/env python3
"""
TheHive -> ServiceNow bridge for the SOC L1 home lab.

Polls TheHive for cases (an L1 analyst creates a case in TheHive when a Splunk
alert is a confirmed true positive - step 6 "Escalate" in the diagram) and
creates/updates a matching ServiceNow incident, so L2 gets a ticket with
priority/SLA/assignment the way the diagram shows.

This is a polling script meant to run every few minutes via cron, not a
long-running daemon - simplest thing that works for a home lab, no public
webhook endpoint required on the TheHive box.

Config via environment variables (put them in scripts/integration/.env and
`export $(grep -v '^#' .env | xargs)` before running, or set them in cron):
    THEHIVE_URL       e.g. http://<thehive-public-ip>:9000
    THEHIVE_API_KEY   generate in TheHive UI: Administration > Users > <you> > API Key
    SNOW_INSTANCE     e.g. https://devXXXXXX.service-now.com  (free PDI - see docs/05)
    SNOW_USER         ServiceNow username
    SNOW_PASS         ServiceNow password
    STATE_FILE        optional, defaults to ./thehive_to_servicenow_state.json

NOTE ON API SHAPES: TheHive 5's query API and ServiceNow's Table API are both
stable but field names/casing can drift between versions. If the field
lookups below (CASE_ID_FIELDS, etc.) don't match what your TheHive instance
actually returns, print(case) once and adjust - this is written defensively
(tries several common field names) rather than hard-coded to one exact
version.
"""

import json
import os
import sys
from pathlib import Path

import requests

THEHIVE_URL = os.environ["THEHIVE_URL"].rstrip("/")
THEHIVE_API_KEY = os.environ["THEHIVE_API_KEY"]
SNOW_INSTANCE = os.environ["SNOW_INSTANCE"].rstrip("/")
SNOW_USER = os.environ["SNOW_USER"]
SNOW_PASS = os.environ["SNOW_PASS"]
STATE_FILE = Path(os.environ.get("STATE_FILE", "thehive_to_servicenow_state.json"))

CASE_ID_FIELDS = ("_id", "id", "caseId")
SEVERITY_TO_URGENCY = {1: "3", 2: "2", 3: "2", 4: "1"}  # TheHive 1-4 -> SNOW 1(high)-3(low)


def load_state() -> dict:
    if STATE_FILE.exists():
        return json.loads(STATE_FILE.read_text())
    return {"synced_case_ids": []}


def save_state(state: dict) -> None:
    STATE_FILE.write_text(json.dumps(state, indent=2))


def fetch_thehive_cases() -> list:
    """TheHive 5 Query API: list all cases, newest first."""
    resp = requests.post(
        f"{THEHIVE_URL}/api/v1/query",
        headers={
            "Authorization": f"Bearer {THEHIVE_API_KEY}",
            "Content-Type": "application/json",
        },
        json={
            "query": [
                {"_name": "listCase"},
                {"_name": "sort", "_fields": [{"_createdAt": "desc"}]},
            ]
        },
        timeout=15,
    )
    resp.raise_for_status()
    return resp.json()


def case_id(case: dict) -> str:
    for field in CASE_ID_FIELDS:
        if field in case:
            return case[field]
    raise KeyError(f"no id field found in case, saw keys: {list(case.keys())}")


def create_servicenow_incident(case: dict) -> None:
    severity = case.get("severity", 2)
    payload = {
        "short_description": f"[TheHive] {case.get('title', 'Untitled case')}",
        "description": case.get("description", ""),
        "urgency": SEVERITY_TO_URGENCY.get(severity, "2"),
        "impact": SEVERITY_TO_URGENCY.get(severity, "2"),
        "category": "Security",
        "correlation_id": f"thehive-case-{case_id(case)}",
        "correlation_display": "TheHive",
    }
    resp = requests.post(
        f"{SNOW_INSTANCE}/api/now/table/incident",
        auth=(SNOW_USER, SNOW_PASS),
        headers={"Content-Type": "application/json", "Accept": "application/json"},
        json=payload,
        timeout=15,
    )
    resp.raise_for_status()
    number = resp.json().get("result", {}).get("number", "?")
    print(f"Created ServiceNow incident {number} for TheHive case {case_id(case)}")


def main() -> int:
    state = load_state()
    synced = set(state["synced_case_ids"])

    try:
        cases = fetch_thehive_cases()
    except requests.RequestException as exc:
        print(f"Failed to fetch TheHive cases: {exc}", file=sys.stderr)
        return 1

    new_cases = [c for c in cases if str(case_id(c)) not in synced]
    if not new_cases:
        print("No new TheHive cases.")
        return 0

    for case in new_cases:
        try:
            create_servicenow_incident(case)
            synced.add(str(case_id(case)))
        except (requests.RequestException, KeyError) as exc:
            print(f"Failed to sync case {case.get('title', '?')}: {exc}", file=sys.stderr)

    state["synced_case_ids"] = sorted(synced)
    save_state(state)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
