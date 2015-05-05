#
# Cookbook Name:: mesos-master-node
# Recipe:: default
#
# Copyright 2015, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

# sudo knife cookbook upload mesos-master-node
# knife bootstrap 10.0.3.100 -j '{"ipaddr":"10.0.3.100", "zk_id":1}' -x vagrant -P vagrant -r 'recipe[mesos-master-node]' --sudo

include_recipe 'apt'

#####
# Configures a node as mesos-master. Installs Zookeeper, mesos-master and marathon. mesos-slave is diasabled.
# Params
#  masterip - IP address of this node
#  zk - Zookeeper URL
#  zkid - Zookeeper id
#####

cluster_name = 'beehive'
chef_ip = '192.168.33.11'
zk = 'zk://10.0.3.100:2181,10.0.3.101:2181,10.0.3.102:2181/mesos'
master_ip = node['masterip']
zk_id = node['zkid']

apt_repository 'mesosphere' do
  uri "http://repos.mesosphere.io/#{node['platform']}"
  distribution node['lsb']['codename']
  keyserver 'keyserver.ubuntu.com'
  key 'E56151BF'
  components ['main']
end

execute "apt-get-update" do
	command "apt-get -y update;apt-get -y upgrade"
end

execute "install-mesos" do
	command "apt-get --yes --force-yes install mesos marathon"
end

execute "disable-slave" do
	command "echo manual > /etc/init/mesos-slave.override"
end

bash 'create_zk_info' do
	code <<-EOF
		echo "#{zk}" > /etc/mesos/zk
      		echo 'ZK=\`cat /etc/mesos/zk\`\nIP=#{master_ip}\nPORT=5050' > /etc/default/mesos-master
		echo "#{zk_id}" > /etc/zookeeper/conf/myid
EOF
	returns [0,2]
end

# Assuming three mesos master setup
bash 'set_mesos_quorum' do
	code <<-EOF
	echo 2 > /etc/mesos-master/quorum
EOF
end

bash 'configure_service' do
	code <<-EOF
		update-rc.d mesos-master defaults
		update-rc.d marathon defaults
		service mesos-master restart
EOF

end




