## builder image
FROM microsoft/powershell:ubuntu16.04 as builder

RUN mkdir /powershell

RUN pwsh -command 'Save-Module -Name PowerShellGet -RequiredVersion "1.6.0" -Path /powershell' > /dev/null

# PSDepend dependency manager
RUN pwsh -command 'Save-Module -Name PSDepend -RequiredVersion "0.1.64" -Path /powershell' > /dev/null

# Fix for https://github.com/RamblingCookieMonster/PSDepend/issues/74
RUN mv /powershell/PSDepend/0.1.64/PSDependScripts/Noop.ps1 /powershell/PSDepend/0.1.64/PSDependScripts/noop.ps1


## base image
FROM vmware/photon2:20180424

RUN tdnf install -y powershell-6.0.1-1.ph2 gzip tar
COPY --from=builder /powershell/ /root/.local/share/powershell/Modules/

ARG IMAGE_TEMPLATE=/image-template
ARG FUNCTION_TEMPLATE=/function-template
ARG servers=1

LABEL io.dispatchframework.imageTemplate="${IMAGE_TEMPLATE}" \
      io.dispatchframework.functionTemplate="${FUNCTION_TEMPLATE}"

COPY image-template ${IMAGE_TEMPLATE}/
COPY function-template ${FUNCTION_TEMPLATE}/

COPY validator /root/validator/

ENV WORKDIR=/root/function PORT=8080 SERVERS=$servers FUNKY_VERSION=0.1.1
EXPOSE ${PORT}
WORKDIR ${WORKDIR}

COPY ./index.ps1 /root

RUN curl -L https://github.com/dispatchframework/funky/releases/download/${FUNKY_VERSION}/funky${FUNKY_VERSION}.linux-amd64.tgz -o funky${FUNKY_VERSION}.linux-amd64.tgz
RUN tar -xzf funky${FUNKY_VERSION}.linux-amd64.tgz

# OpenFaaS readiness check depends on this file
RUN touch /tmp/.lock

CMD SERVER_CMD="pwsh -NoLogo -File /root/index.ps1 $(cat /tmp/handler)" ./funky
