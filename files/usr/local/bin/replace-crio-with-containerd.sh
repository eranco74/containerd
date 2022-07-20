#!/usr/bin/env bash
set -euoE pipefail ## -E option will cause functions to inherit trap


if [ -f replace-crio-with-containerd.done ]; then
  echo "Nothing to do"
  exit 0
fi


if [ ! -f remove-crio.done ]; then
  echo "Removing crio"
  rpm-ostree override remove $(rpm -qa |grep cri-o)
  touch remove-crio.done
fi

if [ ! -f install-contaienrd.done ]; then
  echo "Downloading containerd"
  curl -O -J http://packages.eu-central-1.amazonaws.com/2018.03/updates/adeeb554baf5/x86_64/Packages/containerd-1.4.13-2.1.amzn1.x86_64.rpm

  echo "Installing containerd"
  rpm-ostree install containerd-1.4.13-2.1.amzn1.x86_64.rpm
  touch install-contaienrd.done
fi


#TODO: need to to this some other way
if [ ! -f configure-kubelet.done ]; then
  echo "Configure kubelet"
  sed -i s'/crio/containerd/'g /etc/systemd/system/kubelet.service
  touch configure-kubelet.done
fi

echo "Done replacing crio with containerd"
touch replace-crio-with-containerd.done

echo "Rebooting the node"
reboot
