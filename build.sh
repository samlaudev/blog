#!/usr/bin/env bash
set -e

bundle exec jekyll build
rm _site/build.sh
rsync -azP _site/ samlau@samlaudev.cn:/home/samlau/www/samlaudev.cn