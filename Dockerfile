# Container image that runs your code
FROM public.ecr.aws/lambda/python:3.10-x86_64

RUN yum makecache
RUN yum -y install jq
RUN yum -y install curl

#RUN yum -y group install "Development Tools"
RUN yum install findutils
RUN yum -y install openssl openssl-devel
RUN yum -y install gcc
RUN yum -y install git
RUN yum -y install less
RUN yum -y install wget
RUN yum -y install unzip
RUN yum -y install tar
RUN yum -y install make
RUN yum -y install bison
RUN yum install nodejs npm --enablerepo=epel
#RUN yum –y install openssh-server openssh-clients

RUN wget https://ftp.gnu.org/gnu/libc/glibc-2.28.tar.gz
RUN tar -xzf glibc-2.28.tar.gz && cd glibc-2.28 && mkdir build && pushd build && ../configure --prefix=/usr && make && make check && make install && popd && popd

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
