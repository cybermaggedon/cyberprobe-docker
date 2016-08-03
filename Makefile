
VERSION=0.63

BUILD_ARGS =  --build-arg http_proxy=http://10.0.1.2:3128/
BUILD_ARGS += --build-arg https_proxy=http://10.0.1.2:3128/

FEDORA_FILES =  RPM/RPMS/x86_64/cyberprobe-${VERSION}-1.fc24.x86_64.rpm
FEDORA_FILES += RPM/RPMS/x86_64/cyberprobe-debuginfo-${VERSION}-1.fc24.x86_64.rpm
FEDORA_FILES += cyberprobe-${VERSION}.tar.gz
FEDORA_FILES += RPM/SRPMS/cyberprobe-${VERSION}-1.fc24.src.rpm

DEBIAN_FILES = cyberprobe_${VERSION}-1_amd64.deb

UBUNTU_FILES = cyberprobe_${VERSION}-1_amd64.deb

all: product debian fedora ubuntu deploy

product:
	mkdir product

debian:
	sudo docker build ${BUILD_ARGS} -t cyberprobe-debian-dev \
		-f Dockerfile.debian.dev .
	sudo docker build ${BUILD_ARGS} -t cyberprobe-debian-build \
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
		-f Dockerfile.ubuntu.build .
	id=$$(sudo docker run -d cyberprobe-ubuntu-build sleep 180); \
	dir=/usr/local/src/cyberprobe; \
	for file in ${UBUNTU_FILES}; do \
		bn=$$(basename $$file); \
		sudo docker cp $${id}:$${dir}/$${file} product/ubuntu-$${bn}; \
	done; \
	sudo docker rm -f $${id}

deploy:
	sudo docker build ${BUILD_ARGS} -t cyberprobe \
		-f Dockerfile.cyberprobe.deploy .
	sudo docker build ${BUILD_ARGS} -t cybermon \
		-f Dockerfile.cybermon.deploy .

