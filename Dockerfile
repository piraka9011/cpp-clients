# syntax = docker/dockerfile:1.2
ARG BAZEL_VERSION=5.0.0
ARG TARGET_ARCH=x86_64 # valid values: x86_64, aarch64
ARG TARGET_OS=linux    # valid values: linux, l4t

FROM ubuntu:20.04 AS base
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y libasound2    

FROM base AS builddep
ARG BAZEL_VERSION
ARG TARGET_ARCH
ARG TARGET_OS

RUN apt-get update && apt-get install -y \
    git \
    wget \
    unzip \
    build-essential \
    libasound2-dev

RUN if [ "$TARGET_ARCH" = "aarch64" ] && [ "$TARGET_OS" = "l4t" ]; then \
        apt-get update && apt-get install -y --no-install-recommends openjdk-11-jdk-headless; \
    fi

# install bazel
SHELL ["/bin/bash", "-c"]
RUN wget -nv https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-linux-${TARGET_ARCH//aarch64/arm64} && \
    chmod +x bazel-${BAZEL_VERSION}-linux-${TARGET_ARCH//aarch64/arm64} && \
    mv bazel-${BAZEL_VERSION}-linux-${TARGET_ARCH//aarch64/arm64} /usr/local/bin/bazel;
SHELL ["/bin/sh", "-c"]

ENV PATH="/root/bin:${PATH}"

FROM builddep as builder
ARG TARGET_ARCH
ARG TARGET_OS

WORKDIR /work
COPY .bazelrc .gitignore WORKSPACE ./
COPY .git /work/.git
COPY scripts /work/scripts
COPY third_party /work/third_party
COPY riva /work/riva
ARG BAZEL_CACHE_ARG=""
RUN bazel test $BAZEL_CACHE_ARG --config=${TARGET_ARCH} --config=${TARGET_OS} //riva/clients/... --test_summary=detailed --test_output=all && \
    bazel build --stamp --config=release --config=${TARGET_ARCH} --config=${TARGET_OS} $BAZEL_CACHE_ARG //... && \
    cp -R /work/bazel-bin/riva /opt

RUN ls -lah /work; ls -lah /work/.git; cat /work/.bazelrc

FROM base as riva-clients

WORKDIR /work
COPY --from=builder /opt/riva/clients/asr/riva_asr_client /usr/local/bin/ 
COPY --from=builder /opt/riva/clients/asr/riva_streaming_asr_client /usr/local/bin/ 
COPY --from=builder /opt/riva/clients/tts/riva_tts_client /usr/local/bin/ 
COPY --from=builder /opt/riva/clients/tts/riva_tts_perf_client /usr/local/bin/ 
COPY --from=builder /opt/riva/clients/nlp/riva_nlp_classify_tokens /usr/local/bin/ 
COPY --from=builder /opt/riva/clients/nlp/riva_nlp_punct /usr/local/bin/ 
COPY --from=builder /opt/riva/clients/nlp/riva_nlp_qa /usr/local/bin/
COPY examples /work/examples
