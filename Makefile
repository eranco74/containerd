all: 98-containerd-config

.PHONY: 98-containerd-config
98-containerd-config:
	docker run --rm --interactive --volume "${PWD}"/files:/pwd --workdir /pwd  quay.io/coreos/butane:release --pretty --strict /pwd/config.bu --files-dir /pwd > 98-containerd-config

update_kubelet_service:
	KUBELET_CONF=$(kubectl get mc 01-worker-kubelet -ojson | jq '.spec.config.systemd.units[] | select(.name == "kubelet.service") | .contents')
 	UPDATED_KUBELET_CONF=$(echo $KUBELET_CONF | sed s'/crio/containerd/'g)
	yq '. | .systemd.units += {"name": "containerd.service", "enabled": true, "contents": "$(UPDATED_KUBELET_CONF)"}' files/config.bu