# Release Flow

Run one script, it manages the entire release end-to-end. The only step that runs separately is the npm publish in CI, which fires automatically after the GitHub release is created.

## Stage 1 — Run the script

```bash
bash scripts/release.sh X.Y.Z
```

One command handles the entire release. It does everything that needs local Git access:

- runs `bash tests/test.sh` (17 smoke tests, must pass)
- bumps the `version` field in `package.json` to `X.Y.Z`
- commits with message `chore: bump to vX.Y.Z`
- tags the commit as `vX.Y.Z`
- pushes `main` and the tag to GitHub
- creates a GitHub release via `gh release create`
- fetches the release tarball and computes its SHA256
- updates the Homebrew tap formula at `$TAP_DIR/Formula/cc-statusline-cli.rb`:
  - replaces the tarball URL tag
  - replaces the `sha256` line
  - removes any `revision N` line (new source resets it)
- validates the formula with `brew style`
- commits and pushes the tap

## Stage 2 — CI publishes to npm automatically

The GitHub Action `.github/workflows/release.yml` fires on its own when the GitHub release created by the script is published. No manual trigger needed.

```
release (published) → smoke tests → npm publish
```

- triggers on `release: [published]`
- checks out the tagged commit
- runs smoke tests again (`bash tests/test.sh`)
- publishes to npm with `npm publish`
- npm token comes from the `NPM_TOKEN` secret
- provenance is attached automatically (`provenance: true` in `package.json`)

The CI does **not** bump versions, create tags, or touch the tap — it only runs tests and publishes.

## Stage 3 — End-to-end verification

After CI publishes the npm package:

```bash
brew update
brew upgrade cc-statusline-cli
cc-statusline version
```

## Diagram

```
scripts/release.sh X.Y.Z
  ├─ tests
  ├─ bump package.json
  ├─ git commit + tag + push
  ├─ gh release create
  ├─ sha256 for tarball
  └─ update homebrew tap ────────────────► brew users can upgrade

GitHub Release (published)
  └─ CI (release.yml)
       ├─ smoke tests
       └─ npm publish ───────────────────► npm users get the package
```

## What each part owns

| Step                  | Local script | CI (release.yml) |
|-----------------------|-------------|-------------------|
| Run tests             | yes         | yes (rerun)       |
| Bump package.json     | yes         | no                |
| Git commit + tag      | yes         | no                |
| GitHub Release        | yes         | no                |
| SHA256 for tarball    | yes         | no                |
| Update homebrew tap   | yes         | no                |
| Publish to npm        | no          | yes               |
