# Dev Container

Reproducible Java 25 / Gradle build environment for TicTacTest.

## Requirements

- Docker Desktop (running)
- VS Code + the **Dev Containers** extension (`ms-vscode-remote.remote-containers`)

## Use it

1. Open the repo folder in VS Code.
2. Command Palette -> **Dev Containers: Reopen in Container**.
3. First build pulls the image, installs features, then runs
   `./gradlew build -x test` (see `postCreateCommand`). Subsequent starts are fast
   because `~/.gradle` is kept on the `tictactest-gradle-cache` volume.

Run tests from the integrated terminal with `./gradlew test`, or use the
Testing / Gradle views from the Java extension pack.

## What's inside

| Piece | Value |
| --- | --- |
| Base image | `azul/zulu-openjdk-debian:25` (`JAVA_HOME=/usr/lib/jvm/zulu25`) |
| Gradle | 9.7.0 via `./gradlew` |
| User | `vscode` (non-root, passwordless sudo) |
| Features | `common-utils`, `git` |
| Cache | named volume mounted at `/home/vscode/.gradle` |

The JDK vendor/version match `gradle/gradle-daemon-jvm.properties` and the
`java.toolchain` block in `build.gradle`, so Gradle never downloads a toolchain.

## Rebuilding

**Dev Containers: Rebuild Container** after changing `devcontainer.json`.
To also drop the Gradle cache: `docker volume rm tictactest-gradle-cache`.
