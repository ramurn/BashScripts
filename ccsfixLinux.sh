#!/bin/bash


##############################################################################
#Author: raja.murugan@dxc.com                                                #
#Purpose: Remediate CCS error checks                                         #
#Version: 1.0 : 11Dec2017 - Initial Deployment                               #
#Version: 1.1 : 12Dec2017 - Introducded SSH reload option instead of restart #
##############################################################################

##
#This script remediates following checks in CCS
#CHECK 1: 201.01.1.1.5 - User home directories should have 750 or stricter permission (AON Linux V1.2)
#CHECK 2: 201.01.2.4 - Files /etc/ssh/sshd_config and /etc/sudoers should have the lines - PermitRootLogin no and Defaults syslog = local4 respectively (AON Linux V1.2)
#CHECK 3: 201.01.2.4 - Permission for directory /etc, /usr, /var should be 555 or stricter (AON Linux V1.2)
#CHECK 4: 201.05.2.13 - File /etc/sysctl.conf should have line - net.ipv4.conf.all.accept_redirects  =  0 & net.ipv4.icmp_echo_ignore_broadcasts  =  1 (AON Linux V1.2)
#CHECK 5: 201.01.2.4 - Startup scripts has permission of 775 or stricter? (AON Linux V1.2)
#CHECK 6: 201.01.1.1.5 - File /etc/profile should have default UMASK = 027 (AON Linux V1.2)
#CHECK 7: 201.10.2.2 - Log rotate for file /var/log/faillog is set to 5 weeks? (AON Linux V1.2)
##

DATE=`date '+%F-%H%M'`
DIR=/tmp/ccsfix.$DATE
LOG=${DIR}/ccsfixlog.out
rm -rf ${DIR} 2>/dev/null
mkdir ${DIR}

TMPEXEC=/tmp/ccsfix.exec

BKPHOME=/etc/home.bkp.ccsfix
BKPSSH=/etc/ssh/sshd_config.bkp.ccsfix
BKPSUDO=/etc/sudoers.bkp.ccsfix
BKPSYS=/etc/sysctl.conf.bkp.ccsfix
BKPSYSLOADED=/etc/sysctl-a_output_before_relaod
BKPEXEC1=/etc/initscripts.bkp.ccsfix
BKPEXEC2=/etc/rcscripts.bkp.ccsfix
BKPUMASK=/etc/profile.bkp.ccsfix
BKPLOGROTATE=/etc/logrotate.conf.bkp.ccsfix

##Take backup of backup files if exists
for file in $BKPHOME $BKPSSH $BKPSUDO $BKPSYS $BKPSYSLOADED $BKPEXEC1 $BKPEXEC2 $BKPUMASK $BKPLOGROTATE; do
if [ -f ${file} ]; then cp -p ${file} ${file}.1; fi
rm -f ${file} 2>/dev/null
done


CHK1=${DIR}/check.home
CHK21=${DIR}/check.sshd_config
CHK22=${DIR}/check.sudoers
CHKSSHSVC=${DIR}/check.sshsvc
CHK41=${DIR}/check.sysctl1
CHK42=${DIR}/check.sysctl2
CHK51=${DIR}/check.initscripts
CHK52=${DIR}/check.rcscripts
CHK6=${DIR}/check.umask
CHK7=${DIR}/check.logrotate
CHK7TMP=${DIR}/check.logrotatetmp

RSLT1=${DIR}/result.home
RSLT21=${DIR}/result.sshd_config
RSLT22=${DIR}/result.sudoers
RSLT41=${DIR}/result.sysctl1
RSLT42=${DIR}/result.sysctl2
RSLT6=${DIR}/result.umask
RSLT7=${DIR}/result.logroate

echo " "
echo "CCSFIX script execution started"
echo " "
sleep 1

fnhome ()
{

##################################################################
#SEGMENT 1 - Find directories in /home which are weeker than 750 #
##################################################################
echo " " > ${LOG}
echo "CHECK 1: BEGINS at `date`" >> ${LOG}
echo "Seg 1: Checking directories weaker than 750 under /home"
echo "Seg 1: Checking directories weaker than 750 under /home" >> ${LOG}
echo "Seg 1: Capturing permissions of /home before executing script" >> ${LOG}
ls -ltrd /home/* > ${BKPHOME}
echo "Seg 1: Backup taken. Listing directories which meets the condition" >> ${LOG}
find /home/* -maxdepth 0 -type d -perm -700 -not -perm 750 -not -perm 700 -exec ls -ld {} \; > ${CHK1}
if [ -f ${CHK1} ] && [ -s ${CHK1} ]; then
        echo "Seg 1: Following files meets the condition" >> ${LOG}
        echo " " >> ${LOG}
        cat ${CHK1} >> ${LOG}
        echo " " >> ${LOG}
        echo "Seg 1: Changing permission on impacted directories" >> ${LOG}
        cat ${CHK1} | awk '{print $NF}' | while read dir; do chmod 750 $dir; done
        if [ `echo $?` -eq 0 ]; then
                echo "Seg 1: Changing permission on impacted directories - Completed" >> ${LOG}
                ls -ltrd /home/* > ${RSLT1}
                echo "Seg 1: Output of /home after changing permission is saved in ${RSLT1}" >> ${LOG}
                echo "Seg 1: CHECKRESULT: MODIFIED : Some directories in /home has been modifiled by script" >> ${LOG}
        else
                echo "Seg 1: MANUAL CHECK NEEDED: Changing permission did not complete cleanly" >> ${LOG}
                echo "Seg 1: CHECKRESULT: ERROR : Something went wrong. Check log file in detail" >> ${LOG}
        fi
else
        echo "Seg 1: None of the directory meets condition. NO CHANGES MADE" >> ${LOG}
        echo "Seg 1: CHECKRESULT: PASS : /home meets is already CCS complaint" >> ${LOG}
        ls -ltrd /home/* > ${RSLT1}
fi
echo "CHECK 1: ENDS at `date`" >> ${LOG}
echo " " >> ${LOG}
sleep 1
}

fnsshroot ()
{
###########################################################################
#SEGMENT 2: Check SSH direct root login & Defaults syslog in /etc/sudoers #
###########################################################################

echo "CHECK 2: BEGINS at `date`" >> ${LOG}
echo "Seg 2.1: Checking if direct root login enabled in SSH config file"
echo "Seg 2.1: Checking if direct root login enabled in SSH config file" >> ${LOG}

rm -f ${CHKSSHSVC} 2>/dev/null
cat /etc/ssh/sshd_config | grep -w PermitRootLogin | grep -v ^# > ${CHK21}
if [ -f ${CHK21} ] && [ `wc -l ${CHK21} | awk '{print $1}'` -eq 1 ]; then
        if [ `cat /etc/ssh/sshd_config | grep -w PermitRootLogin | grep -v ^# | awk '{print $2}'` == "no" ]; then
                cat /etc/ssh/sshd_config | grep -w PermitRootLogin | grep -v ^# > ${RSLT21}
                echo "Seg 2.1: Direct root login in SSH config file is already disabled" >> ${LOG}
                echo "Seg 2.1: CHECKRESULT: PASS : PermitRootLogin Already disabled" >> ${LOG}
        elif [ `cat /etc/ssh/sshd_config | grep -w PermitRootLogin | grep -v ^# | awk '{print $2}'` == "yes" ]; then
                echo "Seg 2.1: Direct root login is enabled in SSH config file. Taking backup" >> ${LOG}
                cp -p /etc/ssh/sshd_config ${BKPSSH}
                echo "Seg 2.1: Backup of SSH config is saved with name ${BKPSSH}" >> ${LOG}
                echo "Seg 2.1: Disabling direct root login in ssh config file" >> ${LOG}
                num=`cat /etc/ssh/sshd_config | grep -nw PermitRootLogin | grep -v "#" | cut -d: -f1`
                echo "sed -i '${num}s/yes/no/' /etc/ssh/sshd_config" > ${TMPEXEC}
                sh ${TMPEXEC}
                if [ `echo $?` -eq 0 ]; then
                        cat /etc/ssh/sshd_config | grep -w PermitRootLogin | grep -v ^# > ${RSLT21}
                        echo "Seg 2.1: Root login disabled in config file. Reloading SSH service" >> ${LOG}
                        service sshd reload >> ${LOG}
                        echo "Seg 2.1: Reloading SSH service compelted" >> ${LOG}
                        echo "Seg 2.1: CHECKRESULT: MODIFIED : PermitRootLogin has been disabled by script" >> ${LOG}
                        touch ${CHKSSHSVC}
                else
                        echo "Seg 2.1: MANUAL CHECK NEEDED: Changing permission in ssh config file failed" >> ${LOG}
                        echo "Seg 2.1: CHECKRESULT: ERROR: Something went wrong. Check log file in detail" >> ${LOG}
                fi
        fi
elif [ `wc -l ${CHK21} | awk '{print $1}'` -eq 0 ]; then
        echo "Seg 2.1: No entries matching PermitRootLogin in SSH config file. Taking backup" >> ${LOG}
        cp -p /etc/ssh/sshd_config ${BKPSSH}
        echo "PermitRootLogin no" >> /etc/ssh/sshd_config
        touch ${CHKSSHSVC}
        echo "Seg 2.1: Appended \"PermitRootLogin no\" to SSHD config file. Reloading SSH service" >> ${LOG}
        service sshd reload >> ${LOG}
        echo "Seg 2.1: Reloading SSH service compelted" >> ${LOG}
        echo "Seg 2.1: CHECKRESULT: APPENDED : PermitRootLogin has beed disabled by script" >> ${LOG}
        cat /etc/ssh/sshd_config | grep -w PermitRootLogin | grep -v ^# > ${RSLT21}
else
        echo "Seg 2.1: MANUAL CHECK NEEDED: Duplicate entries found in SSHD config file" >> ${LOG}
        echo "Seg 2.1: CHECKRESULT: ERROR : Duplicate entries founf in SSH config file" >> ${LOG}
fi

echo "Seg 2.2: Checking Defaults syslog entry in /etc/sudoers"
echo "Seg 2.2: Checking Defaults syslog entry in /etc/sudoers" >> ${LOG}
grep Defaults /etc/sudoers | grep syslog | grep -v ^# > ${CHK22}
if [ -f ${CHK22} ] && [ `wc -l ${CHK22} | awk '{print $1}'` -eq 1 ]; then
        grep Defaults /etc/sudoers | grep syslog | grep local4 | grep -v ^# > ${RSLT22}
        if [ `echo $?` -eq 0 ]; then
                echo "Seg 2.2: CHECKRESULT: PASS : /etc/sudoers Defaults syslog already has value local4" >> ${LOG}
        else
                echo "Seg 2.3: Defaults syslog value is not as expected. Taking backup" >> ${LOG}
                cp -p /etc/sudoers ${BKPSUDO}
                echo "Seg 2.2: Backup of sudoers is taken as ${BKPSUDO}" >> ${LOG}
                num=`grep -nw Defaults /etc/sudoers | grep syslog | grep -v "#" | cut -d: -f1`
                echo "sed -i '${num}s/\(local\).*/\14/' /etc/sudoers" > ${TMPEXEC}
                sh ${TMPEXEC}
                grep Defaults /etc/sudoers | grep syslog | grep local4 | grep -v ^# > ${RSLT22}
                echo "Seg 2.2: CHECKRESULT: MODIFIED : Defaults syslog value change to local4" >> ${LOG}
        fi
elif [ `wc -l ${CHK22} | awk '{print $1}'` -eq 0 ]; then
        echo "Seg 2.2: Defaults syslog value is not set in /etc/sudoers. Taking backup" >> ${LOG}
        cp -p /etc/sudoers ${BKPSUDO}
        echo "Seg 2.2: Backup of sudoers is taken as ${BKPSUDO}" >> ${LOG}
        echo "Defaults syslog = local4" >> /etc/sudoers
        grep Defaults /etc/sudoers | grep syslog | grep local4 | grep -v ^# > ${RSLT22}
        echo "Seg 2.2: CHECKRESULT : APPENDED : Defaults syslog = local4 appended to sudoers file" >> ${LOG}
else
        echo "Seg 2.2: MANUAL CHECK NEEDED: Duplicate values found while checking Defaults syslog value" >> ${LOG}
        echo "Seg 2.2: CHECKRESULT : ERROR : Duplicate entries found. Check log file in detail" >> ${LOG}
fi

echo "CHECK 2: ENDS at `date`" >> ${LOG}
echo " " >> ${LOG}
sleep 1
}


fnuveperm ()
{
##########################################################
#SEGMENT 3: Change /etc,/var,/usr file permission to 555 #
##########################################################

echo "CHECK 3: BEGINS at `date`" >> ${LOG}
count=1
for i in etc var usr; do
echo "Seg 3.${count}: Checking current permission of /${i}"
echo "Seg 3.${count}: Checking current permission of /${i}" >> ${LOG}
find / -maxdepth 1 -type d -name ${i} -perm 555 -exec ls -ld {} \; > ${DIR}/check.${i}
grep -q "dr-xr-xr-x" ${DIR}/check.${i}
if [ `echo $?` -eq 0 ]; then
        echo "Seg 3.${count}: /${i} is already having 555 permission" >> ${LOG}
        echo "Seg 3.${count}: CHECKRESULT: PASS : /${i} is already having 555 permission" >> ${LOG}
        ls -ld /etc > ${DIR}/result.${i}
else
        echo "Seg 3.${count}: /${i} is not having 555. Taking backup of current permission" >> ${LOG}
        ls -ld /etc > /etc/${i}.bkp.ccsfix
        echo "Seg 3.${count}: Backup of current permissions has been captured on /etc/${i}.bkp.ccsfix" >> ${LOG}
        echo "Seg 3.${count}: Changing /${i} permission to 555" >> ${LOG}
        chmod 555 /${i}
        echo "Seg 3.${count}: CHECKRESULT: MODIFIED : /${i} permission has been changed to 555" >> ${LOG}
        ls -ld /etc > ${DIR}/result.${i}
fi
count=`expr $count + 1`
done
echo "CHECK 3: ENDS at `date`" >> ${LOG}
echo " " >> ${LOG}
sleep 1
}

fnsysctl ()
{
#####################################################################################################################
#SEGMENT 4: Check value of net.ipv4.conf.all.accept_redirects & net.ipv4.icmp_echo_ignore_broadcasts in sysctl.conf #
#####################################################################################################################

echo "CHECK 4: BEGINS at `date`" >> ${LOG}
echo "Seg 4.1: Checking value of net.ipv4.conf.all.accept_redirects in /etc/sysctl.conf"
echo "Seg 4.1: Checking value of net.ipv4.conf.all.accept_redirects in /etc/sysctl.conf" >> ${LOG}
grep net.ipv4.conf.all.accept_redirects /etc/sysctl.conf | grep -v ^# > ${CHK41}
if [ -f ${CHK41} ] && [ `wc -l ${CHK41} | awk '{print $1}'` -eq 1 ]; then
        if [ `cut -d"=" -f2 ${CHK41}` -eq 0 ]; then
                echo "Seg 4.1: CHECKRESULT: PASS : sysctl.conf already has value 0 for net.ipv4.conf.all.accept_redirects" >> ${LOG}
        else
                echo "Seg 4.1: sysctl.conf doesnot have desired value for net.ipv4.conf.all.accept_redirects. Taking backup" >> ${LOG}
                cp -p /etc/sysctl.conf ${BKPSYS}
                echo "Seg 4.1: /etc/sysctl.conf has been backed up in ${BKPSYS}" >> ${LOG}
                num=`grep -n net.ipv4.conf.all.accept_redirects /etc/sysctl.conf | grep -v "#" | cut -d: -f1`
                echo "sed -i '${num}s/\(net.ipv4.conf.all.accept_redirects\).*$/\1 = 0/' /etc/sysctl.conf" > ${TMPEXEC}
                sh ${TMPEXEC}
                echo "Seg 4.1: value has been changed to \"0\" on sysctl.conf. Preparing to reload sysctl" >> ${LOG}
                echo "Seg 4.1: Current value of net.ipv4.conf.all.accept_redirects is `sysctl net.ipv4.conf.all.accept_redirects`" >> ${LOG}
                sysctl -a > ${BKPSYSLOADED} 2>&1
                echo "Seg 4.1: Backedup current value of all sysctl parameters in ${BKPSYSLOADED}" >> ${LOG}
                echo "Seg 4.1: Manually changing value net.ipv4.conf.all.accept_redirects to 0 in current loaded kernel" >> ${LOG}
                sysctl -w net.ipv4.conf.all.accept_redirects=0 >> ${LOG}
                echo "Seg 4.1: CHECKRESULT: MODIFIED : Changed the required parameter value to 0 in kernel & file" >> ${LOG}
        fi
elif [ `wc -l ${CHK41} | awk '{print $1}'` -eq 0 ]; then
        echo "Seg 4.1: No entry present in /etc/sysctl.conf. Taking backup" >> ${LOG}
        cp -p /etc/sysctl.conf ${BKPSYS}
        echo "Seg 4.1: Appending net.ipv4.conf.all.accept_redirects = 0 to sysctl file" >> ${LOG}
        echo "net.ipv4.conf.all.accept_redirects = 0" >> /etc/sysctl.conf
        echo "Seg 4.1: Value appended in file. Loading the same value in kernel" >> ${LOG}
        sysctl -a > ${BKPSYSLOADED} 2>&1
        echo "Seg 4.1: Backedup current value of all sysctl parameters in ${BKPSYSLOADED}" >> ${LOG}
        sysctl -w net.ipv4.conf.all.accept_redirects=0 >> ${LOG}
        echo "Seg 4.1: CHECKRESULT: APPENDED : Changed the required parameter value to 0 in kernel & file" >> ${LOG}
else
        echo "Seg 4.1: CHECKRESULT: ERROR: Duplicate value found for net.ipv4.conf.all.accept_redirects" >> ${LOG}
fi

echo "Seg 4.2: Checking value of net.ipv4.icmp_echo_ignore_broadcasts in /etc/sysctl.conf"
echo "Seg 4.2: Checking value of net.ipv4.icmp_echo_ignore_broadcasts in /etc/sysctl.conf" >> ${LOG}
grep net.ipv4.icmp_echo_ignore_broadcasts /etc/sysctl.conf | grep -v ^# > ${CHK42}
if [ -f ${CHK42} ] && [ `wc -l ${CHK42} | awk '{print $1}'` -eq 1 ]; then
        if [ `cut -d"=" -f2 ${CHK42}` -eq 1 ]; then
                echo "Seg 4.2: CHECKRESULT : PASS : sysctl.conf already has value 1 for net.ipv4.icmp_echo_ignore_broadcasts" >> ${LOG}
        else
                echo "Seg 4.2: sysctl.conf doesnot have desired value for net.ipv4.icmp_echo_ignore_broadcasts. Taking backup" >> ${LOG}
                if [ -f ${BKPSYS} ]; then
                        echo "Seg 4.2: Backup file already exists in ${BKPSYS}" >> ${LOG}
                else
                        cp -p /etc/sysctl.conf ${BKPSYS}
                fi
                echo "Seg 4.2: /etc/sysctl.conf has been backed up in ${BKPSYS}" >> ${LOG}
                num=`grep -n net.ipv4.icmp_echo_ignore_broadcasts /etc/sysctl.conf | grep -v "#" | cut -d: -f1`
                echo "sed -i '${num}s/\(net.ipv4.icmp_echo_ignore_broadcasts\).*$/\1 = 1/' /etc/sysctl.conf" > ${TMPEXEC}
                sh ${TMPEXEC}
                echo "Seg 4.2: value has been changed to \"1\" on sysctl.conf. Preparing to reload sysctl" >> ${LOG}
                echo "Seg 4.2: Current value of net.ipv4.icmp_echo_ignore_broadcasts is `sysctl net.ipv4.icmp_echo_ignore_broadcasts`" >> ${LOG}
                if [ -f ${BKPSYSLOADED} ]; then
                        echo "Seg 4.2: Backup is already saved in  ${BKPSYSLOADED}" >> ${LOG}
                else
                sysctl -a > ${BKPSYSLOADED} 2>&1
                echo "Seg 4.2: Backed up current value of all sysctl parameters in ${BKPSYSLOADED}" >> ${LOG}
                fi
                echo "Seg 4.2: Manually changing value net.ipv4.icmp_echo_ignore_broadcasts to 1 in current loaded kernel" >> ${LOG}
                sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=1 >> ${LOG}
                echo "Seg 4.2: CHECKRESULT: MODIFIED : Changed the required parameter value to 1 in kernel & file" >> ${LOG}
        fi
elif [ `wc -l ${CHK42} | awk '{print $1}'` -eq 0 ]; then
        echo "Seg 4.2: No entry present in /etc/sysctl.conf. Taking backup" >> ${LOG}
        if [ -f ${BKPSYS} ]; then
                echo "Seg 4.2: Backup is already saved in ${BKPSYS}" >> ${LOG}
        else
                cp -p /etc/sysctl.conf ${BKPSYS}
        fi
        echo "Seg 4.2: Appending net.ipv4.icmp_echo_ignore_broadcasts = 1 to sysctl file" >> ${LOG}
        echo "net.ipv4.icmp_echo_ignore_broadcasts = 1" >> /etc/sysctl.conf
        echo "Seg 4.2: Value appended in file. Loading the same value in kernel" >> ${LOG}
        if [ -f ${BKPSYSLOADED} ]; then
                echo "Seg 4.2: Backup is already saved in  ${BKPSYSLOADED}" >> ${LOG}
        else
                sysctl -a > ${BKPSYSLOADED} 2>&1
                echo "Seg 4.2: Backedup current value of all sysctl parameters in ${BKPSYSLOADED}" >> ${LOG}
        fi
        sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=1 >> ${LOG}
        echo "Seg 4.2: CHECKRESULT: APPENDED : Changed the required parameter value to 0 in kernel & file" >> ${LOG}
else
        echo "Seg 4.2: CHECKRESULT: ERROR: Duplicate value found for net.ipv4.conf.all.accept_redirects" >> ${LOG}
fi


echo "CHECK 4: ENDS at `date`" >> ${LOG}
echo " " >> ${LOG}
sleep 1
}


fninit()
{
####################################################
#SEGMENT 5: Check startup scripts 775 or Strickter #
####################################################

echo "CHECK 5: BEGINS at `date`" >> ${LOG}

echo "Seg 5.1: Checking if /etc/init.d has files weaker than 775"
echo "Seg 5.1: Checking if /etc/init.d has files weaker than 775" >> ${LOG}
echo "Seg 5.1: Taking backup of current permissions in /etc/init.d/ folder" >> ${LOG}
cd /etc/init.d
ls -ltr | grep -v total > ${BKPEXEC1}
echo "Seg 5.1: Checking if any executables in /etc/init.d has permission weaker than 775" >> ${LOG}
cd /etc/init.d
find . -maxdepth 1 -perm -755 ! -perm 755 ! -perm 775 -exec ls -l {} \; > ${CHK51}
if [ -f ${CHK51} ] && [ -s ${CHK51} ]; then
        echo "Seg 5.1: Following files are having weaker permission than 775" >> ${LOG}
        echo " " >> ${LOG}
        cat ${CHK51} >> ${LOG}
        echo " " >> ${LOG}
        echo "Seg 5.1: Changing permission of the impacted files" >> ${LOG}
        cd /etc/init.d
        cat ${CHK51} | awk '{print $NF}' | while read line; do chmod 775 $line; done
        echo "Seg 5.1: Changing permission of the impacted files - Completed" >> ${LOG}
        echo "Seg 5.1: CHECKRESULT: MODIFIED : Files permission changed" >> ${LOG}
else
        echo "Seg 5.1: All files in /etc/init.d are already having stricter permission than 775" >> ${LOG}
        echo "Seg 5.1: CHECKRESULT: PASS : All files already having strict executable permissions" >> ${LOG}
fi

echo "Seg 5.2: Checking if /etc/rc?.d/ directories has files weaker than 775 permission"
echo "Seg 5.2: Checking if /etc/rc?.d/ directories has files weaker than 775 permission" >> ${LOG}
find /etc/rc.d/rc?.d ! -type l ! -type d -perm -755 ! -perm 775 ! -perm 755 -exec ls -l {} \; > ${CHK52}
if [ -f ${CHK52} ] && [ -s ${CHK52} ]; then
        echo "Seg 5.2: Some files found to have permissions greater than 775 in /etc/rc?.d/" >> ${LOG}
        cp -p ${CHK52} ${BKPEXEC2}
        echo "Seg 5.2: Files are saved in ${BKPEXEC2}" >> ${LOG}
        echo "Seg 5.2: Changing permission on the impacted files" >> ${LOG}
        cat ${CHK52} | awk '{print $NF}' | while read line; do chmod 755 $line; done
        echo "Seg 5.2: Changing permission on the impacted files - Completed" >> ${LOG}
        echo "Seg 5.2: CHECKRESULT: MODIFIED : Files permission changed" >> ${LOG}
else
        echo "Seg 5.2: No files are found weaker than 775 in /etc/rc?d/ paths" >> ${LOG}
        echo "Seg 5.2: CHECKRESULT: PASS : All files already having strit executable permissions" >> ${LOG}
fi

echo "CHECK 5: ENDS at `date`" >> ${LOG}
echo " " >> ${LOG}
sleep 1
}

fnumask()
{
#####################################################
#CHECK 6: Change UMASK value to 027 in /etc/profile #
#####################################################

echo "CHECK 6: BEGINS at `date`" >> ${LOG}
echo "Seg 6: Checking in /etc/profile has 022 mask"
echo "Seg 6: Checking in /etc/profile has 022 mask" >> ${LOG}
grep -n umask /etc/profile | grep -v ^# | grep 022 > ${CHK6}
if [ -f ${CHK6} ] && [ -s ${CHK6} ]; then
        if [ `wc -l ${CHK6} | awk '{print $1}'` -eq 1 ]; then
                echo "Seg 6: UMASK 022 is found in /etc/profile. Taking backup" >> ${LOG}
                cp -p /etc/profile ${BKPUMASK}
                echo "Seg 6: Backup is taken on ${BKPUMASK}. Changing UMASK value in profile file" >> ${LOG}
                num=`cat ${CHK6} | cut -d: -f1`
                echo "sed -i '${num}s/\(umask\).*$/\1 027/' /etc/profile" > ${TMPEXEC}
                sh ${TMPEXEC}
                echo "Seg 6: CHECKRESULT: MODIFIED : UMASK value changed in /etc/profile" >> ${LOG}
                grep -i umask /etc/profile | grep -v ^# > ${RSLT6}
        elif [ `wc -l ${CHK6} | awk '{print $1}'` -eq 2 ]; then
                num=`cat ${CHK6} | tail -1 | cut -d: -f1`
                echo "sed -i '${num}s/\(umask\).*$/\1 027/' /etc/profile" > ${TMPEXEC}
                sh ${TMPEXEC}
                echo "Seg 6: CHECKRESULT: MODIFIED : UMASK value changed in /etc/profile" >> ${LOG}
                grep -i umask /etc/profile | grep -v ^# > ${RSLT6}
        else
                echo "Seg 6: MANUAL CHECK NEEDED: Multiple values found for umask" >> ${LOG}
                echo "Seg 6: CHECKRESULT: ERROR: Multiple values found for umask" >> ${LOG}
        fi
else
        echo "Seg 6: CHECKRESULT: PASS: 022 not found in /etc/profile" >> ${LOG}
fi

echo "CHECK 6: ENDS at `date`" >> ${LOG}
echo " " >> ${LOG}
sleep 1
}

fnlogrotate()
{

###############################################
#SEGMENT 7: set logrotate defaults weeks to 5 #
###############################################

echo "CHECK 7: BEGINS at `date`" >> ${LOG}
echo "Seg 7: Checking the current values of logrotate weeks in /etc/logrotate.conf"
echo "Seg 7: Checking the current values of logrotate weeks in /etc/logrotate.conf" >> ${LOG}
grep -w rotate /etc/logrotate.conf | grep -v ^# | grep -v 5 > ${CHK7}
if [ -f ${CHK7} ] && [ -s ${CHK7} ]; then
        echo "Seg 7: Some entries are having values other than 5. Taking backup" >> ${LOG}
        cp -p /etc/logrotate.conf ${BKPLOGROTATE}
        echo "Seg 7: Backup is taken on ${BKPLOGROTATE} file" >> ${LOG}
        rm -rf ${TMPEXEC} 2>/dev/null
        grep -nw rotate /etc/logrotate.conf | grep -v "#" | awk '$2 !~/5/' | cut -d: -f1 | while read num; do echo "sed -i '${num}s/\(rotate\).*$/rotate 5/' /etc/logrotate.conf"; done >> ${TMPEXEC}
        sh ${TMPEXEC}
        grep -w rotate /etc/logrotate.conf | grep -v ^# | grep -v 5 > ${CHK7TMP}
        if [ `wc -l ${CHK7TMP} | awk '{print $1}'` -eq 0 ]; then
                grep rotate /etc/logrotate.conf | grep -v ^# > ${RSLT7}
                echo "Seg 7: CHECKRESULT: MODIFIED : rotate values chagned to 5 to all occurances" >> ${LOG}
        else
                echo "Seg 7: CHECKRESULT: ERROR : MANUAL CHECK NEEDED" >> ${LOG}
        fi
else
        grep rotate /etc/logrotate.conf | grep -v ^# > ${RSLT7}
        echo "Seg 7: CHECKRESULT: PASS : All rotate values are already set to 5" >> ${LOG}
fi

echo "CHECK 7: ENDS at `date`" >> ${LOG}
echo " " >> ${LOG}
sleep 1
}

fnhome
fnsshroot
fnuveperm
fnsysctl
fninit
fnumask
fnlogrotate

echo " "
echo "CCSFIX script execution completed. Below is the summary of the run."
echo " "
echo "################################################################################################################"
echo "# Log directory for this run : ${DIR}"
echo "# Log file for this run : ${LOG}"
echo "# Following are the backups files taken as part of this script"
echo "......................................................................."
ls -ltr /etc/*.bkp.ccsfix
echo "......................................................................."
echo " "
echo "# Script Result: If you don't see ERROR here, then you are good"
grep CHECKRESULT ${LOG}
echo "################################################################################################################"
echo " "
