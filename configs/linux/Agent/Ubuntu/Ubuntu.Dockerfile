# The list of required arguments
# ARG dotnetCoreLinuxComponentVersion
# ARG dotnetCoreLinuxComponent
# ARG teamcityMinimalAgentImage
# ARG dotnetLibs

# Id teamcity-agent
# Platform ${linuxPlatform}
# Tag ${versionTag}-linux${linuxVersion}
# Tag ${latestTag}
# Tag ${versionTag}
# Repo ${repo}
# Weight 1

## ${agentCommentHeader}

# Based on ${teamcityMinimalAgentImage}
FROM ${teamcityMinimalAgentImage}

USER root

LABEL dockerImage.teamcity.version="latest" \
      dockerImage.teamcity.buildNumber="latest"

ARG dotnetCoreLinuxComponentVersion

    # Opt out of the telemetry feature
ENV DOTNET_CLI_TELEMETRY_OPTOUT=true \
    # Disable first time experience
    DOTNET_SKIP_FIRST_TIME_EXPERIENCE=true \
    # Configure Kestrel web server to bind to port 80 when present
    ASPNETCORE_URLS=http://+:80 \
    # Enable detection of running in a container
    DOTNET_RUNNING_IN_CONTAINER=true \
    # Enable correct mode for dotnet watch (only mode supported in a container)
    DOTNET_USE_POLLING_FILE_WATCHER=true \
    # Skip extraction of XML docs - generally not useful within an image/container - helps perfomance
    NUGET_XMLDOC_MODE=skip \
    GIT_SSH_VARIANT=ssh \
    DOTNET_SDK_VERSION=${dotnetCoreLinuxComponentVersion}

# Install Git
# Install Mercurial
ARG dotnetCoreLinuxComponent
ARG dotnetLibs

RUN apt-get update && \
    apt-get install -y git mercurial apt-transport-https software-properties-common && \
    # https://github.com/goodwithtech/dockle/blob/master/CHECKPOINT.md#dkl-di-0005
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    \
# Install Docker Engine
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" && \
    \
    apt-cache policy docker-ce && \
    apt-get update && \
    apt-get install -y  docker-ce=5:19.03.9~3-0~ubuntu-$(lsb_release -cs) \
                        docker-ce-cli=5:19.03.9~3-0~ubuntu-$(lsb_release -cs) \
                        containerd.io=1.2.13-2 \
                        systemd && \
    systemctl disable docker && \
# Install Docker Compose
    curl -SL "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose && \
# Install [${dotnetCoreLinuxComponentName}](${dotnetCoreLinuxComponent})
    apt-get install -y --no-install-recommends ${dotnetLibs} && \
    # https://github.com/goodwithtech/dockle/blob/master/CHECKPOINT.md#dkl-di-0005
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    curl -SL ${dotnetCoreLinuxComponent} --output dotnet.tar.gz && \
    mkdir -p /usr/share/dotnet && \
    tar -zxf dotnet.tar.gz -C /usr/share/dotnet && \
    rm dotnet.tar.gz && \
    find /usr/share/dotnet -name "*.lzma" -type f -delete && \
    ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet && \
    usermod -aG docker buildagent

# A better fix for TW-52939 Dockerfile build fails because of aufs
VOLUME /var/lib/docker

COPY --chown=buildagent:buildagent run-docker.sh /services/run-docker.sh

# Trigger .NET CLI first run experience by running arbitrary cmd to populate local package cache
RUN dotnet help && \
    sed -i -e 's/\r$//' /services/run-docker.sh

USER buildagent

