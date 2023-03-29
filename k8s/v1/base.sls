{% from slspath ~ '/macros.jinja' import relfile, debsource with context %}

{% set version = salt['pillar.get']('k8s:version', '1.23.4-00') %}

include:
- {{ slsdotpath }}.containerd

swapoff:
  cmd.run:
    - name: swapoff -a
    - unless: test $(cat /proc/swaps | wc -l) -eq 1

  file.comment:
    - name: /etc/fstab
    - regex: "^[^#].* swap .*"
    - char: '#'
    - unless: test $(cat /proc/swaps | wc -l) -eq 1

/sys/fs/bpf:
  mount.mounted:
    - device: none
    - fstype: bpf
    - persist: True
    - opts:
      - defaults

module kernel:
  kmod.present:
    - mods:
      - br_netfilter
      - ip_vs_rr
      - ip_vs_wrr
      - ip_vs_sh
      - nf_conntrack
    - persist: True
    - require:
      - pkg: k8s pkg requirements

net.ipv4.ip_forward:
  sysctl.present:
    - value: 1

{{
  debsource(
    "kubernetes",
    "https://apt.kubernetes.io",
    "kubernetes-xenial",
    "main",
    "kubernetes-archive-keyring.gpg",
  )
}}

k8s pkg requirements:
  pkg.installed:
    - pkgs:
      - ipvsadm
      - jq
      - ceph-common

{%- if salt['pillar.get']('k8s:networking:podSubnet:v6') %}
net.ipv6.conf.all.forwarding:
  sysctl.present:
    - value: 1
{%- endif %}

k8s-tools:
  file.recurse:
    - source: {{ relfile("tools") }}
    - name: /opt/k8s-tools/
    - file_mode: "0755"
    - makedirs: true
    - clean: true
    - require:
      - pkgrepo: kubernetes repository

{% for keytype in ['join', 'version'] %}
/root/.ssh/k8s_{{ keytype }}:
  file.managed:
    - user: root
    - group: root
    - mode: "0600"
    - contents_pillar: ssh:user:k8s_{{ keytype }}:key
    - require_in:
      - file: k8s-tools

/root/.ssh/k8s_{{ keytype }}.pub:
  file.managed:
    - user: root
    - group: root
    - mode: "0600"
    - contents_pillar: ssh:user:k8s_{{ keytype }}:pub
    - require_in:
      - file: k8s-tools

{% endfor %}
