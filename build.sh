#!/bin/sh
set -e -x

: ${DOCKER_REGISTRY:="dispatchframework"}

cd $(dirname $0)

FUNKY_VERSION=$(jq -r .funky < version.json)

IMAGE=${DOCKER_REGISTRY}/powershell-base:$(jq -r .tag < version.json)
docker build -t ${IMAGE} --build-arg=FUNKY_VERSION=${FUNKY_VERSION} .
if [ -n "$PUSH" ]; then
    docker push ${IMAGE}
fi