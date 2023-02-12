#!/bin/bash
for KEYTYPE in install join version; do
    OUTFILE="k8s_ssh_$KEYTYPE.sls"
    [ -e "$OUTFILE" ] && continue
    ssh-keygen -b 4096 -f k8s_$KEYTYPE -C k8s_$KEYTYPE -P ''
    python3 -c 'import yaml, sys
v = {"ssh":{"user":{"k8s_'$KEYTYPE'":{"pub":open("k8s_'$KEYTYPE'.pub","r").read(),"key":open("k8s_'$KEYTYPE'","r").read()}}}}
with open("'"$OUTFILE"'","w") as out:
   yaml.dump(v, stream=out, default_flow_style=False, width=6000)'
    rm k8s_${KEYTYPE}{,.pub}
done
