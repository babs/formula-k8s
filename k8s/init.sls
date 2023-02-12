
include:
 - {{ slsdotpath }}.v{{ salt['pillar.get']('k8s:formula_version', "1") }}{{ sls[slspath|length:] }}
