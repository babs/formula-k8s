include:
- {{ slsdotpath }}.base

{%- set mainip = salt['pillar.get']('k8s:networking:vip', salt['pillar.get']('k8s:control-plane:0:ip')) %}

# Removed in case of vip move
#main ip in known_host:
#  ssh_known_hosts.present:
#    - name: {{mainip}}
#    - hash_known_hosts: false
#    - user: root

install kube binnaries according VIP version:
  cmd.run:
    - name: |
        echo Getting the version and installing k8s required binnaries
        PKG_VERSION=$(ssh -i /root/.ssh/k8s_version -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$MAINIP 2>/dev/null)
        /opt/k8s-tools/install-update-pkg.sh $PKG_VERSION
    - env:
      - MAINIP: {{ mainip }}
    - unless:
      - /opt/k8s-tools/install-update-pkg.sh $(ssh -i /root/.ssh/k8s_version -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$MAINIP  2>/dev/null) --check-only

join main server:
  cmd.run:
    - name: |
        echo Getting the token and joining the cluster
        JOIN_CMD=$(ssh -i /root/.ssh/k8s_join -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$MAINIP)
        $JOIN_CMD
    - env:
      - MAINIP: {{ mainip }}
    - unless: test -f /etc/kubernetes/kubelet.conf -a -f /etc/kubernetes/pki/ca.crt
    - require:
      - cmd: install kube binnaries according VIP version
