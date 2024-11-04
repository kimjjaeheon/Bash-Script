#!/bin/bash

#ERROR CODE
GET_VAL_ERROR=100

#VARIABLE
date=$(date +%Y%m%d)
user=`echo $USER`
os=`uname -s`
log_dir="$TRAN_AGT_HOME/scripts/agt_check_log"
config_file="$TRAN_AGT_HOME/config/agt.cfg"

function process_check()
{
	cd $TRAN_AGT_HOME/bin
	./tran_agent.sh show
}

function network_check()
{
	#SERVER_IP get
	get_server_ip

	if [ -z $SERVER_IP ]; then
		return $GET_VAL_ERROR
	else
		echo "\"agt.cfg\" file"
		echo "[TRAN_SERVER]"
		echo "#---- SERVER IP ----#"
		echo "IP_ADDRESS : $SERVER_IP"
	fi

	#LOG_PORT_XX get
	get_log_port

	if [ -z ${PORT[0]} ]; then
		return $GET_VAL_ERROR
	else
		echo "#---- LOG PORT ----#"
		echo "LOG_PORT : ${PORT[@]}"
		echo
	fi

	cd $TRAN_AGT_HOME/bin

	tranget_q=( `./tranget -q` )
	total_count=0

	for P in ${PORT[@]}
	do
		#LINUX
		if [ $os = "Linux" ]; then
			connect="${SERVER_IP}:$P"
			netstat -an | egrep "$connect"
			establish_count=`netstat -an | egrep "$connect" | wc -l`
			(( total_count+=$establish_count ))
		else
		#UNIX
			connect="${SERVER_IP}.$P"
			netstat -an | egrep "$connect"
			establish_count=`netstat -an | egrep "$connect" | wc -l`
			(( total_count+=$establish_count ))
		fi
	done

	if [ ${tranget_q[1]} = "successfully" ]; then
		q_cnt=`echo ${tranget_q[5]} | cut -d ',' -f 1`
	else
		q_cnt="tranget fail"
	fi

	echo
	echo "ESTABLISHED count : $total_count"
	echo "QUEUE       count : $q_cnt"
}

function cpu_mem_check()
{
	ps aux | head -1
	ps aux | grep -w "^$user" 
}

function process_down_check()
{
	cd $TRAN_AGT_HOME/bin

	TIME=( `./tran_agent.sh show | grep -w "^$user" | awk '{print$5}'` )
	standard=${TIME[0]}
	count=0

	for T in ${TIME[@]}
	do
		if [ $standard != $T ]; then
			(( count+=1 ))
		fi
	done

	if [ $count = 0 ]; then
		echo "비정상 종료 프로세스 개수 : $count [ OK ] "
	else
		echo "비정상 종료 프로세스 개수 : $count [ WARN ]"
	fi

}

function disk_check()
{
	#disk="/sw /log"
	
	if [ $os = "HP-UX" ]; then
		bdf
	else 
		#[Linux, AIX, Solaris]
		#df -k $disk
		df -k $TRAN_HOME $TRAN_AGT_HOME/logs
	fi
}

function ipc_check()
{
	shm=`cat $TRAN_AGT_HOME/config/agt.cfg | grep TRAN_LOGF_QUE_INFO_SHMKEY | awk '{printf("%x", $3)}'`

	ipcs -m | head -3
	ipcs -a | grep $shm
}

function wlogs_check()
{
	cd $TRAN_AGT_LOG_HOME/moni
	tail -32 agt_monitor.$date
}

function log_parser_check()
{
	cd $TRAN_AGT_LOG_HOME/proc/log_parser

	err_count=`grep "Error " * | grep -v "Error 0" | wc -l`
	keep_sts_count=`grep "KEEP_STS" * | grep -v "KEEP_STS:0" | wc -l`
	ok="[ OK ]"
	warn="[ OK ]"

	if [ $err_count != 0 ]; then
		ok="[ NOK ]"	
	fi
	if [ $keep_sts_count != 0 ]; then
		warn="[ WARN ]"	
	fi

	echo "[ log_parser status ]"
	printf ">> IN  [ \"ERROR\" ]    count : %10d $ok" $err_count
	echo
	printf "<< OUT [ \"KEEP_STS\" ] count : %10d $warn" $keep_sts_count
	echo
}

function make_backup_dir()
{
	if [ ! -d $log_dir ];then
		mkdir $log_dir	
	fi
}

function get_server_ip()
{
	section_flag=0

	while read line
	do
		find_section=`echo $line | egrep "^\[TRAN_SERVER\]"`	

		if [ ! -z $find_section ]; then
			section_flag=1	
			continue
		fi

		if [ $section_flag = 1 ]; then
			next_section=( `echo $line | grep "^\["` )

			if [ ! -z ${next_section[0]} ]; then
				echo "Section change. ([TRAN_SERVER] -> ${next_section[0]})"
				echo "Please check agt.cfg file."
				echo "Can't find \"IP_ADDRESS\" in [TRAN_SERVER]"
				break;
			fi

			comment=( `echo $line | grep ^#` )

			if [ -z ${comment[0]} ]; then
				SERVER_IP=`echo $line | grep "^IP_ADDRESS" | awk '{print$3}'`	

				if [ -z $SERVER_IP ];then
					continue
				else
					#find SERVER_IP
					section_flag=0
					break;
				fi

			else
				continue
			fi
		fi

	done < $config_file

}

function get_log_port(){
	cd $TRAN_AGT_HOME/bin
	tranget_q=( `./tranget -q` )

	if [ ${tranget_q[1]} = "successfully" ]; then
		q_cnt=`echo ${tranget_q[5]} | cut -d ',' -f 1`
	else
		q_cnt="tranget fail"
	fi

	if [ $q_cnt = 4 ]; then
		LOG_PORT="00 01 02 03"
	else 
		LOG_PORT="00 01 02 03 04 05 06 07"
	fi

	for P in $LOG_PORT
	do
		tmp=( `cat $config_file | grep "LOG_PORT_$P" | awk '{print$3}'` )

		PORT+=(${tmp[0]})
	done
}

#MAIN
make_backup_dir

{
echo "## AGENT CHECK SHELL ##"
echo
echo "1) PROCESS STATUS CHECK"
process_check
echo
echo "2) NETWORK CHECK"
network_check
echo
echo "3) CPU/MEM CHECK"
cpu_mem_check
echo
echo "4) PROCESS DOWN CHECK"
process_down_check
echo
echo "5) DISK CHECK"
disk_check
echo
echo "6) API CHECK"
ipc_check
echo
echo "7) WLOGS CHECK"
wlogs_check
echo
echo "8) LOG_PARSER CHECK"
log_parser_check
echo

} > $log_dir/AGT_CHECK_RESULT_$date
