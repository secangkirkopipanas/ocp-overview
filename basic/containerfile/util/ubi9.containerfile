FROM registry.access.redhat.com/ubi9/ubi:9.7

RUN \
    dnf install -y \
            python3 \
            python3-pip \
            iputils \
        && dnf clean all

COPY resources/helloworld.txt /tmp/
