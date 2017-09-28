#!/bin/bash

declare -i numbercomputes
LOG_FILE=/root/deploy_log_${product}

###################COMMON SHELL FUNCTIONS#################
function LOG ()
{
	echo -e `date` "$1" >> "$LOG_FILE"
}

function funcSetupProxyService()
{
	if [ "${role}" == "symhead" -o "${role}" == "lsfmaster" ]
	then
		if [ -f /etc/redhat-release ]
		then
			LOG "\tyum -y install ed tree lsof psmisc nfs-utils net-tools"
			yum -y install squid
			systemctl enable squid
			systemctl start squid
		fi
	fi
}

function funcUseProxyService()
{
	if [ "${useintranet}" != "false" -a "${role}" != "symhead" -a "${role}" != "lsfmaster" -a "${role}" != "symde" ]
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
	funcSetupProxyService
	funcUseProxyService
	if [ -f /etc/redhat-release ]
	then
		LOG "\tyum -y install ed tree lsof psmisc nfs-utils net-tools"
		yum -y install ed tree lsof psmisc nfs-utils net-tools
	fi
}

function funcGetIp()
{
	## for distributions using ifconfig and eth0
	#ifconfig eth0 | grep "inet " | awk '{print $2}' | sed -e 's/addr://'
	ip address show dev ${1} | grep "inet " | awk '{print $2}' | sed -e 's/addr://' -e 's/\/.*//'
}

function funcGetIPCIDR()
{
	## for distributions using ifconfig and eth0
	ip address show dev ${1} | grep "inet " | awk '{print $2}'
}

function funcStartConfService()
{
	mkdir -p /export
	if [ "$useintranet" == "true" ]
	then
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

function funcDetermineConnection()
{
	if [ -z "$masterprivateipaddress" ]
	then
		## on master node
		masterprivateipaddress=$(funcGetIp eth0)
		masterpublicipaddress=$(funcGetIp eth1)
	fi
	masteripaddress=${masterprivateipaddress}
	
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
	## if localipaddress is not in the same subnet as masterprivateipaddress, force using internet
	if [ "${localipaddress%.*}" != "${masterprivateipaddress%.*}" ]
	then
		useintranet=false
	fi
	if [ "$useintranet" == "false" ]
	then
		masteripaddress=${masterpublicipaddress}
		localipaddress=$(funcGetIp eth1)
	fi
}
##################END FUNCTIONS RELATED######################

######################MAIN PROCEDURE##########################

# configure OS, install basic utilities like wget curl mount .etc
os_config

# get local hostname, ipaddress and netmask
localhostname=$(hostname -s)
localipaddress=$(funcGetIp eth0)
localipcidr=$(funcGetIPCIDR eth0)
localnetmask=$(ipcalc -m $localipcidr | sed -e 's/.*=//')
network=$(ipcalc -n $localipcidr | sed -e 's/.*=//')

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
	if [ "${role}" != "symde" ]
	then
		funcConnectConfService
	else
		mkdir -p /export
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
if [ "$role" == "symhead" ]
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

# generate entitlement file or wait for download
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
	declare -i ROUND=0
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
			sleep 20
			. ${SOURCE_PROFILE}
			ROUND=$((ROUND+1))
			## prepare demo examples
			LOG "prepare demo examples ..."
			LOG "\tlogging in ..."
			egosh user logon -u Admin -x Admin
			LOG "\tlogged in ..."
			LOG "create /SampleAppCPP consumer ..."
			egosh consumer add "/SampleAppCPP" -a Admin -u Guest -e egoadmin -g "ManagementHosts,ComputeHosts" >> $LOG_FILE 2>&1
			LOG "\tconsumer /SampleAppCPP created"
			break
		fi
	done
	echo "$PRODUCT $VERSION $ROLE ready `date`" >> /root/application-ready
	LOG "symphony cluster is now ready ..."
	LOG "generating symphony post configuration activity"
	funcGeneratePost

# install LSF
elif [ "$PRODUCT" == "LSF" -o "$PRODUCT" == "lsf" ]
then
	echo installing spectrum computing LSF
else
	echo "unsupported product $PRODUCT `date`" >> /root/application-failed
fi

[ -x /tmp/post.sh ] && /tmp/post.sh >> /tmp/output

echo "$0 execution ends at `date`" >> /tmp/output
## keep the script running in case symphony stop when shell terminates
#while [ 1 -lt 2 ]
#do
#	sleep 3600
#done
###################END OF MAIN PROCEDURE##################
