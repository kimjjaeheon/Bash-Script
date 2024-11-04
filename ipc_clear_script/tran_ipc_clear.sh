#!/bin/sh

# Platform-specific overrides
uname_S=`sh -c 'uname -s 2>/dev/null || echo not'`

#VARIABLE
config_file="$TRAN_AGT_HOME/config/agt.cfg"
shm_section_flag=0
sem_section_flag=0
msgq_section_flag=0
shm_key=( )
sem_key=( )
msgq_key=( )

function get_ipc_key
{
	section_flag=0
	
	while read line
	do
		tmp_section=`echo $line | grep "^\["`
		if [ ! -z $tmp_section ]; then
			now_section=$tmp_section;
		fi

		if [ "$now_section" = "[IPC_SHARED_MEMORY]" ]; then 
			shm_section_flag=1
      sem_section_flag=0
      msgq_section_flag=0
      logf_section_flag=0
		elif [ "$now_section" = "[IPC_SEMAPHORE]" ]; then
			sem_section_flag=1
      shm_section_flag=0
      msgq_section_flag=0
      logf_section_flag=0
		elif [ "$now_section" = "[IPC_MESSAGE_QUE]" ]; then
			msgq_section_flag=1
      sem_section_flag=0
      shm_section_flag=0
      logf_section_flag=0
    elif [ "$now_section" = "[TRAN_LOGF]" ]; then
      logf_section_flag=1
    else
      shm_section_flag=0
      sem_section_flag=0
      msgq_section_flag=0
      logf_section_flag=0
		fi

		# find key 
		if [ $shm_section_flag -eq 1 ]; then
			# except comment
			comment=( `echo $line | grep "^#"` )
			if [ -z ${comment[0]} ]; then
				shm_key+=(`echo $line | awk '{print$3}'`)
			else
				continue;
			fi
		elif [ $sem_section_flag -eq 1 ]; then
			# except comment
			comment=( `echo $line | grep "^#"` )
			if [ -z ${comment[0]} ]; then
				sem_key+=(`echo $line | awk '{print$3}'`)
			else
				continue;
			fi
		elif [ $msgq_section_flag -eq 1 ]; then
			# except comment
			comment=( `echo $line | grep "^#"` )
			if [ -z ${comment[0]} ]; then
				msgq_key+=(`echo $line | awk '{print$3}'`)
			else
				continue;
			fi
    elif [ $logf_section_flag -eq 1 ]; then
      #except comment
      comment=( `echo $line | grep "^#"` )
      if [ -z ${comment[0]} ]; then
        find_max_que_cnt=`echo $line | grep "^MAX_QUE_CNT" | awk '{print$3}'`
        if [ ! -z ${find_max_que_cnt} ]; then
          max_que_cnt=$(expr ${find_max_que_cnt} - 1)
        fi
      else
        continue;
      fi
		fi

	done < $config_file

  for i in $(seq 1 $max_que_cnt)
  do
    msgq_key+=($(expr ${msgq_key[0]} + $i))
  done

  echo "      All IPC resources have been found."
  if [ $debug_flag -eq 1 ]; then
    debug_get_ipc_key
  fi
}

#Debug
function debug_get_ipc_key
{
  echo ""
  echo "[DEBUG ���] "
  echo "  agt.cfg ���Ͽ� �ִ� ipc �ڿ��� �� �����Դ��� �׽�Ʈ�մϴ�."
  echo "  >>> 1. shm_key "
  for shm in ${shm_key[@]}
  do
    echo "  Shared Memory Key : $shm "
  done

  echo "  >>> 2. sem_key "
  for sem in ${sem_key[@]}
  do
    echo "  SEMAPHORE Key : $sem "
  done

  echo "  >>> 3. msgq_key "
  for msgq in ${msgq_key[@]}
  do
    echo "  MESSAGEQUE Key : $msgq "
  done

  echo ""
}

function conversion
{
# conversion �Լ��� agt.cfg ���Ͽ� �ִ� Ű ���� ������ �ͼ�
# 10������ ���� 16������ ��ȯ��Ų �� 
# ipcs -a ��ɾ��� shmid/semid/msqid �� ������ �ɴϴ�.
# key ���� �տ� 0x0000 Ȥ�� 0x00000 ���� �������̽����� ���ϱ⿡
# key ���� ���� ��Ȯ�� id ���� �����մϴ�.

  if [ $debug_flag -eq 1 ]; then
    echo "[Debug ��� ]"
    echo "  ipc �ڿ��� 16������ �� ��ȯ�ߴ� �� �׽�Ʈ�մϴ�."
    echo "  >> 1. shm key "
  fi
  shm_key_hex=( )
  for shm in ${shm_key[@]}
  do
    shm_key_hex=`printf '%x\n' $shm`
    shm_id+=( `ipcs -m | grep $shm_key_hex | awk '{print $2}'` )
    if [ $debug_flag -eq 1 ]; then
      echo "  10���� : $shm"
      echo "  16���� : $shm_key_hex"
    fi
  done 

  if [ $debug_flag -eq 1 ]; then
    echo "  >> 2. sem key "
  fi
  sem_key_hex=( )
  for sem in ${sem_key[@]}
  do
    sem_key_hex=`printf '%x\n' $sem`
    sem_id+=( `ipcs -s | grep $sem_key_hex | awk '{print $2}'` )

    if [ $debug_flag -eq 1 ]; then
      echo "  10���� : $sem"
      echo "  16���� : $sem_key_hex"
    fi
  done 

  if [ $debug_flag -eq 1 ]; then
    echo "  >> 3. msgq key "
  fi
  msgq_key_hex=( )
  for msgq in ${msgq_key[@]}
  do
    msgq_key_hex=`printf '%x\n' $msgq`
    msgq_id+=( `ipcs -q | grep $msgq_key_hex | awk '{print $2}'` )
    
    if [ $debug_flag -eq 1 ]; then
      echo "  10���� : $msgq"
      echo "  16���� : $msgq_key_hex"
    fi
  done 

  echo "      All IPC resources have been converted."
  if [ $debug_flag -eq 1 ]; then
    debug_conversion
  fi
}
function debug_conversion
{
  echo ""
  echo "[DEBUG ���] "
  echo "  ���� TRANManager�� ����ϰ��ִ� ipc �ڿ��� �����ݴϴ�. "
  echo "  >>> 1. shm_key "
  for shm in ${shm_id[@]}
  do
    echo "  16 ���� Shared Memory id : $shm"
  done

  echo "  >>> 2. sem_key "
  for sem in ${sem_id[@]}
  do
    echo "  16 ���� Semaphore id : $sem"
  done

  echo "  >>> 3. msgq_key "
  for msgq in ${msgq_id[@]}
  do
    echo "  16 ���� Message Que id : $msgq"
  done

  echo ""
}

function remove_ipc
{
  if [ $debug_flag -eq 1 ]; then
    echo "[Debug ��� ]"
    echo "  Debug ���� IPC �ڿ��� �������� �ʽ��ϴ�."
  fi
  echo "  Debug Shared Memory"

  for shm in ${shm_id[@]}
  do
    if [ `ipcs -m | grep $shm | wc -l `  -eq 0 ]; then
      echo "Pass $shm"
    else
      if [ $debug_flag -eq 1 ]; then
        echo "delete : $shm"
      else
        ipcrm -m $shm
      fi
    fi
  done

  echo "  Debug Semaphore"

  for sem in ${sem_id[@]}
  do
    if [ `ipcs -s | grep $sem | wc -l `  -eq 0 ]; then
      echo "Pass $sem"
    else
      if [ $debug_flag -eq 1 ]; then
        echo "delete : $sem"
      else
        ipcrm -s $sem
      fi
    fi
  done

  echo "  Debug Message Que"
  for msgq in ${msgq_id[@]}
  do
    if [ `ipcs -q | grep $msgq | wc -l `  -eq 0 ]; then
      echo "Pass $msgq"
    else
      if [ $debug_flag -eq 1 ]; then
        echo "delete : $msgq"
      else
        ipcrm -q $msgq
      fi
    fi
  done

  echo "      All IPC resources have been deleted."
}

function usage_message
{
  echo " Usage: "
  echo "  tran_ipc_clear.sh [option] " 
  echo ""
  echo " Options: " 
  echo "  start   delete tranmanager ipc resource " 
  echo "  debug   debug mode  " 
  echo "          if debug mode start, do not remove ipc resource"
}

function env_check
{
  echo " > 0. Environment Check "
  if [ $uname_S != Linux ]; then
    echo " This OS is not supported."
    exit 0
  else
    echo " OS info : $uname_S"
  fi

  if [ -f $config_file ]; then
    echo " config file ($config_file) exist."
  else
    echo " config file ($config_file) is not exist."
    echo " Please check env."
  fi
}

function main_start
{
#0. Environment Check
  env_check
#1. Get TRANManager IPC KEY 
  echo " > 1. find IPC key "
  get_ipc_key

#2. Number base conversion
  echo " > 2. Number base conversion (10 -> 16) "
  conversion

#3. Remove IPC
  echo " > 3. Remove TRANManager IPC "
  remove_ipc
}

### Main ###
echo "### TRANManager IPC CLEAR ### "

if [ "$#" -eq 1 ] && [ "$1" = start ]; then
  debug_flag=0
  main_start
elif [ "$#" -eq 1 ] && [ "$1" = debug ]; then 
  debug_flag=1
  main_start
else
  usage_message
fi

