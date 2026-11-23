# Changelog

## 2.0.0-railway.1 (2026-11-23)

- First release: Chatterbox TTS Server v2.0.0 (release commit `f0afcc6`), CPU build, Chatterbox model package `devnen/chatterbox-v2@cc03573`, on `python:3.10.22-slim-bookworm` with Caddy 2.11.9 for basic auth and Bearer API keys.
- Default model Chatterbox-Turbo, cached on the `/data` volume. Needs a Hobby plan (6 GB RAM minimum, 8 GB recommended); smaller plans get a notice page instead of a crash loop.
