# openmf-phee

Open MF Payment Hub Enterprise Edition with Mojaloop for Apache Fineract

## Payment Hub EE x Mojaloop Package

## Introduction

Automated deployment process for adding Open MF Payment Hub EE, and Mojaloop to an existing Apache Fineract installation. The deployment is done onto a local Kubernetes cluster using minikubes (MicroK8s).

## Pre-requisites

- Developed and tested on Ubuntu 22.04.3 LTS
- 24GB of RAM
- 30GB+ free space in your home directory
- Kubernetes microK8s - 1.26 or up
- Docker Engine - Server Version: 20.10.24
- MariaDB 10 setup and running on port 3306
- Apache Fineract v1.9.0

## Quick Start

### Pre-requisites

1. Install docker using snap []()
2. Install MicroK8s using snap []()

### Fineract Installation

- Install fineract v1.9.0 or newer.
- Follow instructions at [Apache Fineract](https://github.com/apache/fineract)

### Install

- Clone the repository into a directory of your choice.
- Change the directory into the cloned repository.

```bash
git clone https://github.com/rheghnairoh/openmf-phee.git
```

```bash
cd openmf-phee
```

```bash
sudo ./installer.sh -m install -u $USER
```

> NOTE: This deployment is for demo purposes and not for production

> Only tested on local kubernetes cluster on microk8s. Work is being done to test it on remote kubernetes clusters

### Checking deployments using kubectl

kubectl get pods -n mojaloop #For testing mojaloop
kubectl get pods -n paymenthub #For testing paymenthub

### Uninstalling

Uninstall the deployment by running the command below

```bash
sudo ./installer.sh -m install -u $USER
```

## References

- Based on the work done by [Elijah Okello](https://github.com/elijah0kello) on the [mojafos project](https://github.com/elijah0kello/mojafos)
- [Open MF Payment Hub EE](https://openmf.github.io/)

```
Copyright © 2024 The Mifos Initiative
```
