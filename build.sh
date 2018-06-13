#!/bin/sh
set -e -x

: ${DOCKER_REGISTRY:="dispatchframework"}

cd $(dirname $0)

IMAGE=${DOCKER_REGISTRY}/powershell-base:$(cat version.txt)
docker build -t ${IMAGE} .
if [ -n "$PUSH" ]; then
    docker push ${IMAGE}
fi