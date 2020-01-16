# k8s-on-eoan

Bare-Metal Kubernetes on Ubuntu 19.10
---

__NOTICE__: These scripts have not yet been re-tested from start to finish on a clean system. There might be a hiccup or two. Regardless, please please please read them before running them.

This repo may be used to configure an Ubuntu 19.10 server to run a single-node Kubernetes cluster, though those who aren't running Ubuntu 19.10 may still find some value in the various scripts within.

It was developed to k8s on a home network for development, testing, playing and maybe some public hosting in the early stages of a project.

There is a "primary" DNS zone associated with this configuration. The scare quotes around primary reflect that there is no fundamental setting, as such -– the k8s cluster's own domain is just the default cluster.local – but the primary zone is that for which we configure nginx-ingress, cert-manager, dex, etc, and off of which the various servers dangle, e.g. https://gangway.\[primary zone\], https://login.\[primary zone\].

Idiosyncracies:

* Amazon Route53 is used as the DNS host for the primary DNS zone, and as such, the cert-manager configuration involves some code that is specific to Route53. This step can be replaced with a script that works for your DNS provider by ....(instructions here)....
* Github is used as the OAuth2 authentication mechanism (through Dex). This step can be replaced with a script that works for your (dex-supported) authentication provider by ...(instructions here)...

There is nothing particularly magical about this configuration – it is the result of banging through what issues cropped up for the bare-metal Ubutu 19.10 platform, and of reading, leveraging, combining and tweaking quite a few how-to recipes for the individual components. Links to such sources appear throughout, along with a few comments.

## What gets installed on the host

The following are installed and configured on the host:

* Kubernetes 1.17.0
* CRI-O
* crun and runc, configured as RuntimeClasses
* fuse-overlayfs
* cni plugins
* buildah
* conmon
* libpod & podman w/support for podman remote
* skopeo
* crictl
* kustomize
* dnsmasq
* golang 1.13.5

## What gets installed in the k8s cluster

* flannel cni plugin
* sealed-secrets
* MetalLB
* nginx-ingress
* cert-manager (configured for letsencrypt)
* dex
* gangway
* TBD pusher/oauth2_proxy
* TBD kubernetes dashboard and metrics-server

<!-- The dashboard, which is exposed behind a singe-signon proxy, is the capstone of this configuration, It exercises all of the other installed runtime components.
-->

## Instructions

### Prerequisites

* Install Ubuntu 19.10 on a machine with at least 8GB RAM. I am using a Mac Mini 2014 :)
* Ensure OpenSSH is installed (the installer will offer)
* Ensure var, tmp, home dirs have enough space (I gave var and tmp 10GB each and home has 100GB. The balance of the disk is lying fallow for persistent volume claims for apps)
* apt install updates
* configure passwordless root ssh (if and only if you want/need to run podman remote)

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
### Step 3 – Platform Installations
```bash
./03-platform-install.sh
# At this point, we should have a running cluster, incl. all of the resources
# installed by kubeadm, as well as flannel networking. The following should show
# all pods as Running.
kubectl get pods -A
```
### Step 4 – Kubernetes Configuration
```bash
./04-k8s-config.sh
```

## License

MIT.

Aside from help files/issues in the various repositories for the components here installed, certain scripts were based on or informed by specific blog posts, which cases are noted in-line. The original authors would probably appreciate credit by passing through those references in derivative works.

## Contributing

This is my first foray into Kubernetes, and nobody has ever paid me to administer linux machines as my primary job function. I imagine there are things I could do better. I would very much welcome any advice/improvements in the form of issues or PRs! Questions are welcome, too!

At present, this repo is in a first-draft state, so expect it to go through a revision in the near future.

In addition to running the scripts from zero to finish with no edits for sanity checking, I also intend to eliminate most of the cat'ing into yaml files, in preference for breaking out the yaml into its own files, to make it all easier to consume.
