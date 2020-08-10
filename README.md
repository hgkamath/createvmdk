# createvmdk

The purpose of this tool is to create vmdk files. It became necessary as a substitute for `vboxmanage` tool from the VirtualBox which is normally used to create vmdk files. Installing virtualbox which takes 200Mb of space just to get the vboxmanage for vmdk creation ability is overkill.
``` 
vboxmanage internalcommands createrawvmdk -filename disk001.vmdk -rawdisk /dev/sda
vboxmanage internalcommands createrawvmdk -filename /path/to/file.vmdk -rawdisk /dev/sda -partitions 1,5
```

## Disclaimer
- use at your own peril 
- fix any bug you find
- author not responsible for any damages

## Contribute
I should be okay with any contributed patches as long as they improve the tool preserving the functionality

## notes
bash and pwsh are very commonly installed shell tools on both windows/linux systems. 
Of the two, at the time, bash seemed more ubiqutous, and so the choice was made to write this script in bash.

## Instructions to run
```
 win:
   pwsh: 
     & 'C:\Program Files\Git\usr\bin\bash.exe' './createvmdk.sh' -h
 lnx: 
   bash:
     bash ./createvmdk.sh -h
```


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
        -m lnx -c partitionedDevice -x CreateSubType:Target:ExtentInfo:Options
             CreateSubType: x=Zero/ b=BlockDevice/ f:Monolithic_flat/ s:Monolithic_sparse
             Target: VMDK_File/ Block File
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
