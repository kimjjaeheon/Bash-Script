#!/bin/bash
init_resource() {
	param=( ) 
	check_value=( )
	value=( )
	warn=0
	warn_check=( )
	index=0
	standard=( )
	os=`uname -a | awk '{print$1}'`
	dbtype=`env | grep DATA_DB_TYPE | cut -d'=' -f2` 	
	memory=`free | grep ^Mem | awk '{print$2}'`
}

free_resource() {
	unset param
	unset value 
	unset warn 
	unset warn_check 
	unset standard
	unset os
	unset dbtype
	unset index
	unset core
	unset openfile	
	unset username
	unset configfile	
	unset shmmax
	unset memory
	unset swappiness
	unset shared_buffer	
	unset shared_buffer_kb	
	unset shared_buffer_mb	
	unset shared_buffer_gb	
	unset thp
	unset net_core_netdev_max_backlog
	unset ntp	
	unset etc_profile_umask
	unset permission 
	unset somaxconn
	unset msgmnb
	unset shmall
	unset COREDUMP_Check
	unset SWAP_Check
	unset THP_Check
	unset NTP_Check	
   	unset OS_Check
	unset SHMALL_Check
	unset SHMMAX_Check
	unset MSGMNB_Check
	unset BACKLOG_Check 
	unset JAVA_Check
	unset PERMISSION_Check
	unset SOMAXCONN_Check
	unset OPENFILEMAX_Check
	unset PG_DATA_MEMORY_Check
	unset HEADER_BAR
	unset WARN_Check
	unset init_resource	
	unset JAVA_GC_Check
	unset chrony
}	

COREDUMP_Check() {	
	core=`ulimit -c`
	param[$index]="COREDUMP"
	standard[$index]="unlimited"
	if [ $core != "unlimited" ] ; then
		check_value[$index]="WARN"
		(( warn++ ))
		value[$index]="$core blocks. It's must be unlimited"
		warn_check+="\"${param[$index]}\" "
	else
		check_value[$index]="PASS" 
		value[$index]="core file size : unlimited"
	fi
	(( index++ ))
}

OPENFILEMAX_Check() {	
	openfile=`ulimit -n`
	username=`whoami | awk '{print$1}'`
	configfile=`cat /etc/security/limits.conf | grep ^$username` 
	param[$index]="OPENFILES"
	standard[$index]=1024
	if [ $openfile != 1024 ] ; then
		if [ -z $configfile 2> /dev/null ] ; then
			value[$index]="open file size : $openfile, /etc/security/limits.conf file has no information"
		else
			value[$index]="open file size : $openfile, /etc/security/limits.conf : $configfile"
		fi
		check_value[$index]="PASS" 
	else
		check_value[$index]="WARN"
		warn_check+="\"${param[$index]}\" "
		(( warn++ ))
		value[$index]="open file size is set def(1024)"
	fi
	(( index++ ))
}

#SHARED MEMORY  
SHMMAX_Check() {
	shmmax="`cat /proc/sys/kernel/shmmax`"
	param[$index]="KERNEL.SHMMAX"
	standard[$index]="33554432"
	#check_int="`echo $shmmax - ${standard[$index]} | bc `" #bc   (toss)
	check_int="`expr $shmmax - ${standard[$index]}`"
	if [[ ${check_int:0:1} = "-" ]]; then
		warn_check+="\"${param[$index]}\" "
		check_value[$index]="WARN" 
		(( warn++ ))
	else
		if [ ${#shmmax} -gt 19 ]; then 	
			(( memory=$memory*1024 ))
			value[$index]="Memory: $memory byte | IPC(kernel.shmmax): $shmmax byte"
			check_value[$index]="PASS" 
			(( memory=$memory/1024 ))
		else
			(( shmmax=$shmmax/1024 ))
			if (( $shmmax > $memory )); then
				value[$index]="Memory: $memory kb < IPC(kernel.shmmax): $shmmax kb"
				standard[$index]="$memory"
			else
				value[$index]="Memory: $memory kb > IPC(kernel.shmmax): $shmmax kb"
			fi
			check_value[$index]="PASS" 
		fi			
	fi	
	(( index++ ))
}

# 
SWAP_Check() {
	swappiness=`cat /proc/sys/vm/swappiness`
	param[$index]="SWAPPINESS"
	value[$index]="Swappiness is set to $swappiness"
	standard[$index]="1"
	if [ $swappiness -le 1 ]; then
		 check_value[$index]="PASS" 
	else
		check_value[$index]="WARN"; (( warn++ ))
		warn_check+="\"${param[$index]}\" "
	fi
	(( index++ ))
}

THP_Check() {
	thp=`cat /proc/meminfo | grep HugePages | awk '{print$2}'`
	param[$index]="THP"
	standard[$index]="0"
	for i in $thp;
	do
		if [ $i != 0 ]; then
			check_value[$index]="WARN"
			warn_check+="\"${param[$index]}\" "
			(( warn++ ))
			value[$index]="thp is on"
			(( index++ ))
			return ;
		fi 
	done
	check_value[$index]="PASS"
	value[$index]="Transparent huge pages not set to always"
	(( index++ ))
}

NTP_Check() {
	ntp=`ps -ef | grep ntpd | grep -cv grep`
	param[$index]="NTP"
	standard[$index]="ProcessON"

	if [ $ntp -ge 1 ]; then
		check_value[$index]="PASS"

		which ntpd >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			value[$index]="NTP is installed and running" 
		else
			value[$index]="NTP is running but not installed" 
		fi
		(( index++ ))
		param[$index]="NTPSTAT"
		value[$index]=`ntpstat` 
		(( index++ ))

	elif [ $ntp -eq 0 ]; then  
		check_value[$index]="WARN"
		warn_check+="\"${param[$index]}\" "
		(( warn++ ))

		which ntpd >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			value[$index]="NTP is installed but not running"
			(( index++ ))
		else
			value[$index]="NTP is not installed or not in PATH environment"
			(( index++ ))
		fi
		
	fi
}

CHRONY_Check() {
	chrony=`ps -ef | grep chronyd | grep -cv grep`
	param[$index]="CHRONY"
	standard[$index]="ProcessON"

	tz_chk=`timedatectl | grep "Time zone" | awk '{print $3}'`

	if [ $chrony -ge 1 ] && [ "$tz_chk" = "Asia/Seoul" ]; then
		check_value[$index]="PASS"

		value[$index]="Chrony is installed and running. Timezone : ${tz_chk}" 
		(( index++ ))

	elif [ $chrony -ge 1 ] && [ "tz_chk" = "Asia/Seoul" ]; then
		check_value[$index]="WARN"
		warn_check+="\"${param[$index]}\" "
		(( warn++ ))
	
		value[$index]="Chronyd is running. but Check your Timezone ( Timezone : ${tz_chk} ) " 
		(( index++ ))

	elif [ $chrony -eq 0 ]; then  
		check_value[$index]="WARN"
		warn_check+="\"${param[$index]}\" "
		(( warn++ ))

		systemctl status chronyd >/dev/null 2>&1
		chrony_chk=`echo $?`
	
		if [ "$chrony_chk" -eq 4 ]; then
			value[$index]="Chronyd is not installed (install command : sudo yum install chrony) " 
			(( index++ ))
		elif [ "$tz_chk" = "Asia/Seoul" ]; then
			value[$index]="Chronyd is not running. (check command : systemctl status chronyd) "
			(( index++ ))
		else 
			value[$index]="Chronyd is not running(check command : systemctl status chronyd) and check Timezone(Timezone : ${tz_chk}) "
			(( index++ ))
		fi
	fi
}

TIME_Check() {
	time_status=`timedatectl | grep "Local time"`
	param[$index]="TIME"
	value[$index]="$time_status"
	(( index++ ))
	
}
	
BACKLOG_Check() {
	net_core_netdev_max_backlog=`cat /proc/sys/net/core/netdev_max_backlog`
	param[$index]="NET.CORE.NETDEV_MAX_BACKLOG"
	value[$index]="$net_core_netdev_max_backlog frames"
	standard[$index]="1000"
	if [ $net_core_netdev_max_backlog = 1000 ]; then
		check_value[$index]="WARN"
		warn_check+="\"${param[$index]}\" "
		(( warn++ ))
	else
		check_value[$index]="PASS"
	fi
	(( index++ ))
}

SHMALL_Check(){
	shmall=`cat /proc/sys/kernel/shmall`
	param[$index]="KERNEL.SHMALL"
	value[$index]="$shmall pages (def: 33554432 pages)"
	standard[$index]="33554432"
	if [ $shmall = 33554432 ]; then
		check_value[$index]="WARN"
		warn_check+="\"${param[$index]}\" "
		(( warn++ ))
	else
		check_value[$index]="PASS"
	fi
	(( index++ ))
}

MSGMNB_Check(){
	msgmnb=`cat /proc/sys/kernel/msgmnb`
	param[$index]="KERNEL.MSGMNB"
	value[$index]="$msgmnb byte (def: 65536 byte)"
	standard[$index]="65536"
	if [ $msgmnb = 65536 ]; then
		check_value[$index]="WARN"
		warn_check+="\"${param[$index]}\" "
		(( warn++ ))
	else
		check_value[$index]="PASS"
	fi
	(( index++ ))
}

OS_Check() {	
	param[$index]="OS"
	value[$index]="$os"
	(( index++ ))
}

SOMAXCONN_Check() {
	param[$index]="NET.CORE.SOMAXCONN"
	if [ $os = "AIX" ]; then
		somaxconn=`no -a | grep somaxconn | awk '{print$3}'`
		standard[$index]="1024"
		if [ $somaxconn -eq 1024 ]; then
			check_value[$index]="WARN"
			warn_check+="\"${param[$index]}\" "
			(( warn++ ))
		else
			check_value[$index]="PASS"
		fi
		value[$index]="$somaxconn"
		(( index++ ))
	elif [ $os = "Linux" ]; then
		somaxconn=`sysctl net.core.somaxconn | awk '{print$3}'`
		standard[$index]="128"
		if [ $somaxconn -eq 128 ]; then
			check_value[$index]="WARN"
			warn_check+="\"${param[$index]}\" "
			(( warn++ ))
		else
			check_value[$index]="PASS"
		fi
		value[$index]="$somaxconn"
		(( index++ ))
	fi
}

JAVA_Check() {
	param[$index]="JRE"
	type -p java 2>&1 >/dev/null 
	if [ $? -eq 0 ]; then
		check_value[$index]="PASS"
		value[$index]="jre in `type -p java`"
	else
		check_value[$index]="WARN"
		value[$index]="no jre in ($PATH)"
		warn_check+="\"${param[$index]}\" "
		(( warn++ ))
	fi	
	(( index++ ))
	
	param[$index]="JDK"
	type -p javac 2>&1 >/dev/null 
	if [ $? -eq 0 ]; then
		check_value[$index]="PASS"
		value[$index]="jdk in `type -p javac`"
	else
		check_value[$index]="WARN"
		value[$index]="no jdk in ($PATH)"
		warn_check+="\"${param[$index]}\" "
		(( warn++ ))
	fi	
	(( index++ ))
}

PERMISSION_Check() {
	permission=`umask`
	param[$index]="UMASK"
	value[$index]="$permission"
	etc_profile_umask=`cat /etc/profile | grep -v '#' | grep "umask"`
	if [[ -z $etc_profile_umask ]]; then
		(( warn++ ))
		warn_check+="\"${param[$index]}\" "
		value[$index]="UMASK not set to /etc/profile"
	else		
		if [ $UID -gt 199 ] && [ "`/usr/bin/id -gn`" = "`/usr/bin/id -un`" ]; then
			standard[$index]="0002"
			if [ $permission -eq 0002 ]; then
				check_value[$index]="PASS"
			else
				check_value[$index]="WARN"
				warn_check+="\"${param[$index]}\" "
				(( warn++ ))
			fi 
		else			
			standard[$index]="0022"
			if [ $permission -eq 0022 ]; then
				check_value[$index]="PASS"
			else
				check_value[$index]="WARN"
				warn_check+="\"${param[$index]}\" "
				(( warn++ ))	
			fi		
 		fi
	fi		
	(( index++ ))
}

PG_DATA_MEMORY_Check() {
	if [ $dbtype = "postgresql" ]; then
		param[$index]="PostgreSQL_Memory_Size"
		standard[$index]="memory/4"

		db_status_tmp=`$PG_HOME/bin/pg_ctl status -D $PG_RB_HOME`
		db_status=`echo $?`

		if [ ${db_status} -eq 0 ]; then
			shared_buffer=`psql $PG_DATA_LOADER_IDPWD -t -A -c "show shared_buffers"`	
			if [ "$shared_buffer" == "" ]; then
					value[$index]="The PG_DATA is off"
					check_value[$index]="WARN"
					warn_check+="\"${param[$index]}\" "
					(( warn++ ))
			fi		
			shared_buffer_kb=`psql $PG_DATA_LOADER_IDPWD -t -A -c "show shared_buffers" | grep KB`	
			shared_buffer_mb=`psql $PG_DATA_LOADER_IDPWD -t -A -c "show shared_buffers" | grep MB`	
			shared_buffer_gb=`psql $PG_DATA_LOADER_IDPWD -t -A -c "show shared_buffers" | grep GB`	
			if [ "$shared_buffer_kb" != "" ]; then
				shared_buffer_kb=`psql $PG_DATA_LOADER_IDPWD -t -A -c "show shared_buffers" | grep MB | cut -d'K' -f1`
				(( memory=$memory / 4 )) 	 #memory is located SHMMAX    		
				echo $memory 
				if [ $shared_buffer_kb -gt $memory ]; then
					check_value[$index]="PASS"
					value[$index]=$shared_buffer
				else
					check_value[$index]="WARN"
					value[$index]="SHARED_BUFFER : $shared_buffer | MEMORY/4 : $memory KB" 
					warn_check+="\"${param[$index]}\" "
					(( warn++ ))
				fi			
			fi
			if [ "$shared_buffer_mb" != "" ]; then
				shared_buffer_mb=`psql $PG_DATA_LOADER_IDPWD -t -A -c "show shared_buffers" | grep MB | cut -d'M' -f1`
				(( memory=$memory / 1024 / 4 ))			
				echo $memory 
				if [ $shared_buffer_mb -gt $memory ]; then
					check_value[$index]="PASS"
					value[$index]=$shared_buffer
				else
					check_value[$index]="WARN"
					value[$index]="SHARED_BUFFER : $shared_buffer | MEMORY/4 : $memory MB" 
					warn_check+="\"${param[$index]}\" "
					(( warn++ ))
				fi			

			fi
			if [ "$shared_buffer_gb" != "" ]; then
				shared_buffer_gb=`psql $PG_DATA_LOADER_IDPWD -t -A -c "show shared_buffers" | grep GB | cut -d'G' -f1`
				(( memory=$memory / 1024 / 1024 / 4 ))			
				echo $memory 
				if [ $shared_buffer_gb -gt $memory ]; then
					check_value[$index]="PASS"
					value[$index]=$shared_buffer
				else
					check_value[$index]="WARN"
					value[$index]="SHARED_BUFFER : $shared_buffer | MEMORY/4 : $memory GB" 
					warn_check+="\"${param[$index]}\" "
					(( warn++ ))
				fi			
			fi
		elif [ ${db_status} -eq 3 ]; then
			check_value[$index]="WARN"
			value[$index]="Postgresql DB is Down"
		else 
			check_value[$index]="WARN"
			value[$index]="Postgresql DB is unused or cannot be used"
		fi
		(( index++ ))
	fi

}

JAVA_GC_Check() {
	check_gc=`ps -ef | grep java | grep ^$USER | grep G1GC`
	param[$index]="GC"
	standard[$index]="G1GC"
	if [[ ! -z ${check_gc} ]]; then
		check_value[$index]="PASS"
		value[$index]="G1GC option exist"
	else
		check_value[$index]="WARN"
		(( warn++ ))
		value[$index]="gc option doesn't exist"
		warn_check+="\"${param[$index]}\" "
	fi	
	(( index++ ))
}

WARN_Check() {
	if [ $warn != "0" ]; then
		echo "Check completed with $warn WARNINGS."
		echo ${warn_check[0]}\ is WARNINGS
	else	
		echo "Check completed successfully."
	fi	
}

HEADER_BAR() {
printf '%-37s' STATUS
printf '%-10s' CHECK
printf '%-12s' STANDARD 
echo VALUE 
}


init_resource
count=0

COREDUMP_Check
SWAP_Check
THP_Check
NTP_Check
CHRONY_Check
TIME_Check
OS_Check
SHMMAX_Check
SHMALL_Check
MSGMNB_Check
BACKLOG_Check 
JAVA_Check
PERMISSION_Check
SOMAXCONN_Check
OPENFILEMAX_Check
JAVA_GC_Check 

if [ -d $PG_DATA_HOME ]; then
	PG_DATA_MEMORY_Check
fi

HEADER_BAR
echo "========================================================================================="
for i in ${param[@]}
do	
	printf "Status: "
	printf '%-30s' $i
	printf '%-10s' ${check_value[$count]}
	printf '%-11s' ${standard[$count]}
	echo ${value[$count]} 
	(( count++ ))
done

echo
WARN_Check

free_resource
unset free_resource
