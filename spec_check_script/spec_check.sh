#!/bin/bash

INIT_VAL(){
	param=( ) 
	check_value=( )
	value=( )
	warn=0
	warn_check=( )
	index=0
	os_ver=`cat /etc/system-release`
	cpu_model=`lscpu | grep "Model name"`
	cpu_core=`lscpu | head -15`	
	memory=`free -h`
	disk=`df -h`
	storage=`lspci -v | egrep "SATA|SAS|RAID|Adapter|HBA|Fibre"`
	id=`whoami`
	kernel_version=`uname -r`
	gcc=`whereis gcc | awk '{print$2}'`
	gplus=`whereis g++ | awk '{print$2}'`
}

OS_VERSION_CHECK() {	
	param[$index]="OS_VERSION"
	value[$index]="$os_ver"
	(( index++ ))
}

CPU_MODEL_CHECK(){
	param[$index]="CPU_MODEL"
	value[$index]="$cpu_model"
	(( index++ ))
}

CPU_CORE_CHECK(){
	lscpu | head -15 | tr -d ' ' | awk '
	{ split($0,a,":"); printf "%8s%-29s %-54s\n", " ", a[1], a[2] }'
}

MEMORY_CHECK(){
	free -h | awk '
	{ split($0,a,":"); printf "%s %s\n", a[1], a[2]	}'
}

DISK_CHECK(){
	df -h | awk '
	{ split($0,a,":"); printf "%s %s\n", a[1], a[2] }'
}

STORAGE_CHECK(){
	lspci -v | egrep "SATA|SAS|RAID|Adapter|HBA|Fibre" | awk '
	{ split($0,a,":"); printf "%s %s %s\n", a[1],a[2],a[3] }' 
}

SERVER_MODEL_CHECK(){
	if [ $id = "root" ]; then
		server_model=`dmidecode -s system-product-name`
		param[$index]="SERVER_MODEL"
		value[$index]="$server_model"
		(( index++ ))
	else
		param[$index]="SERVER_MODEL"
		value[$index]="Please login as root"
		(( index++ ))

	fi

}

KERNEL_VERSION_CHECK(){
	param[$index]="KERNEL_VERSION"
	value[$index]="$kernel_version"		
	(( index++ ))
}

GCC_VERSION_CHECK(){
	if [ -z $gcc ] && [ -z $gplus ]; then
		param[$index]="COMPLIER_VERSION"
		value[$index]= "No such compiler (gcc & g++)"
		(( index++ ))
	else
		if [ -n "$gcc" ]; then
			param[$index]="GCC_VERSION"
			value[$index]="`gcc --version | grep gcc`" 
			(( index++ ))
		fi

		if [ -n "$gplus" ]; then
			param[$index]="G++_VERSION"
			value[$index]="`g++ --version | grep g++`"
			(( index++ ))
		fi
	fi
}

PG_VERSION_CHECK(){
	param[$index]="PG_VERSION"
	psql --version 2>1 >/dev/null
	if [ $? -eq 0 ]; then
		pg_env_check_value=`env | grep PG_RB_LOADER_IDPWD`
		if [ -z "$pg_env_check_value" ]; then
			value[$index]=`psql --version`
		else
			value[$index]=`psql $PG_RB_LOADER_IDPWD -t -A -c "select version()"` 
		fi
		(( index++ ))
	else
		value[$index]="No such postgresql" 
		(( index++ ))
	fi	
}

HEADER_BAR() {
printf '%-37s' STATUS
echo VALUE 
}

INIT_VAL
OS_VERSION_CHECK
CPU_MODEL_CHECK
SERVER_MODEL_CHECK
KERNEL_VERSION_CHECK
GCC_VERSION_CHECK
PG_VERSION_CHECK
HEADER_BAR

echo "========================================================================================="
for i in ${param[@]}
do	
	printf "Status: "
	printf '%-30s' $i
	echo ${value[$count]} 
	(( count++ ))
done
echo

printf "Status: "
printf '%-30s\n' "CPUCORE"
CPU_CORE_CHECK
echo

printf "Status: "
printf '%-30s\n' "MEMORY"
MEMORY_CHECK
echo

printf "Status: "
printf '%-30s\n' "DISK"
DISK_CHECK
echo

printf "Status: "
printf '%-30s\n' "STORAGE"
STORAGE_CHECK
echo
