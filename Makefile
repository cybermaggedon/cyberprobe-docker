
VERSION=1.1
GIT_VERSION=v1.1

FEDORA_FILES =  RPM/RPMS/x86_64/cyberprobe-${VERSION}-1.fc25.x86_64.rpm
FEDORA_FILES += RPM/RPMS/x86_64/cyberprobe-debuginfo-${VERSION}-1.fc25.x86_64.rpm
FEDORA_FILES += cyberprobe-${VERSION}.tar.gz
FEDORA_FILES += RPM/SRPMS/cyberprobe-${VERSION}-1.fc25.src.rpm

DEBIAN_FILES = cyberprobe_${VERSION}-1_amd64.deb

UBUNTU_FILES = cyberprobe_${VERSION}-1_amd64.deb

CENTOS_FILES =  RPM/RPMS/x86_64/cyberprobe-${VERSION}-1.el7.centos.x86_64.rpm
CENTOS_FILES += RPM/RPMS/x86_64/cyberprobe-debuginfo-${VERSION}-1.el7.centos.x86_64.rpm
CENTOS_FILES += RPM/SRPMS/cyberprobe-${VERSION}-1.el7.centos.src.rpm

# Add sudo if you need to
DOCKER=docker

all: product debian fedora ubuntu centos container

product:
	mkdir product

debian: product
	${DOCKER} build ${BUILD_ARGS} -t cyberprobe-debian-dev \
		-f Dockerfile.debian.dev .
	${DOCKER} build ${BUILD_ARGS} -t cyberprobe-debian-build \
		--build-arg GIT_VERSION=${GIT_VERSION} \
		-f Dockerfile.debian.build .
	id=$$(${DOCKER} run -d cyberprobe-debian-build sleep 180); \
	dir=/usr/local/src/cyberprobe; \
	for file in ${DEBIAN_FILES}; do \
		bn=$$(basename $$file); \
		${DOCKER} cp $${id}:$${dir}/$${file} product/debian-$${bn}; \
	done; \
	${DOCKER} rm -f $${id}

fedora: product
	${DOCKER} build ${BUILD_ARGS} -t cyberprobe-fedora-dev \
		-f Dockerfile.fedora.dev .
	${DOCKER} build ${BUILD_ARGS} -t cyberprobe-fedora-build \
		--build-arg GIT_VERSION=${GIT_VERSION} \
		-f Dockerfile.fedora.build .
	id=$$(${DOCKER} run -d cyberprobe-fedora-build sleep 180); \
	dir=/usr/local/src/cyberprobe; \
	for file in ${FEDORA_FILES}; do \
		bn=$$(basename $$file); \
		${DOCKER} cp $${id}:$${dir}/$${file} product/fedora-$${bn}; \
	done; \
	${DOCKER} rm -f $${id}
	mv product/fedora-cyberprobe-${VERSION}.tar.gz product/cyberprobe-${VERSION}.tar.gz
	mv product/fedora-cyberprobe-${VERSION}-1.fc25.src.rpm product/cyberprobe-${VERSION}-1.src.rpm

ubuntu:
	${DOCKER} build ${BUILD_ARGS} -t cyberprobe-ubuntu-dev \
		-f Dockerfile.ubuntu.dev .
	${DOCKER} build ${BUILD_ARGS} -t cyberprobe-ubuntu-build \
		--build-arg GIT_VERSION=${GIT_VERSION} \
		-f Dockerfile.ubuntu.build .
	id=$$(${DOCKER} run -d cyberprobe-ubuntu-build sleep 180); \
	dir=/usr/local/src/cyberprobe; \
	for file in ${UBUNTU_FILES}; do \
		bn=$$(basename $$file); \
		${DOCKER} cp $${id}:$${dir}/$${file} product/ubuntu-$${bn}; \
	done; \
	${DOCKER} rm -f $${id}

container:
	${DOCKER} build ${BUILD_ARGS} -t cyberprobe \
		--build-arg VERSION=${VERSION} \
		-f Dockerfile.cyberprobe.deploy .
	${DOCKER} tag cyberprobe docker.io/cybermaggedon/cyberprobe:${VERSION}
	${DOCKER} tag cyberprobe docker.io/cybermaggedon/cyberprobe:latest
	${DOCKER} build ${BUILD_ARGS} -t cybermon \
		--build-arg VERSION=${VERSION} \
		-f Dockerfile.cybermon.deploy .
	${DOCKER} tag cybermon docker.io/cybermaggedon/cybermon:${VERSION}
	${DOCKER} tag cybermon docker.io/cybermaggedon/cybermon:latest

push:
	${DOCKER} push docker.io/cybermaggedon/cyberprobe:${VERSION}
	${DOCKER} push docker.io/cybermaggedon/cybermon:${VERSION}
	${DOCKER} push docker.io/cybermaggedon/cyberprobe:latest
	${DOCKER} push docker.io/cybermaggedon/cybermon:latest

luarocks-2.4.2.tar.gz:
	wget http://luarocks.org/releases/luarocks-2.4.2.tar.gz

centos: product luarocks-2.4.2.tar.gz
	${DOCKER} build ${BUILD_ARGS} -t cyberprobe-centos-dev \
		-f Dockerfile.centos.dev .
	${DOCKER} build ${BUILD_ARGS} -t cyberprobe-centos-build \
		--build-arg GIT_VERSION=${GIT_VERSION} \
		-f Dockerfile.centos.build .
	id=$$(${DOCKER} run -d cyberprobe-centos-build sleep 180); \
	dir=/usr/local/src/cyberprobe; \
	for file in ${CENTOS_FILES}; do \
		bn=$$(basename $$file); \
		${DOCKER} cp $${id}:$${dir}/$${file} product/centos-$${bn}; \
	done; \
	${DOCKER} rm -f $${id}

