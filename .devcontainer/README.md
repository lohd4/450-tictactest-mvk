# Dev Container

Reproducible Java 25 / Gradle build environment for TicTacTest, defined by
`Dockerfile`. Usable with VS Code, the devcontainer CLI, or plain Docker.

## Requirements

- Docker Desktop (running)
- For the IDE workflow: VS Code + the **Dev Containers** extension
  (`ms-vscode-remote.remote-containers`)

## VS Code

1. Open the repo folder in VS Code.
2. Command Palette -> **Dev Containers: Reopen in Container**.
3. First build compiles the image and runs `./gradlew build -x test` (see
   `postCreateCommand`). Later starts are fast because `~/.gradle` is kept on
   the `tictactest-gradle-cache` volume.
4. **Dev Containers: Rebuild Container** after editing `Dockerfile` /
   `devcontainer.json`.

## Plain Docker

```bash
# build the image
docker build -t tictactest-dev .devcontainer

# interactive shell with the project + Gradle cache mounted
docker run --rm -it \
  -v "${PWD}:/workspaces/450-tictactest-mvk" \
  -v tictactest-gradle-cache:/home/vscode/.gradle \
  -w /workspaces/450-tictactest-mvk \
  tictactest-dev bash
```

On Windows PowerShell use `-v "${PWD}:/workspaces/450-tictactest-mvk"`; in
cmd.exe use `-v "%cd%:/workspaces/450-tictactest-mvk"`.

First run only, fix ownership of the fresh cache volume:

```bash
sudo chown -R vscode:vscode /home/vscode/.gradle
```

Then inside the container:

```bash
./gradlew build                     # compile + test
./gradlew run --console=plain -q     # play the game (needs this interactive shell)
```

One-shot build without opening a shell:

```bash
docker run --rm \
  -v "${PWD}:/workspaces/450-tictactest-mvk" \
  -v tictactest-gradle-cache:/home/vscode/.gradle \
  -w /workspaces/450-tictactest-mvk \
  tictactest-dev sh ./gradlew build
```

## What's inside

| Piece | Value |
| --- | --- |
| Base image | `azul/zulu-openjdk-debian:25` (`JAVA_HOME=/usr/lib/jvm/zulu25`) |
| Gradle | 9.7.0 via `./gradlew` |
| User | `vscode` uid 1000 (non-root, passwordless sudo) |
| Extra pkgs | `git`, `curl`, `sudo`, `unzip`, `ca-certificates` |
| Cache | named volume `tictactest-gradle-cache` at `/home/vscode/.gradle` |

The JDK vendor/version match `gradle/gradle-daemon-jvm.properties` and the
`java.toolchain` block in `build.gradle`, so Gradle never downloads a toolchain.

## Resetting

```bash
docker volume rm tictactest-gradle-cache   # drop the Gradle cache
```

## Troubleshooting

**`Could not set file mode 755 on '.../build/...'`** — a `build/` directory left
on the Windows/macOS bind mount by an earlier build is root-owned, and Gradle's
build-cache restore cannot chmod it. Delete it and rebuild:

```bash
rm -rf build && ./gradlew build
```

**`NoSuchElementException: No line found` when running the game** — `./gradlew
run` needs an interactive terminal for stdin. Run it from a shell
(`./gradlew run --console=plain -q`), not from a VS Code task or the debugger's
internal console.
