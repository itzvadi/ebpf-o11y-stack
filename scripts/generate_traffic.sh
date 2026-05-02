#!/usr/bin/env bash
# Generate demo HTTP traffic with a controlled ratio of synthetic 500 errors.

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080}"
DURATION_SECONDS="${DURATION_SECONDS:-75}"
CONCURRENCY="${CONCURRENCY:-20}"
ERROR_PERCENT="${ERROR_PERCENT:-10}"

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl is required." >&2
  exit 1
fi

if [ "${ERROR_PERCENT}" -lt 0 ] || [ "${ERROR_PERCENT}" -gt 100 ]; then
  echo "ERROR: ERROR_PERCENT must be between 0 and 100." >&2
  exit 1
fi

echo "Generating traffic for ${DURATION_SECONDS}s against ${BASE_URL}"
echo "Concurrency: ${CONCURRENCY}; synthetic 5xx target: ${ERROR_PERCENT}%"

end=$((SECONDS + DURATION_SECONDS))
success_count_file="$(mktemp)"
error_count_file="$(mktemp)"
trap 'rm -f "${success_count_file}" "${error_count_file}"' EXIT
: > "${success_count_file}"
: > "${error_count_file}"

run_worker() {
  local worker_id="$1"
  local request_id=0
  local path status

  while [ "${SECONDS}" -lt "${end}" ]; do
    request_id=$((request_id + 1))
    if [ $(((request_id + worker_id) % 100)) -lt "${ERROR_PERCENT}" ]; then
      path="/error"
    else
      path="/"
    fi

    status="$(curl -sS -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)"
    case "${status}" in
      2*) printf . >> "${success_count_file}" ;;
      5*) printf . >> "${error_count_file}" ;;
    esac
  done
}

for worker_id in $(seq 1 "${CONCURRENCY}"); do
  run_worker "${worker_id}" &
done

wait

successes="$(wc -c < "${success_count_file}" | tr -d ' ')"
errors="$(wc -c < "${error_count_file}" | tr -d ' ')"
total=$((successes + errors))

echo "Done. Total counted requests: ${total}; 2xx: ${successes}; 5xx: ${errors}"
