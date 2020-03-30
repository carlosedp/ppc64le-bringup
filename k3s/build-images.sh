#!/bin/bash

REPO=carlosedp
TMPPATH=$HOME

##############
# Build Images
##############

mkdir $HOME/k3s-images
pushd $HOME/k3s-images

####
## klipper-helm
####

git clone https:////github.com/rancher/klipper-helm
pushd klipper-helm
KLIPPERVERSION=v0.2.3
#or
#KLIPPERVERSION=`git tag | tail -1` # build last tagged version

git checkout $KLIPPERVERSION

patch --ignore-whitespace << 'EOF'
diff --git a/package/Dockerfile b/package/Dockerfile
index 7cbf2cb..49030b4 100644
--- a/package/Dockerfile
+++ b/package/Dockerfile
@@ -1,6 +1,7 @@
 FROM alpine:3.8 as extract
 RUN apk add -U curl ca-certificates
-ARG ARCH
+ARG TARGETARCH
+ENV ARCH $TARGETARCH
 RUN curl https://storage.googleapis.com/kubernetes-helm/helm-v2.12.3-linux-${ARCH}.tar.gz | tar xvzf - --strip-components=1 -C /usr/bin
 RUN mv /usr/bin/helm /usr/bin/helm_v2
 RUN curl https://get.helm.sh/helm-v3.0.0-linux-${ARCH}.tar.gz | tar xvzf - --strip-components=1 -C /usr/bin
EOF

docker buildx build --platform linux/arm64,linux/arm,linux/amd64,linux/ppc64le -t $REPO/klipper-helm:$KLIPPERVERSION --push -f ./package/Dockerfile .
popd

####
## klipper-lb
####

git clone https:////github.com/rancher/klipper-lb
pushd klipper-lb
KLIPPERLBVERSION=v0.1.2

docker buildx build --platform linux/arm64,linux/arm,linux/amd64,linux/ppc64le -t $REPO/klipper-lb:$KLIPPERLBVERSION --push -f ./package/Dockerfile .

popd

####
## metrics-server
####

git clone https://github.com/kubernetes-sigs/metrics-server
pushd metrics-server
#MSVERSION=`git tag | tail -1` # build last tagged version
MSVERSION=v0.3.6

GIT_COMMIT=$(git rev-parse "HEAD^{commit}" 2>/dev/null)
GIT_VERSION_RAW=$(git describe --tags --abbrev=14 "$GIT_COMMIT^{commit}" 2>/dev/null)
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
for ARCH in amd64 arm64 arm ppc64le riscv64; do
    GOARCH=$ARCH GOOS=linux go build -ldflags '-w -X sigs.k8s.io/metrics-server/pkg/version.gitVersion=$GIT_VERSION_RAW -X sigs.k8s.io/metrics-server/pkg/version.gitCommit=$GIT_COMMIT -X sigs.k8s.io/metrics-server/pkg/version.buildDate=$BUILD_DATE' -o _output/$ARCH/metrics-server ./cmd/metrics-server;
done

cat > Dockerfile.simple <<EOF
FROM gcr.io/distroless/static:latest
ARG TARGETARCH

COPY _output/$TARGETARCH/metrics-server /metrics-server

ENTRYPOINT ["/metrics-server"]
EOF

docker buildx build --platform linux/arm64,linux/arm,linux/amd64,linux/ppc64le,linux/riscv64 -t $REPO/metrics-server:$MSVERSION --push -f Dockerfile.simple .
popd

####
## traefik 1.7
####

git clone https://github.com/containous/traefik.git
pushd trarfik
git checkout v1.7
#MSVERSION=`git tag | tail -1` # build last tagged version
TRAEFIKVERSION=v1.7

patch --ignore-whitespace << 'EOF'
diff --git a/.dockerignore b/.dockerignore
index a79fd48b..fef21bc4 100644
--- a/.dockerignore
+++ b/.dockerignore
@@ -1,3 +1,3 @@
 dist/
-!dist/traefik
+!dist/traefik*
 site/
diff --git a/Dockerfile b/Dockerfile
index 873d5531..73202ef7 100644
--- a/Dockerfile
+++ b/Dockerfile
@@ -1,6 +1,7 @@
 FROM scratch
+ARG TARGETARCH
 COPY script/ca-certificates.crt /etc/ssl/certs/
-COPY dist/traefik /
+COPY dist/traefik_linux-$TARGETARCH /traefik
 EXPOSE 80
 VOLUME ["/tmp"]
 ENTRYPOINT ["/traefik"]
diff --git a/script/crossbinary-default b/script/crossbinary-default
index c5e837db..176e0e8d 100755
--- a/script/crossbinary-default
+++ b/script/crossbinary-default
@@ -40,7 +40,7 @@ done
 
 # Build arm64 binaries
 OS_PLATFORM_ARG=(linux)
-OS_ARCH_ARG=(arm64)
+OS_ARCH_ARG=(arm64 arm ppc64le)
 for OS in ${OS_PLATFORM_ARG[@]}; do
   for ARCH in ${OS_ARCH_ARG[@]}; do
     echo "Building binary for ${OS}/${ARCH}..."
EOF

make crossbinary-default-parallel

docker buildx build --platform linux/arm64,linux/arm,linux/amd64,linux/ppc64le,linux/riscv64 -t $REPO/traefik:$TRAEFIKVERSION --push -f Dockerfile .
popd

####
## local-path-provisioner
####

git clone https:////github.com/rancher/local-path-provisioner
pushd local-path-provisioner
LPPVERSION=v0.2.3
git checkout $LPPVERSION

for ARCH in amd64 arm64 arm ppc64le riscv64;
do
    echo "Building local-path-provisioner version $LPPVERSION for $ARCH"
    CGO_ENABLED=0 GOOS=linux GOARCH=$ARCH go build -ldflags "-X main.VERSION=$LPPVERSION -extldflags -static -s -w" -o bin/local-path-provisioner-$ARCH;
done

cat > Dockerfile.simple <<EOF
FROM scratch
ARG TARGETARCH
COPY bin/local-path-provisioner-$TARGETARCH /usr/bin/local-path-provisioner
CMD ["local-path-provisioner"]
EOF

docker buildx build --platform linux/arm64,linux/arm,linux/amd64,linux/ppc64le,linux/riscv64 -t $REPO/local-path-provisioner:$LPPVERSION --push -f Dockerfile.simple .
popd

####
## pause
####

ARCHITECTURES=(amd64 arm64 arm ppc64le)
ORIGINIMAGE=k8s.gcr.io/pause
IMAGE=$REPO/pause
VERSION=3.1
for arch in amd64 arm64 arm ppc64le; do
    docker pull $ORIGINIMAGE-$arch:$VERSION
    docker tag $ORIGINIMAGE-$arch:$VERSION $IMAGE:$VERSION-$arch
    docker push $IMAGE:$VERSION-$arch
done
docker manifest create --amend $IMAGE:$VERSION `echo $ARCHITECTURES | sed -e "s~[^ ]*~$IMAGE:$VERSION\-&~g"`
for arch in $ARCHITECTURES; do docker manifest annotate --arch $arch $IMAGE:$VERSION $IMAGE:$VERSION-$arch; done
docker manifest push --purge $IMAGE:$VERSION

##############
# Finish
##############
popd


