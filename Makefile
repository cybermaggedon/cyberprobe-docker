
#############################################################################
# Input version numbers.  Can be over-riden by CI.
#############################################################################
VERSION=2.0.3
GIT_VERSION=v2.0.3

#############################################################################
# Global configuration
#############################################################################

# These files are part of the 'base' release, used only to extract
# source bundle, and source RPM.
BASE_VERSION=fc30
BASE_FILES =  RPM/RPMS/x86_64/cyberprobe-${VERSION}-1.${BASE_VERSION}.x86_64.rpm
BASE_FILES += RPM/RPMS/x86_64/cyberprobe-debuginfo-${VERSION}-1.${BASE_VERSION}.x86_64.rpm
BASE_FILES += cyberprobe-${VERSION}.tar.gz
BASE_FILES += RPM/SRPMS/cyberprobe-${VERSION}-1.${BASE_VERSION}.src.rpm

# Source bundle and RPM location.
SRC_RPM = product/base/cyberprobe-${VERSION}-1.${BASE_VERSION}.src.rpm
SRC = product/base/cyberprobe-${VERSION}.tar.gz

# Add sudo if you need to
DOCKER=docker

# Where container images are written
# this macro can be over-ridden by the caller.
IMAGE_DIR=images

# GPG user ID
USERID=Cyber MacGeddon <cybermaggedon@gmail.com>
KEYFILE=product/cyberprobe.asc


############################################################################
# Global rules
############################################################################

# Typically, call: make download-product all upload-product

# 'all' target builds everything.
all: ${KEYFILE} base \
	fedora debian ubuntu \
	container container-images

fedora: rpm.f28 rpm.f29 rpm.f30

debian: deb.debian-jessie deb.debian-stretch

ubuntu: deb.ubuntu-xenial deb.ubuntu-bionic deb.ubuntu-cosmic

upload: upload.rpm.f28 upload.rpm.f29 upload.rpm.f30 \
	upload.deb.debian-jessie \
	upload.deb.debian-stretch \
	upload.deb.ubuntu-xenial upload.deb.ubuntu-bionic \
	upload.deb.ubuntu-cosmic \
	container container-images create-release upload-release push

dag: ${KEYFILE} base deb.ubuntu-bionic-dag
dag.upload: ${KEYFILE} base upload.deb.ubuntu-bionic-dag

set-bucket-defacl:
	gsutil defacl ch -u AllUsers:R gs://download.trustnetworks.com

# Downloads the bucket.  This is called before we add things to it.
download-product:
	mkdir -p product
	gsutil rsync -r gs://download.trustnetworks.com/${SUBDIR} \
	  product/${SUBDIR}

# Uploads the bucket, makes it public, and puts 60s TTL cache age-off.
upload-product:
	gsutil rsync -r product/ gs://download.trustnetworks.com/
	-gsutil setmeta -r -h "Cache-Control:public, max-age=60" \
		'gs://download.trustnetworks.com/'

# Creates the public form of the signing key.
${KEYFILE}:
	mkdir -p product
	gpg2 --armor --export > $@

###########################################################################
# Base product - this is called to create the source bundle and source RPM
# which are used as input to all other builds.
###########################################################################

# Base is a Fedora 28 build which produces source tar, source RPM,
# and Fedora 28 RPMs for container builds.

# Base stuff is put in a base directory.
base: PRODUCT=product/base

# We use the 'build' model.  Two containers are created: a dev container
# is created with the right build tools in it.  If everything goes wrong,
# that gives developers a container to try things out manually to see what
# went wrong.  The build container is created with the build in it.  The
# build container can then be launched to extract the build products.
base:
	mkdir -p ${PRODUCT}
	${DOCKER} build ${BUILD_ARGS} -t cyberprobe-base-dev \
		-f Dockerfile.base.dev .
	${DOCKER} build ${BUILD_ARGS} -t cyberprobe-base-build \
		--build-arg GIT_VERSION=${GIT_VERSION} \
		-f Dockerfile.base.build .
	id=$$(${DOCKER} run -d cyberprobe-base-build sleep 180); \
	dir=/usr/local/src/cyberprobe; \
	for file in ${BASE_FILES}; do \
		bn=$$(basename $$file); \
		${DOCKER} cp $${id}:$${dir}/$${file} ${PRODUCT}/$${bn}; \
	done; \
	${DOCKER} rm -f $${id}


###########################################################################
# RPM creation.
###########################################################################

# Targets are:
#   rpm.f?? for Fedora.
#   rpm.centos7 for CentOS.

# Product paths.  This works for Fedora and CentOS.
ARCH=x86_64
rpm.%: OS=$(@:rpm.%=%)
rpm.f%: PRODUCT=product/fedora/$(@:rpm.f%=%)/${ARCH}
rpm.centos%: PRODUCT=product/centos/$(@:rpm.centos%=%)/${ARCH}

# We use the 'build' model.  Two containers are created: a dev container
# is created with the right build tools in it.  If everything goes wrong,
# that gives developers a container to try things out manually to see what
# went wrong.  The build container is created with the build in it.  The
# build container can then be launched to extract the build products.
# RPM files are signed using a GPG2 key, which must already exist.
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
	rm -rf ${PRODUCT}/repodata
	createrepo ${PRODUCT}

upload.rpm.f%: SUBDIR=fedora/$(@:upload.rpm.f%=%)/${ARCH}
upload.rpm.centos%: SUBDIR=centos/$(@:upload.rpm.centos%=%)/${ARCH}

upload.rpm.%:
	rm -rf product/${SUBDIR}
	mkdir -p product/${SUBDIR}
	make $(@:upload.%=%)
	gsutil rsync -d -r product/${SUBDIR} \
		"gs://download.trustnetworks.com/${SUBDIR}"
	-gsutil setmeta -r -h "Cache-Control:public, max-age=300" \
		"gs://download.trustnetworks.com/${SUBDIR}"

###########################################################################
# Deb package creation for Ubuntu and Debian.
###########################################################################

# Extracts operating system name.
deb.%: OS=$(@:deb.%=%)

# Relative pathname of package directory, inside repo.
deb.debian-%: RELATIVE=main/binary-amd64
deb.ubuntu-%: RELATIVE=main/binary-amd64

# Base repo name.
deb.debian-%: BASE=product/debian
deb.ubuntu-%: BASE=product/ubuntu

# Base repo name.
deb.debian-%: DIST=dists/$(@:deb.debian-%=%)
deb.ubuntu-%: DIST=dists/$(@:deb.ubuntu-%=%)

# Repo pathname
deb.debian-%: PRODUCT=${BASE}/${DIST}/${RELATIVE}
deb.ubuntu-%: PRODUCT=${BASE}/${DIST}/${RELATIVE}

# Relative pathname of package directory, inside repo.
deb.debian-%: DISTVSN=$(@:deb.debian-%=%)
deb.ubuntu-%: DISTVSN=$(@:deb.ubuntu-%=%)

# We use the 'build' model.  Two containers are created: a dev container
# is created with the right build tools in it.  If everything goes wrong,
# that gives developers a container to try things out manually to see what
# went wrong.  The build container is created with the build in it.  The
# build container can then be launched to extract the build products.
# This creates a signed package.
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
	dpkg-scanpackages ${DIST}/${RELATIVE} > ${DIST}/${RELATIVE}/Packages
	cd ${BASE}/${DIST}; \
	( \
	  echo Date: $$(date -u +'%a, %d %b %Y %T %Z'); \
	  echo Architectures: amd64; \
	  echo Suite: ${DISTVSN}; \
	  echo Codename: ${DISTVSN}; \
	  echo Origin: github.com/cybermaggedon/cyberprobe; \
	  echo Label: cyberprobe; \
	  echo Components: main; \
	  echo Acquire-By-Hash: no; \
	  echo Description: Cyberprobe package repository; \
	  md5=$$(md5sum main/binary-amd64/Packages | awk '{print $$1}'); \
	  sha256=$$(sha256sum main/binary-amd64/Packages | awk '{print $$1}'); \
	  sha1=$$(sha1sum main/binary-amd64/Packages | awk '{print $$1}'); \
	  sha512=$$(sha512sum main/binary-amd64/Packages | awk '{print $$1}'); \
	  file=main/binary-amd64/Packages; \
	  size=$$(stat -c%s main/binary-amd64/Packages); \
	  echo MD5Sum:; \
	  echo "  $${md5} $${size} $${file} "; \
	  echo SHA1:; \
	  echo "  $${sha1} $${size} $${file} "; \
	  echo 'SHA256:'; \
	  echo "  $${sha256} $${size} $${file} "; \
	  echo 'SHA512:'; \
	  echo "  $${sha512} $${size} $${file} "; \
	) > Release; \
	rm -f InRelease; \
	gpg2 -a -s --clearsign -u "${USERID}" -o InRelease Release; \
	rm -f Release

upload.deb.debian-%: SUBDIR=debian/dists/$(@:upload.deb.debian-%=%)/main/binary-amd64
upload.deb.ubuntu-%: SUBDIR=ubuntu/dists/$(@:upload.deb.ubuntu-%=%)/main/binary-amd64
upload.deb.debian-%: ROOTDIR=debian/dists/$(@:upload.deb.debian-%=%)/
upload.deb.ubuntu-%: ROOTDIR=ubuntu/dists/$(@:upload.deb.ubuntu-%=%)/

upload.deb.%:
	rm -rf product/${SUBDIR}
	mkdir -p product/${SUBDIR}
	make $(@:upload.%=%)
	gsutil rsync -d -r product/${ROOTDIR} \
		"gs://download.trustnetworks.com/${ROOTDIR}"
	-gsutil setmeta -r -h "Cache-Control:public, max-age=300" \
		"gs://download.trustnetworks.com/${ROOTDIR}"


###########################################################################
# Container creation
###########################################################################

# Pathname to the package to install in containers.
PACKAGE=product/fedora/30/x86_64/cyberprobe-${VERSION}-1.fc30.x86_64.rpm

# Creates the containers.
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

# Creates a Docker images tar file.
container-images: images/cyberprobe.img

images/cyberprobe.img: ALWAYS
	mkdir -p images
	${DOCKER} save -o $@ \
		docker.io/cybermaggedon/cyberprobe:${VERSION} \
		docker.io/cybermaggedon/cyberprobe:latest \
		docker.io/cybermaggedon/cybermon:${VERSION} \
		docker.io/cybermaggedon/cybermon:latest

ALWAYS:

# Pushes images to the container repository.  Docker hub authentication
# must have been set up.
load-images:
	${DOCKER} load -i ${IMAGE_DIR}/cyberprobe.img

push: push-images

push-images:
	${DOCKER} push docker.io/cybermaggedon/cyberprobe:${VERSION}
	${DOCKER} push docker.io/cybermaggedon/cybermon:${VERSION}
	${DOCKER} push docker.io/cybermaggedon/cyberprobe:latest
	${DOCKER} push docker.io/cybermaggedon/cybermon:latest


###########################################################################
# Github release
###########################################################################

# Fetches Github release utility.
go:
	GOPATH=$$(pwd)/go go get github.com/aktau/github-release

# Over-rideable location of the Github auth token file.
TOKEN_FILE=TOKEN

# Creates a Github release.  Must be used before upload-release.
create-release: go
	go/bin/github-release release \
	  --user cybermaggedon \
	  --repo cyberprobe \
	  --tag v${VERSION} \
	  --name "Version ${VERSION}" \
	  --description "" \
	  -s $$(cat ${TOKEN_FILE})

# Uploads 
upload-release: go
	for file in product/fedora/30/x86_64/*${VERSION}*.rpm; do \
	name=fedora-$$(basename $$file); \
	go/bin/github-release upload \
	  --user cybermaggedon \
	  --repo cyberprobe \
	  --tag v${VERSION} \
	  --name $$name \
	  --file $$file \
	  -s $$(cat ${TOKEN_FILE}); \
	done
	for file in product/debian/dists/jessie/main/binary-amd64/*${VERSION}*.deb; do \
	name=debian-$$(basename $$file); \
	go/bin/github-release upload \
	  --user cybermaggedon \
	  --repo cyberprobe \
	  --tag v${VERSION} \
	  --name $$name \
	  --file $$file \
	  -s $$(cat ${TOKEN_FILE}); \
	done
	for file in product/ubuntu/dists/bionic/main/binary-amd64/*${VERSION}*.deb; do \
	name=ubuntu-$$(basename $$file); \
	go/bin/github-release upload \
	  --user cybermaggedon \
	  --repo cyberprobe \
	  --tag v${VERSION} \
	  --name $$name \
	  --file $$file \
	  -s $$(cat ${TOKEN_FILE}); \
	done
	go/bin/github-release upload \
	  --user cybermaggedon \
	  --repo cyberprobe \
	  --tag v${VERSION} \
	  --name cyberprobe-${VERSION}-1.src.rpm \
	  --file product/base/cyberprobe-${VERSION}-1.fc30.src.rpm \
	  -s $$(cat ${TOKEN_FILE})
	go/bin/github-release upload \
	  --user cybermaggedon \
	  --repo cyberprobe \
	  --tag v${VERSION} \
	  --name cyberprobe-${VERSION}.tar.gz \
	  --file product/base/cyberprobe-${VERSION}.tar.gz \
	  -s $$(cat ${TOKEN_FILE})


###########################################################################
# GPG signing key management
###########################################################################

# Delete all GPG keys.
delete-keys:
	gpg2 --list-keys --with-colons | grep fpr | awk -F: '{print $$10}' | \
	while read key; \
	do \
	  echo Delete $${key}; \
	  gpg2 --batch --yes --delete-secret-and-public-keys "$${key}"; \
	done

# Create a new signing key.
generate-key:
	gpg2 --yes --batch --passphrase '' \
		--quick-generate-key '${USERID}' rsa4096 sign never

