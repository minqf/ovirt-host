#!/bin/bash -xe

LC_ALL=en_US.UTF-8 rpmlint ovirt-host.spec

./automation/build-artifacts.sh

DISTVER="$(rpm --eval "%dist"|cut -c2-4)"
PACKAGER=""
PACKAGER=dnf

find \
    "$PWD/tmp.repos" \
    -iname \*.rpm \
    -exec mv {} exported-artifacts/ \;
pushd exported-artifacts
    #Restoring sane yum environment
    rm -f /etc/yum.conf
    ${PACKAGER} reinstall -y system-release ${PACKAGER}
    [[ -d /etc/dnf ]] && [[ -x /usr/bin/dnf ]] && dnf -y reinstall dnf-conf
    [[ -d /etc/dnf ]] && sed -i -re 's#^(reposdir *= *).*$#\1/etc/yum.repos.d#' '/etc/dnf/dnf.conf'
    ${PACKAGER} install -y ovirt-release-master
    rm -f /etc/yum/yum.conf
    if [[ "${DISTVER}" == "el" ]]; then
        #Enable CR repo
        sed -i "s:enabled=0:enabled=1:" /etc/yum.repos.d/CentOS-CR.repo
    fi
    ${PACKAGER} repolist enabled
    ${PACKAGER} clean all
    if [[ "$(rpm --eval "%_arch")" == "s390x" ]]; then
        # s390x support is broken, just provide a hint on what's missing
        # without causing the test to fail.
        ${PACKAGER} --downloadonly install *$(arch).rpm || true
    else
        ${PACKAGER} --downloadonly install *$(arch).rpm
    fi
popd

