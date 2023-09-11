#!/bin/bash

[ "${#@}" -lt 1 ] && echo "$0 package_version --check-only"

DESIRED_VERSION="$1"
shift

if ! echo "$DESIRED_VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+-[0-9\.]+$'; then
    echo "Pkg version format error x.yy.zz-aa or x.yy.zz-a.b expected"
    exit 1
fi

PKGS=(kubelet kubeadm kubectl)
declare -a UPGRADE DOWNGRADE CORRECT MISSING

for PKG in ${PKGS[@]}; do
    PVER=$(dpkg-query --showformat='${Version}' --show $PKG 2>/dev/null)
    [ -z "$PVER" ] && UPGRADE+=($PKG) && continue
    [ "$PVER" = "$DESIRED_VERSION" ] && CORRECT+=($PKG) && continue
    dpkg --compare-versions $PVER lt $DESIRED_VERSION && UPGRADE+=($PKG) || DOWNGRADE+=($PKG)
done

[ ${#DOWNGRADE[@]} -gt 0 ] && echo "Downgrade detected won't perform, exit." && exit 0

[ ${#UPGRADE[@]} -eq 0 ] && echo "No upgrade required." && exit 0

[ "$1" = "--check-only" ] && echo "Update needed" && exit 1

IFS=. SPLITTED_VERSION=(${DESIRED_VERSION})
unset IFS
TGT_MINOR=${SPLITTED_VERSION[0]}.${SPLITTED_VERSION[1]}
REPO_FILE=/etc/apt/sources.list.d/kubernetes-v${TGT_MINOR}.list
[ ! -e "$REPO_FILE" ] && echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${TGT_MINOR}/deb/ / " > "$REPO_FILE"

echo " *** Upgrade to $DESIRED_VERSION *** "
echo " * update..."
apt-get update -qq || { echo "apt update failed with code: $?"; exit 1; }
echo " * install..."
apt-get install -y -q --allow-change-held-packages $(for PKG in ${UPGRADE[@]}; do echo -ne " $PKG=$DESIRED_VERSION"; done) >/dev/null
RES=$?
echo " * hold..."
apt-mark hold ${PKGS[@]} >/dev/null
echo " * generate completion..."
for FOLDER in /etc/bash_completion.d /usr/share/bash-completion/completions; do
  [ -d $FOLDER ] && kubectl completion bash > $FOLDER/kube && break
done

echo " *** done *** "
[ $RES -ne 0 ] && echo "install failed with exit code: $RES"
exit $RES
