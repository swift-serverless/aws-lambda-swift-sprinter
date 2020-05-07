FROM swiftlang/swift:nightly-amazonlinux2 as builder

RUN yum -y update && \
    yum -y install libatomic libedit gcc git zlib-dev