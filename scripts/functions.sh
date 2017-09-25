#!/bin/bash

###################COMMON SHELL FUNCTIONS#################

function help()
{
	echo "Usage: $0"
	exit
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
	if [ "$useintranet" == "true" ]
	then
		network=`ipcalc -n $localipaddress $localnetmask | sed -e 's/.*=//'`
		echo -e "/export\t\t${network}/${localnetmask}(ro,no_root_squash)" > /etc/exports
		systemctl start nfs
	fi
}

function funcConnectConfService()
{
	mkdir -p /export
	if [ "$useintranet" == 'true' ]
	then
		while ! mount | grep export | grep -v grep
		do
			LOG "\tmounting /export ..."
			mount -o tcp,vers=3,rsize=32768,wsize=32768 ${masteripaddress}:/export /export
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

#####################SHELL FUNCTIONS RELATED#################
function update_profile_d()
{
	if [ -d /etc/profile.d ]
	then
		if [ "${ROLE}" == "symhead" -o "${ROLE}" == 'symcompute' ]
		then
			echo "[ -f /opt/ibm/spectrumcomputing/profile.platform ] && source /opt/ibm/spectrumcomputing/profile.platform" > /etc/profile.d/symphony.sh
			echo "[ -f /opt/ibm/spectrumcomputing/cshrc.platform ] && source /opt/ibm/spectrumcomputing/cshrc.platform" > /etc/profile.d/symphony.csh
		elif [ "${ROLE}" == "symde" ]
		then
			echo "[ -f /opt/ibm/spectrumcomputing/symphonyde/de72/profile.platform ] && source /opt/ibm/spectrumcomputing/symphonyde/de72/profile.platform" > /etc/profile.d/symphony.sh
			echo "[ -f /opt/ibm/spectrumcomputing/symphonyde/de72/profile.client ] && source /opt/ibm/spectrumcomputing/symphonyde/de72/profile.client" >> /etc/profile.d/symphony.sh
			echo "[ -f /opt/ibm/spectrumcomputing/symphonyde/de72/cshrc.platform ] && source /opt/ibm/spectrumcomputing/symphonyde/de72/cshrc.platform" > /etc/profile.d/symphony.csh
			echo "[ -f /opt/ibm/spectrumcomputing/symphonyde/de72/cshrc.client ] && source /opt/ibm/spectrumcomputing/symphonyde/de72/cshrc.client" >> /etc/profile.d/symphony.csh
		else
			echo "nothing to update"
		fi
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
				if [ "$useintranet" == 'false' ]
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
			sed -i "s/^EGO_MASTER_LIST=.*/EGO_MASTER_LIST=${MASTERHOST}/" /opt/ibm/spectrumcomputing/symphonyde/de72/conf/ego.conf
			sed -i "s/^EGO_KD_PORT=.*/EGO_KD_PORT=7870/" /opt/ibm/spectrumcomputing/symphonyde/de72/conf/ego.conf
			LOG "\tconfigured symphony de node ..."
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
