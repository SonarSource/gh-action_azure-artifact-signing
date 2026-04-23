# gh-action_azure-artifact-signing

Shared GitHub Action to sign Windows artifacts with Azure Artifact Signing

## Usage

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
    runs-on: github-windows-latest-s
    steps:
      - uses: actions/checkout@v6
      - uses: SonarSource/gh-action_azure-artifact-signing@v1
        with:
          files-folder: artifacts
          files-folder-filter: "*.dll,*.exe,*.nupkg"
```

## Inputs

| Name                  | Required | Default             | Description                                                        |
| --------------------- | -------- | ------------------- | ------------------------------------------------------------------ |
| `files-folder`        | Yes      | n/a                 | Path to the folder containing files to sign                        |
| `files-folder-filter` | No       | `*.exe,*.dll,*.msi` | Comma-separated list of glob filters applied inside `files-folder` |

## Branch-based profile selection

This action hardcodes Azure Artifact Signing configuration and selects the signing profile automatically:

- `master`, `branch-*` (push events): release profile (`codesigning-release` / `sonarsource-release`)
- pull requests and all other branches: test profile (`codesigning-test` / `sonarsource-test`)

## Requirements

- Workflow must grant `id-token: write` permission for GitHub OIDC.
- Runner must be Windows and have `dotnet` + Azure CLI available.
- Target files must match one of the configured filter patterns.
