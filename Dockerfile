# Container image that runs your code
FROM python:3.10-slim-bullseye

RUN apt update
RUN apt-get update \
    && apt-get install -y curl jq
RUN apt install bash
RUN apt-get -y install findutils
# RUN apk add --no-cache gcc musl-dev
# RUN apk add --no-cache acf-openssl
RUN apt install openssl
RUN apt install unzip
RUN apt-get install -y wget

#RUN apk --update add git less openssh && \
#    rm -rf /var/lib/apt/lists/* && \
#    rm /var/cache/apk/*0

RUN apt-get update \
    && apt-get clean \
    && curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf \
        awscliv2.zip

COPY --from=golang:1.22.5-bullseye /usr/local/go/ /usr/local/go/

RUN wget https://releases.hashicorp.com/terraform/1.9.3/terraform_1.9.3_linux_amd64.zip
RUN unzip terraform_1.9.3_linux_amd64.zip && rm terraform_1.9.3_linux_amd64.zip
RUN mv terraform /usr/bin/terraform

# Copies your code file from your action repository to the filesystem path `/` of the container
ADD entrypoint.sh /entrypoint.sh

ENV PATH="/usr/local/go/bin:${PATH}"

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/entrypoint.sh"]
