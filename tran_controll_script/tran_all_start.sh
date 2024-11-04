#!/bin/bash
# Version : 1.1
# Main Patch content
# 1. tomcat check change
#    ps -ef | grep tomcat .... -> ps -ef | grep "TRAN_UI_SERVER" ...
# 2. Add Web server check
#    WEBSERVER_TYPE environment check
# 3. Remove While
# 4. Check status 
#    [OK/NOK]

USER="$USER"
OK=0
NOK=1

SVRPID=`ps -fu$USER | grep -w svrchkd | grep -vw grep | grep -vw vi | grep -vw vim | grep -vw tail | awk '{print$2}'`
PROCESSES=`egrep "PROCESS_[0-9]{2}" $TRAN_SVR_HOME/config/svr.cfg | grep -v "^#" | awk '{if($3==1) print $6}' | uniq`

if [ "$SVRPID" = "" ]; then
    PID_PROCESSES=$PROCESSES
else
    PID_PROCESSES=`ps -fu$USER | grep -w $SVRPID | grep -vw grep | grep -vw vi | grep -vw vim | grep -vw tail | awk '{print $8}' | sort | uniq`
    PID_PROCESSES="${PID_PROCESSES##*/}"
fi

for p in $PID_PROCESSES
do
    res=`echo $PROCESSES | grep -w $p`
    if [ "$res" = "" ]; then
        # new process
        PROCESSES+=`printf " %s" $p`
    fi

done

function count_process
{   
    TOT_P_NUM=0 
    for proc in $PID_PROCESSES
    do      P_NUM=`ps -fu$USER | grep -w $proc | grep -vw grep | grep -vw find | grep -vw tail | grep -vw db_load_files | grep -vw vim | grep -vw vi | wc -l`
      let TOT_P_NUM=TOT_P_NUM+P_NUM
    done
    
    echo $TOT_P_NUM
}

function show_process
{ 
  echo " " 
  for proc in $PROCESSES
  do
    if [ "$proc" = "procmon.d" ]; then
      echo "--------------------------------------------------------------------------"
      pids=`ps -ef | grep -w $USER | grep -vw grep | grep procmon.d | awk '{print $2}'`
      for pid in $pids
      do
        ps -ef | grep -w $USER | grep -vw grep | grep -vw tail | grep -vw vi | grep -vw vim | grep procmon.d
        ps -ef | grep -vw grep | grep -vw tail | grep -vw vi | grep -vw vim | grep $pid | grep -vw procmon.d
      done
      echo "--------------------------------------------------------------------------"
    else
      ps -fu$USER | grep -w $proc | grep -vw grep | grep -vw find | grep -vw tail | grep -vw db_load_files | grep -vw vi | grep -vw vim
    fi
  done
  echo " "
}

function show_status
{
  echo
  echo "---------------------------------------------"
  echo "----------거래추적 서버 전체 현황------------"
  echo "---------------------------------------------"

  for proc in $PROCESSES
  do
    P_CNT=`ps -fu$USER | grep -w $proc | grep -vw grep | grep -vw find | grep -vw tail | grep -vw db_load_files | grep -vw vim | grep -vw vi | wc -l`
    C_CNT=`egrep "PROCESS_[0-9]{2}" $TRAN_SVR_HOME/config/svr.cfg | grep $proc | grep -v "^#" | awk '{if($3==1) print $6}' | wc -l`

    if [ "$P_CNT" = "$C_CNT" ]; then
      RES="OK"
    else
      RES="NOK"
    fi

    printf " %-20s   ( %d / %d )    [ %s ]\n" $proc $P_CNT $C_CNT $RES
  done

  echo "---------------------------------------------"
}

#프로세스 상태 체크
TOT_P_NUM=$(count_process)

function engine_check
{
 	e_chk=`ps -fu$USER | grep svrchkd | grep -vw grep | grep -vw tail | grep -vw vi | wc -l`
}

function engine_start
{
	e_cnt=0
	engine_check
	if [ $e_chk -eq 0 ]; then
		echo "거래 추적 서버 프로세스 기동 중..."
		sh $TRAN_SVR_HOME/scripts/check_svr_dir.sh
		sh $TRAN_SVR_HOME/bin/svrchkd.sh
		sleep 5
		echo "거래 추적 서버 프로세스를 다음과 같이 기동하였습니다."
		show_process
		show_status

		engine_check
		if [ $e_chk -ne 0 ]; then
			echo
			echo " TRANManager Engine을 성공적으로 기동하였습니다."
			echo
			engine_result="OK"
		else
			echo
			echo " TRANManager Engine 시작 실패."
			echo " TRANManager Engine 확인 필요."
			echo " TRANManager Engine 시작 명령은 아래와 같습니다."
			echo " ${TRAN_SVR_HOME}/bin/tran_server.sh start."
			engine_result="NOK"
		fi
	else
		echo 
		echo " TRANManager 프로세스가 이미 작동 되고 있습니다."
		echo ""
		engine_result="OK"

	fi

	printf ' %-20s ' "Engine : "
	printf "[ %s ]\n" ${engine_result}
	echo ""

	if [ $engine_result = "NOK" ]; then
		exit 0
	fi
}

function rb_check
{
	rb_status_cmd=`$PG_HOME/bin/pg_ctl status -D $PG_RB_HOME 2>&1 >/dev/null`
	rb_status=`echo $?`
}

function data_check
{
	data_status_cmd=`$PG_HOME/bin/pg_ctl status -D $PG_DATA_HOME 2>&1 >/dev/null`
	data_status=`echo $?`
}

function db_start
{
	rb_check
	rb_cnt=0
	echo "*) RB DB CHECK"
	if [ ${rb_status} -eq 0 ]; then
		echo 
		echo " TRANManager RB DB가 이미 작동 되고 있습니다."
		echo ""
		rb_result="OK"
	else
		echo " TRANManager RB DB를 시작합니다."
		$PG_HOME/bin/pg_ctl start -D $PG_RB_HOME -l $PG_RB_HOME/pg_tranm_rb.log	
		sleep 2

		rb_check
		if [ ${rb_status} -eq 0 ]; then
			echo " TRANManager RB DB를 성공적으로 시작하였습니다."
			echo ""
			rb_result="OK"
		else
			echo " TRANManager RB DB 시작 실패."
			echo " TRANManager RB DB 확인 필요."
			echo " RB DB 시작 명령은 아래와 같습니다."
			echo " ${TRAN_SVR_HOME}/bin/pg.sh rb start"
			echo ""
			rb_result="NOK"
		fi
	fi
	
	data_db_type=`echo $DATA_DB_TYPE`
	echo 
	echo "*) DATA DB CHECK"

	if [ $data_db_type = "postgresql" ]; then
		data_check
		data_cnt=0;

		if [ ${data_status} -eq 0 ]; then
			echo 
			echo " TRANManager DATA DB가 이미 작동 되고 있습니다."
			echo ""
			data_result="OK"
		else
			echo " TRANManager DATA DB를 시작합니다."
			$PG_HOME/bin/pg_ctl start -D $PG_DATA_HOME -l $PG_DATA_HOME/pg_tranm_data.log		
			sleep 2

			data_check
			if [ ${data_status} -eq 0 ]; then
				echo " TRANManager RB DB를 성공적으로 실행하였습니다."
				data_result="OK"
			else
				echo " TRANManager DATA DB 시작 실패."
				echo " TRANManager DATA DB 확인 필요."
				echo " DATA DB 시작 명령은 아래와 같습니다."
				echo " ${TRAN_SVR_HOME}/bin/pg.sh data start"
				echo ""
				data_result="NOK"
			fi
		fi
	else
		echo " DATA DB 타입이 \" $data_db_type \" 입니다."
		echo " DATA DB를 시작하려면 DBA에게 요청하세요."
		data_result="OK"
	fi

	printf ' %-20s ' "RB DB : "
	printf "[ %s ]\n" ${rb_result}
	printf ' %-20s ' "DATA DB : "
	printf "[ %s ]\n" ${data_result}
	echo ""

	if [ $rb_result = "NOK" ] || [ $data_result = "NOK" ]; then
		exit 0
	fi
}

function tomcat_start
{
	t_chk=`ps -fu$USER | grep "TRAN_UI_SERVER" | grep -vw grep | grep -vw tail | grep -vw vi | wc -l`
	if [ ${t_chk} -ne 0 ]; then
		echo
		echo " TRANManager Tomcat이 이미 시작되어있습니다."
		echo " DB가 재기동 되었다면, Tomcat 재기동을 권장합니다."
		echo " tomcat : `ps -fu$USER | grep "TRAN_UI_SERVER" | grep -vw grep | grep -vw tail | grep -vw vi | wc -l`"
		echo ""
		tomcat_result="OK"
	else
		$TOMCAT_HOME/bin/tomup.sh
		sleep 2

		t_chk=`ps -fu$USER | grep "TRAN_UI_SERVER" | grep -vw grep | grep -vw tail | grep -vw vi | wc -l`
		if [ ${t_chk} -ne 0 ]; then
			echo
			echo " TRANManager Tomcat을 성공적으로 시작하였습니다."
			echo ""
			tomcat_result="OK"
		else
			echo " TRANManager Tomcat 실행 중 입니다."
			sleep 2

			t_chk=`ps -fu$USER | grep "TRAN_UI_SERVER" | grep -vw grep | grep -vw tail | grep -vw vi | wc -l`
			if [ ${t_chk} -ne 0 ]; then
				echo
				echo " TRANManager Tomcat을 성공적으로 시작하였습니다."
				echo ""
				tomcat_result="OK"
			else 
				echo " TRANManager Tomcat 시작 실패. "
				echo " TRANManager Tomcat 확인 필요. "
				echo " Tomcat 시작 명령은 아래와 같습니다. "
				echo " $TOMCAT_HOME/bin/tomup.sh "
				echo ""
				tomcat_result="NOK"
			fi
		fi
	fi

	printf ' %-20s ' "Tomcat : "
	printf "[ %s ]\n" ${tomcat_result}
	echo ""

	if [ $tomcat_result = "NOK" ]; then
		exit 0
	fi
}

function web_start
{
        echo " WEBSEVER_TYPE : $WEBSERVER_TYPE"
        if [ $WEBSERVER_TYPE = "nginx" ]; then
                nginx_start
		web_result=$nginx_result
                echo
                echo
        elif [ $WEBSERVER_TYPE = "apache" ]; then
                apache_start
		web_result=$apache_result
                echo
                echo
        else
		echo " please check WEBSERVER_TYPE environment (${TRAN_SVR_HOME}/env/db.env)"
                echo " WEB SERVER down fail"
                echo
                echo
		web_result="NOK"
        fi

	printf ' %-20s ' "WEB SERVER : "
	printf "[ %s ]\n" ${web_result}
	echo ""

	if [ $web_result = "NOK" ]; then
		exit 0
	fi
}

function nginx_start
{
	n_chk=`ps -fu$USER | grep nginx | grep -vw grep | grep -vw tail | grep -vw vi | wc -l`

	if [ ${n_chk} -ne 0 ]; then
		echo
		echo " TRANManager Nginx 가 이미 시작되어있습니다."
		echo ""
		nginx_result="OK"
	else
		${TRAN_SVR_HOME}/bin/nginx.sh start
		sleep 2

		n_chk=`ps -fu$USER | grep nginx | grep -vw grep | grep -vw tail | grep -vw vi | wc -l`
		if [ ${n_chk} -ne 0 ]; then
			echo
			echo " TRANManager Nginx를 성공적으로 시작하였습니다."
			echo ""
			nginx_result="OK"
		else
			echo " TRANManager Nginx 실행 중 입니다."
			sleep 2

			n_chk=`ps -fu$USER | grep nginx | grep -vw grep | grep -vw tail | grep -vw vi | wc -l`
			if [ ${n_chk} -ne 0 ]; then
				echo
				echo " TRANManager Nginx 를 성공적으로 시작하였습니다."
				echo ""
				nginx_result="OK"
			else
				echo " TRANManager Nginx 시작 실패. "
				echo " TRANManager Nginx 확인 필요. "
				echo " Nginx 시작 명령은 아래와 같습니다. "
				echo " ${TRAN_SVR_HOME}/bin/nginx.sh start "
				echo ""
				nginx_result="NOK"
			fi
		fi
	fi
}

function apache_start
{

	if [ -z ${APACHE_HOME} ] || [ ! -f "${APACHE_HOME}/bin/apachectl" ]; then
		echo " \$APACHE_HOME not found"
		echo " 1. $APACHE_HOME 이 정확한지 확인바랍니다."
		echo " 2. $TRAN_SVR_HOME/env/db.env 파일에서 WEBSERVER_TYPE 정의가 제대로 되어있는지 확인바랍니다." 
		echo ""
		apache_result="NOK"
	else
		a_chk=`ps -fu$USER | grep httpd | grep -vw grep | grep -vw tail | grep -vw vi | wc -l` 
		if [ ! -z ${a_chk} ]; then
			echo
			echo " TRANManager Apache가 이미 실행 중 입니다."
			echo ""
			apache_result="OK"
		else
			$APACHE_HOME/bin/apachectl start
			sleep 2

			a_chk=`ps -fu$USER | grep httpd | grep -vw grep | grep -vw tail | grep -vw vi | wc -l`
			if [ ${a_chk} -ne 0 ]; then
				echo
				echo " TRANManager Apache를 성공적으로 시작하였습니다."
				echo ""
				apaceh_result="OK"
			else
				echo " TRANManager Apache 를 실행 중 입니다."
				sleep 2

				a_chk=`ps -fu$USER | grep httpd | grep -vw grep | grep -vw tail | grep -vw vi | wc -l`
				if [ ${a_chk} -ne 0 ]; then
					echo
					echo " TRANManager Apache를 성공적으로 시작하였습니다."
					echo ""
					apache_result="OK"
				else
					if [ ${a_chk} -ne 0 ]; then
						echo
						echo " TRANManager Apache를 성공적으로 시작하였습니다."
						echo ""
						apache_result="OK"
					else
						echo " TRANManager Apache 시작 실패."
						echo " TRANManager Apache 확인 필요."
						echo " TRANManager Apache 시작 명령은 아래와 같습니다."
						echo " ${APACHE_HOME}/bin/apachectl start"
						apaceh_result="NOK"
					fi
				fi
			fi
		fi
	fi
}

##############################
########### MAIN #############
##############################
echo
echo
echo "========================================"
echo " TRANManager START SHELL [`date +%Y-%m-%d\"  \"%H:%M:%S`]"
echo "========================================"
# 1) DB Start
echo "# 1. DB START "
echo "---------------------------------------------"
db_start
echo
echo

# 2) Tomcat Start
echo "# 2. TOMCAT START "
echo "---------------------------------------------"
tomcat_start
echo
echo

# 3) WEB Start
echo "# 3. WEB SERVER START "
echo "---------------------------------------------"
web_start
echo
echo

# 4) Engine Start
echo "# 4. TRANManager Engine START "
echo "---------------------------------------------"
engine_start
echo
echo
