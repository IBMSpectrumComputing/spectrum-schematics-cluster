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

function os_config()
{
	LOG "configuring os ..."
	if [ -f /etc/redhat-release ]
	then
		LOG "\tyum -y install ed tree lsof psmisc nfs-utils net-tools"
		yum -y install ed tree lsof psmisc nfs-utils net-tools
	fi
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

##################END FUNCTIONS RELATED######################

######################MAIN PROCEDURE##########################

# configure OS, install basic utilities like wget curl mount .etc
os_config

# write /tmp/user_metadata.py script to get user_metadata
get_user_metadata

# source user_metadata as shell environment
eval `python /tmp/user_metadata.py`

# download functions file
LOG "donwloading function file and source it"
if [ -n "${functionsfile}" ]
then
	wget --no-check-certificate -o /dev/null -O /tmp/functions.sh ${functionsfile}
	if [ -f "/tmp/functions.sh" ]
	then
		LOG "\tfound /tmp/functions.sh"
		. /tmp/functions.sh
	else
		LOG "\tcan not find /tmp/functions.sh, investigate it please ..."
	fi
fi

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
	useintranet=false
elif [ "$useintranet" == "1" ]
then
	useintranet=true
else
	echo "no action"
fi

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
	useintranet=false
fi
if [ "$useintranet" == "false" ]
then
	masteripaddress=${masterpublicipaddress}
	localipaddress=$(funcGetPublicIp)
fi
localhostname=$(hostname -s)

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
			break
		fi
	done
	echo "$PRODUCT $VERSION $ROLE ready `date`" >> /root/application-ready
	LOG "symphony cluster is now ready ..."
	cat << ENDF > /tmp/post.sh
if [ "${ROLE}" == "symde" ]
then
	echo -e "\tpost configuration for DE host" >> ${LOG_FILE}
	echo -e "\t...logon to soam client" >> ${LOG_FILE}
	while [ 1 -lt 2 ]
	do
		if su - egoadmin -c "soamlogon -u Admin -x Admin" >/dev/null 2>&1
		then
			break
		else
			sleep 60
		fi
	done
	echo -e "\t...logged on to soam client" >> ${LOG_FILE}
	echo -e "\twait 2 minutes for the muster to create consumer" >> ${LOG_FILE}
	wait 120
	su - egoadmin -c "cd /opt/ibm/spectrumcomputing/symphonyde/de72/7.2/samples/CPP/SampleApp; make ; cd Output; gzip SampleServiceCPP; soamdeploy add SampleServiceCPP -p SampleServiceCPP.gz -c \"/SampleAppCPP\""
	su - egoadmin -c "cd /opt/ibm/spectrumcomputing/symphonyde/de72/7.2/samples/CPP/SampleApp; sed -ibak 's/<SSM resReq/<SSM resourceGroupName=\"ManagementHosts\" resReq/' SampleApp.xml; sed -ibak 's/preStartApplication=/resourceGroupName=\"ComputeHosts\" preStartApplication=/' SampleApp.xml; soamreg SampleApp.xml" >> $LOG_FILE 2>&1
	echo -e "\tSampleAppCPP registered..." >> ${LOG_FILE}
	su - egoadmin -c "cd /opt/ibm/spectrumcomputing/symphonyde/de72/7.2/samples/CPP/SampleApp/Output; ./SyncClient ; sleep 5; ./AsyncClient" >> $LOG_FILE 2>&1

elif [ "${ROLE}" == 'symhead' ]
then
	if [ ! -f /etc/checkfailover ]
	then
		. ${SOURCE_PROFILE}
		egosh user logon -u Admin -x Admin
		while [ 1 -lt 2 ]
		do
			if su - egoadmin -c "egosh user logon -u Admin -x Admin" >/dev/null 2>&1
			then
				break
			else
				sleep 60
			fi
		done
		echo -e "\t...logged on to ego" >> ${LOG_FILE}
	fi
else
	echo "nothing to do"
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
