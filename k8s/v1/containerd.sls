
{% from slspath ~ '/macros.jinja' import debsource with context %}

{% set lower_distro = salt['grains.get']('os') | lower %}
{{
  debsource(
    "docker",
    "https://download.docker.com/linux/" ~ lower_distro,
    salt['grains.get']('oscodename'),
    "stable",
    "docker.gpg",
  )
}}

docker requirements:
  pkg.installed:
    - pkgs:
      - apt-transport-https
      - ca-certificates
      - curl
      - software-properties-common
      - gnupg2

containerd python-toml:
  pkg.installed:
    - pkgs:
      - python3-pip
  pip.installed:
    - name: toml
    - bin_env: '/usr/bin/pip3'

containerd:
  pkg.installed:
    - name: containerd.io
    - require:
      - pkgrepo: docker repository
  service.running:
    - enable: true
    - require:
      - pkg: containerd

/etc/containerd/config.toml:
  cmd.run:
    - name: |
          containerd config default > /etc/containerd/default.toml.tmp \
          && python3 -c 'import toml; v = toml.load("/etc/containerd/default.toml.tmp"); v["plugins"]["io.containerd.grpc.v1.cri"]["containerd"]["runtimes"]["runc"]["options"]["SystemdCgroup"] = True; v["root"] = "/srv/containerd/"; v["plugins"]["io.containerd.grpc.v1.cri"]["registry"]["config_path"] = "/etc/containerd/certs.d/";s = toml.dumps(v); print(s);' > /etc/containerd/config.toml && rm /etc/containerd/default.toml.tmp
    - unless:
      - python3 -c 'import toml, sys; v = toml.load("/etc/containerd/config.toml"); sys.exit(v["plugins"]["io.containerd.grpc.v1.cri"]["containerd"]["runtimes"]["runc"]["options"]["SystemdCgroup"] != True or v["root"] != "/srv/containerd/" or v["plugins"]["io.containerd.grpc.v1.cri"]["registry"]["config_path"] != "/etc/containerd/certs.d/");'
    - watch_in:
      - service: containerd

/etc/containerd/certs.d/:
  file.directory:
    - require:
      - service: containerd

{%- for mirror in salt['pillar.get']("containerd:oci mirrors", {}) %}

/etc/containerd/certs.d/{{ mirror }}/hosts.toml:
  file.managed:
    - contents_pillar: containerd:oci mirrors:{{ mirror }}:content
    - makedirs: true
    - watch_in:
      - service: containerd

{%- endfor %}

/etc/crictl.yaml:
  file.managed:
    - contents: |
        runtime-endpoint: "unix:///run/containerd/containerd.sock"
        image-endpoint: ""
        timeout: 0
        debug: false
        pull-image-on-create: false
        disable-pull-on-run: false
