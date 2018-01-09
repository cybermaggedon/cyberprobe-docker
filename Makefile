
VERSION=1.8.2
GIT_VERSION=v1.8.2

BASE_FILES =  RPM/RPMS/x86_64/cyberprobe-${VERSION}-1.fc27.x86_64.rpm
BASE_FILES += RPM/RPMS/x86_64/cyberprobe-debuginfo-${VERSION}-1.fc27.x86_64.rpm
BASE_FILES += cyberprobe-${VERSION}.tar.gz
BASE_FILES += RPM/SRPMS/cyberprobe-${VERSION}-1.fc27.src.rpm

SRC_RPM = product/base/cyberprobe-${VERSION}-1.fc27.src.rpm
SRC = product/base/cyberprobe-${VERSION}.tar.gz

# Add sudo if you need to
DOCKER=docker

# Allows the release process to read from a different directory i.e.
# this macro can be over-ridden by the caller.

IMAGE_DIR=images

all: base rpm.f24 rpm.f25 rpm.f26 rpm.f27 rpm.centos7 deb.debian-jessie \
	deb.debian-wheezy deb.debian-stretch deb.ubuntu-16.04 \
	deb.ubuntu-17.04 deb.ubuntu-17.10 deb.ubuntu-18.04 \
	container

#	make base
#	make rpm OS=f24
#	make rpm OS=f25
#	make rpm OS=f26
#	make rpm OS=f27
#	make deb OS=debian-jessie
#	make deb OS=debian-wheezy
#	make deb OS=debian-stretch
#	make deb OS=ubuntu-16.04
#	make deb OS=ubuntu-17.04
#	make deb OS=ubuntu-17.10
#	make deb OS=ubuntu-18.04
#	make deb OS=centos7
#	make container

#debian fedora ubuntu centos container

# Base is a Fedora 27 build which produces source tar, source RPM,
# and Fedora 27 RPMs for container builds.
base: PRODUCT=product/base

base:
	rm -rf ${PRODUCT}
	mkdir -p ${PRODUCT}
	${DOCKER} build ${BUILD_ARGS} -t cyberprobe-fedora27-dev \
		-f Dockerfile.fedora27.dev .
	${DOCKER} build ${BUILD_ARGS} -t cyberprobe-fedora27-build \
		--build-arg GIT_VERSION=${GIT_VERSION} \
		-f Dockerfile.fedora27.build .
	id=$$(${DOCKER} run -d cyberprobe-fedora27-build sleep 180); \
	dir=/usr/local/src/cyberprobe; \
	for file in ${BASE_FILES}; do \
		bn=$$(basename $$file); \
		${DOCKER} cp $${id}:$${dir}/$${file} ${PRODUCT}/$${bn}; \
	done; \
	${DOCKER} rm -f $${id}

ARCH=x86_64
rpm.%: OS=$(@:rpm.%=%)
rpm.%: PRODUCT=product/${OS}

rpm.%:
	rm -rf ${PRODUCT}
	mkdir -p ${PRODUCT}
	${DOCKER} build ${BUILD_ARGS} -t cyberprobe-${OS}-dev \
		-f ${OS}/Dockerfile.dev .
	${DOCKER} build ${BUILD_ARGS} -t cyberprobe-${OS}-build \
		--build-arg SRC_RPM=${SRC_RPM} \
		-f ${OS}/Dockerfile.build .
	id=$$(${DOCKER} run -d cyberprobe-${OS}-build sleep 180); \
	${DOCKER} exec $${id} sh -c 'cd /root/rpmbuild/RPMS/${ARCH}; tar cfz - .' | (cd ${PRODUCT}; tar xvfz -); \
	${DOCKER} rm -f $${id}

deb.%: OS=$(@:deb.%=%)
deb.%: PRODUCT=product/${OS}

deb.%: 
	rm -rf ${PRODUCT}
	mkdir -p ${PRODUCT}
	${DOCKER} build ${BUILD_ARGS} -t cyberprobe-${OS}-dev \
		-f ${OS}/Dockerfile.dev .
	${DOCKER} build ${BUILD_ARGS} -t cyberprobe-${OS}-build \
		--build-arg SRC=${SRC} \
		--build-arg VERSION=${VERSION} \
		-f ${OS}/Dockerfile.build .
	id=$$(${DOCKER} run -d cyberprobe-${OS}-build sleep 180); \
	${DOCKER} exec $${id} sh -c 'tar cfz - *.deb' | (cd ${PRODUCT}; tar xvfz -); \
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

container-images: images/cyberprobe.img

push-images:
	${DOCKER} load -i ${IMAGE_DIR}/cyberprobe.img
	${DOCKER} push docker.io/cybermaggedon/cyberprobe:${VERSION}
	${DOCKER} push docker.io/cybermaggedon/cybermon:${VERSION}
	${DOCKER} push docker.io/cybermaggedon/cyberprobe:latest
	${DOCKER} push docker.io/cybermaggedon/cybermon:latest

images/cyberprobe.img: ALWAYS images
	${DOCKER} save -o $@ \
		docker.io/cybermaggedon/cyberprobe:${VERSION} \
		docker.io/cybermaggedon/cyberprobe:latest \
		docker.io/cybermaggedon/cybermon:${VERSION} \
		docker.io/cybermaggedon/cybermon:latest

images:
	mkdir images

ALWAYS:

push:
	${DOCKER} push docker.io/cybermaggedon/cyberprobe:${VERSION}
	${DOCKER} push docker.io/cybermaggedon/cybermon:${VERSION}
	${DOCKER} push docker.io/cybermaggedon/cyberprobe:latest
	${DOCKER} push docker.io/cybermaggedon/cybermon:latest

go:
	GOPATH=$$(pwd)/go go get github.com/aktau/github-release

TOKEN_FILE=TOKEN

create-release: go
	go/bin/github-release release \
	  --user cybermaggedon \
	  --repo cyberprobe \
	  --tag v${VERSION} \
	  --name "Version ${VERSION}" \
	  --description "" \
	  -s $$(cat ${TOKEN_FILE})

upload-release: go
	for file in ${PRODUCT}/*${VERSION}*; do \
	name=$$(basename $$file); \
	go/bin/github-release upload \
	  --user cybermaggedon \
	  --repo cyberprobe \
	  --tag v${VERSION} \
	  --name $$name \
	  --file $$file \
	  -s $$(cat ${TOKEN_FILE}); \
	done

# Continuous deployment support
BRANCH=master
PREFIX=resources/probe-svc
FILE=${PREFIX}/ksonnet/version.jsonnet
REPO=git@github.com:cybermaggedon/cyberprobe-docker

tools: phony
	if [ ! -d tools ]; then \
		git clone git@github.com:trustnetworks/cd-tools tools; \
	fi; \
	(cd tools; git pull)

phony:

bump-version: tools
	tools/bump-version

update-cluster-config: tools
	tools/update-version-config ${BRANCH} ${VERSION} ${FILE}
	tools/update-version-config ${BRANCH} ${VERSION} resources/vpn-service/ksonnet/cyberprobe-version.jsonnet

