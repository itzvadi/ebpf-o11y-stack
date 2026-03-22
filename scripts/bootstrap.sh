#!/usr/bin/env bash
# Creates a Grafana service account + API token and saves credentials to .env
# Usage: ./scripts/bootstrap.sh
# Override credentials: GRAFANA_USER=admin GRAFANA_PASS=yourpass ./scripts/bootstrap.sh

set -euo pipefail

GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:-admin}"
SA_NAME="observability-api"
TOKEN_NAME="observability-token"
ENV_FILE=".env"

echo "→ Waiting for Grafana..."
until docker-compose exec -T grafana sh -c "wget -O- http://localhost:3000/api/health 2>/dev/null" | grep -q "ok"; do
  sleep 2
done
echo "✓ Grafana is up"

AUTH=$(echo -n "${GRAFANA_USER}:${GRAFANA_PASS}" | base64)

echo "→ Creating service account..."
SA_RESPONSE=$(docker-compose exec -T grafana sh -c \
  "wget -O- --header='Authorization: Basic ${AUTH}' \
   --header='Content-Type: application/json' \
   --post-data='{\"name\":\"${SA_NAME}\",\"role\":\"Viewer\",\"isDisabled\":false}' \
   http://localhost:3000/api/serviceaccounts 2>/dev/null")

SA_ID=$(echo "${SA_RESPONSE}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'id' in data:
    print(data['id'])
else:
    sys.exit(1)
" 2>/dev/null || true)

if [ -z "${SA_ID}" ]; then
  echo "→ Service account exists, fetching ID..."
  SEARCH=$(docker-compose exec -T grafana sh -c \
    "wget -O- --header='Authorization: Basic ${AUTH}' \
     'http://localhost:3000/api/serviceaccounts/search?query=${SA_NAME}' 2>/dev/null")
  SA_ID=$(echo "${SEARCH}" | python3 -c "
import sys, json
accounts = json.load(sys.stdin).get('serviceAccounts', [])
if not accounts: sys.exit(1)
print(accounts[0]['id'])
")
fi

echo "✓ Service account ID: ${SA_ID}"
echo "→ Creating API token..."

TOKEN_RESPONSE=$(docker-compose exec -T grafana sh -c \
  "wget -O- --header='Authorization: Basic ${AUTH}' \
   --header='Content-Type: application/json' \
   --post-data='{\"name\":\"${TOKEN_NAME}\"}' \
   http://localhost:3000/api/serviceaccounts/${SA_ID}/tokens 2>/dev/null")

API_TOKEN=$(echo "${TOKEN_RESPONSE}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'key' not in data:
    print('Token may already exist — delete it in Grafana UI (Administration → Service Accounts) and retry.', file=sys.stderr)
    sys.exit(1)
print(data['key'])
")

touch "${ENV_FILE}"
grep -v "^GRAFANA_API_TOKEN=" "${ENV_FILE}" > "${ENV_FILE}.tmp" && mv "${ENV_FILE}.tmp" "${ENV_FILE}"
grep -v "^GRAFANA_URL=" "${ENV_FILE}" > "${ENV_FILE}.tmp" && mv "${ENV_FILE}.tmp" "${ENV_FILE}"
echo "GRAFANA_URL=http://localhost:3000" >> "${ENV_FILE}"
echo "GRAFANA_API_TOKEN=${API_TOKEN}" >> "${ENV_FILE}"

echo "✓ Token saved to ${ENV_FILE}"
