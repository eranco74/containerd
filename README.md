Note that this repo is just a proof-of-concept, for debugging / experimenting with containerd as container runtime on OpenShift clusters
This configuration isn't supported in any way!

OpenShift is currently tightly coupled with CRI-O. 
This repository produce machine config that will replace CRI-O with containerd as OpenShift container runtime on the worker nodes.

You can try it out by applying the 98-containerd-config to your cluster nodes
