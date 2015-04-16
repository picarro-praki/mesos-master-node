#
# Cookbook Name:: mesos-master-node
# Recipe:: default
#
# Copyright 2015, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'apt'

#####
# Params
#####
cluster_name = 'beehive2'
chef_ip = '192.168.33.11'
master_ip = '10.0.3.100'

apt_repository 'mesosphere' do
  uri "http://repos.mesosphere.io/#{node['platform']}"
  distribution node['lsb']['codename']
  keyserver 'keyserver.ubuntu.com'
  key 'E56151BF'
  components ['main']
end

execute "apt-get-update" do
	command "apt-get -y update"
	command "apt-get -y upgrade"
end

bash "hosts" do
	code <<-EOF 
cat > /etc/hosts <<-EOF2
127.0.0.1 localhost
#{chef_ip} chef.picarro.com
#{master_ip} mm1

# The following lines are desirable for IPv6 capable hosts
::1 ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
EOF2
EOF
end

execute "install-mesos" do
	command "apt-get --yes --force-yes install mesos marathon"
end

execute "disable-slave" do
	command "echo manual > /etc/init/mesos-slave.override"
end

bash 'create_zk_info' do
	code <<-EOF
		echo "zk://#{master_ip}:2181/mesos" > /etc/mesos/zk
      		echo "MASTER=`cat /etc/mesos/zk`\nIP=#{master_ip}\nPORT=5050" > /etc/default/mesos-master
		echo "1" > /etc/zookeeper/conf/myid
`
EOF
	returns [0,2]
end

bash 'configure_service' do
	code <<-EOF
		update-rc.d mesos-master defaults
		update-rc.d marathon defaults
		service mesos-master restart
EOF

end

u = user 'hduser' do
	home "/home/hduser"
  	shell "/bin/bash"
	action :create
	manage_home true
end
u.run_action(:create)

group 'hadoop' do
	action :create
	members "hduser"
end


bash 'setup_password_less_ssh_login' do
	user 'hduser'
	cwd Dir.home('hduser')
	code <<-EOF
      		mkdir -p ~hduser/.ssh
      		rm -f ~hduser/.ssh/id_rsa
      		ssh-keygen -f ~hduser/.ssh/id_rsa -t rsa -P ""
      		cat .ssh/id_rsa.pub >> .ssh/authorized_keys
EOF
end


bash 'install_hadoop' do
	code <<-EOF
      		# Install hadoop 
		master_ip=#{master_ip}
      		wget http://archive.cloudera.com/cdh4/one-click-install/precise/amd64/cdh4-repository_1.0_all.deb
      		dpkg -i cdh4-repository_1.0_all.deb
      		curl -s http://archive.cloudera.com/cdh4/ubuntu/precise/amd64/cdh/archive.key | apt-key add -
		apt-get update
      		apt-get --yes --force-yes install hadoop-0.20-mapreduce-jobtracker hadoop-hdfs-namenode
      		cp -r /etc/hadoop/conf/. /etc/hadoop/#{cluster_name}.conf
      		update-alternatives --install /etc/hadoop/conf hadoop-conf /etc/hadoop/#{cluster_name}.conf 50
      		update-alternatives --set hadoop-conf /etc/hadoop/#{cluster_name}.conf

      		# Write core-site.xml
      		cat > /etc/hadoop/#{cluster_name}.conf/core-site.xml <<EOF2
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  	<property>
    		<name>fs.default.name</name>
    		<value>hdfs://${master_ip}:9000</value>
  	</property>
  	<property>
    		<name>hadoop.http.staticuser.user</name>
    		<value>hdfs</value>
  	</property>
</configuration>
EOF2

	cat  > /etc/hadoop/#{cluster_name}.conf/hdfs-site.xml <<-EOF2
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
    <name>dfs.replication</name>
     <value>1</value>
   </property>
   <property>
     <name>dfs.namenode.name.dir</name>
     <value>/var/data/hadoop/hdfs/nn</value>
   </property>
   <property>
     <name>fs.checkpoint.dir</name>
     <value>/var/data/hadoop/hdfs/snn</value>
   </property>
   <property>
     <name>fs.checkpoint.edits.dir</name>
     <value>/var/data/hadoop/hdfs/snn</value>
   </property>
   <property>
     <name>dfs.datanode.data.dir</name>
     <value>/var/data/hadoop/hdfs/dn</value>
   </property>
</configuration>
EOF2
EOF
end

execute "hdfs_root" do
	command "mkdir -p /var/data/hadoop/hdfs"
	command "chown -R hdfs:hdfs /var/data/hadoop/hdfs"
	command "chown -R hdfs:hdfs /var/log/hadoop-hdfs"
end

%w{/var/data/hadoop/hdfs/nn /var/data/hadoop/hdfs/snn /var/data/hadoop/hdfs/dn}.each do |path|
	execute "crt_dir_set_mode" do
		command "mkdir -p #{path}; chown -R hdfs:hdfs #{path}; chmod 0700 #{path}"
	end
end

execute "format_name_node" do
	user "hdfs"
      	command "hadoop namenode -format -force"
end

service "hadoop-hdfs-namenode" do
	action :restart
end




