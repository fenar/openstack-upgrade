#!/bin/bash -eu
# Trigger a managed upgrade.
# $ ./07-upgrade-openstack.sh <openstack-release-name>
#
RELEASE=$1
SERIES=${2:-'xenial'}
openstack_service_list=(openstack-dashboard keystone glance cinder neutron-api nova-cloud-controller neutron-gateway nova-compute)

get_units ()
{
cat << EOF| python -
import json, subprocess, re
from subprocess import check_output

data = subprocess.check_output(['juju', 'status', '--format=json'])
j = json.loads(data)
services = j['applications']
print '\n'.join(services["$1"]['units'].keys())
EOF
}

do_upgrade()
{
cat << EOF| python -
import json, subprocess, re
from subprocess import check_output

cmd = ['juju', 'run-action', "$1", 'openstack-upgrade']
out = check_output(cmd)
ret = re.search(r'Action queued with id: (.+)', out)
print ''.join(ret.group(1))
EOF
}

get_status()
{
cat << EOF| python -
import json, subprocess, re
from subprocess import check_output

cmd = ['juju', 'show-action-status', "$1"]
out = check_output(cmd)
ret = re.search(r'\s+status: (.+)', out, flags=re.MULTILINE)
if ret:
    status = ret.group(1)
else:
    status = "unknown"
print ''.join(status)
EOF
}

for service in ${openstack_service_list[@]}
do
    juju config $service action-managed-upgrade=True openstack-origin="cloud:$SERIES-$RELEASE"
    for unit in `get_units $service`
    do
        echo -e "\033[32mUpgrading unit \033[33m$unit\033[32m to \033[33mcloud:$SERIES-$RELEASE\033[0m"
	    action_id=$(do_upgrade $unit)
        echo -e "INFO-LOG:$(date): Upgrade Transaction-ID for $unit: $action_id"
        status=$(get_status $action_id)
        echo -e "INFO-LOG:$(date): Upgrade Status for $unit: $status"
        while [ "$status" != "completed" ]
        do
          sleep 5
          status=$(get_status $action_id)
          echo -e "INFO-LOG:$(date): Upgrade Status for $unit: $status"
        done
    done
done
