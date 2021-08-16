#!/bin/bash

set -eo pipefail

go install github.com/johnstarich/go/gopages

gopages -gh-pages -gh-pages-token $GITHUB_TOKEN -gh-pages-user "GitHub Action" -out "dist/$TAG"
