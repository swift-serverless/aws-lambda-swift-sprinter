FROM swift:latest as builder

RUN apt-get -qq update && apt-get -q -y install \
    libssl-dev libicu-dev \