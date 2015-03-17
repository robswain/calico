#!/bin/bash
[ -z $BASH ] && echo "You must run this script in bash" && exit 1
if [ "$LOGNAME" != "root" ]
then
  echo "You must run this script as root"
  exit 1
fi

echo "Collecting diags"
echo "This script attempts to collect a wide range of diagnostics, some of which may not be available on your system - don't worry if this script produces warning messages for these."

ROUTE_FILE=route
CALICO_CFG=/etc/calico
CALICO_DIR=/var/log/calico
NEUTRON_DIR=/var/log/neutron
NOVA_DIR=/var/log/nova
date=`date +"%F_%H-%M-%S"`
diags_dir=./"$date"
system=`hostname`
echo "  creating dir $diags_dir"
mkdir "$diags_dir" || exit 2
pushd "$diags_dir" > /dev/null || exit 2

echo "  storing system state..."

echo DATE=$date > date
echo $system > hostname

facter 2>&1 > facter
ps auwxx 2>&1 > ps
df -h > df

dpkg -l 2>&1 > dpkg
yum list 2>&1 > yum_list
yum repolist 2>&1 > yum_repolist

for cmd in "route -n" "ip route" "ip -6 route" "ip rule list"
do
  echo $cmd >> $ROUTE_FILE
  $cmd >> $ROUTE_FILE
  echo >> $ROUTE_FILE
done

ip link show > ip_link
ip addr show > ip_addr
netstat -an > netstat
iptables-save > iptables
ip6tables-save > ip6tables
ipset list > ipset
ip -6 neigh > ip6neigh
birdc show protocols 2>&1 > bird_protocols

service calico-felix status 2>&1 > felix_status
service calico-acl-manager status 2>&1 > acl_manager_status
service neutron-server status 2>&1 > neutron_server_status
service nova-compute status 2>&1 > nova_compute_status

echo "  copying config files..."

if [ -f /etc/bird.conf ]; then
    cp /etc/bird.conf bird.conf
    cp /etc/bird6.conf bird6.conf
else
    cp /etc/bird/bird.conf bird.conf
    cp /etc/bird/bird6.conf bird6.conf
fi

cp -a "$CALICO_CFG" etc_calico

# Use grep -v to attempt to strip out password information
grep -v -i "password" /etc/nova/nova.conf 2>&1 > nova.conf
grep -v -i "password" /etc/neutron/neutron.conf 2>&1 > neutron.conf
grep -v -i "password" /etc/neutron/plugins/ml2/ml2_conf.ini 2>&1 > ml2_conf.ini
grep -v -i "password" /etc/neutron/dhcp_agent.ini 2>&1 > dhcp_agent.ini
grep -v -i "password" /etc/neutron/metadata_agent.ini 2>&1 > metadata_agent.ini

echo "  copying log files..."

cp -a "$CALICO_DIR" .
cp -a "$NEUTRON_DIR" .
cp -a "$NOVA_DIR" .

mkdir logs
cp /var/log/syslog* logs 2>&1 >/dev/null
cp /var/log/messages* logs 2>&1 >/dev/null

echo "  compressing..."
cd ..
tar -Jcf "$diags_dir.tar.xz" "$date"

popd > /dev/null

echo "Diags saved to \"$diags_dir\" and compressed to \"$diags_dir.tar.xz\""
echo "Please run this script on all nodes involved in your issue (including any controllers)."
echo "We've tried to strip passwords from your nova and neutron configuration, but please review the diagnostics yourself before uploading."
echo "Once you've collected and reviewed the diagnostics, please raise a github issue detailing the symptoms you encountered, upload the diagnostics and link them from the issue."
echo "If you don't have anywhere to upload diagnostics to, you could use \`curl --upload-file $diags_dir.tar.xz https://transfer.sh/controller_diags.tar.xz\`."
