# Prepare runtime docker image
FROM cgr.dev/chainguard/aspnet-runtime:latest AS base

# Prepare build image
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build-moonlight

# === Heavy download/install tasks ===
# should be put here for caching reasons

# Install nodejs and npm so we can build tailwind
RUN apt-get update && apt-get install nodejs npm git -y && apt-get clean

# === Configuration options ===

# Usefull for custom forks
ARG BUILD_CONFIGURATION=Release
ARG MOONLIGHT_REPO=https://github.com/Moonlight-Panel/Moonlight
ARG MOONLIGHT_BRANCH=v2_ChangeArchitecture
ARG MOONLIGHT_NUGET_SOURCE=https://nuget.pkg.github.com/Moonlight-Panel/index.json
ARG MOONLIGHT_GITHUB_TOKEN=unset

# === Small preparations ===

# Prepare directories
RUN mkdir -p /src

# Setup nuget package source
RUN dotnet nuget add source --username Build --password $MOONLIGHT_GITHUB_TOKEN --store-password-in-clear-text --name nuget-moonlight $MOONLIGHT_NUGET_SOURCE
    
WORKDIR /src

# === Building ===

# Clone the main moonlight repo
RUN git clone --branch $MOONLIGHT_BRANCH $MOONLIGHT_REPO /src/.

# Install npm packages
WORKDIR /src/Moonlight.Client.Runtime/Styles
RUN npm i

WORKDIR /src

# Copying plugin references to src
COPY Plugins.ApiServer.props /src/Moonlight.ApiServer.Runtime/Plugins.props
COPY Plugins.Frontend.props /src/Moonlight.Client.Runtime/Plugins.props

# Build solution so every build task ran. Especially for tailwind class names etc
RUN dotnet build -c $BUILD_CONFIGURATION

# Build tailwind
WORKDIR /src/Moonlight.Client.Runtime/Styles
RUN npm run tailwind-build

# Build moonlight with the built tailwind assets
WORKDIR "/src/Moonlight.ApiServer.Runtime"
RUN dotnet build "Moonlight.ApiServer.Runtime.csproj" -c $BUILD_CONFIGURATION -o /app/build/

# Publish application
FROM build-moonlight AS publish

ARG BUILD_CONFIGURATION=Release

RUN dotnet publish "Moonlight.ApiServer.Runtime.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

# Create final minimal image
FROM base AS final

WORKDIR /app
COPY --from=publish /app/publish .

ENTRYPOINT ["dotnet", "Moonlight.ApiServer.Runtime.dll"]