#!/bin/bash

date=$(date +%Y_%m_%d)
origin_path=`pwd`
user=( `cat /root/backup_script/backup.cfg | egrep "USER_[0-9]{2}" | awk '{print $3}'` )
user_path=( `cat /root/backup_script/backup.cfg | egrep "USER_[0-9]{2}" | awk '{print $4}'` )
backup_dir=`cat /root/backup_script/backup.cfg | grep "TARGET_DIR" | awk '{for(i=3;i<=NF;i++)print $i}'`  
backup_other=( `cat /root/backup_script/backup.cfg | grep "TARGET_DIR_OTHER" | awk '{for(i=3;i<=NF;i++)print $i}'` )
backup_path=( `cat /root/backup_script/backup.cfg | grep "BACKUP_PATH" | awk '{for(i=3;i<=NF;i++)print $i}'` )

###########################################
# BACKUP_PATH Directory CHECK #
###########################################

function backup_path_check
{
	echo "DIR CHECK START"
	for M in ${backup_path[@]}
	do
		if [ ! -d $M ]; then
			echo "$M doesn't exist"
			echo ">> BACKUP_PATH(backup.cfg file) check OR MOUNT check \"$M\""
			exit 1
		fi
		echo "$M exist"
	done
}

###########################################
# USER COUNT #
###########################################

function user_count
{
	echo "\"USER CHECK\""
	user_num=0;
	for U in ${user[@]}
	do
		(( user_num=$user_num+1 ))
	done
	(( user_num=$user_num-1 ))
}


###########################################
# MAKE BACKUP DIRECTORY #
###########################################

function user_dir_check
{
	user+=( "root" )
        for U in ${user[@]}
        do
                for BP in ${backup_path[@]}
                do
                        cd $BP
                        if [ ! -d $U ] || [ ! -d $U/server ]; then
                                mkdir -p $U/server
                                if [ $? = 0 ]; then
                                        echo ">> Make Backup Directory($U) complete"
                                else
                                        echo ">> Make Backup Directory($U) fail"
                                fi
                        fi
                done
        done
}


###########################################
# BACKUP #
###########################################

function backup_account
{
	for I in `seq 0 1 $user_num`
	do
		cd ${user_path[$I]}

		for BP in ${backup_path[@]}
		do
			tar -zcvhf "$BP/${user[$I]}/server/server_${user[$I]}_$date.tar.gz" $backup_dir > /dev/null
			if [ -f $BP/${user[$I]}/server/server_${user[$I]}_$date.tar.gz ]; then
				echo ">> [Make tar file complete] : server_${user[$I]}_$date.tar.gz (path : $BP)"
			else
				echo ">> [Make tar file fail] : server_${user[$I]}_$date.tar.gz (path : $BP)"
			fi
		done
	done
}

###########################################
# OTHER BACKUP #
###########################################

function backup_root
{
	for BP in ${backup_path[@]}
	do
		tar -zcvhf "$BP/root/server/server_root_$date.tar.gz" $backup_other > /dev/null 
		if [ -f $BP/root/server/server_root_$date.tar.gz ]; then
			echo ">> [Make tar file complete] : server_root_$date.tar.gz (path : $BP)"
		else
			echo ">> [Make tar file fail] : server_root_$date.tar.gz (path : $BP)"
		fi
	done
}

###########################################
# GIT BACKUP #
###########################################

function backup_git
{
	gitlab-backup create > /dev/null

	cd /var/opt/gitlab/backups

	git_backup_tar=( `ls *_${date}_*.tar` )

	for BP in ${backup_path[@]}
	do
		cp "${git_backup_tar[0]}" "${BP}/git/${git_backup_tar[0]}"

		if [ $? = 0 ]; then
			echo ">> [copy complete] : $git_backup_tar (path : $BP)"
		else
			echo ">> [copy fail] : $git_backup_tar (path : $BP)"
		fi
	done

	#for GIT in $git_backup_tar
	#do
	#	gzip "$GIT"
	#	if [ $? = 0 ]; then
	#		echo ">> Make gzip file complete : $GIT.gz"
	#	else
	#		echo ">> Make gzip file fail : $GIT.gz"
	#	fi

	#	for BP in {$backup_path[@]}
	#	do
        #                if [ ! -d $BP/server]; then
	#			mkdir $BP/git
	#		fi

	#		cp "$GIT.gz" "$BP/git"
	#		if [ $? = 0 ]; then
	#			echo ">> Backup complete : $GIT.gz file"
	#		else
	#			echo ">> Backup fail : $GIT.gz file"
	#		fi
	#	done
	#	rm -rf "$GIT.gz"
	#done
	
	rm -rf "$git_backup_tar"

	if [ $? = 0 ]; then
		echo ">> [remove complete] : $git_backup_tar"
	else
		echo ">> [remove fail] : $git_backup_tar"
	fi
}


###########################################
# BACKUP CYCLE #
###########################################

function backup_clean
{
	for BP in ${backup_path[@]}
	do
		find $BP -mtime +7 -type f | xargs rm -f 2>&1 >/dev/null
		if [ "$?" = 0 ]; then
			echo ">> Clean complete (target : $BP)"
		else
			echo ">> Clean fail (target : $BP)"
		fi
	done
}

 
###########################################
# MAIN #
###########################################

{
user_count

if [ "$#" -eq 1 ] && [ "$1" = start ]; then
	echo "\"BACKUP START(ALL)\""
	backup_path_check
	user_dir_check
	echo "\"USER BACKUP START\""
	backup_account
	backup_root
	echo "\"GIT BACKUP START\""
	#backup_git
	echo "\"BACKUP CLEAN CHECK\""
	backup_clean
fi

if [ "$#" -eq 1 ] && [ "$1" = start1 ]; then
	echo "BACKUP START(ACCOUNT)"
	backup_path_check
	user_dir_check
	backup_account
	backup_clean
fi

if [ "$#" -eq 1 ] && [ "$1" = start2 ]; then
	echo "BACKUP START(OTHER)"
	backup_path_check
	backup_root
	#backup_clean
fi

if [ "$#" -eq 1 ] && [ "$1" = startgit ]; then
	echo "BACKUP START(GIT)"
	echo "BACKUP FAIL(GIT)"
	#backup_path_check
	#backup_git
	#backup_clean
fi

if [ "$#" != 1 ]; then
	echo " usage : backup start | start1 | start2 | startgit "
	echo " start : backup account + other + gitlab "
	echo " start1 : backup only account "
	echo " start2 : backup only other "
	echo " startgit : backup only gitlab "
fi
} > /log/backup/backup_${date}_log 
cd $origin_path
