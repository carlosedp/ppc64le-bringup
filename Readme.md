# PPC64/PPC64le project tracker and bring-up  <!-- omit in toc -->

The objective of this repository is to track the progress and pre-requisites to bring new applications and projects to PPC64 and PPC64le architecture. The bigger focus is on little-endian but big-endian could also be added.

If you want to start developing and run a PPC64le Virtual Machine, I've uploaded both Debian and Ubuntu versions that can be downloaded from the [releases](https://github.com/carlosedp/ppc64-bringup/releases/tag/v1.0) section.

There is also a [guide](https://github.com/carlosedp/ppc64-bringup/tree/master/QemuVM) if you want to build the VMs from scratch.

## Contents  <!-- omit in toc -->

* [Docker Community Edition](#docker-community-edition)
* [K3s - Lightweight Kubernetes](#k3s---lightweight-kubernetes)
* [Prometheus](#prometheus)
* [Grafana](#grafana)
* [Traefik Image](#traefik-image)
* [Drone-CI CLI](#drone-ci-cli)
* [Kubernetes Dashboard](#kubernetes-dashboard)
* [Minio](#minio)
* [Grafana Loki](#grafana-loki)
* [Aquasecurity Trivy](#aquasecurity-trivy)

---------------------------------------------------

## Docker Community Edition

Until there is an official package,I've built `.deb` and `.rpm` packages available in [releases](https://github.com/carlosedp/ppc64-bringup/releases/). All pre-requisites are already bundled in (containerd, runc, dockerd and docker-cli).

Unpack the `.tar.gz` file and install the packages with the distro tool (apt or yum).

* [ ] Add Debian packages for ppc64el to [docker-ce-packaging](https://github.com/docker/docker-ce-packaging) repo -
* [ ] Add ppc64le to containerd-packaging repo - [Issue#164](https://github.com/docker/containerd-packaging/issues/164)

---------------------------------------------------

## K3s - Lightweight Kubernetes

[K3s](https://k3s.io/) is a highly available, certified Kubernetes distribution designed for production workloads in unattended, resource-constrained, remote locations or inside IoT appliances.

K3s is packaged as a single <40MB binary that reduces the dependencies and steps needed to install, run and auto-update a production Kubernetes cluster.

Since K3s still does not provide `ppc64le` binaries or images, I've build the required pre-requisites and binaries to have a streamlined install on ppc64le architecture. Check the [guide here](k3s/Readme.md#installing) to install on your host.

The [guide](k3s/Readme.md#building-from-source) also provides the process to build images and k3s.

**Dependencies:**

* [x] Add arch to [k3s-root](https://github.com/rancher/k3s-root) - [PR#7](https://github.com/rancher/k3s-root/pull/7)
* [ ] Add ppc64le trivy scanner download on Dockerfile.dapper

**Required `ppc64le` images:**

* [x] `rancher/coredns-coredns:1.6.3`
* [ ] `rancher/klipper-helm:v0.3.0` - [PR#13](https://github.com/rancher/klipper-helm/pull/13)
* [ ] `rancher/klipper-lb:v0.1.2` - []()
* [ ] `rancher/library-traefik:1.7.19` - []()
* [ ] `rancher/local-path-provisioner:v0.0.14` - []()
* [ ] `rancher/library-busybox:1.31.1` - []()
* [ ] `rancher/pause:3.1` - []()

Replace images:

    scripts/airgap/image-list.txt
    vendor/github.com/rancher/helm-controller/pkg/helm/controller.go
    42:     DefaultJobImage = "rancher/klipper-helm:v0.3.0"
    pkg/servicelb/controller.go
    37:     image = "rancher/klipper-lb:v0.1.2"
    manifests/local-storage.yaml
    78:          value: rancher/library-busybox:1.31.1
    manifests/traefik.yaml
    19:    image: "rancher/library-traefik"
    manifests/local-storage.yaml
    62:        image: rancher/local-path-provisioner:v0.0.14
    manifests/metrics-server/metrics-server-deployment.yaml
    38:        image: rancher/metrics-server:v0.3.6
    pkg/cli/cmds/agent.go
    92:             Value:       "docker.io/rancher/pause:3.1",

**Temporary Images:**

All these images are multi-arch for `amd64`, `arm`, `arm64` and `ppc64le`.

* [`carlosedp/pause:3.1`](https://hub.docker.com/r/carlosedp/pause)
* [`carlosedp/local-path-provisioner:v0.0.14`](https://hub.docker.com/r/carlosedp/local-path-provisioner)
* [`carlosedp/klipper-helm:v0.3.0`](https://hub.docker.com/r/carlosedp/klipper-helm)
* [`carlosedp/klipper-lb:v0.1.2`](https://hub.docker.com/r/carlosedp/klipper-lb)
* [`carlosedp/traefik:v1.7`](https://hub.docker.com/r/carlosedp/traefik)
* [`carlosedp/metrics-server:v0.3.6`](https://hub.docker.com/r/carlosedp/metrics-server)
* [`coredns/coredns:1.6.9`](https://hub.docker.com/r/coredns/coredns:1.6.9)

---------------------------------------------------

## Prometheus

Add `ppc64le` images to CI:

* [x] `prometheus` - [PR#7067](https://github.com/prometheus/prometheus/pull/7067)
* [x] `alertmanager` - [PR#2219](https://github.com/prometheus/alertmanager/pull/2219)
* [x] `node-exporter` - Already supports `ppc64le`
* [x] `snmp-exporter` - [PR#494](https://github.com/prometheus/snmp_exporter/pull/494)
* [x] `blackbox-exporter` - [PR#587](https://github.com/prometheus/blackbox_exporter/pull/587)
* [x] `pushgateway` - [PR#339](https://github.com/prometheus/pushgateway/pull/339)

---------------------------------------------------

## Grafana

* [ ] ~~grafana/grafana - [PR#23177](https://github.com/grafana/grafana/pull/23177)~~ - Cancelled

---------------------------------------------------

## Traefik Image

* [ ] traefik v1.7 - [PR#]()

---------------------------------------------------

## Drone-CI CLI

Command Line Tools for Drone CI. <https://github.com/drone/drone-cli>

* [x] Add binaries for ppc64le - [PR#170](https://github.com/drone/drone-cli/pull/170)

---------------------------------------------------

## Kubernetes Dashboard

The new Kubernetes dashboard is composed of the Dashboard front-end and the [metrics-scraper](https://github.com/kubernetes-sigs/dashboard-metrics-scraper). The Dashboard is already built for ppc64le but the scraper needs build support.

* [x] Add build support for ppc64le - [PR#29](https://github.com/kubernetes-sigs/dashboard-metrics-scraper/pull/29)

---------------------------------------------------

## Minio

Minio is a high-performance object storage.

The multiarch images for Minio and Minio client can be pulled from my DockerHub repo:

* [`carlosedp/minio:latest`](https://hub.docker.com/r/carlosedp/minio)
* [`carlosedp/minio-mc:latest`](https://hub.docker.com/r/carlosedp/minio-mc)

* [x] Add multiarch images - [Issue#9546](https://github.com/minio/minio/issues/9546)

---------------------------------------------------

## Grafana Loki

Loki is like Prometheus, but for logs.

* [x] Add support for building binaries for ppc64le arch [PR#2813](https://github.com/grafana/loki/pull/2813#issuecomment-716773195)

---------------------------------------------------

## Aquasecurity Trivy

Container vulnerability scanner

* [x] Add support to trivy <https://github.com/aquasecurity/trivy> [PR#724](https://github.com/aquasecurity/trivy/pull/724)
