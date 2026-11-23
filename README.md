[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/chatterbox-tts-server?utm_medium=integration&utm_source=button&utm_campaign=chatterbox-tts-server)

# Chatterbox TTS Server on Railway

One-click Railway template for [Chatterbox TTS Server](https://github.com/devnen/Chatterbox-TTS-Server) **v2.0.0** (MIT), the web UI and OpenAI-compatible API for Resemble AI's [Chatterbox](https://github.com/resemble-ai/chatterbox) text-to-speech models.

## What you get

One service, **Chatterbox TTS Server**, built from this repo's `Dockerfile`:

- The upstream server, built on CPU from the `v2.0.0` release commit (`f0afcc6`), with the Chatterbox model package pinned to commit `cc03573` of `devnen/chatterbox-v2` (upstream installs it from `@master`). Both downloads are checked by SHA-256. Base images are pinned by digest (`python:3.10.22-slim-bookworm`, `caddy:2.11.9-alpine`).
- Caddy in front on Railway's `PORT`, because the app has no login of its own: **basic auth** for the web UI and a **Bearer API key** for API clients. `/healthz` answers without login once the model is loaded.
- A volume at `/data` for the Hugging Face model cache (about 2.8 GB for the default Chatterbox-Turbo), the 28 bundled voices plus your uploads, reference clips, `config.yaml` and logs.

## Resources: Hobby plan or higher

Railway has no GPUs, so the model runs on CPU in full precision. Measured on Railway with Chatterbox-Turbo:

| Memory limit | Result |
|---|---|
| 0.5 GB / 1 GB (Free, Trial) | Model not loaded; the service stays healthy and shows a "needs more memory" page |
| 4 GB | Killed while loading the model |
| 6 GB | Loads and synthesises (about 5.7 GB used) |
| 8 GB | Recommended |

The volume needs at least 5 GB (the Hobby default). A short sentence takes about 5 to 30 seconds on 2 vCPU. The start script reads the memory limit and volume size; below 5.6 GB RAM or 3.8 GB disk it serves the notice page instead of crashing. Raise the limit in the service's settings and redeploy.

## Variables

| Variable | Default | Purpose |
|---|---|---|
| `ADMIN_USERNAME` | `admin` | Web UI login name |
| `ADMIN_PASSWORD` | `${{secret(24)}}` | Web UI password, generated per deploy |
| `API_KEY` | `${{secret(40)}}` | Bearer key for `/v1/audio/speech`, `/tts` and the rest of the API |
| `PORT` | `8080` | Port Caddy listens on (the public domain targets it) |

No key or account is needed: the models are public on Hugging Face. Optional: add `HF_TOKEN` (a Hugging Face read token) if model downloads hit rate limits.

## After deploying

1. Wait for the first boot to download the model (one to two minutes) and for the deploy to turn green.
2. Open the public URL and sign in as `admin` with the `ADMIN_PASSWORD` from the service's Variables tab.
3. For API use, copy `API_KEY`:

```bash
curl https://YOUR-DOMAIN/v1/audio/speech \
  -H "Authorization: Bearer YOUR-API-KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"chatterbox","input":"Hello from Railway!","voice":"Emily.wav","response_format":"mp3"}' \
  -o hello.mp3
```

OpenAI SDKs work with `base_url="https://YOUR-DOMAIN/v1"` and `api_key` set to the same key. `GET /v1/audio/voices` lists the voices.

Switching to the Original or Multilingual model in the UI downloads more model files (allow about 10 GB of volume) and needs a similar amount of RAM.

## Updates

Deployers get Railway's "update available" notice when this repo's `main` changes. Each version is listed in [CHANGELOG.md](CHANGELOG.md), breaking changes first. Updates keep your volume (models, voices, settings) and variables.

## Licence

The template files in this repo are MIT. Chatterbox TTS Server and the Chatterbox models are MIT, by devnen and Resemble AI. Audio produced by Chatterbox carries Resemble AI's Perth watermark.
