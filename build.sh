#!/bin/sh
set -e -x

cd $(dirname $0)

docker build -t dispatchframework/powershell-base:0.0.7 .
