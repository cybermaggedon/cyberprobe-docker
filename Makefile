
VERSION=0.73
GIT_VERSION=v0.73

FEDORA_FILES =  RPM/RPMS/x86_64/cyberprobe-${VERSION}-1.fc24.x86_64.rpm
FEDORA_FILES += RPM/RPMS/x86_64/cyberprobe-debuginfo-${VERSION}-1.fc24.x86_64.rpm
FEDORA_FILES += cyberprobe-${VERSION}.tar.gz
FEDORA_FILES += RPM/SRPMS/cyberprobe-${VERSION}-1.fc24.src.rpm

DEBIAN_FILES = cyberprobe_${VERSION}-1_amd64.deb

UBUNTU_FILES = cyberprobe_${VERSION}-1_amd64.deb

all: product debian fedora ubuntu container

product:
	mkdir product

debian:
	sudo docker build ${BUILD_ARGS} -t cyberprobe-debian-dev \
		-f Dockerfile.debian.dev .
	sudo docker build ${BUILD_ARGS} -t cyberprobe-debian-build \
		--build-arg GIT_VERSION=${GIT_VERSION} \
		-f Dockerfile.debian.build .
	id=$$(sudo docker run -d cyberprobe-debian-build sleep 180); \
	dir=/usr/local/src/cyberprobe; \
	for file in ${DEBIAN_FILES}; do \
		bn=$$(basename $$file); \
		sudo docker cp $${id}:$${dir}/$${file} product/debian-$${bn}; \
	done; \
	sudo docker rm -f $${id}

fedora:
	sudo docker build ${BUILD_ARGS} -t cyberprobe-fedora-dev \
		-f Dockerfile.fedora.dev .
	sudo docker build ${BUILD_ARGS} -t cyberprobe-fedora-build \
		--build-arg GIT_VERSION=${GIT_VERSION} \
		-f Dockerfile.fedora.build .
	id=$$(sudo docker run -d cyberprobe-fedora-build sleep 180); \
	dir=/usr/local/src/cyberprobe; \
	for file in ${FEDORA_FILES}; do \
		bn=$$(basename $$file); \
		sudo docker cp $${id}:$${dir}/$${file} product/fedora-$${bn}; \
	done; \
	sudo docker rm -f $${id}

ubuntu:
	sudo docker build ${BUILD_ARGS} -t cyberprobe-ubuntu-dev \
		-f Dockerfile.ubuntu.dev .
	sudo docker build ${BUILD_ARGS} -t cyberprobe-ubuntu-build \
		--build-arg GIT_VERSION=${GIT_VERSION} \
		-f Dockerfile.ubuntu.build .
	id=$$(sudo docker run -d cyberprobe-ubuntu-build sleep 180); \
	dir=/usr/local/src/cyberprobe; \
	for file in ${UBUNTU_FILES}; do \
		bn=$$(basename $$file); \
		sudo docker cp $${id}:$${dir}/$${file} product/ubuntu-$${bn}; \
	done; \
	sudo docker rm -f $${id}

container:
	sudo docker build ${BUILD_ARGS} -t cyberprobe \
		--build-arg VERSION=${VERSION} \
		-f Dockerfile.cyberprobe.deploy .
	sudo docker tag cyberprobe docker.io/cybermaggedon/cyberprobe:${VERSION}
	sudo docker tag cyberprobe docker.io/cybermaggedon/cyberprobe:latest
	sudo docker build ${BUILD_ARGS} -t cybermon \
		--build-arg VERSION=${VERSION} \
		-f Dockerfile.cybermon.deploy .
	sudo docker tag cybermon docker.io/cybermaggedon/cybermon:${VERSION}
	sudo docker tag cybermon docker.io/cybermaggedon/cybermon:latest

push:
	sudo docker push docker.io/cybermaggedon/cyberprobe:${VERSION}
	sudo docker push docker.io/cybermaggedon/cybermon:${VERSION}
	sudo docker push docker.io/cybermaggedon/cyberprobe:latest
	sudo docker push docker.io/cybermaggedon/cybermon:latest
