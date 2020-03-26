# PPC64 project tracker and bring-up  <!-- omit in toc -->

The objective of this repository is to track the progress and pre-requisites to allow new applications and projects on PPC64le architecture.

## Contents  <!-- omit in toc -->

* [Docker-ce](#docker-ce)

## Docker-ce

Until there is an official package,I've built the `.deb` package available in [releases](https://github.com/carlosedp/ppc64-bringup/releases/). All pre-requisites are already bundled in (containerd, runc, dockerd and docker-cli).

```sh
# Download the package
wget https://github.com/carlosedp/ppc64-bringup/releases/download/v1.0/docker-19.03.8_ppc64el.deb)

# Install
sudo apt install ./docker-master-dev_ppc64el.deb
```

* [ ] Add Debian packages for ppc64el


