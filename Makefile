all: 98-containerd-config

.PHONY: 98-containerd-config
98-containerd-config:
	docker run --rm --interactive --volume "${PWD}"/files:/pwd --workdir /pwd  quay.io/coreos/butane:release --pretty --strict /pwd/config.bu --files-dir /pwd > 98-containerd-config