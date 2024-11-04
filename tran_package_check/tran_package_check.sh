#!/bin/bash

# INIT
packages=( "readline" "readline-devel" "gettext" "gettext-devel" "openjdk" \
		"openjdk-devel" "expat-devel" "zlib" "zlib-devel" "make" "cmake" "gcc" "gcc-c++" \
		"unzip" "vim-common" "llvm-toolset" "openssl-devel" "perl" "pcre-devel" "pcre2-devel" "libicu-devel" "wget" "gdb" "python3" "unixODBC" "bison" "flex")
# Linux 7.9 이상 필요한 패키지
above_os_7_9_packages=( "libzstd-devel" "autoconf" "automake" "libxslt-devel" "libxml2-devel" "glibc-langpack-ko" "iconv" )
# Linux 8 이상 필요한 패키지
above_os_8_packages=( "net-tools" "llvm-toolset" "libnsl" "lz4-devel" )
# Linux 9 이상 필요한 패키지
above_os_9_packages=( "libtirpc" ) 

function add_package
{
  packages[$pack_cnt]="$1"
  (( pack_cnt++ ))
}

function os_check
{
  os=`uname -s`
  if [ $os = "Linux" ]; then
    echo "os : Linux"
    os_version=`cat /etc/os-release | grep REDHAT_SUPPORT_PRODUCT_VERSION | awk -F '=' '{print$2}'`
    os_major_version=`cat /etc/os-release | grep REDHAT_SUPPORT_PRODUCT_VERSION | awk -F '=' '{print$2}' | \
      awk -F '.' '{print$1}' | tr -d '\"'`
    os_minor_version=`cat /etc/os-release | grep REDHAT_SUPPORT_PRODUCT_VERSION | awk -F '=' '{print$2}' | \
      awk -F '.' '{print$2}' | tr -d '\"'`
    echo "os version : $os_version"
    echo "os major version : $os_major_version"
    echo "os minor version : $os_minor_version"
  else
    echo "os : $os  "
  fi	
}

function package_check
{
  # 패키지 개수 확인
  # 패키지 배열의 마지막 인덱스 값 확인
  pack_cnt=0
  for P in ${packages[@]}
  do
    (( pack_cnt++ ))
  done

  # 버전별 필요한 패키지 추가
  # Linux 7.9 이상일 때 필요한 패키지 추가
  if [ $os_major_version -ge 7 ]; then
    if [ $os_major_version -eq 7 ]; then
      if [ $os_minor_version -ge 9 ]; then
        for P7 in ${above_os_7_9_packages[@]}
        do
          add_package $P7
        done
      fi
    else
      for P7 in ${above_os_7_9_packages[@]}
      do
        add_package $P7
      done
    fi
  fi

  # Linux 8 이상일 때 필요한 패키지 추가
  if [ $os_major_version -ge 8 ]; then
    for P8 in ${above_os_8_packages[@]} 
    do
      add_package $P8
    done
  else
    # 8버전 이상은 lz4-devel 패키지
    # 8버전 미만은 liblz4-dev 패키지
    add_package "liblz4-dev"
  fi

  # Linux 9 이상일 때 필요한 패키지 추가
  if [ $os_major_version -ge 9 ]; then
    for P9 in ${above_os_9_packages[@]}
    do
      add_package "$P9"
    done
  fi

  for P in ${packages[@]}
  {
    STATUS=( `rpm -qa | grep $P` )
    if [ -z ${STATUS[0]} ]; then
      RES="NOK"
      nok_packages+=($P )
    else
      RES="OK"
    fi
    printf " %-20s   [ %s ]\n" $P $RES
  }
}

function print_main
{
  echo ""
  echo "---------------------------------------------"
  echo "--------거래추적 패키지 전체 현황 -----------"
  echo "---------------------------------------------"
    package_check
  echo ""
  if [ ! -z ${nok_packages[0]} ]; then
    echo "yum install ${nok_packages[@]}"
  fi
  echo ""
}

os_check
if [ $os = "Linux" ]; then
  print_main
else
  echo "> 지원하는 OS 가 아닙니다."
fi
