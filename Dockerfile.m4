m4_changequote([[, ]])

##################################################
## "build" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/ubuntu:20.04]], [[FROM docker.io/ubuntu:20.04]]) AS build
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectormolinero/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		build-essential \
		ca-certificates \
		curl \
		file \
		libreadline-dev

# Build Oil shell
ARG OILSHELL_VERSION=0.9.2
ARG OILSHELL_TARBALL_URL=https://www.oilshell.org/download/oil-${OILSHELL_VERSION}.tar.gz
ARG OILSHELL_TARBALL_CHECKSUM=6feee1db48d9296580fdfe715e43c57c080dda49bb5f52a8c8dddcc02a170e57
RUN curl -Lo /tmp/oilshell.tgz "${OILSHELL_TARBALL_URL:?}"
RUN printf '%s' "${OILSHELL_TARBALL_CHECKSUM:?}  /tmp/oilshell.tgz" | sha256sum -c
RUN mkdir /tmp/oilshell/ && tar -xzf /tmp/oilshell.tgz --strip-components=1 -C /tmp/oilshell/
WORKDIR /tmp/oilshell/
RUN ./configure --prefix=/usr --with-readline
RUN make -j"$(nproc)"
RUN ./install
RUN file /usr/bin/oil.ovm
RUN oil.ovm --version

##################################################
## "base" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/ubuntu:20.04]], [[FROM docker.io/ubuntu:20.04]]) AS base
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectormolinero/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		libreadline8 \
		libtinfo6 \
	&& rm -rf /var/lib/apt/lists/*

# Copy Oil shell build
COPY --from=build --chown=root:root /usr/bin/oil.ovm /usr/bin/
RUN ln -rs /usr/bin/oil.ovm /usr/bin/oil
RUN ln -rs /usr/bin/oil.ovm /usr/bin/osh

# Set OSH as default shell
SHELL ["/usr/bin/osh", "-c"]
ENV SHELL=/usr/bin/osh
RUN chsh -s /usr/bin/osh

ENTRYPOINT ["/usr/bin/oil"]

##################################################
## "test" stage
##################################################

FROM base AS test

ENV TEST_IN="hello() { printf 'hello %s\n' \"\${1:?}\"; }; hello world"
ENV TEST_OUT="hello world"
RUN test "$(oil -c "${TEST_IN:?}" 2>&1)" = "${TEST_OUT:?}"
RUN test "$(osh -c "${TEST_IN:?}" 2>&1)" = "${TEST_OUT:?}"

##################################################
## "main" stage
##################################################

FROM base AS main