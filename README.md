# createvmdk

The purpose of this tool is to create vmdk files that wrap raw disks/partitions. It became necessary as a substitute for `vboxmanage` tool from the Oracle-VirtualBox or VMware vdisk-manager which could be used used to create vmdk files. Installing virtualbox,for examples, takes 200Mb of space, which is overkill for just wanting to create vmdks. The vmdk-s thus created can then be used by kvm, qemu, virsh, guestfish, etc. 
``` 
vboxmanage internalcommands createrawvmdk -filename \path\to\file.vmdk -rawdisk /dev/sda
createvmdk.sh -f \path\to\disk001.vmdk -c fullDevice -x b:/dev/sda 

vboxmanage internalcommands createrawvmdk -filename /path/to/file.vmdk -rawdisk /dev/sda -partitions 1,5
createvmdk.sh -f /path/to/file.vmdk -c partitionedDevice -x b:/dev/sda:1,5 
```

## Disclaimer
- Use at your own peril 
- Not well tested
- There may be bugs
- No-one is responsible for any damages

## Contribute bug fixes and feature additions
Contributed patches are welcome as long as they improve the tool while preserving the functionality.

## notes
bash and pwsh are very commonly installed shell tools on both windows/linux systems. 
Of the two, at the time, most functionality lie in linux, bash seemed more ubiqutous.Hence, the choice to write this tool as a bash-script.

## Instructions to run
```
 win:
   pwsh: 
     & 'C:\Program Files\Git\usr\bin\bash.exe' './createvmdk.sh' -h
 lnx: 
   bash:
     bash ./createvmdk.sh -h
```

## Dependencies/requires
- Win: [git-bash 2.28.0](https://git-scm.com/),  Powershell 7.0.3 [pwsh](https://github.com/PowerShell/PowerShell/releases/), libyal/libvmdk [vmdkinfo](https://github.com/libyal/libvmdk), qemu [qemu-img](https://qemu.weilnetz.de/w64/)
- Linux: bash-5, vmdkinfo, qemu-img, block-dev, blkid

## Command line options
```
createvmdk.sh: command line tool to create vmdk files
  Usage:
    createvmdk.sh -f <output_filename> -m <mach_type> -c <vmdk_createtype> <options>
 -h     print this help
 -f <output_filename>     necessary, the output vmdk filename, must have extension '.vmdk'
 -l <log_filename>        optional, the output vmdk filename, defaults to $TEMP/vmdkcreate.log
 -m <machine_type>        optional, autodetects, functions as a check, valid_values=win|lnx
 -c <vmdk_createtype>     necessary, valid_values=fullDevice/partitionedDevice
 -x extent information    necessary, Extents can be of various subtypes
    ex
      For vmdk_createtype fullDevice, only one -x option is to be specified, which is the full-device name
        -m win -c fullDevice -x "\\.\PhysicalDrive2"
        -m lnx -c fullDevice -x /dev/sdc
      For vmdk_createtype partitionedDevice, order matters, the -x option may be repeated to add more partitions
        This vmdk_createtype is suported only for linux
        -m lnx -c partitionedDevice -x CreateSubType:Target:ExtentInfo:Options
             CreateSubType: x=Zero/ b=BlockDevice/ f:Monolithic_flat/ s:Monolithic_sparse
             Target: VMDK_File/ Block-device File
               VMDK_File: sparse or flat vmdk-file
             ExtentInfo: PartitionNos and Suffix options
               PartitionNos: comma-separated-partitions, order matters
               Suffix options:
                 'z' indicates to substitute target with a ZERO-createtype extent of the same size
                 'lLuU' indicates to substitute targetname with label, part-label, UUID, partUUID respectively
               A standalone option c, indicates to create a fresh monolithic-flat/sparse vmdk file
            Options: Access,Size,Offset
              Access: RW/ RDONLY/ NOACCESS    default=RW
              Size:   No# of sectors, default inferred from target, required if Target not specified
              Offset: is the sector number in the file/block to start at    default=0
        -m lnx -c partitionedDevice -x z:/dev/sdc:3     A ZERO-createtype extent having the size of sdc3
        -m lnx -c partitionedDevice -x z:::RW,2129921   A read-write-able zero-extent of given size
        -m lnx -c partitionedDevice -x b:/dev/sdc       Use whole block device
        -m lnx -c partitionedDevice -x b:/dev/sdc:3     Wrap only partition 3
        -m lnx -c partitionedDevice -x b:/dev/sdc:1,4,3     Wrap 1,4,3 in that order skipping partition 2
        -m lnx -c partitionedDevice -x b:/dev/sdc:1,3-5,6   Wrap partitions 1,3,4,5,6
        -m lnx -c partitionedDevice -x b:/dev/sdc:1,2-4z,6  Map partitions 2,3,4 to a ZERO createtype extent
        -m lnx -c partitionedDevice -x f:filepath.vmdk::    Wrap existing vmdk monolithic flat file as a partition
        -m lnx -c partitionedDevice -x s:filepath.vmdk:c:   Create and wrap vmdk monolithic sparse file as a partition
 -v     Print the name/version/date/author/email of vmdkcreate
  The use of some options may require the executables 'bash', 'pwsh', 'qemu-img', 'vmdkinfo', 'blockdev' or 'blkid' to
be present in the PATH
```

## Examples

1) Windows - CreateType: fullDevice

```
PS E:\gitrepos\createvmdk> & 'C:\Program Files\Git\usr\bin\bash.exe' 'E:/gitrepos/createvmdk/createvmdk.sh' -f E:\tmp\testvc.vmdk -c fullDevice -x "\\.\PhysicalDrive2" 
PS E:\gitrepos\createvmdk> type E:\tmp\testvc.vmdk
#Disk Descriptor File
version=1
encoding="windows-1252"
CID=79ac3c13
parentCID=ffffffff

# vmdk type
createType="fullDevice"

RW 3907029168 FLAT "\\.\PhysicalDrive2" 0

# The Disk Data Base
#DDB

ddb.adapterType = "ide"
ddb.geometry.cylinders = "16383"
ddb.geometry.heads = "255"
ddb.geometry.sectors = "63"
ddb.longContentID = "416f042477902c76158b0d0379ac3c13"
ddb.virtualHWVersion = "4"
```

2) Linux - CreateType: partitionedDevice 
```
[root@fedora createvmdk]# rm /tmp/testvc* -f ; ./createvmdk.sh -f /tmp/testvc.vmdk -c partitionedDevice -x "b:/dev/sda::" -x "b:/dev/sdc:1,2z,3-5,7L:"  -x "b:/dev/sdb:1"  ; cat /tmp/testvc.vmdk
#Disk Descriptor File
version=1
encoding="windows-1252"
CID=035e3acb
parentCID=ffffffff

# vmdk type
createType="partitionedDevice"

RW 63 FLAT "/tmp/testvc-pt-flat.vmdk" 0
RW 1985 ZERO
RW 16777216 FLAT "/dev/sda" 0
RW 192937983 FLAT "/dev/sdc1" 0
RW 2097152 ZERO "/dev/sdc2" 0
RW 2097152 FLAT "/dev/sdc3" 0
RW 2097152 FLAT "/dev/sdc4" 0
RW 195035136 FLAT "/dev/sdc5" 0
RW 195035136 FLAT "/dev/disk/by-partlabel/D1_1600_1623" 0
RW 32765919 FLAT "/dev/sdb1" 0
RW 143 ZERO
RW 33 FLAT "/tmp/testvc-pt-flat.vmdk" 63

# The Disk Data Base
#DDB

ddb.adapterType = "ide"
ddb.geometry.cylinders = "16383"
ddb.geometry.heads = "255"
ddb.geometry.sectors = "63"
ddb.longContentID = "6caa371639b74eee042b2d39035e3acb"
ddb.virtualHWVersion = "4"
[root@fedora createvmdk]# ls -l /tmp/testvc*.*
-rw-r--r--. 1 root root 1048576 Aug  9 21:41 /tmp/testvc-pt-flat.vmdk
-rw-r--r--. 1 root root     313 Aug  9 21:41 /tmp/testvc-pt.vmdk
-rw-r--r--. 1 root root     735 Aug  9 21:41 /tmp/testvc.vmdk
```

### Notes on building libyal/libvmdk  vmdkinfo 

```
https://github.com/libyal/libvmdk
https://github.com/libyal/libvmdk/wiki/Building

https://repo.msys2.org/distrib/
C:\tmp\Downloads\msys2-i686-latest.exe

https://www.msys2.org/news/#2020-06-29-new-packages
https://www.msys2.org/news/#2020-06-29-new-packagers
[]# pacman-key --init
[]# pacman-key --populate msys2
[]# pacman-key --refresh-keys
[]# curl -O http://repo.msys2.org/msys/x86_64/msys2-keyring-r21.b39fb11-1-any.pkg.tar.xz
[]# pacman -U msys2-keyring-r21.b39fb11-1-any.pkg.tar.xz

[]# pacman -Syu 
[]# pacman -S mingw-w64-i686-gcc mingw-w64-i686-libtool mingw-w64-cross-binutils mingw-w64-i686-gettext autoconf automake vim git pkgconfig intltool make
./autogen.sh

[]# cd /c/tmp
[]# git clone https://github.com/libyal/libvmdk

[]# # create a.sh file for compiling
[]# cat a.sh
#!/bin/sh

CC=/mingw32/bin/i686-w64-mingw32-gcc
CXX=/mingw32/bin/i686-w64-mingw32-g++
AR=/mingw32/bin/i686-w64-mingw32-gcc-ar
OBJDUMP=/opt/i686-w64-mingw32/bin/objdump
RANLIB=/mingw32/bin/i686-w64-mingw32-gcc-ranlib
STRIP=/opt/i686-w64-mingw32/bin/strip
MINGWFLAGS="-mwin32 -mconsole -march=i586 "
CFLAGS="$MINGWFLAGS"
CXXFLAGS="$MINGWFLAGS"

CC=$CC CXX=$CXX AR=$AR OBJDUMP=$OBJDUMP RANLIB=$RANLIB STRIP=$STRIP ./configure --host=i686-w64-mingw32 --prefix=/e/apps_win/libvmdk --enable-winapi=yes

CC=$CC CXX=$CXX AR=$AR OBJDUMP=$OBJDUMP RANLIB=$RANLIB STRIP=$STRIP CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" make



[]# ldd /e/apps_win/libvmdk/bin/vmdkinfo.exe
        ntdll.dll => /c/WINDOWS/SYSTEM32/ntdll.dll (0x77700000)
        KERNEL32.DLL => /c/WINDOWS/System32/KERNEL32.DLL (0x75800000)
        KERNELBASE.dll => /c/WINDOWS/System32/KERNELBASE.dll (0x75b80000)
        libvmdk-1.dll => /e/apps_win/libvmdk/bin/libvmdk-1.dll (0x70300000)
        msvcrt.dll => /c/WINDOWS/System32/msvcrt.dll (0x76d80000)
        libwinpthread-1.dll => /mingw32/bin/libwinpthread-1.dll (0x64b40000)
        zlib1.dll => /mingw32/bin/zlib1.dll (0x63080000)
        libgcc_s_dw2-1.dll => /mingw32/bin/libgcc_s_dw2-1.dll (0x6eb40000)

```
