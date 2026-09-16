# syntax=docker/dockerfile:1
#
# Development image for TicTacTest.
#
# Base: official Azul Zulu JDK 25 on Debian bookworm. The repo pins the Gradle
# daemon JVM to "Azul Zulu 25" (gradle/gradle-daemon-jvm.properties) and the
# build toolchain to the same (build.gradle), so shipping that exact JDK means
# Gradle never has to download a toolchain. JAVA_HOME=/usr/lib/jvm/zulu25 is
# already set by the base image. Gradle itself (9.7.0) comes from ./gradlew.
#
# Build:  docker build -t tictactest-dev .devcontainer
# Run:    docker run --rm -it \
#           -v "${PWD}:/workspaces/450-tictactest-mvk" \
#           -v tictactest-gradle-cache:/home/vscode/.gradle \
#           -w /workspaces/450-tictactest-mvk \
#           tictactest-dev bash
FROM azul/zulu-openjdk-debian:25

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Dev essentials + a non-root user with passwordless sudo (matches
# devcontainer.json's remoteUser).
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        sudo \
        unzip \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd --gid "$USER_GID" "$USERNAME" \
 && useradd --uid "$USER_UID" --gid "$USER_GID" --create-home --shell /bin/bash "$USERNAME" \
 && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME" \
 && chmod 0440 "/etc/sudoers.d/$USERNAME" \
 && mkdir -p "/home/$USERNAME/.gradle" /workspaces/450-tictactest-mvk \
 && chown -R "$USER_UID:$USER_GID" "/home/$USERNAME" /workspaces

ENV GRADLE_USER_HOME=/home/vscode/.gradle

USER $USERNAME
WORKDIR /workspaces/450-tictactest-mvk
CMD ["bash"]
