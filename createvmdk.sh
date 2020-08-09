#!/usr/bin/env bash

# https://www.vmware.com/app/vmdk/?src=vmdk
# https://web.archive.org/web/20191225213417/https://www.vmware.com/app/vmdk/?src=vmdk
# https://www.vmware.com/support/developer/vddk/vmdk_50_technote.pdf
# https://web.archive.org/web/20200404235153/https://www.vmware.com/support/developer/vddk/vmdk_50_technote.pdf
# https://github.com/libyal/libvmdk/blob/master/documentation/VMWare%20Virtual%20Disk%20Format%20(VMDK).asciidoc

# win:
#   pwsh: 
#     & 'C:\Program Files\Git\usr\bin\bash.exe' './createvmdk.sh' -h
#   requires: qemu-img vmdkinfo 
# lnx: 
#   bash:
#     bash ./createvmdk.sh -h
#   requires: qemu-img vmdkinfo blockdev blkid

prm_toolname="createvmdk.sh"
prm_copyright="Copyright (C) 2020"
prm_license="MIT"
prm_tooldesc="command line tool to create vmdk files"
prm_toolver=0.1
prm_tooldate=20200809
prm_toolauthorname="Ganapathi Kamath"
prm_toolauthoremail="hgkamath@hotmail.com"

# Autodetecting machine type inside bash shell using bash shell environment variable,
# Perhaps the argument '-m' is not necessary, it only serves as a self-check for the user
if [ "x$prm_machtype" ] ; then
  case $OSTYPE in
    msys)
      prm_machtype="win"
      ;;
    linux-gnu)
      prm_machtype="lnx"
      ;;
  esac
fi

print_error() {
  # print string to stderr and exit from script
  opstream=/dev/stderr
  {
    echo "Error: $1" 
  }>$opstream
  exit 1
}

print_warning() {
  # print string to stderr and return from function continuing execution
  opstream=/dev/stderr
  {
    echo "Warning: $1"
  }>$opstream
}

print_log() {
  printf -v NOW '%(%F_%H:%M:%S)T' -1
  echo "$NOW: $1" >$prm_logflname
}

ansi_filter() {
  # remove color escape sequences from line read from stdin, which may be redirected
  local line
  local IFS=
  while read -r line || [[ "$line" ]]; do
    re=$'\e'"[\[(]*([0-9;])[@-n]"
    echo "${line//$re/}"
  done
}

# ISHbasename() is an internal bash shell equivalent of the external basename command
ISHbasename() { f=${1:0:1} ; p=${1%%*(/)} ; p=${p##*/} ; if [[ $f == "/" && $p == "" ]] ; then p="/" ; fi ; echo "$p" ;  } 

# ISHdirname() is an internal bash shell equivalent of the external dirname command
ISHdirname() { f=${1:0:1}; p="$1" ; b=$(ISHbasename $1) ;  p=${1%%*(/)} ; p=${p%%$b}; p=${p%%*(/)} ;  if [[ $p == "" ]] ; then if [[ $f != "/" ]] ; then p="." ; else p="/" ; fi ; fi ;  echo "$p" ; }

# mkemptyfile() creates a zero-byte file if given filename does not exist, mimicking behavior of touch in this case
mkemptyfile() { printf "" >>$1 ; }

ensure_valid_vals() {
  # Check whether the value in the first positional parameter matches 
  #   any one of the remaining positional parameters
  allparams=("$@")
  vartocheck="$1"
  notokay=1
  i1=1
  while [ $i1 -lt ${#allparams[@]} ] ; do
    if [ "x$vartocheck" == "x${allparams[$i1]}" ] ; then
      notokay=0
    fi
    i1=$((i1+1))
  done 
  echo "$notokay"
}

fpath_win2lnx() {
  local -n fpath=$1
  fpath=${fpath//\\/\/}
}

ascii2char() {
  [ "$1" -lt 256 ] || return 1
  printf "\\$(printf '%03o' "$1")"
}

char2ascii() {
  LC_CTYPE=C printf '%d' "'$1"
}

print_help() {
  echo "createvmdk.sh: command line tool to create vmdk files" 
  echo "  Usage:"
  echo "    createvmdk.sh -f <output_filename> -m <mach_type> -c <vmdk_createtype> <options> "
  for i in h f l m c x v ; do print_arghelp $i noerr ; done
  echo "  The use of some options may require the executables 'bash', 'pwsh', 'qemu-img', 'vmdkinfo', 'blockdev' or 'blkid' to be present in the PATH"
}

print_verinfo() {
  printf "Tool Name: ${prm_toolname}\nCopyright: ${prm_copyright}\nLicense: ${prm_license}\nDescription: ${prm_tooldesc}\nVersion: ${prm_toolver}\nDate: ${prm_tooldate}\nAuthor: ${prm_toolauthorname}\nEmail: ${prm_toolauthoremail}\n"
  exit 0
}

function print_arghelp {
  if [ "x$2" != "xnoerr" ] ; then
    echo "Error: $2"
    opstream=/dev/stderr
  else
    opstream=/dev/stdout
  fi
  {
    case $1 in
      h)
          echo " -h     print this help"
        ;;
      f)
          echo " -f <output_filename>     necessary, the output vmdk filename, must have extension '.vmdk'"
        ;;
      l)
          echo " -l <log_filename>        optional, the output vmdk filename, defaults to \$TEMP/vmdkcreate.log"
        ;;
      m)
          echo " -m <machine_type>        optional, autodetects, functions as a check, valid_values=win|lnx"
        ;;
      c)
          echo " -c <vmdk_createtype>     necessary, valid_values=fullDevice/partitionedDevice"
        ;;
      x)
          echo " -x extent information    necessary, Extents can be of various subtypes"
          echo "    ex"
          echo "      For vmdk_createtype fullDevice, only one -x option is to be specified, which is the full-device name "
          echo "        -m win -c fullDevice -x \"\\\\.\\PhysicalDrive2\" "
          echo "        -m lnx -c fullDevice -x /dev/sdc"
          echo "      For vmdk_createtype partitionedDevice, order matters, the -x option may be repeated to add more partitions"
          echo "        -m lnx -c partitionedDevice -x CreateSubType:Target:ExtentInfo:Options "
          echo "             CreateSubType: x=Zero/ b=BlockDevice/ f:Monolithic_flat/ s:Monolithic_sparse "
          echo "             Target: VMDK_File/ Block File "
          echo "               VMDK_File: sparse or flat vmdk-file "
          echo "             ExtentInfo: PartitionNos and Suffix options "
          echo "               PartitionNos: comma-separated-partitions, order matters "
          echo "               Suffix options: " 
          echo "                 'z' indicates to substitute target with a ZERO-createtype extent of the same size "
          echo "                 'lLuU' indicates to substitute targetname with label, part-label, UUID, partUUID respectively"
          echo "               A standalone option c, indicates to create a fresh monolithic-flat/sparse vmdk file "
          echo "            Options: Access,Size,Offset"
          echo "              Access: RW/ RDONLY/ NOACCESS    default=RW"
          echo "              Size:   No# of sectors, default inferred from target, required if Target not specified"
          echo "              Offset: is the sector number in the file/block to start at    default=0"
          echo "        -m lnx -c partitionedDevice -x z:/dev/sdc:3     A ZERO-createtype extent having the size of sdc3"
          echo "        -m lnx -c partitionedDevice -x z:::RW,2129921   A read-write-able zero-extent of given size"
          echo "        -m lnx -c partitionedDevice -x b:/dev/sdc       Use whole block device"
          echo "        -m lnx -c partitionedDevice -x b:/dev/sdc:3     Wrap only partition 3"
          echo "        -m lnx -c partitionedDevice -x b:/dev/sdc:1,4,3     Wrap 1,4,3 in that order skipping partition 2"
          echo "        -m lnx -c partitionedDevice -x b:/dev/sdc:1,3-5,6   Wrap partitions 1,3,4,5,6"
          echo "        -m lnx -c partitionedDevice -x b:/dev/sdc:1,2-4z,6  Map partitions 2,3,4 to a ZERO createtype extent"
          echo "        -m lnx -c partitionedDevice -x f:filepath.vmdk::    Wrap existing vmdk monolithic flat file as a partition "
          echo "        -m lnx -c partitionedDevice -x s:filepath.vmdk:c:   Create and wrap vmdk monolithic sparse file as a partition "
        ;;
      v)
          echo " -v     Print the name/version/date/author/email of vmdkcreate"
    esac
  } >$opstream
  if [ "x$2" != "xnoerr" ] ; then
    exit 1
  fi
}
shopt -s extglob
prm_partinfoarray=()
while getopts "hf:m:l:c:x:v" arg; do
  case $arg in
    h)
      print_help
      exit 0
      ;;
    f) 
      #if ! [[ -w $OPTARG ]] ; then  print_arghelp f "output filename is not a writable file" ; fi 
      if [[ -a $OPTARG && ! -f $OPTARG ]] ; then print_arghelp f "Output file $OPTARG is not a regular file" ; fi
      if [[ -f $OPTARG ]] ; then print_error "Output file $OPTARG already exists" ; fi
      if ! [[ -e $OPTARG ]] ; then mkemptyfile $OPTARG ; fi
      if ! [[ -f $OPTARG ]] ; then print_error "Output file $OPTARG could not be created" ; fi
      prm_flname="$OPTARG"
      if ! [[ $prm_flname =~ .*\.vmdk$ ]] ; then
        print_error "Filename $prm_flname should have extension .vmdk"
      fi
      if [ $prm_machtype == "win" ] ; then
        fpath_win2lnx prm_flname
      fi
      prm_basename=$(ISHbasename $prm_flname)
      prm_truncbasename=${prm_flname%.vmdk}
      prm_dirname=$(ISHdirname $prm_flname)
      ;;
    l)
      if ! [ -e $OPTARG ] ; then mkemptyfile $OPTARG ; fi
      if ! [ -w $OPTARG ] ; then  print_arghelp l "log filename is not a writable file" ; fi 
      prm_logflname="$OPTARG"
      ;;
    m) 
      vvals=("win" "lnx")
      ret=$(ensure_valid_vals $OPTARG ${vvals[@]})
      if [ $ret -ne 0 ] ; then print_arghelp m "unsupported mach_type $OPTARG, valid values: ${vvals[*]}" ; fi
      prm_machtype="$OPTARG"
      ;;
    c)
      vvals=("fullDevice" "partitionedDevice")
      ret=$(ensure_valid_vals $OPTARG ${vvals[@]})
      if [ $ret -ne 0 ] ; then print_arghelp c "unsupported vmdk_createtype $OPTARG, valid values: ${vvals[*]}" ; fi
      prm_vmdk_createtype="$OPTARG"
      ;;
    x)
      prm_partinfoarray=("${prm_partinfoarray[@]}" "$OPTARG")
      ;;
    v)
      print_verinfo
      ;;
  esac
done


case $OSTYPE in
  msys)
    if [ "$prm_machtype" != "win" ] ; then print_arghelp m "invoked for Windows machine. This command needs to be executed in Windows bash shell" ; fi
    if [ "x$PWSHBIN" == "x" ] ; then
      PWSHBIN=$(command -v pwsh)
      if [ "x$PWSHBIN" == "x" ] ; then
        print_error "Running on Windows, pwsh not found in PATH"
      fi
    fi
    if [ "x$QEMUIMGBIN" == "x" ] ; then
      QEMUIMGBIN=`pwsh -nop -c "(Get-Command qemu-img).Source"`  
    fi
    if [ "x$VMDKINFOBIN" == "x" ] ; then
      VMDKINFOBIN=`pwsh -nop -c '(Get-Command vmdkinfo).Source' | ansi_filter` 
    fi
    ;;
  linux-gnu)
    prm_machtype="lnx"
    if [ "$prm_machtype" != "lnx" ] ; then print_arghelp m "invoked for Linux machine. This command needs to be executed in Linux bash shell" ; fi
    if [ "x$QEMUIMGBIN" == "x" ] ; then
      QEMUIMGBIN=$(command -v qemu-img)
    fi
    if [ "x$VMDKINFOBIN" == "x" ] ; then
      VMDKINFOBIN=$(command -v vmdkinfo)
    fi
    if [ "x$BLOCKDEVBIN" == "x" ] ; then
      BLOCKDEVBIN=$(command -v blockdev)
    fi
    if [ "x$BLKIDBIN" == "x" ] ; then
      BLKIDBIN=$(command -v blkid)
    fi
esac
if [[ "x$QEMUIMGBIN" == "x" || ( "$prm_machtype" == "win" && "$QEMUIMGBIN" =~ ^Get-Command:.* ) ]] ; then
  print_warning "Binary 'qemu-img' not in path"
  QEMUIMGBIN=""
fi
if [[ "x$VMDKINFOBIN" == "x" || ( "$prm_machtype" == "win" && "$VMDKINFOBIN" =~ ^Get-Command:.* ) ]] ; then
  print_warning "Binary 'vmdkinfo' not in path"
  VMDINFOBIN=""
fi
if [[ "x$BLKIDBIN" == "x" && $prm_machtype == "lnx" ]] ; then
  print_warning "Binary 'blkid' not in path"
  BLKIDBIN=""
fi
if [[ "x$BLOCKDEVBIN" == "x" && $prm_machtype == "lnx" ]] ; then
  print_warning "Binary 'blockdev' not in path"
  BLOCKDEVBIN=""
fi

# Check if any necessary arg is empty
for prmi in prm_machtype prm_vmdk_createtype ; do
  if [ "x$(eval echo \$$prmi)" == "x" ] ; then
     echo "Error: parameter $prmi not supplied"
     print_help
     exit 1
  fi
done
if [ "x$prm_flname" == "x" ] ; then
  prm_flname=/dev/stdout
fi

if [ $prm_machtype == "win" -a "$prm_vmdk_createtype" == "partitionedDevice" ] ; then
  print_warning "For Windows, the vmdk CreateType 'PartitionedDevice' is not supported"
fi

if [ "x$prm_logflname" == "x" ] ; then
  case $prm_machtype in
    win)
      prm_logflname=`pwsh -nop -c 'Write-Output \$env:Temp'` 
      ;;
    lnx)
      if [ "x$TMP" == "x" ] ; then 
        prm_logflname=/tmp/createvmdk.log
      else
        prm_logflname=$TMP/createvmdk.log
      fi
      ;;
  esac
fi

cd ${prm_dirname}

strsplit () {
  local -n splitarr=$1
  local string="$2"
  local delimiter="$3"
  splitarr=()
  if [ -n "$string" ] ; then
    local part
    while read -d "$delimiter" part ; do
      splitarr=("${splitarr[@]}" "$part")
    done <<< "${string}${delimiter}"
  fi
}

winblockdevname_win2bash() {
  # convert a windows physicaldevice-name (\\.\PhysicalDevice2) 
  #   into corresponding msys/linux device-name (/dev/sdc)
  #   drvindex 0,1,2 -> a,b,c
  wname="$1"
  re='\\\\\.\\PhysicalDrive'
  if [[ $wname =~ ^$re ]] ; then 
    drvindex="${wname#$re}"
    re='^[0-9]+$'
    if ! [[ $drvindex =~ $re ]] ; then 
      print_arghelp x "$WNAME does not identify a drive index"
    fi
  else
    print_arghelp x '$WNAME does not seem to be a windows drive name of the form \\.\PhysicalDrive[0-9]'
  fi
  lname=/dev/sd`printf "\x$(printf %x $((97+$drvindex))) "`
  echo $lname
}

winblockdevname_number() {
  # remove the prefix part of the windows block device name
  wname="$1"
  if [[ $wname =~ .*sd.* ]] ; then
    re='*sd'
    wname0="${wname##$re}" # chop off everything upto 'sd'
    re='*([0-9])'
    wname0="${wname0%%$re}" # chop off numeric suffix
    # do an ascii conversion from a -> 0 (subtract 49)
    drvindex=$(ascii2char $(( $(char2ascii $wname0) - 49 )) )
  elif [[ $wname =~ .*PhysicalDrive.* ]] ; then
    re='\\\\\.\\PhysicalDrive'
    drvindex="${wname#$re}"
  else
    print_error "can't determine partition number from $wname"
  fi
  echo $drvindex
}

# CreateType fullDevice should have atleast 1 extent target specified
if [ ${#prm_partinfoarray[@]} != 1 -a "x$prm_vmdk_createtype" == "xfullDevice" ] ; then
  print_arghelp x "For vmdk_createtype fullDevice, only one full physical block device is to be specified"
fi
# CreateType fullDevice Target must be a block device
if [ ${#prm_partinfoarray[@]} == 1 -a "x$prm_vmdk_createtype" == "xfullDevice" ] ; then
  if [ "$prm_machtype" == "win" ] ; then 
    blkname=`winblockdevname_win2bash "${prm_partinfoarray[0]}"`
  else
    blkname="${prm_partinfoarray[0]}"
  fi
  if ! [ -a "$blkname" ] ; then
    print_arghelp x "blockfile '$blkname' does not exist for the vmdk_createtype fullDevice"
  else
    if ! [ -b  ${blkname} ] ; then
      print_arghelp x "file '$blkname' not a blockfile for the vmdk_createtype fullDevice"
    fi
  fi
fi

CID=`printf "%04x%04x" $RANDOM $RANDOM`
parentCID=ffffffff
encoding="windows-1252"
DDB_virtualHWVersion="4"
DDB_longContentID=`printf '%04x%04x%04x%04x%04x%04x%s' $RANDOM $RANDOM $RANDOM $RANDOM $RANDOM $RANDOM $CID `

definevar(){ IFS='\n' read -r -d '' ${1} || true; }

definevar tmpl_headsec <<'ENDT'
#Disk Descriptor File
version=1
encoding="windows-1252"
CID={VARSUB_CID}
parentCID={VARSUB_parentCID}

ENDT

definevar tmpl_createtype <<'ENDT'
# vmdk type
createType="{VARSUB_createtype}"
 
ENDT

definevar tmpl_ddb <<'ENDT'
# The Disk Data Base 
#DDB

ddb.adapterType = "ide"
ddb.geometry.cylinders = "16383"
ddb.geometry.heads = "255"
ddb.geometry.sectors = "63"
ddb.longContentID = "{VARSUB_DDB_longContentID}"
ddb.virtualHWVersion = "{VARSUB_DDB_virtualHWVersion}"
ENDT
# ddb.uuid = "60 00 C2 98 c0 d3 5e 02-6a d0 ad e1 c9 e6 05 97"


#file_extent_Description() {
#dummy test
#  echo "RW 10485760 FLAT \"Ubuntu-5GB-flat.vmdk\" 0"
#}

getSizeOfBlockDevice() {
  # get info of the physical block device 
  devname="$1"
  partnum="$2" # optional in linux, as it can be part of devname
  case $prm_machtype in
    "win")
      devnum=$(winblockdevname_number $devname)
      if [ "x$partnum" == "x" -o "x$partnum" == "x." ] ; then
        dsize=`pwsh -nop -c "(Get-PhysicalDisk -DeviceNumber $devnum).Size"`
      else
        dsize=`pwsh -nop -c "(Get-Partition -DiskNumber $devnum -PartitionNumber $partnum).Size"`
      fi
      esize=$((dsize/512))
      ;;
    "lnx")
      bdevname=$(ISHbasename $devname)
      re='+([^0-9])'
      #esize=`cat /sys/class/block/${bdevname}${partnum}/size`
      if [ "x$partnum" == "x" -o "x$partnum" == "x." ] ; then
        esize=`$BLOCKDEVBIN --getsz ${devname}`
      else
        esize=`$BLOCKDEVBIN --getsz ${devname}${partnum}`
      fi
      ;;
  esac
  echo "$esize"
}

fullDevice_print_extent_description() {
  devname="${prm_partinfoarray[0]}"
  esize=$(getSizeOfBlockDevice ${prm_partinfoarray[0]})
  if [ $esize -eq 0 ] ; then print_error "Cold not infer extent size from '${prm_partinfoarray[0]}'" ; fi
  echo "RW ${esize} FLAT \"$devname\" 0"
  echo ""
}

fetch_vmdkinfo() {
  local -n lvmdkinfoaarr=$1 
  vmdkfile=$2
  # read lines in file
  op=`$VMDKINFOBIN $vmdkfile`
  extnum=0
  while read line ; do
    if ! [[ $line =~ .*:.* ]] ; then continue ; fi
    lval=${line%%:*} ; lval=${lval##*([ ])}
    rval=${line##*:} ; rval=${rval##*([ 	])}
    if [[ $lval == "Extent" ]] ; then extnum=$rval ; fi 
    if [[ $rval =~ .*bytes.* ]] ; then
      rval=${rval##*\(} ; rval=${rval%% bytes\)}
      rval=$((rval / 512 ))
    fi 
    lvmdkinfoaarr["$extnum:$lval"]="$rval"
  done <<<"$op"
}

getBlockDevName() {
# getBlockDevName by-label $newExtTarget $extTarget
  local -n newExtTarget=$2
  eval `$BLKIDBIN $3 -o export`
  case "$1" in
    by-label)
      if [[ "x$LABEL" == "x" ]] ; then print_error "Device $3 LABEL unknown: blkid $3" ; fi 
      newExtTarget="/dev/disk/by-label/$LABEL"
      ;;
    by-partlabel)
      if [[ "x$PARTLABEL" == "x" ]] ; then print_error "Device $3 PARTLABEL unknown: blkid $3" ; fi 
      newExtTarget="/dev/disk/by-partlabel$PARTLABEL"
      ;;
    by-uuid)
      if [[ "x$UUID" == "x" ]] ; then print_error "Device $3 UUID unknown: blkid $3" ; fi 
      newExtTarget="/dev/disk/by-uuid/$UUID"
      ;;
    by-partuuid)
      if [[ "x$PARTUUID" == "x" ]] ; then print_error "Device $3 PARTUUID unknown: blkid $3" ; fi 
      newExtTarget="/dev/disk/by-partuuid$PARTUUID"
      ;;
  esac
}

partitionedDevice_print_coreextent_description() {
  # create vmdk leader extents
  # parse prm_partinfoarray
  declare -A vmdkinfoaarr=()
  extentRow=()
  i1=0
  while [ $i1 -lt ${#prm_partinfoarray[@]} ] ; do
    rslt=()
    strsplit rslt "${prm_partinfoarray[$i1]}" ':'
    CreateSubType="${rslt[0]}"
    Target="${rslt[1]}"
    PartNos="${rslt[2]}"
    Options="${rslt[3]}"
    partbit=()
    partnumrng=()
    partsfx=()
    re='!([0-9]*)'
    if [ "x${PartNos%%$re}" == "x" ] ; then 
      # no leading partition number in the partition info field
      nopartno=1
      partbit=(".")
      partnumrng=(".")
      partsfx=("$PartNos")
    else
      nopartno=0
      strsplit partbit0 "${PartNos}" ','
      i2=0
      while [ $i2 -lt ${#partbit0[@]} ] ; do
        # check for suffixes
        # remove alpabetic suffix, leaving the numeric-range suffix
 #re1='!([0-9\-]*)' ;  re2='*([0-9\-])' ;  echo  ${q1%%$re1} : ${q1##$re2}
        re='!([0-9\-]*)'
        currpartnumrng="${partbit0[$i2]%%$re}"
        # remove numeric-range prefix, leaving the alphabetic suffix
        if [ "x$currpartnumrng" == "x" ] ; then
          print_error "In '${prm_partinfoarray[$i]}', no partition numeric info : ${partbit[$i2]}"
        fi
        partnumrng=($partnumrng $currpartnumrng)
        re='+([0-9\-])' ;
        currpartsfx="${partbit0[$i2]##$re}"
        if [ "x$currpartsfx" == "x" ] ; then currpartsfx="." ; fi
        if [[ ${currpartnumrng} =~ .*-.* ]] ; then
          i3=${currpartnumrng%%-*}  
          i4=${currpartnumrng##*-}
        else
          i3=${currpartnumrng}
          i4=${currpartnumrng}
        fi
        if [ $i4 -lt $i3 ] ; then 
          print_error "In '${prm_partinfoarray[$i]}', invalid partition range $Partnos ${partbit[$i2]}"
        fi
        i5=$i3
        while [ $i5 -le $i4 ] ; do 
          partbit=(${partbit[@]} $i5)
          partsfx=(${partsfx[@]} $currpartsfx)
          i5=$((i5+1))
        done
        i2=$((i2+1))
      done
    fi
    rslt=()
    strsplit rslt "${Options}" ','
    extAccess0="${rslt[0]}"
    if [ "x$extAccess0" == "x" ] ; then extAccess0="RW" ; fi
    vvals=("RW" "RDONLY" "NOACCESS")
    ret=$(ensure_valid_vals $extAccess0 ${vvals[@]})
    if [ $ret -ne 0 ] ; then print_arghelp x "In '${prm_partinfoarray[$i]}', invalid extent access $extAccess0, valid values: ${vvals[*]}" ; fi
    extCount0="${rslt[1]}"
    extOffset0="${rslt[2]}"
    if [ "x$extOffset0" == "x" ] ; then extOffset0="0" ; fi
    i2=0
    while [ $i2 -lt ${#partbit[@]} ] ; do
      case $nopartno in
        0)
          if [[ ${partsfx[$i2]} =~ .*[zZ].* ]] ; then exttype="ZERO" ; fi
          ;;
        1)
          if [[ ${partsfx[$i2]} =~ .*[c].* ]] ; then createfile=1 ; else createfile=0 ; fi
          ;;
      esac
      extAccess=$extAccess0
      extOffset=$extOffset0
      case "$CreateSubType" in 
        "z")
          extType="ZERO"
          if [ "x$Target" == "x" ] ; then
            # extent count must be specified in the options
            if [ "x$extCount" == "x" ] ; then print_error "In '${prm_partinfoarray[$i]}', extent size cannot be infered" ; fi
            extType="ZERO"
          else
            # target has been specified
            # determine the target
            extCount="1002"
            extTarget="$Target"
          fi
          extentRow[${#extentRow[@]}]="$extAccess $extCount $extType \"$extTarget\" $extOffset"
          ;;
        "f")
          exttype="FLAT"
          extTarget="$Target"
          if [ $nopartno -eq 0 ] ; then printr_arghelp x "In '${prm_partinfoarray[$i1]}', the FLAT VMDK extent createtype should not have partitions specified" ; fi 
          if [ "x$Target" == "x" ] ; then print_arghelp x "In '${prm_partinfoarray[$i1]}', the FLAT VMDK extent createtype requires a target" ; fi
          if [ ! -f "$extTarget" ] ; then
            if [ $createfile -eq 0 ] ; then 
              print_arghelp x "In '${prm_partinfoarray[$i1]}', Target $extTarget not found" 
            fi
            if [ "x$extCount0" == "x" ] ; then print_arghelp x "In '${prm_partinfoarray[$i1]}', the extent size in blocks needs to be specified in order to create the vmdk file " ; fi
            # create the vmdk file
            # 1 extent = 512 bytes, 1Mb = 1024*1024 bytes => 2048 extents = 1Mb 
            sizemeg=$(( (extCount0+2047)/2048 )) # in order to round up to nearest number divisiable by 2048
            cmd="$QEMUIMGBIN create -f vmdk $extTarget ${sizemeg}M -o subformat=monolithicFlat"
            print_log "$cmd" 
            eval $cmd >>$prm_logflname
            vmdkinfoaarr=()
            fetch_vmdkinfo vmdkinfoaarr $extTarget
            extnum=1
            while [ "${vmdkinfoaarr[$extnum:Size]}" != "" ] ; do
              if [ "x$extOffset0" == "x" ] ; then extOffset=${vmdkinfoaarr["$extnum:Start Offset"]} ; else extOffset=$extOffset0 ; fi
              extTarget=${vmdkinfoaarr["$extnum:Filename"]}
              extCount=${vmdkinfoaarr["$extnum:Size"]}
              extCount=$((extCount - extOffset0))
              extentRow[${#extentRow[@]}]="$extAccess $extCount $extType \"$extTarget\" $extOffset"
              extnum=$((extnum+1))
            done
          else
            if [ $createfile -eq 1 ] ; then print_error "In '${prm_partinfoarray[$i1]}', Target $extTarget already exists, and hence cannot be created" ; fi
            vmdkinfoaarr=(["aa"]="qwsd")
            fetch_vmdkinfo vmdkinfoaarr $extTarget
            if [ "x$extOffset0" == "x" ] ; then extOffset=${vmdkinfoaarr["$extnum:Start Offset"]} ; else extOffset=$extOffset0 ; fi
            extTarget=${vmdkinfoaarr["1:Filename"]}
            extCount=${vmdkinfoaarr["1:Size"]}
            extCount=$((extCount - extOffset0))
            extentRow[${#extentRow[@]}]="$extAccess $extCount $extType \"$extTarget\" $extOffset"
          fi
          ;;
        "s")
          extType="SPARSE"
          extTarget="$Target"
          if [ $nopartno -eq 0 ] ; then printr_arghelp x "In '${prm_partinfoarray[$i1]}', the SPARSE VMDK extent createtype should not have partitions specified" ; fi 
          if [ "x$Target" == "x" ] ; then print_arghelp x "In '${prm_partinfoarray[$i1]}', the SPARSE VMDK extent createtype requires a target" ; fi
          if [ ! -f "$extTarget" ] ; then
            if [ $createfile -eq 0 ] ; then 
              print_arghelp x "In '${prm_partinfoarray[$i1]}', Target $extTarget not found" 
            fi
            if [ "x$extCount0" == "x" ] ; then print_arghelp x "In '${prm_partinfoarray[$i1]}', the extent size in blocks needs to be specified in order to create the vmdk file " ; fi
            # create the vmdk file
            # 1 extent = 512 bytes, 1Mb = 1024*1024 bytes => 2048 extents = 1Mb 
            sizemeg=$(( (extCount0+2047)/2048 )) # in order to round up to nearest number divisiable by 2048
            cmd="$QEMUIMGBIN create -f vmdk $extTarget ${sizemeg}M -o subformat=monolithicSparse"
            print_log "$cmd" 
            eval $cmd >>$prm_logflname
            vmdkinfoaarr=()
            fetch_vmdkinfo vmdkinfoaarr $extTarget
            extnum=1
            while [ "${vmdkinfoaarr[$extnum:Size]}" != "" ] ; do
              if [ "x$extOffset0" == "x" ] ; then extOffset=${vmdkinfoaarr["$extnum:Start Offset"]} ; else extOffset=$extOffset0 ; fi
              # for monolithicSparse the extTarget will be the vmdk file itself
              extCount=${vmdkinfoaarr["$extnum:Size"]}
              extCount=$((extCount - extOffset))
              extentRow[${#extentRow[@]}]="$extAccess $extCount $extType \"$extTarget\" $extOffset"
              extnum=$((extnum+1))
            done
          else
            if [ $createfile -eq 1 ] ; then print_error "In '${prm_partinfoarray[$i1]}', Target $extTarget already exists, and hence cannot be created" ; fi
            vmdkinfoaarr=()
            fetch_vmdkinfo vmdkinfoaarr $extTarget
            if [ "x$extOffset0" == "x" ] ; then extOffset=${vmdkinfoaarr["$extnum:Start Offset"]} ; else extOffset=$extOffset0 ; fi
            # for monolithicSparse the extTarget will be the vmdk file itself
            extCount=$vmdkinfoaarr["1:Size"]
            extCount=$((extCount - extOffset0))
            extentRow[${#extentRow[@]}]="$extAccess $extCount $extType \"$extTarget\" $extOffset"
          fi
          ;;
        "b")
          extType="FLAT"
          # determine extcount from the sparsefile 
          if [[ ${partsfx[$i2]} =~ .*[zZ].* ]] ; then extType="ZERO" ; fi
          if [ "x${partbit[$i2]}" == "x" -o "x${partbit[$i2]}" == "x." ] ; then
            extTarget="${Target}"
          else
            extTarget="${Target}${partbit[$i2]}"
          fi
          if [ "x$extCount0" == "x" ] ; then
            extCount=$(getSizeOfBlockDevice $Target ${partbit[$i2]})
            extCount=$((extCount - extOffset0))
          else
            $extCount=$extCount0
          fi
          if [[ ${partsfx[$i2]} =~ .*l.* ]] ; then 
            getBlockDevName by-label extTarget2 $extTarget
            extTarget="$extTarget2"
          elif [[ ${partsfx[$i2]} =~ .*L.* ]] ; then 
            getBlockDevName by-partlabel extTarget2 $extTarget
            extTarget="$extTarget2"
          elif [[ ${partsfx[$i2]} =~ .*u.* ]] ; then 
            getBlockDevName by-uuid extTarget2 $extTarget
            extTarget="$extTarget2"
          elif [[ ${partsfx[$i2]} =~ .*U.* ]] ; then 
            getBlockDevName by-partuuid extTarget2 $extTarget
            extTarget="$extTarget2"
          fi
          extentRow[${#extentRow[@]}]="$extAccess $extCount $extType \"$extTarget\" $extOffset"
          ;;
      esac
      i2=$((i2+1))
    done
    i1=$((i1+1))
  done
  i1=0
  while [ $i1 -lt ${#extentRow[@]} ] ; do
    printf "%s\n" "${extentRow[$i1]}"
    i1=$((i1+1))
  done
  # create vmdk tailend extents
}

partitionedDevice_print_extent_description() {
  # create vmdk start extent
  sizemeg=1 # 1 Mb =2048 sectors
  extTarget="${prm_truncbasename}-pt.vmdk"
  cmd="$QEMUIMGBIN create -f vmdk $extTarget ${sizemeg}M -o subformat=monolithicFlat"
  print_log "$cmd" 
  eval $cmd >>$prm_logflname
  echo "RW 63 FLAT \"${prm_truncbasename}-pt-flat.vmdk\" 0"
  echo "RW 1985 ZERO"
  partitionedDevice_print_coreextent_description
  echo "RW 143 ZERO"
  echo "RW 33 FLAT \"${prm_truncbasename}-pt-flat.vmdk\" 63"
  printf "\n"
  # create vmdk end extent
}

print_extent_description() {
  case $prm_vmdk_createtype in
    "fullDevice")
      fullDevice_print_extent_description
      ;;
    "partitionedDevice")
      partitionedDevice_print_extent_description
      ;;
  esac
}

{
  vop_headsec="$tmpl_headsec"
  for kk in CID parentCID ; do ss="{VARSUB_$kk}" ; vv=${!kk} ; vop_headsec="${vop_headsec//${ss}/${vv}}" ; done
  printf "${vop_headsec}" 

  vop_createtype="${tmpl_createtype//\{VARSUB_createtype\}/$prm_vmdk_createtype}"
  printf "$vop_createtype"

  print_extent_description

  vop_ddb="${tmpl_ddb}"
  for kk in DDB_virtualHWVersion DDB_longContentID ; do ss="{VARSUB_$kk}" ; vv=${!kk} ; vop_ddb="${vop_ddb//${ss}/${vv}}" ; done
  printf "${vop_ddb}"
}>$prm_flname
