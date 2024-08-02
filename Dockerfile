# Container image that runs your code
FROM python:3.8-alpine

RUN apk add --update --no-cache curl jq
RUN apk add --no-cache bash
RUN apk add --no-cache gcc musl-dev
RUN apk add --no-cache findutils
RUN apk add --no-cache acf-openssl
RUN apk --update add git less openssh && \
    rm -rf /var/lib/apt/lists/* && \
    rm /var/cache/apk/*


RUN pip install awscli
COPY --from=golang:1.22.5-alpine3.20 /usr/local/go/ /usr/local/go/

RUN release=`curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest |  grep tag_name | cut -d: -f2 | tr -d \"\,\v | awk '{$1=$1};1'`
RUN wget https://releases.hashicorp.com/terraform/${release}/terraform_${release}_linux_amd64.zip
RUN unzip terraform_${release}_linux_amd64.zip && rm terraform_${release}_linux_amd64.zip
RUN mv terraform /usr/bin/terraform

# Copies your code file from your action repository to the filesystem path `/` of the container
ADD entrypoint.sh /entrypoint.sh

ENV PATH="/usr/local/go/bin:${PATH}"

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/entrypoint.sh"]
