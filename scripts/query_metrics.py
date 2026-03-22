#!/usr/bin/env python3
"""
Query Mimir metrics via Grafana's proxy API.

Usage:
    python3 scripts/query_metrics.py                          # RED summary
    python3 scripts/query_metrics.py --list                   # all metric names
    python3 scripts/query_metrics.py --query 'up'             # custom PromQL

Reads GRAFANA_URL and GRAFANA_API_TOKEN from .env
"""

import argparse
import json
import os
import sys
import urllib.request
import urllib.parse
import urllib.error
from pathlib import Path


def load_env(path=".env"):
    env_file = Path(path)
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, _, value = line.partition("=")
                os.environ.setdefault(key.strip(), value.strip())

load_env()

GRAFANA_URL    = os.environ.get("GRAFANA_URL", "http://localhost:3000")
API_TOKEN      = os.environ.get("GRAFANA_API_TOKEN", "")
DATASOURCE_UID = os.environ.get("MIMIR_DATASOURCE_UID", "mimir")

if not API_TOKEN:
    print("ERROR: GRAFANA_API_TOKEN not set. Run ./scripts/bootstrap.sh first.")
    sys.exit(1)


def grafana_get(path: str, params: dict = None) -> dict:
    url = f"{GRAFANA_URL}{path}"
    if params:
        url += "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {API_TOKEN}"})
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code}: {e.read().decode()}")
        sys.exit(1)


def list_metrics():
    data = grafana_get(f"/api/datasources/proxy/uid/{DATASOURCE_UID}/api/v1/label/__name__/values")
    metrics = sorted(data.get("data", []))
    print(f"Found {len(metrics)} metrics:\n")
    for m in metrics:
        print(f"  {m}")


def run_query(promql: str):
    data = grafana_get(
        f"/api/datasources/proxy/uid/{DATASOURCE_UID}/api/v1/query",
        params={"query": promql}
    )
    results = data.get("data", {}).get("result", [])
    if not results:
        print("No data returned.")
        return
    print(f"Query: {promql}\n")
    print(f"{'Metric':<60} {'Value'}")
    print("-" * 80)
    for r in results:
        labels = ", ".join(f'{k}="{v}"' for k, v in r["metric"].items())
        print(f"{labels:<60} {r['value'][1]}")


def show_red_summary():
    queries = {
        "Request Rate (req/s)":
            'sum by (service_name) (rate(http_server_request_duration_seconds_count{cluster="local"}[5m]))',
        "Error Rate (5xx req/s)":
            'sum by (service_name) (rate(http_server_request_duration_seconds_count{cluster="local", http_response_status_code=~"5.."}[5m]))',
        "p95 Latency (s)":
            'histogram_quantile(0.95, sum by (service_name, le) (rate(http_server_request_duration_seconds_bucket{cluster="local"}[5m])))',
    }
    for label, q in queries.items():
        print(f"\n── {label} ──")
        run_query(q)


def main():
    parser = argparse.ArgumentParser(description="Query Mimir metrics via Grafana API")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--list",  action="store_true", help="List all metric names")
    group.add_argument("--query", metavar="PROMQL",    help="Run a custom PromQL query")
    args = parser.parse_args()

    if args.list:
        list_metrics()
    elif args.query:
        run_query(args.query)
    else:
        show_red_summary()


if __name__ == "__main__":
    main()
