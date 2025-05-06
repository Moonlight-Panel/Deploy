# Prepare runtime docker image
FROM cgr.dev/chainguard/dotnet-runtime:latest AS base
WORKDIR /app

# Prepare build image
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

# === Heavy download/install tasks ===
# should be put here for caching reasons

# Install nodejs and npm so we can build tailwind
RUN apt-get update && apt-get install nodejs npm git python3 -y && apt-get clean

# === Configuration options ===
# Usefull for custom forks
ARG BUILD_CONFIGURATION=Release
ARG MOONLIGHT_REPO=https://github.com/Moonlight-Panel/Moonlight
ARG MOONLIGHT_BRANCH=v2_ChangeArchitecture

# === Small preparations ===

# Prepare directories
RUN mkdir -p /src && \
    mkdir -p /src/Moonlight && \
    mkdir -p /src/Plugins && \
    mkdir /src/nuget && \
    mkdir -p /src/build_scripts
    
WORKDIR /src

# === Building ===

# Copying build scripts
COPY build_scripts/* /src/build_scripts

# Clone the main moonlight repo
RUN git clone --branch $MOONLIGHT_BRANCH $MOONLIGHT_REPO /src/Moonlight

COPY plugins.txt /src/plugins.txt

# Clone plugins
RUN grep -v '^#' plugins.txt | \
    while read -r repo; \
    do \
    git clone "$repo" /src/Plugins/$(basename "$repo" .git); \
    done

# Build plugins as source only nuget packages
WORKDIR /src/Plugins
RUN python3 /src/build_scripts/prepare_nuget.py