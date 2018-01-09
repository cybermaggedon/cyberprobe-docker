
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

# GPG user ID
USERID=Trust Networks <cyberprobe@trustnetworks.com>

all: product/trust-networks.asc base \
	rpm.f24 rpm.f25 rpm.f26 rpm.f27 rpm.centos7 \
	deb.debian-jessie deb.debian-wheezy deb.debian-stretch \
	deb.ubuntu-xenial deb.ubuntu-zesty deb.ubuntu-artful \
	deb.ubuntu-bionic \
	container

download-product:
	mkdir -p product
	gsutil rsync -r gs://download.trustnetworks.com/ product/

upload-product:
	gsutil -m rsync -r product/ gs://download.trustnetworks.com/
	gsutil -m acl -r ch -u AllUsers:R gs://download.trustnetworks.com/

product/trust-networks.asc:
	mkdir -p product
	gpg2 --armor --export > $@

# Base is a Fedora 27 build which produces source tar, source RPM,
# and Fedora 27 RPMs for container builds.
base: PRODUCT=product/base

base:
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
rpm.f%: PRODUCT=product/fedora/$(@:rpm.f%=%)/x86_64
rpm.centos%: PRODUCT=product/centos/$(@:rpm.centos%=%)/x86_64

rpm.%:
	mkdir -p ${PRODUCT}
	${DOCKER} build ${BUILD_ARGS} -t cyberprobe-${OS}-dev \
		-f ${OS}/Dockerfile.dev .
	${DOCKER} build ${BUILD_ARGS} -t cyberprobe-${OS}-build \
		--build-arg SRC_RPM=${SRC_RPM} \
		-f ${OS}/Dockerfile.build .
	id=$$(${DOCKER} run -d cyberprobe-${OS}-build sleep 180); \
	${DOCKER} exec $${id} sh -c 'cd /root/rpmbuild/RPMS/${ARCH}; tar cfz - .' | (cd ${PRODUCT}; tar xvfz -); \
	${DOCKER} rm -f $${id}
	for file in ${PRODUCT}/*.rpm; \
	do \
		rpm \
		  -D '%_signature gpg' \
		  -D '%_gpg_name ${USERID}' \
		  -D "%_gpg_path $${HOME}/.gnupg" \
		  -D '%_gpgbin /usr/bin/gpg2' \
		  --resign $${file}; \
	done
	createrepo ${PRODUCT}

deb.%: OS=$(@:deb.%=%)
deb.debian-%: RELATIVE=debian/$(@:deb.debian-%=%)/main/binary-amd64
deb.ubuntu-%: RELATIVE=ubuntu/$(@:deb.ubuntu-%=%)/main/binary-amd64
deb.debian-%: BASE=product
deb.ubuntu-%: BASE=product
deb.debian-%: PRODUCT=${BASE}/${RELATIVE}
deb.ubuntu-%: PRODUCT=${BASE}/${RELATIVE}

deb.%: 
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
	cd ${PRODUCT}; \
	for file in *.deb; \
	do \
	  echo $${file}; \
	  rm -rf tmp; \
	  mkdir tmp; \
	  ( \
	    cd tmp; ar x ../$${file}; \
	    cat debian-binary control.* data.* > tempfile; \
	    gpg2 -u '${USERID}' -abs -o _gpgorigin tempfile; \
	    ar rc ../$${file} _gpgorigin debian-binary control.* data.*; \
	  ); \
	  rm -rf tmp; \
	done
	cd ${BASE}; \
	dpkg-scanpackages ${RELATIVE} > ${RELATIVE}/Packages

PACKAGE=product/fedora/27/x86_64/cyberprobe-${VERSION}-1.fc27.x86_64.rpm

container:
	${DOCKER} build ${BUILD_ARGS} -t cyberprobe \
		--build-arg PKG=${PACKAGE} \
		-f Dockerfile.cyberprobe.deploy .
	${DOCKER} tag cyberprobe docker.io/cybermaggedon/cyberprobe:${VERSION}
	${DOCKER} tag cyberprobe docker.io/cybermaggedon/cyberprobe:latest
	${DOCKER} build ${BUILD_ARGS} -t cybermon \
		--build-arg PKG=${PACKAGE} \
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

# GPG key admin

delete-keys:
	gpg2 --list-keys --with-colons | grep fpr | awk -F: '{print $$10}' | \
	while read key; \
	do \
	  echo Delete $${key}; \
	  gpg2 --batch --yes --delete-secret-and-public-keys "$${key}"; \
	done

generate-key:
	gpg2 --yes --batch --passphrase '' \
		--quick-generate-key '${USERID}' rsa4096 sign never

