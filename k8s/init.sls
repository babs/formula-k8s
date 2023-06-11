{%- set formula_name = "k8s" %}
{%- set include_path = slsdotpath ~ ".v" ~ salt['pillar.get'](formula_name ~ ':formula_version', "1") ~ sls[slspath|length:] %}
include:
  - {{ include_path }}

formula {{ include_path }}:
  test.nop:
    - require:
      - sls: {{ include_path }}
