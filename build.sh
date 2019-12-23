#!/usr/bin/env bash
set -e

bundle exec jekyll build
rm _site/build.sh