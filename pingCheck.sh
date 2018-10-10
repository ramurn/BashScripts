#!/bin/bash

##########################################################################################################
# Author/Contributor: Raja T / Muthu Murugan  MRK                                                        #                                                                        #
# Purpose: This is a highlevel module based shell script written in order to accomplish FMO migration    #
#          tasks quickly and error free                                                                  #
# Current Version : 4.3                                                                                  #
# Supported OS: OEL 6.9, RHEL 6.9, 7.2                                                                   #
# Furture Scope: To create custom config script to change sub functions and with mutiple sub-functions   #
##########################################################################################################

######################## Version Info   ##################################
# 1.0 - 18 Jan 2018 - Base Script with OS partion and sync OS data
# 1.1 - 24 Jan 2018 - Added Application FS creation, DT Package Install
# 2.0 - 11 Apl 2018 - Added DB OS layout, user, kernel and ulimit parameters
# 2.1 - 15 May-2018 - Re-created script with Module based structure
# 3.0 - 29 May 2018 - Integerated OS and DB parts in single script
# 3.1 - 08 Jun 2018 - Added new functions for Azure related post migration OS tasks
# 3.2 - 15 Jun 2018 - Added new function to perform DT Cleanup tasks
#                   - Added additional checks for user and os in main function
# 3.3 - 21 Jun 2018 - Enhanced sub-functions and help options for osp1, osp2 & osp3 tasks
# 3.4 - 25 Jun 2018 - Tweaked multiple functions to get more usage availing fn_gen* functions
#                   - Additional validation for fn_gen_osvg and fn_gen_oslv & introduced fn_vglvfs
# 4.0 - 10 Jul 2018 - Added SRA Tools Removed functions with logging
# 4.1 - 01 Aug 2018 - Unified all config files and mapped with respective function
#                   - Bug fix in SRA tools removal log function
# 4.2 - 14 Aug 2018 - Bug Fix
# 4.3 - 03 Sep 2018 - Minor Enhancements


#----------------------------------------------------------------------------------------------------#

##################### Argument Assignment #####################
nargs=$#; option=$1; custopt=$2; custopt1=$3; custopt2=$4;

##################### Global Variable Declarations #####################
TS=$(date +%Y%m%d-%H%M)
WDIR=/tmp/migr
TDIR=${WDIR}/tmp
FLOG=${WDIR}/tmpScrtoutFull.${TS}
LOGFILE=${WDIR}/scriptLog.${TS}


#Standard Config Files
FSTAB=/etc/fstab					# fn_gen_oslv, fn_db_fsrsync, fn_os_fsrsync_ba, fn_os_fsrsync_buo				
SEFILE=/etc/selinux/config				# fn_gen_selinuxoff
SUDOFILE=/etc/sudoers					# fn_gen_dtmigsudo, fn_gen_dxcsupt
HOSTFILE=/etc/hosts					# fn_gen_etchosts
TZFILE=/etc/sysconfig/clock				# fn_gen_ostimezone
ACCESSFILE=/etc/security/access.conf			# fn_gen_dxcsupt
SYSFILE=/etc/sysctl.conf				# fn_db_kernel
LIMITSFILE=/etc/security/limits.conf			# fn_db_ulimits

#Script Config Files
DTFILE=/tmp/DoubleTake-8.1.1.808.0-1.x86_64.rpm		# fn_gen_dtinstall
SCPTESS=${WDIR}/checkfileforscript			# fn_gen_scriptessentials
CTAB=${WDIR}/crontab.txt				# fn_sra_osit_rm



#Script Temporary Files (Will be deleted by end of script execution)
UNAVBL=${TDIR}/essential_unavbl				# fn_gen_scriptessentials
SBFN=${TDIR}/luxsubfn					# fn_gen_help
SBFNC=${TDIR}/luxsubfncust				# fn_gen_custom
TMDIR=/mnt/test						# fn_gen_fscleanup
XPKG=${TDIR}/pkg-xorg-x11.txt				# dbp4
XMPKG=${TDIR}/pkg-xorg-missing.txt			# dbp4
APKG=${TDIR}/pkg-additional.txt				# dbp4
AMPKG=${TDIR}/pkg-additional-missing.txt		# dbp4
TFTAB=${TDIR}/part2uuid					# fn_db_fsrsync
GFILE=/${TDIR}/groupadd					# dbuserngrp
TSHMX=${TDIR}/shmmax

##################### Validation Segment #####################
if [ `id -u` -ne 0 ]; then echo "Please execute this script as ROOT user. Quiting" && exit 1; fi
if [ -f /etc/redhat-release -a -f /etc/oracle-release ]; then OS=oel; elif [ -f /etc/redhat-release ]; then OS=rhel; fi
if [[ $OS == oel || $OS == rhel ]]; then continue; else echo "This script supports OEL and RHEL only. Quiting" && exit 1; fi
if [[ $OS == oel ]]; then OSVER=`awk '{print $NF}' /etc/oracle-release`; fi
if [[ $OS == rhel ]]; then OSVER=`awk '{print $(NF-1)}' /etc/redhat-release`; fi

##################### Creating base directories #####################
mkdir ${WDIR} ${TDIR} 2>/dev/null; cd ${WDIR}

#----------------------------------------------------------------------------------------------------#

######################################################################################################
#My Format Functions
fn_bkp ()
{
for arg; do
 if [ -f ${arg}.${TS} ]; then cp -p ${arg}.${TS} ${arg}.${TS}.bkp; fi
 cp -p ${arg} ${arg}.${TS}
done
}

fn_lines ()
{
echo "........................................................................................... $@"
}

LOG ()
{
echo "${TS} : ${FNVAR} : $@"
echo "${TS} : ${FNVAR} : $@" >> ${LOGFILE}
}


######################################################################################################
#Generic Functions


#########---------------------------***-------------------------------#########

fn_gen_help ()
{
echo " "; echo "CAUTION: This script should be executed in FMO server. Retreat if this is a CMO server";
echo " "
echo "............................................................"
echo "Script Syntax:            fmoscript.sh <OPTION>"
echo "............................................................"
echo " "
echo "Example:                  fmoscript.sh dbp1"
echo " "
echo "Valid options are:        <osp1|osp2|osp3>"
echo "                          <dbp1|dbp2|dbp3|dbp4|asmpart>"
echo "                          <azagtchk|azpostdt|dtclean|sraclean>"
echo "                          <custom|listfn|preout|vglvfs|asmpart>"
echo " "
echo "          osp1        --> OS: Server Phase 1: Create root disk (/dev/sda) partitions & Reboot"
echo "          osp2        --> OS: Server Phase 2: Rsync OS Filesystems to new partitions & Reboot"
echo "          osp3        --> OS: Server Phase 3: Install DT & perform other DT pre-requisites"
echo " "
echo "          dbp1        --> DB: Server Phase 1: Create root disk (/dev/sda) partitions for DB layout & Reboot"
echo "          dbp2        --> DB: Server Phase 2: Rsync OS Filesystems to new partitions & Reboot"
echo "          dbp3        --> DB: Server Phase 3: Cleanup FS and set Azure parameters"
echo "          dbp4        --> DB: Server Phase 4: Get FMO ready for DB pre-requisites"
echo " "
echo "          azagtchk    --> AZ: Check status of Azure Agents"
echo "          azpostdt    --> DT: Post Double-Take Cutover Tasks for Azure VM"
echo "          dtclean     --> DT: Perform DT cleanup task. Use with option 'all' or 'help' to see options"
echo "          sraclean    --> OS: Remove SRA tools. Use 'all' or help to see options"
echo " "
echo "          custom      --> Run sub-function of this script. Use \"listfn\" option to view available options"
echo "          listfn      --> List reusable sub-functions used in this script"
echo "          preout      --> OS: Take Basic OS info of Linux config"
echo "          vglvfs      --> OS: Create VG,LV and FS for App FS (Uses Template file)"
echo "          asmpart     --> DB: Create ASM single partition disk"
echo " "
}

#########---------------------------***-------------------------------#########
fn_gen_caution ()
{
echo "************************ Caution **********************"
echo "This script must be executed in just deployed FMO"
echo "Delaying for 5 seconds if you want to interrupt"
echo "*******************************************************"
echo " "; sleep 5;
}

#########---------------------------***-------------------------------#########
fn_gen_scriptessentials ()
{
touch ${SCPTESS}; rm ${UNAVBL} 2>/dev/null;
pkg="ksh bc rsync lvm2 redhat-lsb nc telnet traceroute"
echo " "; echo "This script will install \"${pkg}\", if it is not already installed"; echo " "; sleep 3;
echo "###################### VALIDATING ########################";
echo "----------------------------------------------------------";
for i in ${pkg}; do  rpm -qa | grep $i 1>/dev/null 2>&1; if [ $? -ne 0 ]; then
echo -e "|\t ${i} \t\t|    Not Installed     |"; echo ${i} >> ${UNAVBL}; else
echo -e "|\t ${i} \t\t|    Installed         |"; fi; done;
echo "----------------------------------------------------------"; echo " ";
if [ -f ${UNAVBL} ]; then echo "Installing unavailable packages"; echo " ";
for i in `cat ${UNAVBL}`; do echo "................................. Installing ${i} "; yum install -y $i; done; 
echo  " ";
echo "###################### RE-VALIDATING ########################";
echo "-------------------------------------------------------------";
for i in ${pkg}; do  rpm -qa | grep $i 1>/dev/null 2>&1; if [ $? -ne 0 ]; then
echo -e "|\t ${i} \t\t|    Not Installed     |"; echo ${i} >> ${UNAVBL}; else
echo -e "|\t ${i} \t\t|    Installed         |"; fi; done;
echo "-------------------------------------------------------------"; echo " ";
else
echo "All the packages are already installed"; echo " "; fi
}

#########---------------------------***-------------------------------#########
fn_gen_subfn ()
{
echo " "; echo "Following sub-functions can be called separately using custom option"; echo " ";
echo "fn_gen_help
fn_gen_caution
fn_gen_scriptessentials
fn_gen_ostimezone
fn_gen_etchosts
fn_gen_osfsmkfs
fn_gen_fscleanup
fn_gen_chtmpperm
fn_gen_osvg
fn_gen_oslv
fn_gen_selinuxoff
fn_gen_iptablesoff
fn_gen_dtmigsudo
fn_gen_dtinstall
fn_gen_preout
fn_gen_dxcsupt

fn_db_asmdisk
fn_db_fileperm
fn_db_kernel
fn_db_ulimits
fn_db_userngrp
fn_db_fileperm

fn_gen_azswapsize
fn_gen_azpeerdns
fn_gen_azdnssearch
fn_gen_azntpserver

fn_az_agentcheck" > ${SBFN}; cat ${SBFN}; rm ${SBFN}; echo " ";
}



#########---------------------------***-------------------------------#########

fn_gen_etchosts ()
{
#Call it with required interface name. Preparing defaults
LETH=`ifconfig | egrep 'eth0|ens1|eno1' | head -1 | awk '{print $1}' | cut -d: -f1`
ETH=${1:-$LETH}
fn_bkp ${HOSTFILE}
sed -i "/[^#]/ s/\(^.*$(hostname -s).*$\)/#\ \1/" $HOSTFILE
echo "$(ifconfig ${ETH}  | grep -w 'inet' | awk '{print $2}' | cut -d: -f2)       $(hostname -s).luxgroup.net     $(hostname -s)"  >> ${HOSTFILE}
echo "${HOSTFILE} updated with IP address of $ETH"
}


#########---------------------------***-------------------------------#########
fn_gen_osfsmkfs ()
{
##Pass two arguments while calling this function
if [ $# -ne 2 ]; then
echo "ERROR:"
echo "       Syntax:  fn_dbfsosmkfs <last partition number> <filesystem type>"; echo " ";
echo "       Example: fn_dbfsosmkfs 8 ext4";
echo "                fn_dbfsosmkfs 9 xfs"; exit 1; fi;

echo "Creating FS on newly creation partition";
for p in $(seq 3 $1); do
if test $p -ne 4; then
echo "........................................................... Creating filesystem in /dev/sda${p}";
mkfs.$2 /dev/sda${p}; fi; done; echo " ";
}


#########---------------------------***-------------------------------#########
fn_gen_fscleanup ()
{
if test $# -lt 1; then echo "SYNTAX ERROR: fn_gen_fscleanup <dir1> <dir1>";exit 1; fi
DIRS=$@
echo "Cleaning up hiddenfiles in / filesystem"
rmdir ${TMDIR} 2>/dev/null; mkdir ${TMDIR} && mount /dev/sda2 ${TMDIR}; cd ${TMDIR};
echo " "; echo "FS Utilizaition before cleanup in ${TMDIR}";
for fs in ${DIRS}; do du -sh ${fs} ${fs}* ; done;
echo " "; echo "Initiating Cleanup";
for fs in ${DIRS}; do echo "cleaning up on ${fs}"; mv ${TMDIR}/${fs}/* /${fs}-new/ && mv /${fs}-new ${fs}-org; rm -rf ${fs}-org; done;
echo "Cleanup done on hidden directories";
for fs in ${DIRS}; do du -sh ${fs}*; done;
echo " "; echo "FS Utilization after cleanup of files";
for fs in ${DIRS}; do du -sh /${fs} $fs ${fs}-org 2>/dev/null; done;
cd /; umount ${TMDIR} && rmdir ${TMDIR};
echo "Cleaning hiddenfiles completed. Temporary directory unmounted";
echo " "
}


#########---------------------------***-------------------------------#########
fn_gen_chtmpperm ()
{
chmod 1777 /tmp; echo "Set Stickybit permission to /tmp directory";
}

#########---------------------------***-------------------------------#########
fn_gen_osvg ()
{

mvg=$1
mpd=$2

ans=" "

if [ $# -ne 2 ]; then
echo " "
echo "SYNTAX ERROR: fn_gen_osvg <vgname> <diskname>"
echo "Example:      fn_gen_osvg vgu01 /dev/sdc"
echo " "; exit 1;
fi

echo " "
echo "Creating VG \"${mvg}\" using \"${mpd}\""
pvcreate ${mpd} 2>/dev/null
if [ `echo $?` -eq 0 ]; then vgcreate ${mvg} ${mpd}; else echo "ERROR: pv might already exists. Recheck inputs!"; fi
echo " ";
}


#########---------------------------***-------------------------------#########
fn_gen_oslv ()
{

LVFILE=$1

if test $# -ne 1; then
echo "Syntax Error:       fn_gen_oslv <Template Filename>"
echo "Example:            fn_gen_oslv /tmp/lvfile"; exit 1; fi

echo "Creating Logical Volumes as per ${LVFILE}"
echo " "

cat ${LVFILE} | while read line; do
l=`echo $line | cut -d: -f1`; s=`echo $line | cut -d: -f2`; v=`echo $line | cut -d: -f3`; m=`echo $line | cut -d: -f4`; f=`echo $line | cut -d: -f5`;
vgs --noheadings | grep -w ${v} 1>/dev/null 2>&1; if test $? -eq 0; then
lvcreate --name=$l -L${s}G /dev/${v}; if test $? -ne 0; then echo "WARN: Not adequate space. Rounding off with remaining space"; lvcreate --name=$l -l100%FREE /dev/$v; fi; else echo "ERROR: VG /dev/${v} doesn't exists"; exit 1; fi; done
echo " ";


cat ${LVFILE} | while read line; do
l=`echo $line | cut -d: -f1`; s=`echo $line | cut -d: -f2`; v=`echo $line | cut -d: -f3`; m=`echo $line | cut -d: -f4`; f=`echo $line | cut -d: -f5`;
echo ".................................................................................... Creating FileSystem on $l";
if [ -L /dev/$v/$l ]; then mkfs.${f} /dev/$v/$l; else echo "ERROR: LV /dev/$v/$l path doesn't exists"; exit 1; fi; done
echo " "
echo "Filesystems are created as per LVs mentioned in ${LVFILE}"
echo " "

echo "Appending ${FSTAB} with new mounts"
fn_bkp ${FSTAB}
echo " " >> ${FSTAB}
cat ${LVFILE} | while read line; do
l=`echo $line | cut -d: -f1`; s=`echo $line | cut -d: -f2`; v=`echo $line | cut -d: -f3`; m=`echo $line | cut -d: -f4`; f=`echo $line | cut -d: -f5`;
echo "/dev/${v}/${l}       ${m}          ${f}          defaults 1 2" >> ${FSTAB}; done
echo " " >> ${FSTAB};
echo "${FSTAB} file updated"; echo " ";
echo "Creating mountpoint & mounting newly created LVs"
cat ${LVFILE} | cut -d: -f4 | while read dir; do mkdir -p ${dir} 2>/dev/null; mount ${dir}; done; echo " ";

echo " "; echo "Mounting all FSTAB entries";
mount -a
if test $? -eq 0; then echo "All filesystem in ${LVFILE} are mounted"; else echo "ERROR: mount -a failed. Perform manual cleanup"; fi
echo " "
}


#########---------------------------***-------------------------------#########
fn_gen_selinuxoff ()
{
echo " "
echo "Setting SELINUX to disabled"
echo " "
fn_bkp ${SEFILE}
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' ${SEFILE}
sed -i 's/SELINUX=permissive/SELINUX=disabled/' ${SEFILE}
echo "Done"
}


#########---------------------------***-------------------------------#########
fn_gen_iptablesoff ()
{
echo "Stopping IPtables and disabled iptabled at boot time"
service iptables stop
chkconfig iptables off
chkconfig --list iptables
echo "Done"
}


#########---------------------------***-------------------------------#########
fn_gen_dtmigsudo ()
{
echo "Updating NOPASSWD entry to dtmigrator user in /etc/sudoers"
echo " " >> ${SUDOFILE}
echo "#DoubleTake user" >> ${SUDOFILE}
echo "dtmigrator      ALL=(ALL)       NOPASSWD: ALL" >> ${SUDOFILE}
echo "/etc/sudoers file updated"
}


#########---------------------------***-------------------------------#########
fn_gen_dtinstall ()
{
#Depends on fn_gen_dtmigsudo sub-script
fn_dtsub ()
{
echo "Installing DoubleTake Agent"
rpm -ivh ${DTFILE}
echo " "
echo "Adding DT groups to dtmigrator"
id dtmigrator 1>/dev/null 2>&1
if [ `echo $?` -ne 0 ]; then
echo " "; echo "SCWARN: User \"dtmigrator\" does not exists. Creating user with generic password";
useradd -m -d /home/dtmigrator -s /bin/bash -c "DoubleTake Agent" dtmigrator
echo "b1LlKDpPCNqfiKav" | passwd --stdin dtmigrator; echo "User created"; fi
echo " "; echo "Modifying root and dtmigrator account groups for DT"
usermod -G dtadmin,dtmon dtmigrator; usermod -G dtmon root

fn_gen_dtmigsudo

echo " "; echo "Setting up DT Agent"; DTSetup -E yes; DTSetup -k cxa3-ned7-duzk-zttb-18yf-vuda
service DT status; echo "Starting DT Agent"; service DT start; echo " ";
}
if [ -f ${DTFILE} ]; then fn_dtsub; else echo "SCERR: ${DTFILE} is not present. Skipping DT installation"; fi
}



#########---------------------------***-------------------------------#########
fn_gen_ostimezone ()
{
if [ $# -eq 0 ]; then echo "SYNTAX ERROR: No arguments given"; echo "Example: fn_gen_ostimezone CET"; exit 1; fi
time=$1
fn_bkp ${TZFILE}

case ${time} in
est|EST)
echo "ZONE="Europe/Rome"
UTC=true" > ${TZFILE}
mv /etc/localtime /root/localtime.old
ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime;;
cet|CET)
echo "ZONE="Europe/Rome"
UTC=true" > ${TZFILE}
mv /etc/localtime /root/localtime.old
ln -sf /usr/share/zoneinfo/CET /etc/localtime;;
edt|EDT)
echo "ZONE="America/New_York"
UTC=true" > ${TZFILE}
mv /etc/localtime /root/localtime.old
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime;;
*)
echo "Currently supported values are : fn_gen_ostimezone [EDT|EST|CET]"
exit 1;;
esac
echo "Timezone changed to ${time}. Current time is : `date`"; echo " ";
}


#########---------------------------***-------------------------------#########
fn_gen_preout ()
{
fn_lines; echo "FMO-PRE: SEG1: ========================= OS DETAILS =========================";
fn_lines HOSTNAME;
hostname -f 1>/dev/null 2>&1; if test $? -eq 0; then hostname -f | awk -F"." '{print $2"."$3}'; else hostname; fi
fn_lines UNAME; uname -a;
fn_lines dmidecode-product-name; dmidecode -s system-product-name
fn_lines DATE; date;
fn_lines LOCALE; locale | egrep "^LANG=|^LC_CTYPE="
fn_lines /etc/issue; cat /etc/issue; echo " ";
fn_lines OS-Release-Info;
if [ -f /etc/redhat-release ]; then cat /etc/redhat-release; fi; echo " ";
if [ -f /etc/SuSE-release ]; then echo "SuSE `grep VERSION /etc/SuSE-release | awk '{print $3}'`:`grep PATCHLEVEL /etc/SuSE-release | awk '{print $3}'`"; fi
fn_lines CPU-INFO
echo "`grep processor /proc/cpuinfo | wc -l` x`grep "model name" /proc/cpuinfo | awk -F":" '{print $2}' | sort -u`"
fn_lines MEM-INFO
grep MemTotal /proc/meminfo | awk '{mem=$2/1024} END {print mem,"MB"}'
fn_lines; echo "FMO-PRE: SEG2: ========================= NETWORK DETAILS =========================";
fn_lines IPADDR; ip addr show; echo " ";
fn_lines ROUTING-TABLES; netstat -rnv; echo " ";
fn_lines IPTABLES; iptables -L; echo " ";
fn_lines /etc/sysconfig/network; cat /etc/sysconfig/network; echo " ";
fn_lines IFCFG-FILES; tail -vn +1 /etc/sysconfig/network-scripts/ifcfg-eth* 2>/dev/null; echo " ";
fn_lines ROUTE-FILES; tail -vn +1 /etc/sysconfig/network-scripts/route-eth* 2>/dev/null; echo " ";
fn_lines /etc/resolv.conf; cat /etc/resolv.conf; echo " ";
fn_lines NSSWITCH.CONF-FILE; cat /etc/nsswitch.conf;
fn_lines NTPQ-P; ntpq -p; echo " ";
fn_lines NTP-FILE; cat /etc/ntp.conf; echo " ";
fn_lines HOSTS-FILE; cat /etc/hosts; echo " ";
fn_lines; echo "FMO-PRE: SEG3: ========================= DISK & FS DETAILS =========================";
fn_lines FDISK-L; fdisk -l 2>/dev/null | grep Disk | egrep -iv "iden|map|dm|ram|dos"
fn_lines DF-K; df -kP; echo " ";
fn_lines DF-Th; df -ThP; echo " ";
fn_lines FSTAB; cat /etc/fstab; echo " ";
fn_lines MTAB; cat /etc/mtab; echo " ";
fn_lines; echo "========================= LVM STATS =========================";
fn_lines LVS; lvs; echo " ";
fn_lines VGS; vgs; echo " ";
fn_lines PVS; pvs; echo " ";
fn_lines /etc/passwd; cat /etc/passwd;
fn_lines
}


#########---------------------------***-------------------------------#########
fn_gen_custom ()
{
if [ ! -z ${custopt} ]; then
fn_gen_subfn > ${SBFNC}; grep -v ^Following ${SBFNC} | grep ${custopt} 1>/dev/null 2>&1;
if [ `echo $?` -ne 0 ]; then echo "Invalid sub-function. Use \"fmoscript.sh -listfn\" to get the valid entry";
else
echo " "; echo "Executing \"${custopt}\" sub-function from this script"; echo " ";
${custopt} ${custopt1};
echo " "; fi
else
echo " "; echo "SYNTAX ERROR: 'custom' option must follow with subfunctions. use \"fmoscript.sh -listfn\" option to see available options";
echo " "; echo "Correct Syntax: \"fmoscript.sh custom <subfunction>\"";
echo "Example:        \"fmoscript.sh custom fn_az_agentcheck\""; echo " "; fi
}


#########---------------------------***-------------------------------#########
fn_gen_dxcsupt ()
{
id dxcsupt 1>/dev/null 2>&1;
if [ `echo $?` -ne 0 ]; then useradd -c "Admin login for Migration" dxcsupt; echo "dxcsupt is created";
fn_bkp ${ACCESSFILE}; sed -i '/-:ALL:ALL/i \+:dxcsupt:ALL' ${ACCESSFILE}; echo "dxcsupt id added to access file"; fi

echo "Hg@a4s&Tel" | passwd --stdin root
echo "Hg@a4s&Tel" | passwd --stdin dxcsupt
echo "Standard DT password has been set root and dxcsupt users"

echo "#Added for dxcsupt user for post migration admin login" >> ${SUDOFILE}
echo "dxcsupt      ALL=(ALL) NOPASSWD: ALL" >> ${SUDOFILE}
echo "dxcsupt user added in SUDOERs  file"
}


#########---------------------------***-------------------------------#########
fn_gen_dtcleanup ()
{
fn_dtstop ()
{
fn_lines; echo "Make sure DT job and server is removed from DT console"; sleep 2;
fn_lines; echo "Stopping DT Service:"; service DT status;
fn_lines; service DT stop;
fn_lines; service DT status; echo " ";
}

fn_dtstagdu ()
{
fn_lines; echo "Finding Current utilization of .dtstaging folders:"; echo " ";
FST=`df -PhT / | sed '1d' | awk '{print $2}'`
du -sh /.dtstaging; df -t $FST -PhT | sed '1,2d' | awk '{print $NF}' | while read fs; do du -sh ${fs}/.dtstaging 2>/dev/null; done
fn_lines;
}

fn_dtstagrm ()
{
fn_lines; echo "Deleting DT Staging directories:"; echo " ";
echo "................................... Removing /.dtstaging"; rm -rf /.dtstaging;
df -t $FST -PhT | sed '1,2d' | awk '{print $NF}' | while read fs; do echo "................................... Removing ${fs}/.dtstaging"; rm -rf ${fs}/.dtstaging 2>/dev/null; done;
fn_lines;
}

fn_dtuninst ()
{
fn_lines; echo "Uninstalling DoubleTake Tool:"
DTV=`rpm -q DoubleTake`; echo "Current version of DT is ${DTV}";
fn_lines "Erasing DT"; rpm -e ${DTV};
fn_lines "Revalidating DT package"; rpm -qi DoubleTake; echo " ";
}

fn_dtuserrm ()
{
echo "Deleting dtmigrator user:"
fn_lines "Validating user"; id -a dtmigrator;
fn_lines "Deleting User"; userdel -r dtmigrator;
fn_lines "Revalidating user"; id -a dtmigrator; echo " ";
}

fn_dtusersudorm ()
{
echo "Removing SUDO entry for dtmigrator:"
sed -i.bak '/dtmigrator/d' /etc/sudoers; fn_lines;
}

## DTCleanup Main script

case $1 in
dtfsclean)
fn_dtstagdu
fn_dtstagrm;;
dtagrm)
fn_dtstop
fn_dtuninst;;
dtuserdel)
fn_dtuserrm
fn_dtusersudorm;;
all)
fn_dtstop
fn_dtstagdu
fn_dtstagrm
fn_dtuninst
fn_dtuserrm
fn_dtusersudorm;;
*)
fn_lines; echo "SYNTAX: fn_gen_dtcleanup <all|dtagrm|dtfsclean|dtuserdel>";
echo "Example: fn_gen_dtcleanup all"; echo " ";
echo "     all                :      Perfrom all DT Cleanup Tasks"
echo "     dtfsclean          :      Delete hidden dtstaging FileSystem"
echo "     dtagrm             :      Stop and Uninstall DT agent"
echo "     dtuserdel          :      Remove dtmigrator user deletion"; echo " ";
exit 1;;
esac
}


#########---------------------------***-------------------------------#########
fn_gen_azpeerdns ()
{
fn_bkp /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i '/PEERDNS/,/yes/s/yes/no/' /etc/sysconfig/network-scripts/ifcfg-eth0
echo "PEERDNS value changed to NO in ifcfg-eth0 file"
}


#########---------------------------***-------------------------------#########
fn_gen_azswapsize ()
{
fn_bkp /etc/waagent.conf
memval=`free -m | grep ^Mem | awk '{print $2}'`
if [ ${memval} -gt 1000 ] && [ ${memval} -lt 1500 ]; then swapval=`expr ${memval} \* 3 / 2`; fi;
if [ ${memval} -gt 1500 ] && [ ${memval} -lt 16000 ]; then swapval=${memval}; fi;
if [ ${memval} -gt 16000 ]; then swapval=16384; fi;
sed -i '/ResourceDisk.SwapSizeMB=/c\ResourceDisk.SwapSizeMB='"${swapval}"'' /etc/waagent.conf
service waagent restart
}


#########---------------------------***-------------------------------#########
fn_gen_azdnssearch ()
{
fn_bkp /etc/resolv.conf
sed -i '/search /a \search luxgroup.net' /etc/resolv.conf
echo "DNS file appeneded with luxgroup.net search domain"
}


#########---------------------------***-------------------------------#########
fn_gen_azntpserver ()
{
NTPFILE=/etc/ntp.conf
fn_bkp ${NTPFILE}
sed -i '/[^#]/ s/\(^.*server.*$\)/#\ \1/' ${NTPFILE}
sed -i '/[^#]/ s/\(^.*restrict.*$\)/#\ \1/' ${NTPFILE}
echo "server 10.6.0.52  version 3" >> ${NTPFILE}
echo "server 10.6.0.53  version 3" >> ${NTPFILE}
service ntpd restart; echo "NTP file updated with Azure NTP servers"; echo " ";
}

######################################################################################################
# SRA Tools Removal

#########---------------------------***-------------------------------#########
fn_sra_hpsa_rm ()
{
FNVAR="SRA-HPSA-0103"
LOG INFO: Initiating HPSA Uninstallation
if [ -f /opt/opsware/agent/bin/agent_uninstall.sh ]; then
/opt/opsware/agent/bin/agent_uninstall.sh --no_deactivate --force
if test $? -eq 0; then
        if [ -d /var/opt/opsware ]; then rm -rf /var/opt/opsware; fi
LOG RESULT: SUCCESS: HPSA Uninstalled successfully; else
LOG RESULT: FAILED: HPSA Uninstallation Failed. Check Manually; fi
else
LOG RESULT: NOACTION: HPSA agent_uninstall.sh script not found. Probably already uninstalled; fi
}

#########---------------------------***-------------------------------#########
fn_sra_ddmi_rm ()
{
FNVAR="SRA-DDMI-0104"
LOG INFO: Initiating DDMI Cleanup
DDMI=`rpm -aq | grep ddmi-installer`;
if [ ! -z $DDMI ]; then rpm -e $DDMI;
        LOG RESULT: SUCCESS: DDMI Uninstalled successfully; else
        LOG RESULT: NOACTION: DDMI is not installed; fi
}

#########---------------------------***-------------------------------#########
fn_sra_esar_rm ()
{
FNVAR="SRA-ESAR-0105"
LOG INFO: Initiating ESAR Cleanup. 4 packages will be uninstalled
ESDISK=`rpm -aq | grep HPITO-ESAR-LX-dsidiskcap`
ESDWTIME=`rpm -aq | grep HPITO-ESAR-LX-sysdowntime`
ESINV=`rpm -aq | grep HPITO-ESAR-LX-esarinv`
ESBASE=`rpm -aq | grep HPITO-ESAR-LX-base_package`
if [ ! -z ${ESDISK} ]; then rpm -e ${ESDISK};
        LOG RESULT: SUCCESS: ESAR-HPITO-ESAR-LX-dsidiskcap package uninstalled; else
        LOG RESULT: NOACTION: ESAR-HPITO-ESAR-LX-dsidiskcap package not found; fi
if [ ! -z ${ESDWTIME} ]; then rpm -e ${ESDWTIME};
        LOG RESULT: SUCCESS HPITO-ESAR-LX-sysdowntime package uninstalled; else
        LOG RESULT: NOACTION: HPITO-ESAR-LX-sysdowntime package not found; fi
if [ ! -z ${ESINV} ]; then rpm -e ${ESINV};
        LOG RESULT: SUCCESS: ESAR-HPITO-ESAR-LX-esarinv package uninstalled; else
        LOG RESULT: NOACTION: ESAR-HPITO-ESAR-LX-esarinv package not found; fi
if [ ! -z ${ESBASE} ]; then rpm -e ${ESBASE};
        LOG RESULT: SUCCESS: HPITO-ESAR-LX-base_package package uninstalled; else
        LOG RESULT: NOACTION: HPITO-ESAR-LX-base_package package not found; fi
}

#########---------------------------***-------------------------------#########
fn_sra_osit_rm ()
{
FNVAR="SRA-OSIT-0106"
LOG INFO: Inititing OSIT/ACF Cleanup
LOG INFO: Validation DF command - 1 min
df -h 1>/dev/null & export PIDDH=$!
sleep 60
ps -lp $PIDDH 1>/dev/null
if test $? -eq 1; then 
LOG INFO: df command validation passed. Proceeding with uninstallation

/opt/osit/acf/scripts/remove_acf.sh JOBS+FILES
if test $? -eq 0; then
       LOG RESULT: SUCCESS: OSIT/ACF packages are uninstalled; else
       LOG RESULT: NOACTION: OSIT/ACF is not installed on this server; fi

LOG INFO: Cleaning up osit and ACF entries in crontab
crontab -l > ${CTAB}
fn_bkp ${CTAB}
sed -i '/ACF\|osit\|^$/d' ${CTAB}
crontab ${CTAB}
crontab -l > /tmp/ctab
egrep "osit|ACF" /tmp/ctab
if test $? -eq 0; then
        LOG RESULT: SUCCESS: OSIT/ACF entries are removed in crontab; rm /tmp/ctab; else
        LOG RESULT: ERROR: Some issue in deleting crontab entries; rm /tmp/ctab; fi
else
	LOG ERROR: df command validation failed. Cannot proceed with uninstallation; kill -9 ${PIDDH}; fi
}


#########---------------------------***-------------------------------#########
fn_sra_hpoa_rm ()
{
FNVAR="SRA-HPOA-0107"
LOG INFO: Initiating HPOA cleanup
if [ -f /opt/OV/bin/opcagt ]; then
LOG INFO: Stopping HPOA Agents
/opt/OV/bin/opcagt -stop
if [ `opcagt -status 2>/dev/null | grep "AGENT,EA" | awk '{print $NF}' | sort -u` == Stopped ]; then 
	LOG INFO: HPOA Agent stopped; else 
	LOG ERROR: HPOA Agent is not stopped. Check Manually; fi

LOG INFO: Stopping TTD Agent
/opt/perf/bin/ttd -k
if [ `/opt/OV/bin/opcagt -status 2>/dev/null | grep ^ttd | awk '{print $NF}'` == Stopped ]; then
	LOG INFO: TTD Agent is stopped; else
	LOG ERROR: HPOA TTD Agent is not stopped. Check Manually; fi
LOG INFO: Uninstalling HPOA
/opt/OV/bin/OpC/install/oainstall.sh -r -a
if [ ! -f /opt/OV/bin/OpC/install/oainstall.sh ]; then
	LOG RESULT: SUCCESS: HPOA Uninstalled successfully; else
	LOG RESULT: ERROR: HPOA uninstall script did not execute correctly. Check Manually; fi
else
LOG INFO: opcagt file doesnot exists. Probably HPOA is arleady uninstalled
LOG INFO: Validation final check on HPOA
if [ ! -f /opt/OV/bin/OpC/install/oainstall.sh ]; then
	LOG RESULT: NOACTION: HPOA is not installed on this server; else
	LOG RESULT: ERROR: HPOA uninstall script is located. Random error. Check Manually; fi
fi
}

#########---------------------------***-------------------------------#########
fn_sra_rm ()
{
case $1 in
all)
fn_sra_hpsa_rm
fn_sra_ddmi_rm
fn_sra_esar_rm
fn_sra_osit_rm
fn_sra_hpoa_rm
echo " "; echo "RESULT of SRA Cleanup"; 
echo "=============================================================================================="; echo " ";
grep RESULT ${LOGFILE}; echo " ";;
hpsa) fn_sra_hpsa_rm;;
ddmi) fn_sra_ddmi_rm;;
esar) fn_sra_esar_rm;;
osit) fn_sra_osit_rm;echo "i am out of fn now";;
hpos) fn_sra_hpoa_rm;;
*)
echo "SYNTAX ERROR: Usage: fn_sra_rm <all|hpsa|ddmi|esar|osit|hpoa>"
exit 1;;
esac
}


######################################################################################################
# Azure Related Functions


#########---------------------------***-------------------------------#########
fn_az_agentcheck ()
{
echo "************************************************************************************************************************************"
echo "................................... Verifying Agent Running Status ............................................."
echo "Checking waagent"
service waagent status
echo " "
echo "Checking OMS Agent"
/etc/init.d/omsagent* status
echo " "
echo "Checking crowdstrike Agent"
service falcon-sensor status
echo ".................................... Agent Verification Completed ............................................."
echo ""; sleep 1
}



######################################################################################################
# OS Functions


#########---------------------------***-------------------------------#########
fn_os_fspart_ba ()
{
echo " "
echo "Pringing current partition table for /dev/sda"
parted /dev/sda unit GiB print free
echo "Creating necessary partitions as per CMO OS FS layout"
echo " "

parted /dev/sda unit GiB print free
parted /dev/sda unit GiB mkpart primary 32 42 1>/dev/null
parted /dev/sda unit GiB mkpart extended 42 100 1>/dev/null
parted /dev/sda unit GiB mkpart logical 42 52 1>/dev/null
parted /dev/sda unit GiB mkpart logical 52 62 1>/dev/null
parted /dev/sda unit GiB mkpart logical 62 77 1>/dev/null
parted /dev/sda unit GiB mkpart logical 77 82 1>/dev/null
echo " "
echo "Pringing partition table for /dev/sda after creating partitions"
parted /dev/sda unit GiB print free
echo " "
echo "System will be rebooted in 10 secs. You can either interrupt or HIT ENTER to reboot immediatly"
read -t 10 value
echo "Proceeding with reboot"
sleep 1;
init 6 &
exit
}


#########---------------------------***-------------------------------#########
fn_os_fsrsync_ba ()
{

echo "Backing up fstab file"
fn_bkp ${FSTAB}
echo " "
echo "Making new entries in ${FSTAB}"
echo "/dev/sda3               /var-new                    ext4    defaults        1 2
/dev/sda5               /home-new                   ext4    defaults        1 2
/dev/sda6               /tmp-new                    ext4    defaults        1 2
/dev/sda7               /var/crash-new              ext4    defaults        1 2
/dev/sda8               /var/log/audit-new          ext4    defaults        1 2" >> ${FSTAB}

echo "Making new directories for temporary mount"
mkdir /var/crash /var/log/audit 2>/dev/null
mkdir /var-new /home-new /var/crash-new /tmp-new /var/log/audit-new 2>/dev/null


echo "Creating filesystems in newly created partitions"
fn_gen_osfsmkfs 8 ext4; sleep 1; echo " ";

echo "Mounting all Temporary FS"
mount -a
echo " "
echo "Output of current mounts"
df -Ph
echo " "


echo "Syncing files from current mounts to new partitions"
rsync -a /home/* /home-new & export PIDHOME=$!
rsync -a /var/* /var-new & export PIDVAR=$!
rsync -a /var/log/audit/* /var/log/audit-new & export PIDAUD=$!
echo " "

echo "PIDs for the rsync jobs running are : ${PIDHOME} ${PIDVAR} ${PIDAUD}"
echo "Waiting for approx 3 minutes for rsync jobs to complete. Enjoy a Coldplay song till then :) "
echo " "
sleep 200
echo "Had a good nap :) Checking if all FS sync is completed"

while :; do ps -lp ${PIDHOME} ${PIDVAR} ${PIDAUD} 1>/dev/null; test $? -ne 0 && break
echo "OOPs! Rsync PIDs are still running. Waiting for 2 minutes"; sleep 120; done
echo " "
echo "Rsync of OS filesystems completed"
echo "Current utilization of directories"
du -sk /home* /var* /var/log/audit*
echo " "

echo "Umounting new directories"
umount /home-new /var-new /var/log/audit-new /var/crash-new /tmp-new 2>/dev/null

echo " "; echo "Current mount status after unmounting new FS"
df -Ph; echo " ";

echo "Adjusting entries in fstab to match originals"
sed -i 's/-new//' ${FSTAB}; echo " "

echo "Moutning new filesystem partitions"
mount -a; if [ `echo $?` == 0 ]; then echo "No Error in fstab. System will reboot in 10 secs"; read -t 10 ans; init 6; else echo "Error in FSTAB, do a manual reboot after fixing it"; fi
echo " "
}


#########---------------------------***-------------------------------#########
fn_os_fspart_buo ()
{
echo " "
echo "Pringing current partition table for /dev/sda"
parted /dev/sda unit GiB print free
echo "Creating necessary partitions as per CMO OS FS layout"
echo " "

parted /dev/sda unit GiB print free
parted /dev/sda unit GiB mkpart primary 32 42 1>/dev/null
parted /dev/sda unit GiB mkpart extended 42 100 1>/dev/null
parted /dev/sda unit GiB mkpart logical 42 52 1>/dev/null
parted /dev/sda unit GiB mkpart logical 52 62 1>/dev/null
parted /dev/sda unit GiB mkpart logical 62 77 1>/dev/null
parted /dev/sda unit GiB mkpart logical 77 87 1>/dev/null
parted /dev/sda unit GiB mkpart logical 87 97 1>/dev/null
echo " "
echo "Pringing partition table for /dev/sda after creating partitions"
parted /dev/sda unit GiB print free
echo " "
echo "System will be rebooted in 10 secs. You can either interrupt or HIT ENTER to reboot immediatly"
read -t 10 value
echo "Proceeding with reboot"
sleep 1;
init 6 &
exit
}


#########---------------------------***-------------------------------#########
fn_os_fsrsync_buo ()
{

echo "Backing up fstab file"
fn_bkp ${FSTAB}
echo " "
echo "Making new entries in ${FSTAB}"
echo "/dev/sda3               /var-new                    ext4    defaults        1 2
/dev/sda5               /home-new                   ext4    defaults        1 2
/dev/sda6               /tmp-new                    ext4    defaults        1 2
/dev/sda7               /var/crash-new              ext4    defaults        1 2
/dev/sda8               /usr-new                    ext4    defaults        1 2
/dev/sda9              /opt-new                    ext4    defaults        1 2" >> ${FSTAB}

echo "Making new directories for temporary mount"
mkdir /var/crash /var/log/audit 2>/dev/null
mkdir /var-new /home-new /var/crash-new /tmp-new /usr-new /opt-new 2>/dev/null

echo "Creating filesystems in newly created partitions"
fn_gen_osfsmkfs 9 ext4; sleep 1; echo " ";

echo "Mounting all Temporary FS"
mount -a
echo " "
echo "Output of current mounts"
df -Ph
echo " "


echo "Syncing files from current mounts to new partitions"
rsync -a /home/* /home-new & export PIDHOME=$!
rsync -a /var/* /var-new & export PIDVAR=$!
rsync -a /usr/* /usr-new & export PIDUSR=$!
rsync -a /opt/* /opt-new & export PIDOPT=$!
echo " "

echo "PIDs for the rsync jobs running are : ${PIDHOME} ${PIDVAR} ${PIDUSR} ${PIDOPT}"
echo "Waiting for approx 3 minutes for rsync jobs to complete. Enjoy a Coldplay song till then :) "
echo " "
sleep 200
echo "Had a good nap :) Checking if all FS sync is completed"

while :; do ps -lp ${PIDHOME} ${PIDVAR} ${PIDUSR} ${PIDOPT} 1>/dev/null; test $? -ne 0 && break
echo "OOPs! Rsync PIDs are still running. Waiting for 2 minutes"; sleep 120; done
echo " "
echo "Rsync of OS filesystems completed"
echo "Current utilization of directories"
du -sk /home* /var* /var/log/audit*
echo " "

echo "Umounting new directories"
umount /home-new /var-new /var/log/audit-new /var/crash-new /tmp-new 2>/dev/null

echo " "; echo "Current mount status after unmounting new FS"
df -Ph; echo " ";

echo "Adjusting entries in fstab to match originals"
sed -i 's/-new//' ${FSTAB}; echo " "

echo "Moutning new filesystem partitions"
mount -a; if [ `echo $?` == 0 ]; then echo "No Error in fstab. System will reboot in 10 secs"; read -t 10 ans; init 6; else echo "Error in FSTAB, do a manual reb  oot after fixing it"; fi
echo " "
}


#########---------------------------***-------------------------------#########
fn_os_fspart_bauo ()
{
echo " "
echo "Pringing current partition table for /dev/sda"
parted /dev/sda unit GiB print free
echo "Creating necessary partitions as per CMO OS FS layout"
echo " "

parted /dev/sda unit GiB print free
parted /dev/sda unit GiB mkpart primary 32 42 1>/dev/null
parted /dev/sda unit GiB mkpart extended 42 100 1>/dev/null
parted /dev/sda unit GiB mkpart logical 42 52 1>/dev/null
parted /dev/sda unit GiB mkpart logical 52 62 1>/dev/null
parted /dev/sda unit GiB mkpart logical 62 77 1>/dev/null
parted /dev/sda unit GiB mkpart logical 77 82 1>/dev/null
parted /dev/sda unit GiB mkpart logical 82 91 1>/dev/null
parted /dev/sda unit GiB mkpart logical 91 100 1>/dev/null
echo " "
echo "Pringing partition table for /dev/sda after creating partitions"
parted /dev/sda unit GiB print free
echo " "
echo "System will be rebooted in 10 secs. You can either interrupt or HIT ENTER to reboot immediatly"
read -t 10 value
echo "Proceeding with reboot"
sleep 1;
init 6 &
exit
}

#########---------------------------***-------------------------------#########
fn_os_fsrsync_bauo ()
{

echo "Backing up fstab file"
fn_bkp ${FSTAB}
echo " "
echo "Making new entries in ${FSTAB}"
echo "/dev/sda3               /var-new                    ext4    defaults        1 2
/dev/sda5               /home-new                   ext4    defaults        1 2
/dev/sda6               /tmp-new                    ext4    defaults        1 2
/dev/sda7               /var/crash-new              ext4    defaults        1 2
/dev/sda8               /var/log/audit-new          ext4    defaults        1 2
/dev/sda9               /usr-new                    ext4    defaults        1 2
/dev/sda10              /opt-new                    ext4    defaults        1 2" >> ${FSTAB}

echo "Making new directories for temporary mount"
mkdir /var/crash /var/log/audit 2>/dev/null
mkdir /var-new /home-new /var/crash-new /tmp-new /var/log/audit-new /usr-new /opt-new 2>/dev/null


echo "Creating filesystems in newly created partitions"
fn_gen_osfsmkfs 10 ext4; sleep 1; echo " ";

echo "Mounting all Temporary FS"
mount -a
echo " "
echo "Output of current mounts"
df -Ph
echo " "


echo "Syncing files from current mounts to new partitions"
rsync -a /home/* /home-new & export PIDHOME=$!
rsync -a /var/* /var-new & export PIDVAR=$!
rsync -a /var/log/audit/* /var/log/audit-new & export PIDAUD=$!
rsync -a /usr/* /usr-new & export PIDUSR=$!
rsync -a /opt/* /opt-new & export PIDOPT=$!
echo " "

echo "PIDs for the rsync jobs running are : ${PIDHOME} ${PIDVAR} ${PIDAUD} ${PIDUSR} ${PIDOPT}"
echo "Waiting for approx 3 minutes for rsync jobs to complete. Enjoy a Coldplay song till then :) "
echo " "
sleep 200
echo "Had a good nap :) Checking if all FS sync is completed"

while :; do ps -lp ${PIDHOME} ${PIDVAR} ${PIDAUD} ${PIDUSR} ${PIDOPT} 1>/dev/null; test $? -ne 0 && break
echo "OOPs! Rsync PIDs are still running. Waiting for 2 minutes"; sleep 120; done
echo " "
echo "Rsync of OS filesystems completed"
echo "Current utilization of directories"
du -sk /home* /var* /var/log/audit* /usr* /opt*
echo " "

echo "Umounting new directories"
umount /home-new /var-new /var/log/audit-new /var/crash-new /tmp-new /usr-new /opt-new 2>/dev/null

echo " "; echo "Current mount status after unmounting new FS"
df -Ph; echo " ";

echo "Adjusting entries in fstab to match originals"
sed -i 's/-new//' ${FSTAB}; echo " "

echo "Moutning new filesystem partitions"
mount -a; if [ `echo $?` == 0 ]; then echo "No Error in fstab. System will reboot in 10 secs"; read -t 10 ans; init 6; else echo "Error in FSTAB, do a manual reboot after fixing it"; fi
echo " "
}


######################################################################################################
#DB Functions

fn_db_fspart ()
{
echo "Updating NOPASSWD entry to dtmigrator user in /etc/sudoers"
echo " " >> /etc/sudoers
echo "#DoubleTake user" >> /etc/sudoers
echo "dtmigrator      ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers
echo "/etc/sudoers file updated"

echo " "
echo "Pringing current partition table for /dev/sda"
parted /dev/sda unit GiB print free
echo "Creating necessary partitions as per DB FS layout"
echo " "
parted /dev/sda unit GiB mkpart primary 30 45 1>/dev/null
parted /dev/sda unit GiB mkpart extended 45 100 1>/dev/null
parted /dev/sda unit GiB mkpart logical 45 65 1>/dev/null
parted /dev/sda unit GiB mkpart logical 65 80 1>/dev/null
parted /dev/sda unit GiB mkpart logical 80 90 1>/dev/null
parted /dev/sda unit GiB mkpart logical 90 100 1>/dev/null
echo " "
echo "Pringing partition table for /dev/sda after creating partitions"
parted /dev/sda unit GiB print free
echo " "
echo "System will be rebooted in 10 secs. You can either interrupt or HIT ENTER to reboot immediatly"
read -t 10 value
echo "Proceeding with reboot"
sleep 1;
init 6 &
exit
}

fn_db_fsrsync ()
{
echo "Backing up fstab file"
fn_bkp ${FSTAB}
echo " "
echo "Making new entries in ${FSTAB}"
echo "/dev/sda3       /usr-new    ext4    defaults        1 2
/dev/sda5       /var-new    ext4    defaults        1 2
/dev/sda6       /home-new    ext4    defaults        1 2
/dev/sda7       /tmp-new    ext4    defaults        1 2
/dev/sda8       /opt-new    ext4    defaults        1 2" >> ${FSTAB}

echo "Finding UUIDs of the partitions"
for p in 3 5 6 7 8; do echo "sda${p}:UUID=`ls -l /dev/disk/by-uuid/ | grep -w sda${p} | awk '{print $9}'`"; done > ${TFTAB}
echo "Adding relevant entry in /etc/fstab for new partitions"
for p in 3 5 6 7 8; do  val=`cat ${TFTAB} | grep sda${p} | awk -F":" '{print $2}'`; sed -i "s/\/dev\/sda${p}/$val/g" ${FSTAB}; done
rm -f ${TFTAB}

echo "fstab updated with UUID entries"
echo "Making new directories for temporary mount"
mkdir /usr-new /var-new /home-new /tmp-new /opt-new 2>/dev/null
echo "Mounting all Temporary FS"
mount -a
echo " "
echo "Output of current mounts"
df -Ph
echo " "

echo "Syncing files from current mounts to new partitions"
rsync -a /usr/* /usr-new & export PIDUSR=$!
rsync -a /var/* /var-new & export PIDVAR=$!
rsync -a /home/* /home-new & export PIDHOME=$!
rsync -a /opt/* /opt-new & export PIDOPT=$!
echo " "; sleep 5;

echo "PIDs for the rsync jobs running are : ${PIDHOME} ${PIDUSR} ${PIDOPT} ${PIDVAR}"
echo "Waiting for approx 3 minutes for rsync jobs to complete. Enjoy a Coldplay song till then :) "
echo " "
sleep 200
echo "Had a good nap :) Checking if all FS sync is completed"


while :; do ps -lp ${PIDHOME} ${PIDUSR} ${PIDOPT} ${PIDVAR} 1>/dev/null; test $? -ne 0 && break
echo "OOPs! Rsync PIDs are still running. Waiting for 2 minutes"; sleep 120; done
echo " "
echo "Rsync of OS filesystems completed"
echo "Current utilization of directories"
du -sk /home* /usr* /opt* /var*
echo " "

echo "Umounting new directories"
umount /home-new /usr-new /opt-new /var-new /tmp-new

echo " "; echo "Current mount status after unmounting new FS"
df -Ph; echo " ";

echo "Adjusting entries in fstab to match originals"
sed -i 's/-new//' ${FSTAB}; echo " "

echo "Moutning new filesystem partitions"
mount -a; if [ `echo $?` == 0 ]; then echo "No Error in fstab. System will reboot in 10 secs"; read -t 10 ans; init 6; else echo "Error in FSTAB, do a manual reb  oot after fixing it"; fi
echo " "
}

fn_db_kernel ()
{
echo "Changing kernel parameters"
echo " "
fn_bkp ${SYSFILE}
sed -i '/kernel.shmmax/d' ${SYSFILE}
sed -i '/kernel.shmall/d' ${SYSFILE}
echo "`free -m | grep ^Mem | awk '{print $2}'` / 2 * 1024 * 1024" | bc > ${TSHMX}
echo "kernel.shmmax = `cat /tmp/shmmax`" >> ${SYSFILE}
echo "kernel.shmall = `expr $(cat /tmp/shmmax) / 4096`" >> ${SYSFILE}; 

echo "kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
fs.file-max = 6815744
fs.aio-max-nr = 1048576
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
kernel.panic_on_oops=1" >> ${SYSFILE}

echo " "; echo "Updating new kernel config lively. For better results, reboot the server once all tasks are done"
fn_lines Updating sysctl.conf file; sysctl -p; echo " "

}

fn_db_ulimits ()
{
echo "Adding entries to limits.conf file"
fn_bkp ${LIMITSFILE}

echo "oracle          soft    memlock         33554432
oracle          hard    memlock         33554432
oracle          soft    nproc           2047
oracle          hard    nproc           16384
oracle          soft    nofile          1024
oracle          hard    nofile          65536
oracle          soft    stack           10240
oracle          hard    stack           10240
grid            soft    nproc           2047
grid            hard    nproc           16384
grid            soft    nofile          1024
grid            hard    nofile          65536
grid            soft    stack           10240
grid            hard    stack           10240
" >> ${LIMITSFILE}

fn_lines limits.conf file is updated; echo " "
}

fn_db_userngrp ()
{
rm -f ${GFILE} 2>/dev/null

echo "Creating required DB groups"

echo "oinstall:10003
dba:1003
asmadmin:1004
asmdba:1005
asmoper:1006" > ${GFILE}

for grp in $(cat ${GFILE}); do groupadd -g `echo $grp |cut -d':' -f2` `echo $grp |cut -d':' -f1`; echo "Group `echo $grp |cut -d':' -f1` created"; done

echo "Creating users"
useradd -u 1101 -g oinstall -G 1003,1004,1005,1006 -s /bin/ksh -m -d /home/oracle oracle && echo "User oracle created"
useradd -u 1102 -g oinstall -G 1003,1004,1005,1006 -s /bin/ksh -m -d /home/grid grid && echo "User grid created"

echo "Setting password for users"
for user in oracle grid; do echo 'Nfh56)$3' | passwd --stdin $user; done
echo "Setting account not expiry"
for user in oracle grid; do passwd -x -1 ${user}; done
echo " "

echo "Adding SUDO entry to Oracle"
echo "oracle          ALL=(ALL)       NOPASSWD: ALL" >> ${SUDOFILE}
echo "Done"
echo " "

echo "Setting standard password for root and dtmigrator user"
echo "Dg@a4s&Tel" | passwd --stdin root
echo "Dg@a4s&Tel" | passwd --stdin dtmigrator
echo "Passwords have been reset to standards"
echo " "

}

fn_db_xorgpkg ()
{
echo "Install xorg-x11 packages"
rm -rf ${XPKG} ${XMPKG}  ${APKG} 2>/dev/null

echo " "
echo "xorg-x11-font-utils
xorg-x11-server-common
xorg-x11-drv-void
xorg-x11-utils
xorg-x11-drv-mouse
xorg-x11-xkb-utils
xorg-x11-drv-evdev
xorg-x11-drv-vesa
xorg-x11-server-utils
xorg-x11-drv-keyboard
xorg-x11-twm
xorg-x11-fonts-misc
xorg-x11-fonts-Type1
xorg-x11-apps
xorg-x11-server-Xorg
xorg-x11-xinit" > ${XPKG}

echo "Validating if pacakge is already installed"
for x in `cat ${XPKG}`; do echo "...................... Verifying $x"; rpm -q $x 1>/dev/null 2>&1; if [ `echo $?` -ne 0 ]; then echo "$x" >> ${XMPKG}; fi; done;   echo " ";
if [ ! -s ${XMPKG} ]; then echo "Required pacakges are already installed. Good to go!"; else echo "Following pacakges are not installed"; fn_lines; cat ${XMPKG};   echo " ";
echo "Installing required packages"; echo " ";
for i in `cat ${XMPKG}`; do fn_lines Installing $i; yum install -y $i; done; fi
echo " "; fn_lines; echo " "
echo "Re-Validating packages"
for x in `cat ${XPKG}`; do rpm -q $x; done
echo " "

#Cleaning up junk
rm -rf ${XPKG} ${XMPKG} ${APKG} 2>/dev/null
}


fn_db_addpkg ()
{
echo "Addtional Pacakges required for Database"
echo " "

#Cleaning up temp files
rm -rf ${APKG} ${AMPKG}  2>/dev/null

echo "binutils
glibc
libgcc
libstdc++
libaio
libXext
libXtst
libX11
libXau
libxcb
libXi
make
sysstat
compat-libcap1
compat-libstdc++-33
gcc
gcc-c++
glibc-devel
libstdc++-devel
libaio-devel
cloog-ppl
cpp
glibc-headers
kernel-headers
mpfr
ppl" > ${APKG}

echo "Validating if pacakge is already installed"
for x in `cat ${APKG}`; do echo "...................... Verifying $x"; rpm -qa | grep ${x} 1>/dev/null 2>&1; if [ `echo $?` -ne 0 ]; then echo "$x" >> ${AMPKG}; fi; done;   echo " ";
if [ ! -s ${AMPKG} ]; then echo "Required pacakges are already installed. Good to go!"; else echo "Following pacakges are not installed"; fn_lines; cat ${AMPKG};   echo " ";
echo "Installing required packages"; echo " ";
for i in `cat ${AMPKG}`; do fn_lines Installing $i; yum install -y $i; done; fi
echo " "; fn_lines; echo " "
echo "Re-Validating packages"
for x in `cat ${APKG}`; do rpm -q $x; done
echo " "

#Cleaning up junk
rm -rf ${APKG} ${AMPKG} 2>/dev/null
}

fn_db_fileperm ()
{
mkdir /u00 /u01 /u02 2>/dev/null
chown -R grid:oinstall /u00
chown -R oracle:oinstall /u01 /u02
chmod -R 755 /u0*
}

fn_db_asmdisk ()
{
D=$1
if test $# -ne 1; then echo " "; echo "Syntax Error"; echo " ";
echo "Syntax:     fn_asmfulldisk \"sdc|sdd\"      (Make sure \"\" & | symbol is given for multiple disks)";
echo "            Note: sda & sdb is ignored by default for Azure VMs"; echo " "; exit 1; fi;
echo "";
echo "#####################################################################i#########################"
echo "Validate the inputs thoroughly before execution. Waiting for 10 seconds to Double-Check"
echo "                    -->  Hit ENTER if you are OK to proceed  <--"
echo "############################################################################################"
echo " "; read -t 10 ans;
fdisk -l | grep Disk | grep sd | egrep -v "sda|sdb|$D" | awk '{print $2}' | cut -d: -f1 | while read disk; do
echo "Stripping single partion on ${disk} for ASM usage"; sleep 1; parted ${disk} mklabel msdos 1>/dev/null; parted ${disk} mkpart primary 0% 100% 1>/dev/null; done;
echo " "; echo "ASM Partition function completed"
}

######################################################################################################
#Prime Functions

fn_osp1 ()
{
if [ ! -z ${custopt} ]; then
case ${custopt} in
audit) fn_gen_selinuxoff; fn_gen_iptablesoff; fn_os_fspart_ba;;
usropt) fn_gen_selinuxoff; fn_gen_iptablesoff; fn_os_fspart_buo;;
audusropt) fn_gen_selinuxoff; fn_gen_iptablesoff; fn_os_fspart_bauo;;
*) echo "Syntax Error: Use below arguments"; echo " ";
echo "osp1 audit     -> To create /, /boot, /var,/ home, /tmp, /var/crash, /audit filesystems";
echo "osp1 usropt    -> To create /, /boot, /var,/ home, /tmp, /var/crash, /usr, /opt filesystems";
echo "osp1 audusropt -> To create /, /boot, /var,/ home, /tmp, /var/crash, /audit, /usr, /opt filesystems";
echo " "; exit 1;;
esac

else
echo "Syntax Error: Use \"osp1 help\" for help"; fi
}

fn_osp2 ()
{
if [ ! -z ${custopt} ]; then
case ${custopt} in
audit) fn_os_fsrsync_ba;;
usropt) fn_os_fsrsync_buo;;
audusropt) fn_os_fsrsync_bauo;;
*) echo "Syntax Error: Use below arguments"; echo " ";
echo "osp2 audit     -> To sync /var,/ home, /tmp, /var/crash, /audit filesystems";
echo "osp2 usropt    -> To sync /var,/ home, /tmp, /var/crash, /usr, /opt filesystems";
echo "osp2 audusropt -> To sync /var,/ home, /tmp, /var/crash, /audit, /usr, /opt filesystems";
echo " "; exit 1;;
esac
else
echo "Syntax Error: Use \"osp2 help\" for help"; fi
}

fn_osp3 ()
{
if [ ! -z ${custopt} ]; then
case ${custopt} in
audit) fn_gen_fscleanup home var var/log/audit ;;
usropt) fn_gen_fscleanup home var usr opt ;;
audusropt) fn_gen_fscleanup home var usr opt var/log/audit ;;
*) echo "Syntax Error: Use below arguments"; echo " ";
echo "osp3 audit     -> To sync /var,/ home, /tmp, /var/crash, /audit filesystems";
echo "osp3 usropt    -> To sync /var,/ home, /tmp, /var/crash, /usr, /opt filesystems";
echo "osp3 audusropt -> To sync /var,/ home, /tmp, /var/crash, /audit, /usr, /opt filesystems";
echo " "; exit 1;;
esac
fn_gen_chtmpperm
fn_gen_dtinstall
else
echo "Syntax Error: Use \"osp3 help\" for help"; fi

}

fn_azpostdt ()
{
fn_gen_etchosts
fn_gen_dxcsupt
fn_gen_azpeerdns
fn_gen_azdnssearch
fn_gen_azntpserver
}

fn_dbp1 ()
{
fn_gen_caution
fn_gen_ostimezone EST
fn_gen_etchosts
fn_db_fspart
}

fn_dbp2 ()
{
fn_gen_caution
fn_gen_osfsmkfs 8 ext4
fn_db_fsrsync
}

fn_dbp3 ()
{
fn_gen_caution
fn_gen_fscleanup home var usr opt
fn_gen_chtmpperm
fn_gen_azswapsize
fn_gen_azpeerdns
fn_gen_azdnssearch
}

fn_dbp4 ()
{
fn_db_xorgpkg
fn_db_addpkg
fn_db_kernel
fn_db_ulimits
fn_db_userngrp
fn_db_fileperm
}

fn_vglvfs ()
{
if test ${nargs} -eq 4;
        then
if [ -b ${custopt} ] && [ ! -d /dev/${custopt1} ] && [ -f ${custopt2} ]; then

        fn_gen_osvg ${custopt1} ${custopt}
        fn_gen_oslv ${custopt2}
else
        echo "Error: Something is wrong. Double check disk name (with full path), vgname and LV file path"
fi
else
echo " "
echo "Syntax Error:       vglvfs <diskpath> <vgname> <lvtemplatefile>"
echo "Example:            vglvfs /dev/sdc vg01 /tmp/lvtemplate"
echo " ";
echo "Template File Syntax:     lvname:size:vgname:mount:fstype"
echo "Template File Example:    lvu00:50:vg01:/u00:ext4"
echo "                          lvu01:100:vg01:/u01:ext4"; echo " "; exit 1;
fi
}


######################################################################################################
#Main Program

fn_main ()
{
if [ "$option" = "proxy" ]; then touch ${SCPTESS}; exit 0; fi;
if [ "$option" = "essentials" ]; then fn_gen_scriptessentials; exit 0; fi;
if [ ! -f ${SCPTESS} ]; then echo "Install script essentials. Use \"fmoscript.sh essentials\" to proceed"; exit 1; fi;
case $option in
-osp1|osp1) fn_osp1;;
-osp2|osp2) fn_osp2;;
-osp3|osp3) fn_osp3;;
-dbp1|dbp1) fn_dbp1;;
-dbp2|dbp2) fn_dbp2;;
-dbp3|dbp3) fn_dbp3;;
-dbp4|dbp4) fn_dbp4;;
-asmpart|asmpart) fn_db_asmdisk ${custopt};;
-azpostdt|azpostdt) fn_azpostdt;;
-vglvfs|vglvfs) fn_vglvfs;;
-preout|preout) fn_gen_preout;;
-listfn|listfn) fn_gen_subfn;;
-custom|custom) fn_gen_custom;;
-azagtchk|azagtchk) fn_az_agentcheck;;
-dtclean|dtclean)
if [ ! -z ${custopt} ]; then fn_gen_dtcleanup ${custopt}; else echo "Syntax error: Use \"fn_gen_dtcleanup help\" for help"; fi;;
-sraclean|sraclean) 
if [ ! -z ${custopt} ]; then fn_sra_rm ${custopt}; else echo "Syntax error: Use \"fn_sra_rm help\" for help"; fi;;
-help|--help|help) fn_gen_help;;
*)  fn_gen_help; exit 1;;
esac
}

fn_main |& tee -a ${FLOG}
rm -rf ${TDIR}