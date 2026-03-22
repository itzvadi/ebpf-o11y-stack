# eBPF Observability — Zero Instrumentation

CPU flamegraphs and HTTP RED metrics for any Docker workload, with no code changes.

Grafana Alloy uses eBPF to watch every process on the host. It captures continuous CPU profiles (via `pyroscope.ebpf`) and HTTP/gRPC request metrics (via Beyla) — then ships them to Pyroscope and Mimir. Grafana visualizes everything out of the box.

```
Your services  ──eBPF──▶  Alloy  ──▶  Pyroscope  ──▶  Grafana (flamegraphs)
                                  └──▶  Mimir     ──▶  Grafana (RED metrics)
```

No SDKs. No restarts. No code changes.

---

## Quick start

Requires Docker + Docker Compose. On macOS, use [Colima](https://github.com/abiosoft/colima) (eBPF needs a Linux kernel).

**1. Start the stack**

```bash
docker compose up -d
```

**2. Generate some traffic**

The `demo-app` (nginx) starts automatically and is immediately visible to Alloy's eBPF probes. Hit it manually or just let it idle — Pyroscope will profile its processes either way.

**3. Open Grafana**

```
http://localhost:3000  →  admin / admin
```

Go to Dashboards and open:
- `CPU Flamegraph` — live eBPF CPU profiles for every process
- `eBPF RED Metrics (Beyla)` — request rate, error rate, latency by service

---

## Architecture

| Service     | Port  | Role                              |
|-------------|-------|-----------------------------------|
| Grafana     | 3000  | Dashboards                        |
| Pyroscope   | 4040  | Continuous CPU profile storage    |
| Mimir       | 9009  | Long-term Prometheus metrics      |
| Alloy       | 12345 | eBPF pipeline + web UI            |
| demo-app    | 8080  | Sample nginx target               |

All services share the `ebpf` Docker bridge network and communicate via service names.

---

## Profiling your own services

Add any service to `docker-compose.yml` on the `ebpf` network:

```yaml
services:
  my-app:
    image: my-app:latest
    networks:
      - ebpf
```

`pyroscope.ebpf` profiles all processes automatically — no Alloy config change needed.

For RED metrics, also add the service port to `open_port` in `alloy/config.alloy`, then run `make restart`.

---

## Useful commands

```bash
make up       # start everything
make down     # stop everything
make restart  # reload Alloy after config changes
make logs     # tail Alloy logs
make ps       # check service health
make clean    # stop and wipe all volumes
```

---

## macOS setup (Colima)

eBPF requires a Linux kernel. On macOS:

```bash
brew install colima
colima start --cpu 4 --memory 8 --mount-type virtiofs
docker compose up -d
```
