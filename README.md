# k8s-on-eoan

Bare-Metal Kubernetes on Ubuntu 19.10
---

__NOTICE__: _Steps 1 and 2_ of these scripts have not yet been re-tested from start to finish on a clean system. There might be a hiccup or two. Regardless, please please please read them before running them. It may be advisable to execute the .sh files one-by-one.

This repo may be used to configure an Ubuntu 19.10 server to run a single-node Kubernetes cluster, though those who aren't running Ubuntu 19.10 may still find some value in the various scripts within.

It was developed to k8s on a home network for development, testing, playing and maybe some public hosting in the early stages of a project.

There is a "primary" DNS zone associated with this configuration. The scare quotes around primary reflect that there is no fundamental setting, as such -– the k8s cluster's own domain is just the default cluster.local – but the primary zone is that for which we configure nginx-ingress, cert-manager, dex, etc, and off of which the various servers dangle, e.g. `https://keys.intranet.[primary zone];`, `https://auth.[primary zone]`.

Idiosyncracies:

* Amazon Route53 is used as the DNS host for the primary DNS zone, and as such, the cert-manager configuration involves some code which is specific to Route53. This step can be replaced with a script that works for your DNS provider.
* Github is used as an OAuth2 authentication mechanism (through Dex). This step can be replaced with a script that works for your (dex-supported) authentication provider.

There is nothing particularly magical about this configuration – it is the result of banging through what issues cropped up for the bare-metal Ubuntu 19.10 platform, and of reading, leveraging, combining and tweaking quite a few how-to recipes for the individual components. Links to such sources appear throughout, along with a few comments.

## What gets installed on the host

The following are installed and configured on the host:

* Kubernetes 1.17.1
* [dnsmasq](https://wiki.debian.org/dnsmasq)
* [golang 1.13.5](https://github.com/golang/go)
* [jq](https://stedolan.github.io/jq/) and [yq](https://github.com/kislyuk/yq)
* [CRI-O](https://github.com/cri-o/cri-o)
* [crun](https://github.com/containers/crun) and [runc](https://github.com/opencontainers/runc), configured as RuntimeClasses
* [fuse-overlayfs](https://github.com/containers/fuse-overlayfs)
* [cni plugins](https://github.com/containernetworking/plugins)
* [buildah](https://github.com/containers/buildah)
* [conmon](https://github.com/containers/conmon)
* [libpod & podman](https://github.com/containers/libpod) w/support for podman remote
* [skopeo](https://github.com/containers/skopeo)
* [crictl](https://github.com/kubernetes-sigs/cri-tools/blob/master/docs/crictl.md)
* [kustomize](https://github.com/kubernetes-sigs/kustomize)
* [helm](https://github.com/helm/helm)

## What gets installed in the k8s cluster

* [flannel](https://github.com/coreos/flannel) cni plugin
* [sealed-secrets](https://github.com/bitnami-labs/sealed-secrets)
* [MetalLB](https://metallb.universe.tf/)
* [storage/local-static-provisioner](https://github.com/kubernetes-sigs/sig-storage-local-static-provisioner)
* [nginx-ingress](https://kubernetes.github.io/ingress-nginx/)
* [cert-manager](https://cert-manager.io/) (configured for letsencrypt)
* [PostgreSQL](https://www.postgresql.org/)
* [PowerDNS](https://www.powerdns.com/)
* [external-dns](https://github.com/kubernetes-sigs/external-dns)
* [dex](https://github.com/dexidp/dex)
* [gangway](https://github.com/heptiolabs/gangway)
* [oauth2_proxy](https://github.com/pusher/oauth2_proxy)
* [kubernetes dashboard](https://github.com/kubernetes/dashboard) and [metrics-server](https://github.com/kubernetes-sigs/metrics-server)

The dashboard, which is exposed behind a singe-signon proxy configured to authenticate against Github via Dex, is the capstone of this configuration, It exercises all of the other installed k8s-hosted services.

## Instructions

### Prerequisites

* Install Ubuntu 19.10 on a machine with at least 8GB RAM, using GPT partition tables. I am using a Mac Mini 2014 :)
* Ensure var, tmp, home dirs have enough space (I gave root 20GB, var and tmp 10GB each and home has 100GB. The balance of the disk is lying fallow for persistent volume claims for apps)
* Ensure OpenSSH is installed (the Ubuntu installer will offer)
* apt install updates
* configure passwordless root ssh (if you want/need to run podman remote)

### Step 0 - Add values to secure-vars.sh / env-vars.sh

Edit `./secure-vars.sh` and `env-vars.sh`, providng values for all the variables.

### Step 1 – Host Configuration
```bash
./01-host-config.sh

sudo reboot now
```
### Step 2 –
```bash
# After reboot, ssh back into the server, if not at its terminal
# if the following reports "Cannot dig @127.0.0.1", then the situatino should be
# corrected before proceeding.
./02-local-dns-primary.sh
```
### Steps 3 & 4 – Platform Install/Config
```bash
./03-platform-install.sh
# Step 3 ends having just installed kubeadm, kubectl and kubelet
# Step 4 is a good place to pick up again if you've just run kubeadm reset for one reason or another...
./04-platform-config.sh
# At this point, we should have a running cluster, incl. all of the resources
# installed by kubeadm init, as well as flannel networking. The following should show
# all pods as Running.
kubectl get pods -A
```
### Step 5 – Kubernetes Configuration
```bash
./05-k8s-config.sh
```

## License

The individual software packages that these scripts install bear their own licenses. Please mind them. This repository is intended to jump-start using some or all of the services, it's not an application in itself.

The scripts, such as they are, are [WTFPL V2](https://en.wikipedia.org/wiki/WTFPL).

Aside from help files/issues in the various repositories for the components here installed, certain scripts were based on or informed by specific blog posts, which cases are noted in-line. The original authors would probably appreciate credit by passing through those references in derivative works.

## Contributing

This is my first foray into Kubernetes, and nobody has ever paid me to administer linux machines as my primary job function. I imagine there are things I could do better. I would very much welcome any advice/improvements in the form of issues or PRs! Questions are welcome, too!

At present, this repo is in a second-draft state, so expect it to go through at least one more revision in the near future.

In addition to running the scripts from zero to finish with no edits for sanity checking, I also intend to eliminate most of the cat'ing into yaml files, in preference for breaking out the yaml into its own files, to make it all easier to consume.
