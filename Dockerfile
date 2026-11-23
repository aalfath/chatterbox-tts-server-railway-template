# Chatterbox TTS Server for Railway
# Upstream: https://github.com/devnen/Chatterbox-TTS-Server (MIT), release v2.0.0.
# Upstream's published 2.0.0 image is the CUDA build, so this builds the CPU
# variant from the pinned release commit, the same way upstream's Dockerfile.cpu does.

FROM caddy:2.11.9-alpine@sha256:003a97808e781aa9f7e75cc2f43d34d461099031faf5e20faefb9f61126836f0 AS caddy

FROM python:3.10.22-slim-bookworm@sha256:5be5aaecb962a41567bc8041f1e9e3432cb085b037fe057f9a562630b2e4b370

# Chatterbox TTS Server v2.0.0 (tag commit) and the Chatterbox model package fork
# that upstream installs (devnen/chatterbox-v2, pinned to a commit instead of @master).
ARG SERVER_REF=f0afcc6d01d4424ad72950038dff66646b24bc78
ARG SERVER_SHA256=aa1139748c4d8d3a8937a1138ed105fce12ca7aae6b73b6181825ebe889a8c6e
ARG MODEL_PKG_REF=cc0357396d9c73fc1e6c544ee40bb596020edd09
ARG MODEL_PKG_SHA256=9454a3833e9eee3527633215b9b417793b93ff5dfc1fe3b7ccfbcb09c9c6a6ee

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    HF_HOME=/data/hf_cache \
    HF_HUB_DISABLE_TELEMETRY=1 \
    DO_NOT_TRACK=1 \
    TOKENIZERS_PARALLELISM=false

RUN apt-get update \
 && apt-get install -y --no-install-recommends libsndfile1 ffmpeg curl ca-certificates build-essential \
 && mkdir -p /app \
 && curl -fsSL -o /tmp/server.tgz "https://codeload.github.com/devnen/Chatterbox-TTS-Server/tar.gz/${SERVER_REF}" \
 && echo "${SERVER_SHA256}  /tmp/server.tgz" | sha256sum -c - \
 && tar -xzf /tmp/server.tgz --strip-components=1 -C /app \
 && curl -fsSL -o /tmp/chatterbox.tar.gz "https://codeload.github.com/devnen/chatterbox-v2/tar.gz/${MODEL_PKG_REF}" \
 && echo "${MODEL_PKG_SHA256}  /tmp/chatterbox.tar.gz" | sha256sum -c - \
 && python3 -m pip install --upgrade pip \
 && python3 -m pip install -r /app/requirements.txt \
 && python3 -m pip install --no-deps /tmp/chatterbox.tar.gz s3tokenizer==0.3.0 onnx==1.16.0 \
 && python3 -m pip install "protobuf>=4.25.0" \
 && apt-get purge -y build-essential && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/* /tmp/*.tgz /tmp/*.tar.gz /root/.cache \
 && rm -rf /app/.github /app/static /app/*.ipynb /app/Dockerfile* /app/docker-compose*.yml /app/start.bat

# The Turbo model download pattern also fetches s3gen.safetensors (1 GB), which
# Turbo never loads. Skip it so the model cache fits a 5 GB volume.
RUN f=$(python3 -c 'import chatterbox.tts_turbo as m; print(m.__file__)') \
 && grep -q 'allow_patterns=\["\*.safetensors"' "$f" \
 && sed -i 's/allow_patterns=\["\*.safetensors", "\*.json", "\*.txt", "\*.pt", "\*.model"\]/allow_patterns=["*.safetensors", "*.json", "*.txt", "*.pt", "*.model"], ignore_patterns=["s3gen.safetensors"]/' "$f" \
 && grep -q 'ignore_patterns=\["s3gen.safetensors"\]' "$f" \
 && python3 -c "import chatterbox.tts_turbo"

COPY --from=caddy /usr/bin/caddy /usr/bin/caddy
COPY Caddyfile Caddyfile.lowmem /etc/caddy/
COPY lowmem.html /srv/lowmem/index.html
COPY start.sh /usr/local/bin/start.sh
RUN chmod 755 /usr/local/bin/start.sh && mkdir -p /data

WORKDIR /data
EXPOSE 8080
CMD ["/usr/local/bin/start.sh"]
