
# Kind (kind)

Installs latest version of kind (Kubernetes In Docker). Auto-detects latest versions and installs needed dependencies.

## Example Usage

```json
"features": {
        "ghcr.io/neermitt/devcontainers-features/kind:1": {
            "version": "latest"
        }
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Select or enter a kind version to install | string | latest |
| kind_sha256 | Select or enter a kind version SHA256 to check | string | automatic |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/neermitt/devcontainers-features/blob/main/src/kind/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
