#!/usr/bin/env bash
set -euo pipefail

TAP_DIR="${TAP_DIR:-$HOME/Projects/personal/homebrew-tap}"
VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
  echo "usage: bash scripts/release.sh X.Y.Z" >&2
  exit 1
fi

TAG="v$VERSION"
REPO="tenondecrpc/cc-statusline"

echo "==> running tests"
bash tests/test.sh

echo "==> bumping package.json version"
version_ts="$(jq -r '.version' package.json)"
if [[ "$version_ts" == "$VERSION" ]]; then
  echo "package.json version already $VERSION, skipping bump"
else
  jq --arg v "$VERSION" '.version = $v' package.json > package.json.tmp
  mv package.json.tmp package.json
fi

echo "==> committing and tagging"
git add package.json
git commit -m "chore: bump to $TAG"
git tag "$TAG"

echo "==> pushing to origin"
git push origin "$(git rev-parse --abbrev-ref HEAD)" "$TAG"

echo "==> creating GitHub release"
gh release create "$TAG" --title "$TAG" --notes "Release $TAG"

echo "==> computing tarball SHA256"
SHA256=$(curl -fsSL "https://github.com/$REPO/archive/refs/tags/$TAG.tar.gz" | shasum -a 256 | awk '{print $1}')
echo "sha256: $SHA256"

echo "==> updating homebrew tap formula in $TAP_DIR"
FORMULA="$TAP_DIR/Formula/cc-statusline-cli.rb"
if [[ ! -f "$FORMULA" ]]; then
  echo "error: formula not found at $FORMULA" >&2
  exit 1
fi

# Update url tag
sed -i '' "s|/refs/tags/v[0-9]\+\.[0-9]\+\.[0-9]\+\.tar\.gz|/refs/tags/$TAG.tar.gz|" "$FORMULA"
# Update sha256
sed -i '' "s|sha256 \".*\"|sha256 \"$SHA256\"|" "$FORMULA"
# Remove revision line if present (new source version resets it)
sed -i '' '/  revision [0-9]/d' "$FORMULA"

echo "==> validating tap formula"
(cd "$TAP_DIR" && brew style Formula/cc-statusline-cli.rb)

echo "==> committing and pushing tap"
(cd "$TAP_DIR" && git add Formula/cc-statusline-cli.rb && git commit -m "chore: bump cc-statusline-cli to $TAG" && git push origin main)

echo ""
echo "done! verify with: brew update && brew upgrade cc-statusline-cli && cc-statusline version"
