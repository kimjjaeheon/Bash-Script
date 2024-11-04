#!/bin/sh

#arg
char_set=$1

#directory
target=$2

function find_files()
{
	files=`find $target -type f`	

	file_cnt=0

	for F in ${files[@]}
	do
		file_charset=`file -bi $F | cut -d'=' -f2`
		file_charset=${file_charset^^}  #uppercase

		for C in ${provide_charset[@]}
		do
			if [ $file_charset = $C ]; then
				echo "find ${file_charset} file : $F"
				(( file_cnt+=1 ))
			fi
		done
	done
}

function euckr_to_utf8()
{
	#Find file
	files=`find $target -type f`	

	flag=0
	i=0

	if [ ! -d $target/backup/euckr ]; then
		mkdir $target/backup_euckr
	fi
	
	for F in ${files[@]}
	do
		file_charset=`file -bi $F | cut -d'=' -f2`
		file_charset=${file_charset^^}

		for C in ${provide_charset[@]}
		do
			if [ $file_charset = $C ]; then
				flag=1
			fi

			if [ "$flag" -eq 1 ]; then
				echo "[convert start]"
				echo ">> $F ( file charset : $file_charset ) ---> ( arg charset : $char_set )"
				cp $F $target/backup_euckr
				iconv -c -f euckr -t utf8 $F > $F.tmp 
				mv -f $F.tmp $F
				chmod 774 $F
				flag=0
			fi
		done
	done
}

function utf8_to_euckr()
{
	#Find file
	files=`find $target -type f`	

	flag=0
	i=0

	#Make backup directory
	if [ ! -d $target/backup_utf8 ]; then
		mkdir $target/backup_utf8
	fi
	
	for F in ${files[@]}
	do
		file_charset=`file -bi $F | cut -d'=' -f2`
		file_charset=${file_charset^^}

		for C in ${provide_charset[@]}
		do
			if [ $file_charset = $C ]; then
				flag=1
			fi

			if [ "$flag" -eq 1 ]; then
				echo "[convert start]"
				echo ">> $F ( file charset : $file_charset ) ---> ( arg charset : $char_set )"
				cp $F $target/backup_utf8
				iconv -c -f utf8 -t euckr $F > $F.tmp 
				mv -f $F.tmp $F
				chmod 774 $F
				flag=0
			fi
		done
	done
}

if ! [ "$#" -eq 2 ]; then
	echo "usage : ./iconv_jhkim.sh [encoding] [target_directory]"
	echo
	echo "encoding : utf8          | euckr"
	echo "           euckr -> utf8 | utf8 -> euckr"
	echo 
	exit
fi


if [ "$char_set" = "utf8" ]; then
	provide_charset=( "ISO8859" "ISO-8859" "ISO-8859-1" "EUCKR" "EUC-KR" "ISO_8859" )
	find_files
	
	if [ ${file_cnt} = 0 ]; then
		echo
		echo "파일이 검출되지 않았습니다. 인코딩을 확인하세요 "
		exit
	else
		echo
		echo "총 ${file_cnt} 개의 파일이 검출되었습니다."
		echo "위 파일을 $char_set 으로 바꾸시겠습니까? [ y or n ]"
	fi

	read ANSWER
	if [ "$ANSWER" = "y" ] || [ "$ANSWER" = "Y" ]; then
		euckr_to_utf8
	fi
fi

if [ "$char_set" = "euckr" ]; then
	provide_charset=( "UTF-8" "UTF8" )
	find_files

	if [ ${file_cnt} = 0 ]; then
		echo
		echo "파일이 검출되지 않았습니다. 인코딩을 확인하세요 "
		exit
	else
		echo
		echo "총 ${file_cnt} 개의 파일이 검출되었습니다."
		echo "위 파일을 $char_set 으로 바꾸시겠습니까? [ y or n ]"
	fi

	read ANSWER
	if [ "$ANSWER" = "y" ] || [ "$ANSWER" = "Y" ]; then
		utf8_to_euckr	
		echo "change encoding success"
	fi
fi
