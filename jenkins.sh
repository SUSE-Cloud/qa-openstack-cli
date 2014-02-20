#!/bin/bash

zypper -n addrepo -G http://download.opensuse.org/repositories/devel:/tools:/scm/SLE_11_SP3/devel:tools:scm.repo
zypper -n addrepo -G http://download.opensuse.org/repositories/devel:/languages:/perl/SLE_11_SP3/devel:languages:perl.repo
zypper -n install git-core
grep -q LESS /etc/bash.bashrc || echo "export LESS='-R'" >> /etc/bash.bashrc ; source /etc/bash.bashrc
git config --global color.diff auto ; git config --global color.status auto ; git config --global color.branch auto

test -e qa-openstack-cli || git clone https://github.com/SUSE-Cloud/qa-openstack-cli.git
cd qa-openstack-cli
echo
./run.sh | perl -pe '$|=1;s/\e\[?.*?[\@-~]//g'
