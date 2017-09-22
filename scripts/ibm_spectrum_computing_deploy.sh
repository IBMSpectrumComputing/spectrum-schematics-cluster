#!/bin/bash

declare -i ROUND=0
declare -i numbercomputes
DEBUG=1
LOG_FILE=/root/sym_deploy_log


###################COMMON SHELL FUNCTIONS#################
function LOG ()
{
	echo -e `date` "$1" >> "$LOG_FILE"
}

function help()
{
	echo "Usage: $0"
	exit
}

function os_config()
{
	LOG "configuring os ..."
	if [ -f /etc/redhat-release ]
	then
		LOG "\tyum -y install ed tree lsof psmisc nfs-utils net-tools"
		yum -y install ed tree lsof psmisc nfs-utils net-tools
	fi
}

function add_admin_user()
{
	user_id=`id $1 2>>/dev/null`
	if [ "$?" != "0" ]; then
		useradd -d /home/$1 -s /bin/bash $1 >/dev/null 2>&1
		ls /home/$1 > /dev/null
	else
		LOG "User $1 exists already."
	fi
}

function funcGetPrivateIp()
{
	## for distributions using ifconfig and eth0
	ifconfig eth0 | grep "inet " | awk '{print $2}' | sed -e 's/addr://'
}

function funcGetPublicIp()
{
	## for distributions using ifconfig and eth0
	ifconfig eth1 | grep "inet " | awk '{print $2}' | sed -e 's/addr://'
}

function funcGetPrivateMask()
{
	## for distributions using ifconfig and eth0
	ifconfig eth0 | grep "inet " | awk '{print $4}' | sed -e 's/Mask://'
}

function funcGetPublicMask()
{
	## for distributions using ifconfig and eth0
	ifconfig eth1 | grep "inet " | awk '{print $4}' | sed -e 's/Mask://'
}

function funcStartConfService()
{
	mkdir -p /export
	if [ "$useintranet" == "yes" ]
	then
		network=`ipcalc -n $localipaddress $localnetmask | sed -e 's/.*=//'`
		echo -e "/export\t\t${network}/${localnetmask}(rw,no_root_squash)" > /etc/exports
		systemctl start nfs
	fi
}

function funcConnectConfService()
{
	mkdir -p /export
	if [ "$useintranet" == 'yes' ]
	then
		while ! mount | grep export | grep -v grep
		do
			LOG "\tmounting /export ..."
			mount ${masteripaddress}:/export /export
			sleep 60
		done
		LOG "\tmounted /export ..."
	fi
}
####################FUNCTION PYTHON SCRIPTS##################
function create_udp_server()
{
	cat << ENDF > /tmp/udpserver.py
#!/usr/bin/env python

ETC_HOSTS = '/etc/hosts'
import re, socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(('0.0.0.0',9999))
while True:
	data, addr = s.recvfrom(1024)
	print('Received from %s:%s.' % addr)
	if re.match(r'^update', data, re.I):
		record = data.strip().split()[1:]
		if len(record) == 3 and re.match(r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}', record[0]):
			with open(ETC_HOSTS,'a') as f:
				f.write("%s\t%s\t%s\n" % (record[0],record[1],record[2]))
	s.sendto("done", addr)
ENDF
	chmod +x /tmp/udpserver.py
	nohup python /tmp/udpserver.py >> /tmp/udpserver.log 2>&1 &
}

function create_udp_client()
{
	cat << ENDF > /tmp/udpclient.py
#!/usr/bin/env python

import socket
import sys
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
for data in sys.argv:
	print(data)
	s.sendto(data,('${masteripaddress}',9999))
	print(s.recv(1024))
s.close()
ENDF
	chmod +x /tmp/udpclient.py
}

function get_user_metadata()
{
	cat << ENDF > /tmp/user_metadata.py
import subprocess
import json
output = subprocess.check_output("curl https://api.service.softlayer.com/rest/v3/SoftLayer_Resource_Metadata/UserMetadata.txt 2>/dev/null; echo test > /dev/null",shell=True)
user_metadata = json.loads(output)
print("export METADATA=\"METADATA\"")
for key in user_metadata.keys():
	print("%s=\"%s\"" % (key,user_metadata[key]))
ENDF
}

#####################SHELL FUNCTIONS RELATED#################
function update_profile_d()
{
	if [ -d /etc/profile.d ]
	then
		echo "[ -f /opt/ibm/spectrumcomputing/profile.platform ] && source /opt/ibm/spectrumcomputing/profile.platform" > /etc/profile.d/symphony.sh
		echo "[ -f /opt/ibm/spectrumcomputing/cshrc.platform ] && source /opt/ibm/spectrumcomputing/cshrc.platform" > /etc/profile.d/symphony.csh
	fi
}

function app_depend()
{
	LOG "handle symphony dependancy ..."
	if [ "${PRODUCT}" == "SYMPHONY" -o "${PRODUCT}" == "symphony" ]
	then
		LOG "\tyum -y install java-1.7.0-openjdk gcc gcc-c++ glibc.i686 httpd"
		yum -y install java-1.7.0-openjdk gcc gcc-c++ glibc.i686 httpd
	elif [ "${PRODUCT}" == "LSF" -o "${PRODUCT}" == "lsf" ]
	then
		LOG "...handle lsf dependancy"
	else
		LOG "...unknown application"
	fi
}

function download_packages()
{
	if [ "$MASTERHOSTNAMES" == "$MASTERHOST" ]
	then
		# we can get the package from anywhere applicable, then export through nfs://export, not implemented here yet
		if [ "${PRODUCT}" == "SYMPHONY" -o "$PRODUCT" == "symphony" ]
		then
			LOG "download symphony packages ..."
			mkdir -p /export/symphony/${VERSION}
			if [ "${VERSION}" == "latest" ]
			then
				ver_in_pkg=7.2.0.0
			else
				ver_in_pkg=${VERSION}
			fi
			if [ "$ROLE" == 'symhead' -o "${ROLE}" == 'lsfmaster' ]
			then
				LOG "\twget -nH -c --limit-rate=10m http://158.85.106.44/export/symphony/${VERSION}/sym-${ver_in_pkg}_x86_64.bin"
				cd /export/symphony/${VERSION} && wget -nH -c --limit-rate=10m http://158.85.106.44/export/symphony/${VERSION}/sym-${ver_in_pkg}_x86_64.bin
				touch /export/download_finished
			else
				if [ "$useintranet" == 'no' ]
				then
					if [ "${ROLE}" == "symcompute" ]
					then
						LOG "\twget -nH -c --limit-rate=10m http://158.85.106.44/export/symphony/${VERSION}/sym-${ver_in_pkg}_x86_64.bin"
						cd /export/symphony/${VERSION} && wget -nH -c --limit-rate=10m http://158.85.106.44/export/symphony/${VERSION}/sym-${ver_in_pkg}_x86_64.bin
						touch /export/download_finished
					elif [ "${ROLE}" == 'symde' ]
					then
						LOG "\twget -nH -c --limit-rate=10m http://158.85.106.44/export/symphony/${VERSION}/symde-${ver_in_pkg}_x86_64.bin"
						cd /export/symphony/${VERSION} && wget -nH -c --limit-rate=10m http://158.85.106.44/export/symphony/${VERSION}/symde-${ver_in_pkg}_x86_64.bin
						touch /export/download_finished
					else
						echo "no download"
					fi
				else
					if [ "${ROLE}" == 'symde' ]
					then
						LOG "\twget -nH -c --limit-rate=10m http://158.85.106.44/export/symphony/${VERSION}/symde-${ver_in_pkg}_x86_64.bin"
						cd /export/symphony/${VERSION} && wget -nH -c --limit-rate=10m http://158.85.106.44/export/symphony/${VERSION}/symde-${ver_in_pkg}_x86_64.bin
						touch /export/download_finished
					fi
				fi
			fi
		fi
	else
		echo "wont come here before failover implementation"
	fi
}

function generate_entitlement()
{
	if [ "$PRODUCT" == "SYMPHONY" -o "$PRODUCT" == "symphony" ]
	then
		if [ -n "$entitlement" ]
		then
			echo $entitlement | base64 -d > ${ENTITLEMENT_FILE}
			sed -i 's/\(sym_[a-z]*_edition .*\)/\n\1/' ${ENTITLEMENT_FILE}
			echo >> ${ENTITLEMENT_FILE}
		fi
	fi
}

function install_symphony()
{
	LOG "installing ${PRODUCT} version ${VERSION} ..."
	sed -i -e '/7869/d'  -e '/7870/d' -e '/7871/d' /etc/services
	echo "... trying to install symphony version $VERSION"
	if [ "${ROLE}" == "symde" ]
	then
		if [ "$VERSION" == "latest" -o "$VERSION" = "7.2.0.0" ]
		then
			LOG "\tsh /export/symphony/${VERSION}/symde-7.2.0.0_x86_64.bin --quiet"
			sh /export/symphony/${VERSION}/symde-7.2.0.0_x86_64.bin --quiet
		fi
	else
		if [ "${ROLE}" == "symcompute" ]
		then
			export EGOCOMPUTEHOST=Y
		fi
		if [ "$VERSION" == "latest" -o "$VERSION" = "7.2.0.0" ]
		then
			LOG "\tsh /export/symphony/${VERSION}/sym-7.2.0.0_x86_64.bin --quiet"
			sh /export/symphony/${VERSION}/sym-7.2.0.0_x86_64.bin --quiet
		elif [ "$VERSION" == "7.1.2" ]
		then
			LOG "\tsh /export/symphony/${VERSION}/sym-7.1.2.0_x86_64.bin --quiet"
			sh /export/symphony/${VERSION}/sym-7.1.2.0_x86_64.bin --quiet
		else
			LOG "\tfailed to install application"
			echo "... unimplimented version"
			echo "... failed to install application" >> /root/symphony_failed
		fi
	fi
}

function start_symphony()
{
	if [ "${ROLE}" == "symhead" -o "${ROLE}" == "symcompute" ]
	then
		LOG "\tstart symphony..."
		service ego start
	fi
}

function configure_symphony()
{
	SOURCE_PROFILE=/opt/ibm/spectrumcomputing/profile.platform
	## currently only single master
	if [ "$MASTERHOSTNAMES" == "$MASTERHOST" ]
	then
		# no failover
		if [ "${ROLE}" == "symhead" ]
		then
			LOG "configure symphony master ..."
			LOG "\tsu $CLUSTERADMIN -c \". ${SOURCE_PROFILE}; egoconfig join ${MASTERHOST} -f; egoconfig setentitlement ${ENTITLEMENT_FILE}\""
			su $CLUSTERADMIN -c ". ${SOURCE_PROFILE}; egoconfig join ${MASTERHOST} -f; egoconfig setentitlement ${ENTITLEMENT_FILE}"
			sed -i 's/AUTOMATIC/MANUAL/' /opt/ibm/spectrumcomputing/eservice/esc/conf/services/named.xml
			sed -i 's/AUTOMATIC/MANUAL/' /opt/ibm/spectrumcomputing/eservice/esc/conf/services/wsg.xml
			## disable compute role on head if there is compute nodes
			if [ ${numbercomputes} -gt 0 ]
			then
				sed -ibak "s/\(^${MASTERHOST} .*\)(linux)\(.*\)/\1(linux mg)\2/" /opt/ibm/spectrumcomputing/kernel/conf/ego.cluster.${clustername}
			fi
		elif [ "$ROLE" == "symcompute" ]
		then
			LOG "configure symphony compute node ..."
			LOG "\tsu $CLUSTERADMIN -c \". ${SOURCE_PROFILE}; egoconfig join ${MASTERHOST} -f\""
			su $CLUSTERADMIN -c ". ${SOURCE_PROFILE}; egoconfig join ${MASTERHOST} -f"
		elif [ "$ROLE" == "symde" ]
		then
			LOG "configure symphony de node ..."
			echo "to implement"
		else
			echo nothing to do
		fi
	fi
	if [ "${ROLE}" == "symhead" -o "${ROLE}" == "symcompute" ]
	then
		LOG "prepare to start symphony cluster ..."
		LOG "\tegosetrc.sh; egosetsudoers.sh"
		. ${SOURCE_PROFILE}
		egosetrc.sh
		egosetsudoers.sh
		sleep 2
	fi
}
##################END FUNCTIONS RELATED######################

######################MAIN PROCEDURE##########################

# configure OS, install basic utilities like wget curl mount .etc
os_config

# write /tmp/user_metadata.py script to get user_metadata
get_user_metadata

# source user_metadata as shell environment
eval `python /tmp/user_metadata.py`

# handle environment
[ -z "$product" ] && product=SYMPHONY
[ -z "$version" ] && version=latest
[ -z "$domain" ] && domain=domain.com
[ -z "$clustername" ] && clustername=symcluster
if [ -z "$role" ]
then
	if hostname | grep -qi master
	then
		role=symhead
	else
		role=symcompute
	fi
fi
if [ "$useintranet" == "0" ]
then
	useintranet=no
elif [ "$useintranet" == "1" ]
then
	useintranet=yes
else
	echo "no action"
fi

# create and/or start up upd server/client to update /etc/hosts and other messages
if [ "$role" == "symhead" ]
then
	create_udp_server
fi
create_udp_client

# get local intranet IP address and local hostname
if [ -z "$masterprivateipaddress" ]
then
	## on master node
	masterprivateipaddress=$(funcGetPrivateIp)
	masterpublicipaddress=$(funcGetPublicIp)
fi
masteripaddress=${masterprivateipaddress}
localipaddress=$(funcGetPrivateIp)
localnetmask=$(funcGetPrivateMask)
# if localipaddress is not in the same subnet as masterprivateipaddress, force using internet
if [ "${localipaddress%.*}" != "${masterprivateipaddress%.*}" ]
then
	useintranet=no
fi
if [ "$useintranet" == "no" ]
then
	masteripaddress=${masterpublicipaddress}
	localipaddress=$(funcGetPublicIp)
fi
localhostname=$(hostname -s)

#normalize variables
export PRODUCT=$product
export VERSION=$version
export ROLE=$role
export CLUSTERNAME=$clustername
export OVERWRITE_EGO_CONFIGURATION=Yes
export SIMPLIFIEDWEM=N
export ENTITLEMENT_FILE=/tmp/entitlement
if [ -z "$masterhostnames" ]
then
	funcStartConfService
	masterhostnames=${localhostname}
	echo -e "127.0.0.1\tlocalhost.localdomain\tlocalhost\n${localipaddress}\t${localhostname}.${domain}\t${localhostname}" > /etc/hosts
	export MASTERHOSTNAMES=$masterhostnames
	export MASTERHOST=`echo $MASTERHOSTNAMES | awk '{print $1}'`
else
	export MASTERHOSTNAMES=$masterhostnames
	export MASTERHOST=`echo $MASTERHOSTNAMES | awk '{print $1}'`
	if [ "${ROLE}" != "symde" ]
	then
		funcConnectConfService
	fi
	python /tmp/udpclient.py "update ${localipaddress} ${localhostname}.${domain} ${localhostname}"
	echo -e "127.0.0.1\tlocalhost.localdomain\tlocalhost\n${masteripaddress}\t${MASTERHOST}.${domain}\t${MASTERHOST}\n${localipaddress}\t${localhostname}.${domain}\t${localhostname}" > /etc/hosts
	ping -c2 -w2 ${MASTERHOST}
fi
export DERBY_DB_HOST=$MASTERHOST
if [ -z "$clusteradmin" ]
then
	if [ "$product" == "SYMPHONY" -o "$product" == "symphony" ]
	then
		clusteradmin=egoadmin
	elif [ "$product" == "LSF" -o "$product" == "lsf"  ]
	then
		clusteradmin=lsfadmin
	else
		clusteradmin=lsfadmin
	fi
fi
export CLUSTERADMIN=$clusteradmin

# create related user accounts
add_admin_user $CLUSTERADMIN

# handle application dependancy
app_depend

# download packages to /export
download_packages

if [ "${ROLE}" == "symhead" -o "${ROLE}" == "lsfmaster" ]
then
	generate_entitlement
else
	## wait untils /export/download_finished appears
	while [ ! -f /export/download_finished ]
	do
		LOG "\twaiting for package downloads ..."
		sleep 60
	done
	LOG "\tpackages downloaded ..."
fi
# generate entitlement file

# install symphony
SOURCE_PROFILE=/opt/ibm/spectrumcomputing/profile.platform
if [ "$PRODUCT" == "SYMPHONY" -o "$PRODUCT" == "symphony" ]
then
	install_symphony >> $LOG_FILE 2>&1
	configure_symphony >> $LOG_FILE 2>&1
	update_profile_d
	start_symphony >> $LOG_FILE 2>&1
	sleep 120 
	## watch 2 more rounds to make sure symhony service is running
	while [ $ROUND -lt 2 ]
	do
		if [ "$ROLE" == "symde" ]
		then
			break
		fi
		if ! ps ax | egrep "opt.ibm.*lim" | grep -v grep > /dev/null
		then
			start_symphony
			sleep 120
			continue
		else
			sleep 60
		fi
		. ${SOURCE_PROFILE}
		egosh user logon -u Admin -x Admin
		ROUND=$((ROUND+1))
	done
	echo "$PRODUCT $VERSION $ROLE ready `date`" >> /root/application-ready
	LOG "symphony cluster is now ready ..."
	cat << ENDF > /tmp/post.sh
if [ "${ROLE}" == "symde" ]
then
	echo "post for DE host"
else
	if [ ! -f /etc/checkfailover ]
	then
		. ${SOURCE_PROFILE}
		egosh user logon -u Admin -x Admin
	fi
ENDF

# install LSF
elif [ "$PRODUCT" == "LSF" -o "$PRODUCT" == "lsf" ]
then
	echo installing spectrum computing LSF
else
	echo "unsupported product $PRODUCT `date`" >> /root/application-failed
fi

[ -x /tmp/post.sh ] || chmod +x /tmp/post.sh
[ -x /tmp/post.sh ] && /tmp/post.sh >> /tmp/output

echo "$0 execution ends at `date`" >> /tmp/output
## keep the script running in case symphony stop when shell terminates
while [ 1 -lt 2 ]
do
	sleep 3600
done
###################END OF MAIN PROCEDURE##################
