
VERSION=1.7.4
GIT_VERSION=v1.7.4

UBUNTU_FILES = cyberprobe_${VERSION}-1_amd64.deb

# Add sudo if you need to
DOCKER=docker

# Allows the release process to read from a different directory i.e.
# this macro can be over-ridden by the caller.
PRODUCT_DIR=product

all: product ubuntu

product:
	mkdir product

ubuntu: dag-5.6.0-deb.tar.gz
	${DOCKER} build ${BUILD_ARGS} -t cyberprobe-ubuntu-dev \
		-f Dockerfile.ubuntu.dev .
	${DOCKER} build ${BUILD_ARGS} -t cyberprobe-ubuntu-build \
		--build-arg GIT_VERSION=${GIT_VERSION} \
		-f Dockerfile.ubuntu.build .
	id=$$(${DOCKER} run -d cyberprobe-ubuntu-build sleep 180); \
	dir=/usr/local/src/cyberprobe; \
	for file in ${UBUNTU_FILES}; do \
		bn=$$(basename $$file); \
		${DOCKER} cp $${id}:$${dir}/$${file} product/ubuntu-dag-$${bn}; \
	done; \
	${DOCKER} rm -f $${id}


go:
	GOPATH=$$(pwd)/go go get github.com/aktau/github-release

TOKEN_FILE=TOKEN

upload-release: go
	for file in ${PRODUCT_DIR}/*${VERSION}*; do \
	name=$$(basename $$file); \
	go/bin/github-release upload \
	  --user cybermaggedon \
	  --repo cyberprobe \
	  --tag v${VERSION} \
	  --name $$name \
	  --file $$file \
	  -s $$(cat ${TOKEN_FILE}); \
	done

