{% from './macros.jinja' import deploysshkeys, relfile, servicecmd, proxysource with context %}

include:
 - {{ slsdotpath }}.control-plane

{%- set mainip = salt['pillar.get']('k8s:networking:vip', salt['pillar.get']('k8s:control-plane:0:ip')) %}

# Removed in case of vip move
#main ip in known_host:
#  ssh_known_hosts.present:
#    - name: {{ mainip }}
#    - hash_known_hosts: false
#    - user: root

pki:
  cmd.run:
   - name: ssh -i /root/.ssh/k8s_install -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@{{ mainip }} tar -cf - -C /etc/kubernetes/ admin.conf pki/{front-proxy-ca,{etcd/c,c}a}.{crt,key} pki/sa.{key,pub} | tar -xvf - -C /etc/kubernetes
   - unless:
      - cd /etc/kubernetes; ls admin.conf pki/{front-proxy-ca,{etcd/c,c}a}.{crt,key} pki/sa.{key,pub} > /dev/null 2>&1
#   - require:
#     - ssh_known_hosts: main ip in known_host

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
       $JOIN_CMD --control-plane
   - env:
     - MAINIP: {{ mainip }}
   - require:
     - cmd: pki
     - cmd: install kube binnaries according VIP version
   - unless: test -f /etc/kubernetes/manifests/kube-apiserver.yaml -a -f /etc/kubernetes/manifests/kube-controller-manager.yaml -a -f /etc/kubernetes/manifests/kube-scheduler.yaml
