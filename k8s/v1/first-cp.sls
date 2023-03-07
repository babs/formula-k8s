{% from slspath ~ '/macros.jinja' import relfile, debsource with context %}
{% set version = salt['pillar.get']('k8s:version', '1.23.4-00') %}

include:
- {{ slsdotpath }}.control-plane

/etc/kubernetes/kubeadm/kubeadm-config.yaml:
  file.managed:
    - source: {{ relfile('kubeadm-config.yaml.jinja.v1beta3') }}
    - template: jinja
    - makedirs: True
    - user: root
    - group: root
    - mode: "0644"

/opt/k8s-tools/install-update-pkg.sh {{ version }}:
  cmd.run:
    - unless:
      - /opt/k8s-tools/install-update-pkg.sh {{ version }} --check-only

kubeadm init:
  cmd.run:
    - name: kubeadm init --config /etc/kubernetes/kubeadm/kubeadm-config.yaml {{ salt['pillar.get']('k8s:kubeadm:extraOptions', '') }}
    - unless: test -f /etc/kubernetes/manifests/kube-apiserver.yaml -a -f /etc/kubernetes/manifests/kube-controller-manager.yaml -a -f /etc/kubernetes/manifests/kube-scheduler.yaml
    - require:
      - file: /etc/kubernetes/kubeadm/kubeadm-config.yaml
      - file: /etc/kubernetes/manifests/kube-vip.yaml

{% if salt['pillar.get']("k8s:cni:provider", "kube-router") == "kube-router" %}
### enbale kube-router ###
/etc/kubernetes/addons/kube-router.yaml:
  file.managed:
    - source: {{ relfile('kube-router-kubeadm-all-features.yaml') }}
    - template: jinja
    - makedirs: True
    - mode: "0640"
    - user: root
    - group: root
    - require:
      - cmd: kubeadm init

install kube-router:
  cmd.run:
    - name: kubectl apply -f /etc/kubernetes/addons/kube-router.yaml
    - onchanges:
      - file: /etc/kubernetes/addons/kube-router.yaml
    - require:
      - cmd: kubeadm init
remove kube-proxy:
  cmd.run:
    - name: kubectl -n kube-system delete ds kube-proxy
    - require:
      - cmd: install kube-router
    - onlyif: kubectl -n kube-system describe ds kube-proxy
{% endif %}

helm_repository_are_up_to_date:
  helm.repo_updated: []

{% if salt['pillar.get']("k8s:cni:provider", "kube-router") == "cilium" %}
{%- set mainip = salt['pillar.get']('k8s:networking:vip', salt['pillar.get']('k8s:control-plane:0:ip')) %}

cilium_repo:
    helm.repo_managed:
      - present:
        - name: cilium
          url: https://helm.cilium.io/
      - unless:
        - helm repo list | grep -q cilium
      - onchanges_in:
        - helm: helm_repository_are_up_to_date

install cilium via helm:
  helm.release_present:
    - name: cilium
    - chart: cilium/cilium
    - namespace: kube-system
    - kvflags:
        version: {{ salt['pillar.get']('k8s:cni:version', '1.12.4') }}
    - set:
      - tunnel=disabled
      - ipam.mode=kubernetes
      - ipv4NativeRoutingCIDR={{ salt['pillar.get']('k8s:networking:podSubnet:v4') }}
{%- if salt['pillar.get']('k8s:networking:podSubnet:v6') %}
      - ipv6NativeRoutingCIDR={{ salt['pillar.get']('k8s:networking:podSubnet:v6') }}
      - ipv6.enabled=true
{%- endif %}
      - autoDirectNodeRoutes=true
      - hubble.relay.enabled=true
      - hubble.ui.enabled=true
      - hubble.peerService.clusterDomain={{ salt['pillar.get']('k8s:networking:dnsDomain') }}
      - kubeProxyReplacement=strict
      - loadBalancer.mode=dsr
      - loadBalancer.algorithm=maglev
      - k8sServiceHost={{ mainip }}
      - k8sServicePort=6443
    - require:
      - helm: cilium_repo
    - unless:
      - helm -n kube-system get manifest cilium >/dev/null 2>&1

{% endif %}

### install kubernetes-dashboard
{%- if  salt['pillar.get']('k8s:kube-dashboard:version', None) != None %}
install kubernetes-dashboard:
  cmd.run:
    - name: kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/{{ salt['pillar.get']('k8s:kube-dashboard:version') }}/aio/deploy/recommended.yaml
    - require:
      - cmd: kubeadm init
    - unless: kubectl -n kubernetes-dashboard get deployments kubernetes-dashboard
{%- endif %}


{%- for release, relinfos in salt['pillar.get']('k8s:helm', {}).items() %}
{%- set repodef = relinfos.get('repo') %}
{%- set reldef = relinfos.get('release') %}
helm repo {{ release }}:
    helm.repo_managed:
      - present:
        - name: {{ repodef.get('name') }}
          url: {{ repodef.get('url') }}
      - unless:
        - helm repo list | grep -q {{ repodef.get('name') }}
      - onchanges_in:
        - helm: helm_repository_are_up_to_date

helm release {{ release }}:
  helm.release_present:
    - name: {{ release }}
    - chart: {{ reldef.get('chart') }}
    - namespace: {{ reldef.get('namespace') }}
    - kvflags: {{ reldef.get('kvflags') | yaml }}
    - set: {{ reldef.get('set') | yaml }}
    - flags: {{ reldef.get('flags') | yaml }}
    - require:
      - helm: helm repo {{ release }}
    - unless:
      - helm -n {{ reldef.get('namespace') }} get manifest {{ release }} >/dev/null 2>&1

{%- endfor %}
