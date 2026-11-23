#!/bin/bash
# Railway start script for Chatterbox TTS Server.
# Runs the upstream FastAPI server on 127.0.0.1:8004 behind Caddy on $PORT
# (basic auth for the web UI, Bearer API key for API clients) and exits
# non-zero when either process stops, so Railway's ON_FAILURE policy restarts it.
set -euo pipefail

log() { echo "[start] $*"; }
die() { echo "[start] ERROR: $*" >&2; exit 1; }

export PORT="${PORT:-8080}"
export ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
[ -n "${ADMIN_PASSWORD:-}" ] || die "ADMIN_PASSWORD is empty; refusing to start an open server."
[ -n "${API_KEY:-}" ] || die "API_KEY is empty; refusing to start an open API."
[ "${#ADMIN_PASSWORD}" -ge 12 ] || die "ADMIN_PASSWORD must be at least 12 characters."
[ "${#API_KEY}" -ge 24 ] || die "API_KEY must be at least 24 characters."
case "$API_KEY" in *[!A-Za-z0-9._~-]*) die "API_KEY may only contain letters, digits and . _ ~ -";; esac

DATA=/data
mkdir -p "$DATA"/{voices,reference_audio,outputs,logs,model_cache,hf_cache}
export HF_HOME="$DATA/hf_cache"

# --- Resources: size threads from the cgroup CPU limit, not the host's CPU count.
cpus=""
if [ -r /sys/fs/cgroup/cpu.max ]; then
  read -r q p < /sys/fs/cgroup/cpu.max || true
  if [ "${q:-max}" != "max" ] && [ -n "${p:-}" ]; then cpus=$(( (q + p - 1) / p )); fi
fi
[ -n "$cpus" ] || cpus=$(nproc)
[ "$cpus" -gt 8 ] && cpus=8
[ "$cpus" -lt 1 ] && cpus=1
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-$cpus}" MKL_NUM_THREADS="${MKL_NUM_THREADS:-$cpus}"
export NUMBA_NUM_THREADS="${NUMBA_NUM_THREADS:-$cpus}" MALLOC_ARENA_MAX="${MALLOC_ARENA_MAX:-2}"
export GOMAXPROCS="${GOMAXPROCS:-2}"

mem_mb=0
if [ -r /sys/fs/cgroup/memory.max ] && [ "$(cat /sys/fs/cgroup/memory.max)" != "max" ]; then
  mem_mb=$(( $(cat /sys/fs/cgroup/memory.max) / 1048576 ))
else
  mem_mb=$(( $(awk '/MemTotal/ {print $2}' /proc/meminfo) / 1024 ))
fi
disk_mb=$(df -Pm "$DATA" | awk 'NR==2 {print $2}')
MIN_MEMORY_MB="${MIN_MEMORY_MB:-5600}"
MIN_DISK_MB="${MIN_DISK_MB:-3800}"
log "cpus=$cpus threads=$OMP_NUM_THREADS memory_limit=${mem_mb}MB volume=${disk_mb}MB"

if [ "$mem_mb" -lt "$MIN_MEMORY_MB" ] || [ "$disk_mb" -lt "$MIN_DISK_MB" ]; then
  log "Not enough resources for the Chatterbox model (need ${MIN_MEMORY_MB}MB RAM and ${MIN_DISK_MB}MB volume)."
  log "Serving a notice page instead. Raise the memory limit (Hobby plan or higher) and redeploy."
  exec /usr/bin/caddy run --config /etc/caddy/Caddyfile.lowmem --adapter caddyfile
fi

# --- First boot: seed bundled voices; every boot: keep config paths on the volume.
cp -rn /app/voices/. "$DATA/voices/" 2>/dev/null || true
cp -rn /app/reference_audio/. "$DATA/reference_audio/" 2>/dev/null || true
[ -f "$DATA/config.yaml" ] || cp /app/config.yaml "$DATA/config.yaml"
python3 - <<'PY'
import yaml
p = "/data/config.yaml"
c = yaml.safe_load(open(p)) or {}
s = c.setdefault("server", {})
s.update({"host": "127.0.0.1", "port": 8004, "use_ngrok": False, "log_file_path": "/data/logs/tts_server.log"})
c.setdefault("tts_engine", {}).update({"device": "cpu", "predefined_voices_path": "/data/voices", "reference_audio_path": "/data/reference_audio"})
c.setdefault("paths", {}).update({"model_cache": "/data/model_cache", "output": "/data/outputs"})
yaml.safe_dump(c, open(p + ".tmp", "w"), sort_keys=False, allow_unicode=True)
import os; os.replace(p + ".tmp", p)
PY

export ADMIN_PASSWORD_HASH
ADMIN_PASSWORD_HASH="$(/usr/bin/caddy hash-password --plaintext "$ADMIN_PASSWORD")"

cd "$DATA"
log "Starting Chatterbox TTS Server (the first boot downloads about 3 GB of model files into the volume)."
python3 -m uvicorn server:app --app-dir /app --host 127.0.0.1 --port 8004 --workers 1 --log-level info &
app_pid=$!
/usr/bin/caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
caddy_pid=$!

stop() { kill "$app_pid" "$caddy_pid" 2>/dev/null || true; }
trap 'stop; exit 143' TERM INT

# Upstream keeps serving when the model fails to load; treat that as a failed start.
checked=0
while true; do
  if ! kill -0 "$app_pid" 2>/dev/null; then wait "$app_pid" || true; log "TTS server exited."; stop; exit 1; fi
  if ! kill -0 "$caddy_pid" 2>/dev/null; then wait "$caddy_pid" || true; log "Caddy exited."; stop; exit 1; fi
  if [ "$checked" = 0 ]; then
    info=$(curl -fsS -m 5 http://127.0.0.1:8004/api/model-info 2>/dev/null || true)
    if [ -n "$info" ]; then
      case "$info" in
        *'"loaded":true'*) log "Model loaded; server ready on port $PORT."; checked=1 ;;
        *) log "Model failed to load: $info"; stop; exit 1 ;;
      esac
    fi
  fi
  sleep 5
done
