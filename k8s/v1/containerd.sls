
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
          && python3 -c 'import toml; v = toml.load("/etc/containerd/default.toml.tmp"); v["plugins"]["io.containerd.grpc.v1.cri"]["containerd"]["runtimes"]["runc"]["options"]["SystemdCgroup"] = True; v["root"] = "/srv/containerd/"; s = toml.dumps(v); print(s);' > /etc/containerd/config.toml && rm /etc/containerd/default.toml.tmp
    - unless:
      - python3 -c 'import toml, sys; v = toml.load("/etc/containerd/config.toml"); sys.exit(v["plugins"]["io.containerd.grpc.v1.cri"]["containerd"]["runtimes"]["runc"]["options"]["SystemdCgroup"] != True or v["root"] != "/srv/containerd/");'
    - watch_in:
      - service: containerd

/etc/crictl.yaml:
  file.managed:
    - contents: |
        runtime-endpoint: "unix:///run/containerd/containerd.sock"
        image-endpoint: ""
        timeout: 0
        debug: false
        pull-image-on-create: false
        disable-pull-on-run: false
