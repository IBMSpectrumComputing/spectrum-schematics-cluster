#!/bin/bash

declare -i numbercomputes
LOG_FILE=/root/deploy_log_${product}

##run only once cloud config is not there##
[ -f /root/user_metadata ] && . /root/user_metadata
[ -f /tmp/deploy ] && exit || touch /tmp/deploy

###################COMMON SHELL FUNCTIONS#################
function LOG ()
{
	echo -e `date` "$1" >> "$LOG_FILE"
}

function funcSetupProxyService()
{
	if [ "${role}" == "master" ]
	then
		if [ -f /etc/redhat-release ]
		then
			LOG "\tyum -y install ed tree lsof psmisc nfs-utils net-tools"
			yum -y install squid
			systemctl enable squid
			systemctl start squid
		elif [ -f /etc/lsb-release ]
		then
			apt-get update
			export DEBIAN_FRONTEND=noninteractive
			apt-get install -y squid
			systemctl enable squid
			systemctl start squid
		else
			echo "not proxy setup"
		fi
	fi
}

function funcUseProxyService()
{
	if [ "${useintranet}" != "false" -a "${role}" != "master" -a "${role}" != "symde" ]
	then
		export http_proxy=http://${masterprivateipaddress}:3128
		export https_proxy=http://${masterprivateipaddress}:3128
		export ftp_proxy=http://${masterprivateipaddress}:3128
		echo export http_proxy=http://${masterprivateipaddress}:3128 >> /root/.bash_profile
		echo export https_proxy=http://${masterprivateipaddress}:3128 >> /root/.bash_profile
		echo export ftp_proxy=http://${masterprivateipaddress}:3128 >> /root/.bash_profile
		if [ -f /etc/redhat-release ]
		then
			echo "proxy=http://${masterprivateipaddress}:3128" >> /etc/yum.conf
		elif [ -f /etc/lsb-release ]
		then
			echo "Acquire::http::Proxy \"http://${masterprivateipaddress}:3128/\";" > /etc/apt/apt.conf
		else
			echo noconfig
		fi
	fi
}

function os_config()
{
	LOG "configuring os ..."
	# check metadata to see if we need use internet interface
	if [ "$useintranet" == "0" ]
	then
		useintranet=false
	elif [ "$useintranet" == "1" ]
	then
		useintranet=true
	else
		echo "no action"
	fi
	funcSetupProxyService
	funcUseProxyService
	if [ -f /etc/redhat-release ]
	then
		LOG "\tyum -y install ed tree lsof psmisc nfs-utils net-tools"
		yum -y install ed tree lsof psmisc nfs-utils net-tools
	elif [ -f /etc/lsb-release ]
	then
		LOG "\tapt-get bash install -y wget curl tree ncompress gettext rpm nfs-kernel-server"
		apt-get update
		export DEBIAN_FRONTEND=noninteractive
		if  cat /etc/lsb-release | egrep -qi "ubuntu 16"
		then
			apt-get install -y --allow-downgrades --allow-remove-essential --allow-change-held-packages  wget curl tree ncompress gettext rpm nfs-kernel-server
		else
			apt-get install -y --force-yes  wget curl tree ncompress gettext rpm nfs-kernel-server
		fi
	else
		echo "os_config not handled"
	fi
	if [ -h /bin/sh -a -f /bin/bash ]
	then
		rm -f /bin/sh
		cp /bin/bash /bin/sh
	fi
}

function funcGetPrivateIp()
{
	ip address show | egrep "inet .*global" | egrep "inet[ ]+10\." | head -1 | awk '{print $2}' | sed -e 's/\/.*//'
}

function funcGetPublicIp()
{
	ip address show | egrep "inet .*global" | egrep -v "inet[ ]+10\." | head -1 | awk '{print $2}' | sed -e 's/\/.*//'
}

function funcGetIPCIDR()
{
	ip address show | egrep "inet .*global" | egrep "inet[ ]+10\." | head -1 | awk '{print $2}'
}

function funcStartConfService()
{
	mkdir -p /export
	if [ "$useintranet" == "true" ]
	then
		echo -e "/export\t\t${localnetwork}/${localnetmask}(ro,no_root_squash)" > /etc/exports
		systemctl enable nfs
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

function funcDetermineConnection()
{
	if [ -z "$masterprivateipaddress" ]
	then
		## on master node
		masterprivateipaddress=$(funcGetPrivateIp)
		masterpublicipaddress=$(funcGetPublicIp)
	fi
	masteripaddress=${masterprivateipaddress}
	
	## if localipaddress is not in the same subnet as masterprivateipaddress, force using internet
	if [ "${localipaddress%.*}" != "${masterprivateipaddress%.*}" ]
	then
		useintranet=false
	fi
	if [ "$useintranet" == "false" ]
	then
		masteripaddress=${masterpublicipaddress}
		localipaddress=$(funcGetPublicIp)
	fi
}
##################END FUNCTIONS RELATED######################

######################MAIN PROCEDURE##########################

# configure OS, install basic utilities like wget curl mount .etc
os_config

# get local hostname, ipaddress and netmask
localhostname=$(hostname -s)
localipaddress=$(funcGetPrivateIp)
localipcidr=$(funcGetIPCIDR)
localnetmask=$(ipcalc -m $localipcidr | sed -e 's/.*=//')
localnetwork=$(ipcalc -n $localipcidr | sed -e 's/.*=//')

# determine to use intranet or internet interface
funcDetermineConnection

# start nfs service on primary master and try to mount nfs service from compute nodes
if [ -z "$masterhostnames" ]
then
	if echo ${localhostname} | egrep -qi "0$"
	then
		funcStartConfService
	else
		funcConnectConfService
	fi
else
	if [ "${role}" == "symde" ]
	then
		mkdir -p /export
	else
		funcConnectConfService
	fi
fi

# download functions file if not there already
LOG "donwloading product function file and source it"
if [ -n "${functionsfile}" ]
then
	if [ ! -f /export/${product}.sh ]
	then
		wget --no-check-certificate -o /dev/null -O /export/${product}.sh ${functionsfile}
	fi
	LOG "\tfound /export/${product}.sh"
	. /export/${product}.sh
fi

# create and/or start up upd server/client to update /etc/hosts and other messages
if [ "$role" == "master" ]
then
	create_udp_server
fi
create_udp_client

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
	masterhostnames=${localhostname}
	echo -e "127.0.0.1\tlocalhost.localdomain\tlocalhost\n${localipaddress}\t${localhostname}.${domain}\t${localhostname}" > /etc/hosts
	export MASTERHOSTNAMES=$masterhostnames
	export MASTERHOST=`echo $MASTERHOSTNAMES | awk '{print $1}'`
else
	export MASTERHOSTNAMES=$masterhostnames
	export MASTERHOST=`echo $MASTERHOSTNAMES | awk '{print $1}'`
	python /tmp/udpclient.py "update ${localipaddress} ${localhostname}.${domain} ${localhostname}"
	echo -e "127.0.0.1\tlocalhost.localdomain\tlocalhost\n${masteripaddress}\t${MASTERHOST}.${domain}\t${MASTERHOST}\n${localipaddress}\t${localhostname}.${domain}\t${localhostname}" > /etc/hosts
	ping -c2 -w2 ${MASTERHOST}
fi
export DERBY_DB_HOST=$MASTERHOST
if [ -z "$clusteradmin" ]
then
	if [ "$product" == "symphony" ]
	then
		clusteradmin=egoadmin
	elif [ "$product" == "lsf"  ]
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

# generate entitlement file or wait for download
if [ "${ROLE}" == "master" ]
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

#deploy product 
if [ "$PRODUCT" == "symphony" ]
then
	SOURCE_PROFILE=/opt/ibm/spectrumcomputing/profile.platform
	deploy_product

# install LSF
elif [ "$PRODUCT" == "lsf" ]
then
	echo installing spectrum computing LSF
else
	echo "unsupported product $PRODUCT `date`" >> /root/application-failed
fi

[ -x /tmp/post.sh ] && /tmp/post.sh >> /tmp/output

echo "$0 execution ends at `date`" >> /tmp/output
###################END OF MAIN PROCEDURE##################
