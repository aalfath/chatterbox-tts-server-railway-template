# Deploy and Host Chatterbox TTS Server on Railway

Chatterbox TTS Server is an open-source (MIT) web app and API for Resemble AI's Chatterbox text-to-speech models. It turns text into natural speech with 28 built-in voices, voice cloning from a short audio clip, long-text chunking for audiobooks, tags such as [laugh] or [sigh], and an OpenAI-compatible /v1/audio/speech endpoint.

## About Hosting Chatterbox TTS Server

This template runs Chatterbox TTS Server v2.0.0 as one CPU service built from a public GitHub repo. Railway has no GPUs, so it uses the CPU build with the default Chatterbox-Turbo model. On the first boot the server downloads about 2.8 GB of model files from Hugging Face into the service's volume, which takes one to two minutes; restarts reuse them. The model needs at least 6 GB of RAM (8 GB recommended), so it needs a Hobby plan or higher. On a smaller plan the service stays up and shows a page explaining how to raise the memory limit. A short sentence takes about 5 to 30 seconds on 2 vCPU.

## Common Use Cases

* Narrate articles, docs and audiobooks with a consistent voice
* Give voice agents, bots and apps a self-hosted, OpenAI-compatible speech API
* Clone a voice from a short reference clip for videos or podcasts

## Dependencies for Chatterbox TTS Server Hosting

* A Railway Hobby plan or higher: 6 GB RAM minimum, 8 GB recommended
* One volume of at least 5 GB for the models, voices and settings

### Deployment Dependencies

* Chatterbox TTS Server: https://github.com/devnen/Chatterbox-TTS-Server
* Chatterbox models by Resemble AI: https://huggingface.co/ResembleAI/chatterbox-turbo
* Template repo: https://github.com/aalfath/chatterbox-tts-server-railway-template

### Implementation Details

The template deploys one service, **Chatterbox TTS Server**: the upstream FastAPI server, with Caddy in the same container as its front door on Railway's public URL. Its volume at `/data` holds the Hugging Face model cache, the bundled and uploaded voices, reference clips, `config.yaml` and logs.

The upstream app has no login, so the template locks it on the first deploy:

* **Web UI:** open the public URL and sign in with user `admin` and the generated `ADMIN_PASSWORD` (service Variables tab).
* **API:** send `Authorization: Bearer YOUR-API-KEY`, where the key is the generated `API_KEY` variable.

```bash
curl https://YOUR-DOMAIN/v1/audio/speech \
  -H "Authorization: Bearer YOUR-API-KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"chatterbox","input":"Hello from Railway!","voice":"Emily.wav","response_format":"mp3"}' \
  -o hello.mp3
```

OpenAI SDKs work with `base_url="https://YOUR-DOMAIN/v1"` and `api_key` set to the same key; list the voices at `/v1/audio/voices`. No other variables are needed. Switching to the Original or Multilingual model in the UI downloads more files (allow about 10 GB of volume).

**Updates:** the service builds from the template repo, which pins the upstream release and its Python dependencies. When we publish a new version, Railway shows an update notice on your project; read the repo's CHANGELOG.md, then apply it. Your volume and variables are kept.

## Why Deploy Chatterbox TTS Server on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Chatterbox TTS Server on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->
