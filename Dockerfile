# Prepare runtime docker image
FROM cgr.dev/chainguard/aspnet-runtime:latest AS base

# Prepare build image
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build

# === Heavy download/install tasks ===
# should be put here for caching reasons

# Install nodejs and npm so we can build tailwind
RUN apt-get update && apt-get install nodejs npm git -y && apt-get clean

# === Configuration options ===
# Usefull for custom forks
ARG BUILD_CONFIGURATION=Release
ARG PACK_BUILD_CONFIGURATION=Debug
ARG MOONLIGHT_REPO=https://github.com/Moonlight-Panel/Moonlight
ARG MOONLIGHT_BRANCH=v2_ChangeArchitecture

# === Small preparations ===

# Prepare directories
RUN mkdir -p /src && \
    mkdir -p /src/Moonlight && \
    mkdir -p /src/Plugins && \
    mkdir -p /src/pluginNuget && \
    mkdir -p /src/moonlightNuget
    
WORKDIR /src

# === Building ===

# Clone the main moonlight repo
RUN git clone --branch $MOONLIGHT_BRANCH $MOONLIGHT_REPO /src/Moonlight

# Install npm packages
WORKDIR /src/Moonlight/Moonlight.Client/Styles
RUN npm i

WORKDIR /src

# Build moonlight as nuget packages
RUN dotnet run --project Moonlight/Resources/Scripts/Scripts.csproj -- pack /src/Moonlight /src/moonlightNuget --build-configuration $PACK_BUILD_CONFIGURATION

# Make the moonlight nuget accessible for the compilation
RUN dotnet nuget add source /src/moonlightNuget -n moonlightNuget

# Copy plugin links
COPY plugins.txt /src/plugins.txt

# Clone plugins
RUN grep -v '^#' plugins.txt | \
    while read -r repo; \
    do \
    git clone "$repo" /src/Plugins/$(basename "$repo" .git); \
    done 

# Build plugin nuget packages
RUN dotnet run --project Moonlight/Resources/Scripts/Scripts.csproj -- pack /src/Plugins /src/pluginNuget --build-configuration $PACK_BUILD_CONFIGURATION

# Make the plugin nuget accessible for the compilation and remove the moonlight nuget source
RUN dotnet nuget remove source moonlightNuget
RUN dotnet nuget add source /src/pluginNuget -n pluginNuget

# Prepare moonlight for compilation
RUN dotnet run --project Moonlight/Resources/Scripts/Scripts.csproj -- prebuild /src/Moonlight /src/pluginNuget

# Build tailwind
WORKDIR /src/Moonlight/Moonlight.Client/Styles
RUN npm run tailwind

# Build moonlight
WORKDIR "/src/Moonlight/Moonlight.ApiServer"
RUN dotnet build "Moonlight.ApiServer.csproj" -c $BUILD_CONFIGURATION -o /app/build/

# Publish application
FROM build AS publish

ARG BUILD_CONFIGURATION=Release

RUN dotnet publish "Moonlight.ApiServer.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

# Create final minimal image
FROM base AS final

WORKDIR /app
COPY --from=publish /app/publish .

ENTRYPOINT ["dotnet", "Moonlight.ApiServer.dll"]