#!/bin/sh

DATE=`date +%Y-%m-%d`
TIME=`date +%H:%M:%S`
LOG_DIR=$TRAN_LOG_HOME/restart_log
ALOG=$TRAN_LOG_HOME/restart_log/$1_restart_$DATE.log
HOSTNAME=`hostname`

TRAN_XXX_HOME=""
TRAN_SYS_TYPE=""
TRAN_SHELL=""
TRAN_PROC=""

RETRY_COUNT=0
TRAN_STATUS=0

#로그 디렉토리 확인
function log_file_check
{
	if [ ! -f $ALOG ]; then
		if [ ! -d $LOG_DIR ]; then
			mkdir -p $LOG_DIR	
			echo "** LOG DIRECTORY && LOG FILE MAKE COMPELETE **" > $ALOG
		else
			echo "** LOG FILE MAKE COMPELETE **" > $ALOG	
		fi	
	fi
}

if [ "$1" == "agt" ];
then
	log_file_check
    TRAN_XXX_HOME=$TRAN_AGT_HOME
    TRAN_SYS_TYPE="AGENT"
    TRAN_SHELL="tran_agent.sh"
    TRAN_PROC="agtchkd"
    echo "[$TRAN_SYS_TYPE RESTART PROCEDURE START]" >> $ALOG
    echo `date` >> $ALOG
elif [ "$1" == "svr" ];
then
	log_file_check
    TRAN_XXX_HOME=$TRAN_SVR_HOME
    TRAN_SYS_TYPE="SERVER"
    TRAN_SHELL="tran_server.sh"
    TRAN_PROC="svrchkd"
    echo "[$TRAN_SYS_TYPE RESTART PROCEDURE START]" >> $ALOG
    echo `date` >> $ALOG
else
    echo "usage : $0 option"
    echo "(option : agt, svr)"
    exit
fi


function tran_validation
{
    if [ $TRAN_XXX_HOME -a -d $TRAN_XXX_HOME ];
    then
        echo  " STEP_1 -> VALIDATION SUCCESS!" >> $ALOG
    else
        echo  " STEP_1 -> VALIDATION : FAIL! DIR NOT FOUND. ($TRAN_XXX_HOME)" >> $ALOG
        exit
    fi
} >> $ALOG

function tran_check
{
	TRAN_STATUS=`ps -ef | awk '{if ( $1 == "tranmgr8" ) print $0}' | grep $TRAN_PROC | grep $USER | grep -v grep | grep -v tail | grep -v vi | awk '{print $3}'`
	if [ -z $TRAN_STATUS ];
	then
		TRAN_STATUS=0
	fi
} >> $ALOG

function tran_stop
{
    if [ ${TRAN_STATUS} -eq 1 ]; then
        while [ $RETRY_COUNT -lt 3 ] 
        do
            echo " STEP_2 -> $TRAN_SYS_TYPE stop..." >> $ALOG
            echo "y" | $TRAN_XXX_HOME/bin/$TRAN_SHELL stop
            sleep 10;
            tran_check
            if [ $TRAN_STATUS -eq 0 ]; then
                RETRY_COUNT=3
                echo " STEP_2 -> $TRAN_SYS_TYPE stop success" >> $ALOG
            else
                RETRY_COUNT=$(($RETRY_COUNT+1))
                echo " STEP_2 -> $TRAN_SYS_TYPE stop fail. retry... (retry_count:$RETRY_COUNT)" >> $ALOG
				if [ $RETRY_COUNT -eq 3 ]; then
					echo " STEP_2 -> $TRAN_SYS_TYPE stop fail. please check process" >> $ALOG
					exit	
				fi
            fi
        done
    else
        echo " STEP_2 -> $TRAN_SYS_TYPE is not running. skip stop procedure." >> $ALOG
    fi
}

function tran_start
{
    RETRY_COUNT=0
    if [ ${TRAN_STATUS} -eq 0 ]; then
        while [ $RETRY_COUNT -lt 5 ] 
        do
            if [ $TRAN_STATUS -eq 0 ]
            then
                echo " STEP_3 -> $TRAN_SYS_TYPE Start." >> $ALOG
                $TRAN_XXX_HOME/bin/$TRAN_SHELL start
                sleep 1
            else
                echo " STEP_3 -> $TRAN_SYS_TYPE is running. Start fail!" >> $ALOG
            fi
            tran_check
            if [ $TRAN_STATUS -eq 1 ]; then
                RETRY_COUNT=5
                echo " STEP_3 -> $TRAN_SYS_TYPE start success" >> $ALOG
				
				SERVER_STAT=`/sw/tranmgr8/svr/bin/tran_server.sh show | tail -10`
				
				SEND_MSG=`echo -e 발송시간 : [$TIME] "\n" 호스트명 : [$HOSTNAME] "\n" $SERVER_STAT`
				#nohup /sw/tranmgr8/hubgateway/send2gateway 1 02309_이경원 "[$HOSTNAME] TRAN 수집 서버 재기동 정상 완료 알림" "$SEND_MSG" Y > /dev/null 2>&1 &
				
            else
                RETRY_COUNT=$(($RETRY_COUNT+1))
                echo " STEP_3 -> $TRAN_SYS_TYPE start fail. retry... (retry_count:$RETRY_COUNT)" >> $ALOG

				if [ $RETRY_COUNT -eq 1 ]; then
					echo echo " STEP_4 -> $TRAN_SYS_TYPE start fail. retry fail... (retry_count:$RETRY_COUNT)" >> $ALOG
				
					SEND_MSG=`echo -e 발송시간 : [$TIME] "\n"호스트명 : [$HOSTNAME] "\n"`
					#nohup /sw/tranmgr8/hubgateway/send2gateway 1 02309_이경원 "[$HOSTNAME] TRAN 수집 서버 재기동 정상 완료 알림" "$SEND_MSG" Y > /dev/null 2>&1 &
				fi
            fi
        done
    fi
} >> ALOG

date
#재기동 하기 위한 기본값 설정 및 검증
tran_validation
#기동 상태 확인
tran_check
#중지
tran_stop
#기동
tran_start
