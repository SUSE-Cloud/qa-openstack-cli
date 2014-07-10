#!/bin/bash

source functions

if [[ "$1" == "init" ]] ; then
	./tests/104_import_ssh_keypair
	./tests/105_add_security_rules
	./tests/106_allocate_floating_ip
	./tests/107_glance_import_image_jeos1

	tenantid=$(keystone `keystone_flags` tenant-list | grep openstack | awk '{print $2}')
	imgid=$(glance `glance_flags` image-list --name jeos1 --status active | grep jeos1 | awk '{print $2}')
	flavorid=$(nova `nova_flags` flavor-list | grep "m1.tiny" | awk '{print $2}')

	nova `nova_flags` quota-update --floating-ips 200 --instances 200 --cores 200 $tenantid
	neutron quota-update --port 200 --vip 200 --tenant-id $tenantid

	nova `nova_flags` boot --num-instances 60 --flavor $flavorid --image $imgid jeos_auto60 --key-name dashboard
elif [[ "$1" == "check" ]] ; then
	if [[ $(nova `nova_flags` list | grep ACTIVE | grep "fixed=44" | wc -l) == "60" ]] ; then
		echo -e "[ \e[1;32mok\e[00m ] All 60 instances got an ip"
	else
		echo -e "[\e[1;31mfail\e[00m] Not all instances got an ip"
		nova `nova_flags` list
		exit 1
	fi

	echo -e "\nChecking via ssh..."

	# free floating ip
	for ent in "$(nova `nova_flags` floating-ip-list | grep floating)" ; do
		if [[ `echo $ent | cut -d ' ' -f 4` != "-" ]] ; then
			nova `nova_flags` remove-floating-ip `echo $ent | cut -d ' ' -f 4` `echo $ent | cut -d ' ' -f 2`
		fi
	done
	floating_ip=$(nova `nova_flags` floating-ip-list | grep "^|[^|]*|[ -]*|" | head -1 | awk '{print $2}')

	failcounter=0
	for instid in `nova list | grep ACTIVE | grep "fixed=44" | cut -d ' ' -f 2` ; do
		nova `nova_flags` add-floating-ip $instid $floating_ip
		sleep 1
		if ssh root@$floating_ip \
			-o StrictHostKeyChecking=no \
			-o UserKnownHostsFile=/dev/null \
			-o ConnectTimeout=3 \
			-o PasswordAuthentication=no \
			-o Loglevel=error \
			-o BatchMode=yes echo >/dev/null ; then
			echo -e "[ \e[1;32mok\e[00m ] ssh to $instid"
		else
			echo -e "[\e[1;31mfail\e[00m] ssh to $instid"
			let failcounter+=1
		fi
		nova `nova_flags` remove-floating-ip $instid $floating_ip
	done
	echo
	if (( ! failcounter )) ; then
		echo -e "[ \e[1;32mok\e[00m ] ssh to all instances"
	else
		echo -e "[\e[1;31mfail\e[00m] could not ssh to $failcounter instances"
		exit 1
	fi
elif [[ "$1" == "cleanup" ]] ; then
	for instid in `nova list | grep jeos_auto60 | cut -d ' ' -f 2` ; do
		echo -n "Deleting $instid ... "
		nova `nova_flags` delete $instid
		echo "DONE"
	done
	./tests/991_cleanup_glance_image_jeos1
	./tests/994_cleanup_floating_ip
	./tests/995_cleanup_security_rules
	./tests/996_cleanup_ssh_keypair
else
	cat <<EOF
Scaling up with Neutron

This test starts 60 instances and tries to reach them using ssh

Usage:
$0 init
# wait until all 60 instances are ACTIVE
# and then wait one more minute for booting
$0 check
$0 cleanup
EOF

fi
