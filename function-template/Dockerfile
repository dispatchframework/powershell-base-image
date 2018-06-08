ARG IMAGE
FROM ${IMAGE}

ARG HANDLER
ENV HANDLER=$HANDLER

WORKDIR ${WORKDIR}

COPY . .

# Create handler file if passed in otherwise assume default handler
RUN echo -n ${HANDLER} > /tmp/handler
RUN [ -z "${HANDLER}" ] && \
    [ $(ls *.ps1 | wc -l) -eq "1" ] && \
    filename=$(ls *.ps1) && \
    { echo -n $filename; echo -n "::handle"; } > /tmp/handler || :

# Validate function file and given handler
RUN pwsh -NoLogo -File /root/validator/validator.ps1 ${WORKDIR} $(cat /tmp/handler) || (echo "Invalid function file or handler" >&2 && exit 1)