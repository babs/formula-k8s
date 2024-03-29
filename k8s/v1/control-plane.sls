{% from slspath ~ '/macros.jinja' import relfile with context %}

include:
- {{ slsdotpath }}.base
- {{ slsdotpath }}.helm

{% if salt['pillar.get']("k8s:networking:vip") and salt['pillar.get']("k8s:networking:vipProvider", "kube-vip") == "kube-vip" %}
/etc/kubernetes/manifests/kube-vip.yaml:
  file.managed:
    - source: {{ relfile('kube-vip.yaml.jinja') }}
    - template: jinja
    - makedirs: True
    - user: root
    - group: root
    - mode: "0644"
{% endif %}

/etc/kubernetes/kubeadm/kubeadm-config.yaml:
  file.managed:
    - source: {{ relfile('kubeadm-config.yaml.jinja.v1beta3') }}
    - template: jinja
    - makedirs: True
    - user: root
    - group: root
    - mode: "0644"

/root/.kube/config:
  file.symlink:
    - target: /etc/kubernetes/admin.conf
    - makedirs: True
    - user: root
    - group: root
    - mode: "0755"

/root/.ssh/k8s_install:
  file.managed:
    - user: root
    - group: root
    - mode: "0600"
    - contents_pillar: ssh:user:k8s_install:key

/root/.ssh/k8s_install.pub:
  file.managed:
    - user: root
    - group: root
    - mode: "0600"
    - contents_pillar: ssh:user:k8s_install:pub

/root/.ssh/authorized_keys k8s_install:
  file.append:
    - name: /root/.ssh/authorized_keys
    - text: {{ salt['pillar.get']("ssh:user:k8s_install:pub") }}

/root/.ssh/authorized_keys k8s_join:
  file.append:
    - name: /root/.ssh/authorized_keys
    - text: command="kubeadm token create --print-join-command | tr -d '\r\n'" {{ salt['pillar.get']("ssh:user:k8s_join:pub") }}

/root/.ssh/authorized_keys k8s_version:
  file.append:
    - name: /root/.ssh/authorized_keys
    - text: command="dpkg-query --showformat='${Version}' --show kubelet 2>/dev/null" {{ salt['pillar.get']("ssh:user:k8s_version:pub") }}

