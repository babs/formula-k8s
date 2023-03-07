{% from slspath ~ '/macros.jinja' import relfile with context %}

/usr/local/sbin/get_helm.sh:
  file.managed:
    - source: {{ relfile('get_helm.sh') }}
    - user: root
    - group: root
    - mode: "0755"

/usr/local/bin/helm:
  cmd.run:
    - name: /usr/local/sbin/get_helm.sh
    - unless:
      - test -f /usr/local/bin/helm
    - require:
      - file: /usr/local/sbin/get_helm.sh

helm completion bash:
  cmd.run:
    - name: helm completion bash > /etc/bash_completion.d/helm
    - require:
      - cmd: /usr/local/bin/helm
    - unless: test ! -d /etc/bash_completion.d -o -f /etc/bash_completion.d/helm
