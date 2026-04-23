# gh-action_azure-artifact-signing

Shared GitHub Action to sign Windows artifacts with Azure Artifact Signing.

The action supports two modes:

- `sign` (default): authenticate and sign artifacts directly.
- `setup`: authenticate and export environment variables for downstream signing tools such as [`jsign-maven-plugin`](https://central.sonatype.com/artifact/net.jsign/jsign-maven-plugin).

## Usage

**Note:** The workflow must grant `id-token: write` permission for GitHub OIDC
authentication with Azure.

### Sign mode (default)

```yaml
name: Build

on:
  push:
    branches:
      - master
      - branch-*
  pull_request:

permissions:
  id-token: write
  contents: read

jobs:
  sign:
    runs-on: sonar-xs
    steps:
      - uses: actions/checkout@v6
      - run: dotnet build project.slnx
      - uses: SonarSource/gh-action_azure-artifact-signing@v1
        with:
          files: artifacts/artifact.1.2.3.nupkg
```

### Setup mode (for Maven lifecycle signing)

```yaml
name: Build

on:
  push:
    branches:
      - master
      - branch-*
  pull_request:

permissions:
  id-token: write
  contents: read

jobs:
  build:
    runs-on: sonar-xs
    steps:
      - uses: actions/checkout@v6
      - uses: SonarSource/gh-action_azure-artifact-signing@v1
        with:
          mode: setup
      - uses: SonarSource/ci-github-actions/build-maven@v1
```

## Inputs

- `mode` (default: `sign`): `sign` to sign directly, `setup` to export env vars only.
- `files` (required in sign mode, default: `""`): one or more glob patterns
  used to resolve files to sign; use a multiline value with one pattern per
  line. Uses the [tj-actions/glob](https://github.com/tj-actions/glob) action under the hood.
- `signing-profile` (default: `""`): override profile selection with `test` or `release`.

## Outputs

| Name               | Description                                                  |
| ------------------ | ------------------------------------------------------------ |
| `signing-endpoint` | Azure signing endpoint (`https://weu.codesigning.azure.net`) |
| `signing-account`  | Selected signing account (e.g. `codesigning-test`)           |
| `signing-profile`  | Selected signing profile (e.g. `sonarsource-test`)           |
| `access-token`     | Azure access token (masked in logs)                          |

## Setup mode environment variables

When `mode: setup` is used, the action exports:

- `SIGNING_ENDPOINT=https://weu.codesigning.azure.net`
- `SIGNING_ACCOUNT=<account>`
- `SIGNING_PROFILE=<profile>`
- `ACCESS_TOKEN=<azure-access-token>`

These variables are intended for tools like `jsign-maven-plugin`.

## Maven plugin example

This example signs and verifies artifacts during the Maven lifecycle only when the `sign` profile is activated.

First, declare the plugin version and shared configuration in `<pluginManagement>`:

```xml
<build>
  <pluginManagement>
    <plugins>
      <plugin>
        <groupId>net.jsign</groupId>
        <artifactId>jsign-maven-plugin</artifactId>
        <version>7.4</version>
        <configuration>
          <storetype>TRUSTEDSIGNING</storetype>
          <keystore>${env.SIGNING_ENDPOINT}</keystore>
          <storepass>env:ACCESS_TOKEN</storepass>
          <alias>${env.SIGNING_ACCOUNT}/${env.SIGNING_PROFILE}</alias>
        </configuration>
      </plugin>
    </plugins>
  </pluginManagement>
</build>
```

Then declare the plugin executions in a `sign` profile in the module that needs signing:

```xml
<profiles>
  <profile>
    <id>sign</id>
    <build>
      <plugins>
        <plugin>
          <groupId>net.jsign</groupId>
          <artifactId>jsign-maven-plugin</artifactId>
          <executions>
            <execution>
              <id>sign</id>
              <phase>prepare-package</phase>
              <goals>
                <goal>sign</goal>
              </goals>
              <configuration>
                <file>${project.basedir}/SonarAnalyzer.dll</file>
              </configuration>
            </execution>
            <execution>
              <id>verify-signature-presence</id>
              <phase>verify</phase>
              <goals>
                <goal>sign</goal>
              </goals>
              <configuration>
                <command>extract</command>
                <file>${project.basedir}/SonarAnalyzer.dll</file>
              </configuration>
            </execution>
          </executions>
        </plugin>
      </plugins>
    </build>
  </profile>
</profiles>
```

With this setup:

- `mvn verify` does not run signing
- `mvn verify -Psign` runs signing and signature-presence verification

## Automatic signing profile selection

This action hardcodes Azure Artifact Signing configuration and auto-selects the signing profile unless `signing-profile` is explicitly set:

- `master`, `branch-*` (push events): release profile (`codesigning-release`)
- pull requests and all other branches: test profile (`codesigning-test`)

Explicit override examples:

```yaml
- uses: SonarSource/gh-action_azure-artifact-signing@v1
  with:
    files: artifacts/*.dll
    signing-profile: release
```

```yaml
- uses: SonarSource/gh-action_azure-artifact-signing@v1
  with:
    files: artifacts/*.dll
    signing-profile: test
```

## Signature verification

In `sign` mode the action verifies that each artifact carries a signature after signing, but it does **not** validate the signature's trust
chain. `jsign` does not support full signature validation. Use language-specific tooling to verify signature validity
(e.g. `signtool verify` on Windows, `nuget verify` for NuGet packages, `Get-AuthenticodeSignature` in PowerShell).

Note that the `test` signing certificate is not trusted by OS certificate stores by default and must be manually imported before
verification will succeed.

## Requirements

- Workflow must grant `id-token: write` permission for GitHub OIDC.
- Runner must be Linux and provide `bash`, `curl`, and `jq`.
- Java runtime (17+) must be available on `PATH` when using `mode=sign` (this action does not install Java).
- In `mode=sign`, `files` is required and must match at least one existing file.
