#!/bin/bash

set -eo pipefail

cd "$(dirname "$(find . -name 'go.mod' | head -n 1)")" || exit 1

MODULE_ROOT="$(go list -m)"
REPO_NAME="$(basename $(echo $GITHUB_REPOSITORY))"

mkdir -p "$GOPATH/src/github.com/$GITHUB_REPOSITORY"
cp -r * "$GOPATH/src/github.com/$GITHUB_REPOSITORY"
(cd /tmp && godoc -http localhost:8080 &)

for (( ; ; )); do
  sleep 0.5
  if [[ $(curl -so /dev/null -w '%{http_code}' "http://localhost:8080/pkg/$MODULE_ROOT/") -eq 200 ]]; then
    break
  fi
done

git checkout origin/gh-pages || git checkout -b gh-pages

wget --quiet --mirror --show-progress --page-requisites --execute robots=off --no-parent "http://localhost:8080/pkg/$MODULE_ROOT/"

rm -rf doc lib "$TAG" # Delete previous documents.
mv localhost:8080/* .
rm -rf localhost:8080
find pkg -type f -exec sed -i "s#/lib/godoc#/$REPO_NAME/lib/godoc#g" {} +
find . -maxdepth 1 -type f -delete # Delete first level files

git config --local user.email "action@github.com"
git config --local user.name "GitHub Action"
[ -d "$TAG" ] || mkdir "$TAG"
mv pkg "$TAG"
git add "$TAG" doc lib
git commit -m "Update documentation"

GODOC_URL="https://$(dirname $(echo $GITHUB_REPOSITORY)).github.io/$REPO_NAME/$TAG/pkg/$MODULE_ROOT/index.html"

if ! curl -sH "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$GITHUB_REPOSITORY/releases/tags/$TAG" | grep '## GoDoc' > /dev/null; then
  echo "updating tag: https://api.github.com/repos/$GITHUB_REPOSITORY/releases/tags/$TAG"
  curl -sH "Authorization: token $GITHUB_TOKEN" \
    -X PATCH \
    -d '{ "body": "## GoDoc\n'"$GODOC_URL"'" }' \
    "https://api.github.com/repos/$GITHUB_REPOSITORY/releases/tags/$TAG"
fi
