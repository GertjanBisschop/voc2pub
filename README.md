## Vocabulary Dropbox to Nanopublication Template

This repository is a template for a staged vocabulary workflow:

1. New YAML vocab files are dropped into `dropbox/`.
2. Processing converts them into RDF assertions in `unpublished/`.
3. Processed source YAML files move to `archive/`.
4. Publishing creates nanopublications from `unpublished/`.
5. Successfully published assertion files move to `published/`.

## Folder Semantics

- `dropbox/`: incoming YAML vocabulary files
- `archive/`: processed YAML files moved out of dropbox
- `unpublished/`: generated RDF term assertions waiting for publish
- `published/`: assertions already published as nanopublications
- `build/`: transient build artifacts

## Local Usage

Install dependencies:

```bash
uv sync
```

Process incoming YAML from `dropbox/`:

```bash
make pipeline
```

Dry-run publish (no move to `published/`):

```bash
make publish-pipeline DRY=--dry-run
```

Real publish (requires nanopub credentials in environment):

```bash
export NANOPUB_PRIVATE_KEY=...
export NANOPUB_PUBLIC_KEY=...
export INTRO_NANOPUB_URI=...
make publish-pipeline
```

End-to-end local smoke test:

```bash
make test-flow
```

## GitHub Workflows

- `serialize.yaml`: on push to `main` with `dropbox/**` changes, runs `make pipeline` and commits `archive/` + `unpublished/` updates.
- `test-serialize.yaml`: on PR with `dropbox/**` changes, validates processing behavior.
- `publish.yaml`: publishes nanopublications on:
  - release publish (real publish),
  - tag push (dry-run),
  - manual `workflow_dispatch` ("Publish mode" input: `dry-run` or `publish`).

In manual real publish mode (`workflow_dispatch` with `publish`), published assertion files are moved from `unpublished/` to `published/` and committed.
