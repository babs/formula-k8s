{%- set ns = namespace() %}
{%- set ns.node_recipe = None %}

{%- for controlplane in salt['pillar.get']('k8s:control-plane') %}
{%-   if controlplane.name == salt['grains.get']('host') %}
{%-     if loop.index0 == 0 %}
{%-       set ns.node_recipe = 'first-cp' %}
{%-     else %}
{%-       set ns.node_recipe = 'following-cp' %}
{%-     endif %}
{%-   endif %}
{%- endfor %}
{%- if salt['grains.get']('host') in salt['pillar.get']('k8s:worker') or salt['grains.get']('host') is match(salt['pillar.get']('k8s:worker pattern', '===')) %}
{%-   set ns.node_recipe = 'worker' %}
{%- endif %}

{%- if ns.node_recipe %}
include:
  - {{ slsdotpath }}.base
  - {{ slsdotpath }}.{{ ns.node_recipe }}
{%-   else %}
"=== Configuration Error: k8s invoked without node referenced in pillar ===":
  test.fail_without_changes:
    - order: last
{%-   endif %}

formula k8s.v1.init:
  test.nop: []