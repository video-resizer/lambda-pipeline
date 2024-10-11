# Container image that runs your code
FROM public.ecr.aws/lambda/python:3.12-x86_64

RUN dnf makecache
RUN dnf -y install jq
# Curl is already installed on Amazon Linux 2023
#RUN dnf -y install curl

# Amazon Linux 2023 uses microdnf which doesn't support group install
#RUN dnf group install "Development Tools"
RUN dnf -y install findutils
RUN dnf -y install openssl openssl-devel
RUN dnf -y install gcc
RUN dnf -y install gcc-c++
RUN dnf -y install git
RUN dnf -y install less
RUN dnf -y install wget
RUN dnf -y install unzip
RUN dnf -y install tar
RUN dnf -y install make
RUN dnf -y install bison
RUN curl -fsSL https://rpm.nodesource.com/setup_22.x -o nodesource_setup.sh
RUN bash nodesource_setup.sh
#RUN dnf –y install openssh-server openssh-clients

RUN dnf -y install nodejs
RUN npm install -g cypress

RUN pip install awscli
COPY --from=golang:1.22.5-alpine3.20 /usr/local/go/ /usr/local/go/

RUN wget https://releases.hashicorp.com/terraform/1.9.3/terraform_1.9.3_linux_amd64.zip
RUN unzip terraform_1.9.3_linux_amd64.zip && rm terraform_1.9.3_linux_amd64.zip
RUN mv terraform /usr/bin/terraform


# Copies your code file from your action repository to the filesystem path `/` of the container
ADD entrypoint.sh /entrypoint.sh

ENV PATH="/usr/local/go/bin:${PATH}"

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/entrypoint.sh"]
