#!/usr/bin/env bash
set -euoE pipefail ## -E option will cause functions to inherit trap


if [ -f replace-crio-with-containerd.done ]; then
  echo "Nothing to do"
  exit 0
fi

function createContainerdServiceFile() {
  echo "Create containerd service file"
  tee /etc/systemd/system/containerd.service > /dev/null <<EOT
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/bin/containerd --config /etc/containerd/config.toml

Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=infinity
# Comment TasksMax if your systemd version does not supports it.
# Only systemd 226 and above support this version.
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOT
}

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


if [ ! -f configure-contaienrd.done ]; then
  echo "Configure containerd CNI plugin"
  tee /etc/containerd/config.toml > /dev/null <<EOT
[plugins]
  [plugins.cri.cni]
  bin_dir = "/var/lib/cni/bin"
  conf_dir = "/var/run/multus/cni/net.d/"
EOT

  createContainerdServiceFile
  echo "Enable containerd"
  systemctl enable containerd.service
  touch configure-contaienrd.done
fi



#TODO: Unsure this will work without reboot
echo "Start containerd"
systemctl start containerd.service

if [ ! -f fake-crio-sock-for-sdn.done ]; then
  echo "creating fake crio.sock for openshift-sdn"
  tee /etc/systemd/system/fake-crio-sock-for-sdn.service > /dev/null <<EOT
[Unit]
Description=Fake CRI-O socket for OpenShift SDN
Requires=containerd.service
After=containerd.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c "mkdir -p /var/run/crio && touch /var/run/crio/crio.sock && mount --bind /var/run/containerd/containerd.sock /var/run/crio/crio.sock"
EOT

  systemctl daemon-reload
  systemctl start fake-crio-sock-for-sdn.service
  touch fake-crio-sock-for-sdn.done
fi

if [ ! -f configure-crictl.done ]; then
  echo "Configure crictl to use containerd endpoint"
  tee /etc/crictl.yaml > /dev/null <<EOT
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
EOT
  touch configure-crictl.done
fi


if [ ! -f configure-kubelet.done ]; then
  echo "Configure kubelet"
  sed -i s'/--container-runtime-endpoint=\/var\/run\/crio\/crio.sock/--container-runtime-endpoint=\/var\/run\/containerd\/containerd.sock/'g /etc/systemd/system/kubelet.service
  sed -i s'/--runtime-cgroups=\/system.slice\/crio.service/--runtime-cgroups=\/system.slice\/containerd.service/'g /etc/systemd/system/kubelet.service
  systemctl daemon-reload
  systemctl restart kubelet
  touch configure-kubelet
fi

echo "Done replacing crio with containerd"
touch replace-crio-with-containerd.done

echo "Rebooting the node"
# reboot
