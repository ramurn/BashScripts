#!/bin/bash


######################################################################################
#Author: raja.murugan@dxc.com                                                        #
#Purpose: Remediate CCS error checks                                                 #
#Version: 1.0 : 11Dec2017 - Initial Deployment                                       #
#Version: 1.1 : 12Dec2017 - Introduced SSH reload option instead of restart          #
#Version: 2.0 : 16Jan2018 - More checks added (Check 8 till 14 )                     #
#                         - Mapped function name for each check along with variables #
#Version: 2.1 : 14Feb2018 - Added minor changes and 201.03 check on fnpamctrlval     #
#Version: 2.2 : 13Mar2018 - Minute changes and enhanced Seg 1 and Seg 13.3 checks    # 
#Version: 2.3 : 17Apl2018 - Set PATH variable                                        #
#                                                                                    #
######################################################################################

##
#This script remediates following checks in CCS
#CHECK 01: 201.01.1.1.5 - User home directories should have 750 or stricter permission (AON Linux V1.2)
#CHECK 02: 201.01.2.4 - Files /etc/ssh/sshd_config and /etc/sudoers should have the lines - PermitRootLogin no and Defaults syslog = local4 respectively (AON Linux V1.2)
#CHECK 03: 201.01.2.4 - Permission for directory /etc, /usr, /var should be 555 or stricter (AON Linux V1.2)
#CHECK 04: 201.05.2.13 - File /etc/sysctl.conf should have line - net.ipv4.conf.all.accept_redirects  =  0 & net.ipv4.icmp_echo_ignore_broadcasts  =  1 (AON Linux V1.2)
#CHECK 05: 201.01.2.4 - Startup scripts has permission of 775 or stricter? (AON Linux V1.2)
#CHECK 06: 201.01.1.1.5 - File /etc/profile should have default UMASK = 027 (AON Linux V1.2)
#CHECK 07: 201.10.2.2 - Log rotate for file /var/log/faillog is set to 5 weeks? (AON Linux V1.2)
#CHECK 08: 201.01.2.4 - File /etc/pam.d/password-auth and /etc/pam.d/system-auth should have the lines for auth required and account required
#CHECK 09: 201.02.1.5 - Pam authentication files should have the lines for password control values
#		   201.03     - File /etc/pam.d/passwd or /etc/pam.d/system-auth should be compliant
#CHECK 10: 201.02.1.5.1 - File /etc/pam.d/system-auth should have parameters on password required pam_passwdqc.so OR pam_cracklib.so
#CHECK 11: 201.02.1.9.1 - File /etc/pam.d/system-auth or /etc/pam.d/password-auth should have the line remember parameter
#CHECK 12: 201.10.1.1 - File /etc/rsyslog.conf should have the lines for capturing login success or failure
#CHECK 13: 201.10.1.1 - Files /etc/pam.d/system-auth or /etc/pam.d/password-auth should be compliant
##


##
#Functions

#CHECK 01: 201.01.1.1.5         - Function Name: fnhome
#CHECK 02: 201.01.2.4           - Function Name: fnsshroot
#CHECK 03: 201.01.2.4           - Function Name: fnuveperm
#CHECK 04: 201.05.2.13          - Function Name: fnsysctl
#CHECK 05: 201.01.2.4           - Function Name: fninit
#CHECK 06: 201.01.1.1.5         - Function Name: fnumask
#CHECK 07: 201.10.2.2           - Function Name: fnlogrotate
#CHECK 08: 201.01.2.4           - Function Name: fnpamauth
#CHECK 09: 201.02.1.5           - Function Name: fnpamctrlval
#CHECK 10: 201.02.1.5.1         - Function Name: fnsyspass
#CHECK 11: 201.02.1.9.1         - Function Name: fnpassremember
#CHECK 12: 201.10.1.1           - Function Name: fnrsyslogincap
#CHECK 13: 201.10.1.1           - Function Name: fnauthcomplaint

DATE=`date '+%F-%H%M'`
DIR=/tmp/ccsfix.$DATE
BDIR=/etc/ccsfix.$DATE
TMPEXEC=/tmp/ccsfix.exec
LOG=${BDIR}/ccsfixlog.out

#Setting env PATH: 
export PATH=$PATH:/bin:/usr/bin:/sbin:/usr/sbin

#Temporary Files
TMPSAUTH=/tmp/system-auth.tmp
TMPPAUTH=/tmp/password-auth.tmp

#Cleaning up temporary files
rm -rf ${DIR} ${TMPEXEC} ${TMPSAUTH} ${TMPPAUTH} 2>/dev/null
mkdir ${DIR} ${BDIR} ${BDIR}/pam.d-bkp 2>/dev/null
rsync -a /etc/pam.d/* ${BDIR}/pam.d-bkp/


##Config Files
PAUTH=/etc/pam.d/password-auth          #fnpamauth, fnpassremember, fnauthcomplaint
SAUTH=/etc/pam.d/system-auth            #fnpamauth, fnsyspass, fnpassremember, fnauthcomplaint
OAUTH=/etc/pam.d/other                  #fnpamauth
PSSH=/etc/pam.d/sshd                    #fnpamctrlval
PPASSWD=/etc/pam.d/passwd               #fnpamctrlval
PAMSU=/etc/pam.d/su                     #fnpamctrlval
SYSLOG=/etc/syslog.conf                 #fnrsyslogincap
RSYSLOG=/etc/rsyslog.conf               #fnrsyslogincap

#Backup files
BKPHOME=${BDIR}/home.bkp.ccsfix                         #fnhome
BKPSSH=${BDIR}/sshd_config.bkp.ccsfix                   #fnsshroot
BKPSUDO=${BDIR}/sudoers.bkp.ccsfix                      #fnsshroot
BKPSYS=${BDIR}/sysctl.conf.bkp.ccsfix                   #fnsysctl
BKPSYSLOADED=${BDIR}/sysctl-a_output_before_relaod      #fnsysctl
BKPEXEC1=${BDIR}/initscripts.bkp.ccsfix                 #fninit
BKPEXEC2=${BDIR}/rcscripts.bkp.ccsfix                   #fninit
BKPUMASK=${BDIR}/profile.bkp.ccsfix                     #fnumask
BKPLOGROTATE=${BDIR}/logrotate.conf.bkp.ccsfix          #fnlogrotate
BKPPAUTH=${BDIR}/password-auth                          #fnpamauth, fnpassremember, fnauthcomplaint
BKPSAUTH=${BDIR}/system-auth                            #fnpamauth, fnsyspass, fnpassremember, fnauthcomplaint
BKPPSSH=${BDIR}/pam-sshd                                #fnpamctrlval
BKPPPASSWD=${BDIR}/pam-passwd                           #fnpamctrlval
BKPPAMSU=${BDIR}/pam-su                                 #fnpamctrlval
BKPSYSLOG=${BDIR}/syslog.conf                           #fnrsyslogincap
BKPRSYSLOG=${BDIR}/rsyslog.conf                         #fnrsyslogincap


#Check Files
CHK1=${DIR}/check.home                                  #fnhome
CHK21=${DIR}/check.sshd_config                          #fnsshroot
CHK22=${DIR}/check.sudoers                              #fnsshroot
CHKSSHSVC=${DIR}/check.sshsvc                           #fnsshroot
CHK41=${DIR}/check.sysctl1                              #fnsysctl
CHK42=${DIR}/check.sysctl2                              #fnsysctl
CHK51=${DIR}/check.initscripts                          #fninit
CHK52=${DIR}/check.rcscripts                            #fninit
CHK6=${DIR}/check.umask                                 #fnumask
CHK7=${DIR}/check.logrotate                             #fnlogrotate
CHK7TMP=${DIR}/check.logrotatetmp                       #fnlogrotate

#Result Files
RSLT1=${DIR}/result.home                                #fnhome
RSLT21=${DIR}/result.sshd_config                        #fnsshroot
RSLT22=${DIR}/result.sudoers                            #fnsshroot
RSLT41=${DIR}/result.sysctl1                            #fnsysctl
RSLT42=${DIR}/result.sysctl2                            #fnsysctl
RSLT6=${DIR}/result.umask                               #fnumask
RSLT7=${DIR}/result.logroate                            #fnlogrotate

#Declaration of Backup Functions


fnbkpsauth ()
{
if [ ! -f ${BKPSAUTH} ]; then cp -p ${SAUTH} ${BKPSAUTH}
echo "Seg 10: Backup of ${SAUTH} is saved in ${BKPSAUTH}" >> ${LOG}
else
echo "Seg 10: Backup of ${SAUTH} is already saved in ${BKPSAUTH}" >> ${LOG}
fi
}

fnbkppauth ()
{
if [ ! -f ${BKPPAUTH} ]; then cp -p ${PAUTH} ${BKPPAUTH}
echo "Seg $1: Backup of ${PAUTH} is saved in ${BKPPAUTH}" >> ${LOG}
else
echo "Seg $1: Backup of ${PAUTH} is already saved in ${BKPPAUTH}" >> ${LOG}
fi
}

fnbkpsyslog ()
{
if [ ! -f ${BKPSYSLOG} ]; then cp -p ${SYSLOG} ${BKPSYSLOG}
echo "Seg $1: Backup of ${SYSLOG} is saved in ${BKPSYSLOG}" >> ${LOG}
else
echo "Seg $1: Backup of ${SYSLOG} is already saved in ${BKPSYSLOG}" >> ${LOG}
fi
}

fnbkprsys ()
{
if [ ! -f ${BKPRSYSLOG} ]; then cp -p ${RSYSLOG} ${BKPRSYSLOG}
echo "Seg $1: Backup of ${RSYSLOG} is saved in ${BKPRSYSLOG}" >> ${LOG}
else
echo "Seg $1: Backup of ${RSYSLOG} is already saved in ${BKPRSYSLOG}" >> ${LOG}
fi
}

#Declaring sub functions

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
ls -ltrd /home/* > ${BKPHOME} 2>/dev/null
echo "Seg 1: Backup taken. Listing directories which meets the condition" >> ${LOG}
find /home/* -maxdepth 0 -type d -perm -700 -not -perm 750 -not -perm 700 -exec ls -ld {} \; > ${CHK1} 2>/dev/null
if [ -f ${CHK1} ] && [ -s ${CHK1} ]; then
        echo "Seg 1: Following files meets the condition" >> ${LOG}
        echo " " >> ${LOG}
        cat ${CHK1} >> ${LOG}
        echo " " >> ${LOG}
        echo "Seg 1: Changing permission on impacted directories" >> ${LOG}
        cat ${CHK1} | awk '{print $NF}' | while read dir; do chmod 750 $dir; done
        if [ `echo $?` -eq 0 ]; then
                echo "Seg 1: Changing permission on impacted directories - Completed" >> ${LOG}
                ls -ltrd /home/* > ${RSLT1} 2>/dev/null
                echo "Seg 1: Output of /home after changing permission is saved in ${RSLT1}" >> ${LOG}
                echo "Seg 1: CHECKRESULT: MODIFIED : Some directories in /home has been modifiled by script" >> ${LOG}
        else
                echo "Seg 1: MANUAL CHECK NEEDED: Changing permission did not complete cleanly" >> ${LOG}
                echo "Seg 1: CHECKRESULT: ERROR : Something went wrong. Check log file in detail" >> ${LOG}
        fi
else
        echo "Seg 1: None of the directory meets condition. NO CHANGES MADE" >> ${LOG}
        echo "Seg 1: CHECKRESULT: PASS : /home meets is already CCS complaint" >> ${LOG}
        ls -ltrd /home/* > ${RSLT1} 2>/dev/null
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
                                                service sshd reload >/dev/null 2>&1
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

fnpamauth ()
{
##############################################################################################################
#SEGMENT 08: File password-auth and system-auth should have the lines for auth required and account required #
##############################################################################################################
echo "CHECK 08: BEGINS at `date`" >> ${LOG}
echo "Seg 08.1: Checking 'auth required pam_deny.so' in ${PAUTH} & ${SAUTH}"
echo "Seg 08.1: Checking 'auth required pam_deny.so' in ${PAUTH} & ${SAUTH}" >> ${LOG}

grep auth ${PAUTH} | grep -v ^# | grep required  | grep -q pam_deny.so && grep auth ${SAUTH} | grep -v ^# | grep required  | grep -q pam_deny.so
if [ `echo $?` -eq 0 ] ; then
echo "Seg 08.1: CHECKRESULT: PASS : 'auth required pam_deny.so' already present in both files" >> ${LOG}
else
echo "Seg 08.1: parameter not present in any one or both files" >> ${LOG}
for file in ${PAUTH} ${SAUTH}
do
grep auth ${file}  | grep -v ^# | grep required  | grep -q pam_deny.so
if [ `echo $?` -ne 0 ] ; then
echo "Seg 08.1: parameter not present in ${file} file. Taking backup" >> ${LOG}
cp -p ${PAUTH} ${BDIR}
awk 'FNR==NR{ if (/auth/) p=NR; next} 1; FNR==p{ print "auth        required      pam_deny.so" }' ${file} ${file} > ${file}.tmp
mv -f ${file}.tmp ${file}
echo "Seg 08.1: CHECKRESULT: APPENDED: parameter added into ${file} file" >> ${LOG}
fi
done
fi

echo "Seg 08.2: Checking 'account  required       pam_deny.so' in ${OAUTH} file"
echo "Seg 08.2: Checking 'account  required       pam_deny.so' in ${OAUTH} file" >> ${LOG}
grep account ${OAUTH} | grep -v ^# | grep required | grep -q pam_deny.so
if [ `echo $?` -eq 0 ] ; then
echo "Seg 08.2: CHECKRESULT: PASS : 'auth required pam_deny.so' already present in ${OAUTH} file" >> ${LOG}
else
echo "Seg 08.2: parameter not present in ${OAUTH} file. Taking backup" >> ${LOG}
cp -p ${OAUTH} ${BDIR}
awk 'FNR==NR{ if (/account/) p=NR; next} 1; FNR==p{ print "account  required       pam_deny.so" }' ${OAUTH} ${OAUTH} > ${OAUTH}.tmp
mv -f ${OAUTH}.tmp ${OAUTH}
echo "Seg 08.2: CHECKRESULT: APPENDED: parameter added into ${OAUTH} file" >> ${LOG}
fi

}

fnpamctrlval ()
{
#########################################################################################
#SEGMENT 09: Pam authentication files should have the lines for password control values #
#########################################################################################
echo "CHECK 09: BEGINS at `date`" >> ${LOG}
echo "Seg 09.1: Checking ${PSSH} for 'password include system-auth'"
echo "Seg 09.1: Checking ${PSSH} for 'password include system-auth'" >> ${LOG}
grep -n ^password $PSSH | grep include | grep -q system-auth
if [ `echo $?` -eq 0 ]; then
echo "Seg 09.1: CHECKRESULT: PASS : 'password include system-auth' already exists in ${PSSH}" >> ${LOG}
else
echo "Seg 09.1: 'password include system-auth' does not exists on $PSSH. Appending" >> ${LOG}
cp -p ${PSSH} ${BKPPSSH}
echo "Seg 09.1: Backup of ${PSSH} is saved in ${BKPPSSH}" >> ${LOG}
awk 'FNR==NR{ if (/password/) p=NR; next} 1; FNR==p{ print "password   include      system-auth" }' ${PSSH} ${PSSH} > ${PSSH}.tmp
mv -f ${PSSH}.tmp ${PSSH}
grep -n ^password $PSSH | grep include | grep -q system-auth
if [ `echo $?` -eq 0 ]; then
echo "Seg 09.1: CHECKRESULT: APPENDED: Required parameter added to ${PSSH}" >> ${LOG}
else
echo "Seg 09.1: CHECKRESULT: ERROR: Parameter not appended in ${PSSH}. Check Manually" >> ${LOG}
fi
fi

echo "Seg 09.2: Checking ${PSSH} for 'auth include system-auth'"
echo "Seg 09.2: Checking ${PSSH} for 'auth include system-auth'" >> ${LOG}
grep -n ^auth $PSSH | grep include | grep -q system-auth
if [ `echo $?` -eq 0 ]; then
echo "Seg 09.2: CHECKRESULT: PASS : 'auth include system-auth' already exists in ${PSSH}" >> ${LOG}
else
echo "Seg 09.2: 'auth include system-auth' does not exists on $PSSH. Appending" >> ${LOG}
if [ ! -f ${BKPPSSH} ]; then cp -p ${PSSH} ${BKPPSSH}
echo "Seg 09.2: Backup of ${PSSH} is saved in ${BKPPSSH}" >> ${LOG}
else
echo "Seg 09.2: Backup of ${PSSH} is already saved in ${BKPPSSH}" >> ${LOG}
fi
awk 'FNR==NR{ if (/auth/) p=NR; next} 1; FNR==p{ print "auth       include      system-auth" }' ${PSSH} ${PSSH} > ${PSSH}.tmp
mv -f ${PSSH}.tmp ${PSSH}
grep -n ^auth $PSSH | grep include | grep -q system-auth
if [ `echo $?` -eq 0 ]; then
echo "Seg 09.2: CHECKRESULT: APPENDED: Required parameter added to ${PSSH}" >> ${LOG}
else
echo "Seg 09.2: CHECKRESULT: ERROR: Parameter not appended in ${PSSH}. Check Manually" >> ${LOG}
fi
fi

echo "Seg 09.3: Checking ${PSSH} for 'account include system-auth'"
echo "Seg 09.3: Checking ${PSSH} for 'account include system-auth'" >> ${LOG}
grep -n ^account $PSSH | grep include | grep -q system-auth
if [ `echo $?` -eq 0 ]; then
echo "Seg 09.3: CHECKRESULT: PASS : 'account include system-auth' already exists in ${PSSH}" >> ${LOG}
else
echo "Seg 09.3: 'account include system-auth' does not exists on $PSSH. Appending" >> ${LOG}
if [ ! -f ${BKPPSSH} ]; then cp -p ${PSSH} ${BKPPSSH}
echo "Seg 09.3: Backup of ${PSSH} is saved in ${BKPPSSH}" >> ${LOG}
else
echo "Seg 09.3: Backup of ${PSSH} is already saved in ${BKPPSSH}" >> ${LOG}
fi
awk 'FNR==NR{ if (/account/) p=NR; next} 1; FNR==p{ print "account    include      system-auth" }' ${PSSH} ${PSSH} > ${PSSH}.tmp
mv -f ${PSSH}.tmp ${PSSH}
grep -n ^account $PSSH | grep include | grep -q system-auth
if [ `echo $?` -eq 0 ]; then
echo "Seg 09.3: CHECKRESULT: APPENDED: Required parameter added to ${PSSH}" >> ${LOG}
else
echo "Seg 09.3: CHECKRESULT: ERROR: Parameter not appended in ${PSSH}. Check Manually" >> ${LOG}
fi
fi



echo "Seg 09.4: Checking ${PPASSWD} for 'password include system-auth'"
echo "Seg 09.4: Checking ${PPASSWD} for 'password include system-auth'" >> ${LOG}
grep -n ^password $PPASSWD | grep include | grep -q system-auth
if [ `echo $?` -eq 0 ]; then
echo "Seg 09.4: CHECKRESULT: PASS : 'password include system-auth' already exists in ${PPASSWD}" >> ${LOG}
else
echo "Seg 09.4: 'password include system-auth' does not exists on $PPASSWD. Appending" >> ${LOG}
if [ ! -f ${BKPPPASSWD} ]; then cp -p ${PPASSWD} ${BKPPPASSWD}
echo "Seg 09.4: Backup of ${PPASSWD} is saved in ${BKPPPASSWD}" >> ${LOG}
else
echo "Seg 09.4: Backup of ${PPASSWD} is already saved in ${BKPPPASSWD}" >> ${LOG}
fi
awk 'FNR==NR{ if (/password/) p=NR; next} 1; FNR==p{ print "password   include     system-auth" }' ${PPASSWD} ${PPASSWD} > ${PPASSWD}.tmp
mv -f ${PPASSWD}.tmp ${PPASSWD}
grep -n ^password $PPASSWD | grep include | grep -q system-auth
if [ `echo $?` -eq 0 ]; then
echo "Seg 09.4: CHECKRESULT: APPENDED: Required parameter added to ${PPASSWD}" >> ${LOG}
else
echo "Seg 09.4: CHECKRESULT: ERROR: Parameter not appended in ${PPASSWD}. Check Manually" >> ${LOG}
fi
fi

echo "Seg 09.5: Checking ${PAMSU} for 'auth include system-auth'"
echo "Seg 09.5: Checking ${PAMSU} for 'auth include system-auth'" >> ${LOG}
grep -n ^auth ${PAMSU} | grep include | grep -q system-auth
if [ `echo $?` -eq 0 ]; then
echo "Seg 09.5: CHECKRESULT: PASS : 'auth include system-auth' already exists in ${PAMSU}" >> ${LOG}
else
echo "Seg 09.5: 'auth include system-auth' does not exists on ${PAMSU}. Appending" >> ${LOG}
if [ ! -f ${BKPPAMSU} ]; then cp -p ${PAMSU} ${BKPPAMSU}
echo "Seg 09.5: Backup of ${PAMSU} is saved in ${BKPPAMSU}" >> ${LOG}
else
echo "Seg 09.5: Backup of ${PAMSU} is already saved in ${BKPPAMSU}" >> ${LOG}
fi
awk 'FNR==NR{ if (/auth/) p=NR; next} 1; FNR==p{ print "auth            include         system-auth" }' ${PAMSU} ${PAMSU} > ${PAMSU}.tmp
mv -f ${PAMSU}.tmp ${PAMSU}
grep -n ^auth ${PAMSU} | grep include | grep -q system-auth
if [ `echo $?` -eq 0 ]; then
echo "Seg 09.5: CHECKRESULT: APPENDED: Required parameter added to ${PAMSU}" >> ${LOG}
else
echo "Seg 09.5: CHECKRESULT: ERROR: Parameter not appended in ${PAMSU}. Check Manually" >> ${LOG}
fi
fi
}

fnsyspass ()
{
####################################################################################################################
#SEGMENT 10: /etc/pam.d/system-auth should have parameters on password required pam_passwdqc.so OR pam_cracklib.so #
####################################################################################################################
echo "CHECK 10: BEGINS at `date`" >> ${LOG}
echo "Seg 10: Checking ${SAUTH} for required parameters"
echo "Seg 10: Checking ${SAUTH} for required parameters" >> ${LOG}
cat $SAUTH | grep password | grep required | egrep -q "pam_passwdqc.so|pam_cracklib.so"
if [ `echo $?` -eq 1 ]; then
        echo "Seg 10: None of the required parameter found in ${SAUTH}. Proceeding to append value" >> ${LOG}
        fnbkpsauth
        sed '/password[^\n]*/,$!b;//{x;//p;g};//!H;$!d;x;s//&\npassword    required      pam_cracklib.so retry=3 minlen=8 dcredit=-1 ucredit=0 lcredit=-1 ocredit=0 type=reject_username/' ${SAUTH} > ${SAUTH}.tmp
        mv -f ${SAUTH}.tmp ${SAUTH}
        cat $SAUTH | grep password | grep required | egrep -q "pam_passwdqc.so|pam_cracklib.so"
        if [ `echo $?` -eq 0 ]; then
                echo "Seg 10: CHECKRESULT: APPENDED: Requried value added to ${SAUTH}" >> ${LOG}
        else
                echo "Seg 10: CHECKRESULT: ERROR: Something went wrong. Look for CHECK 10 in ${SAUTH}" >> ${LOG}
        fi
else

        cat $SAUTH | grep password | grep required | grep -q "pam_cracklib.so"
        if [ `echo $?` -eq 0 ]; then
                echo "Seg 10: pam_cracklib.so found. Analysing other parameters" >> ${LOG}
                cat $SAUTH | grep password | grep required | grep "pam_cracklib.so" | grep "retry=3" | grep "minlen=8" | grep "dcredit=-1" | grep "ucredit=0" | grep "lcredit=-1" | grep "ocredit=0" | grep "type=" | grep -q "reject_username"
                if [ `echo $?` -eq 0 ]; then
                        echo "Seg 10: CHECKRESULT: PASS : $SAUTH already has all parameters required for pam_cracklib.so" >> ${LOG}
                else
                        fnbkpsauth
                        sed 's/^password\s*required\s*pam_cracklib.so.*$/password    required      pam_cracklib.so retry=3 minlen=8 dcredit=-1 ucredit=0 lcredit=-1 ocredit=0 type=reject_username/' ${SAUTH} > ${SAUTH}.tmp
                        mv -f ${SAUTH}.tmp ${SAUTH}
                        echo "Seg 10: CHECKRESUT: MODIFIED: pam_cracklib.so is updated with all required parameters" >> ${LOG}
                fi
        else
                cat $SAUTH | grep password | grep required | grep -q "pam_passwdqc.so"
                if [ `echo $?` -eq 0 ]; then
                        echo "Seg 10: pam_passwdqc.so found. Analysing other parameters" >> ${LOG}
                        cat $SAUTH | grep password | grep required | grep "pam_passwdqc.so" | grep "min=disabled,8,8,8,8" | grep "passphrase=0" | grep "random=0" | grep -q "enforce=everyone"
                        if [ `echo $?` -eq 0 ]; then
                                echo "Seg 10: CHECKRESULT: PASS : $SAUTH already has all parameters required for pam_passwdqc.so" >> ${LOG}
                        else
                                fnbkpsauth
                                sed 's/^password\s*required\s*pam_passwdqc.so.*$/password    required      pam_passwdqc.so min=disabled,8,8,8,8 passphrase=0 random=0 enforce=everyone/' ${SAUTH} > ${SAUTH}.tmp
                                mv -f ${SAUTH}.tmp ${SAUTH}
                                echo "Seg 10: CHECKRESUT: MODIFIED: pam_passwdqc.so is updated with all required parameters" >> ${LOG}
                        fi
                fi
        fi
fi
}

fnpassremember ()
{
##############################################################################################################
#SEGMENT 11: File /etc/pam.d/system-auth or /etc/pam.d/password-auth should have the line remember parameter #
##############################################################################################################
echo "CHECK 10: BEGINS at `date`" >> ${LOG}
echo "Seg 10: Checking ${SAUTH} & ${PAUTH} for required parameters"
echo "Seg 10: Checking ${SAUTH} & ${PAUTH} for required parameters" >> ${LOG}


grep password ${PAUTH}  | grep sufficient  | grep -q pam_unix.so || grep password ${SAUTH}  | grep sufficient | grep -q pam_unix.so
if [ `echo $?` -ne 0 ] ; then
        echo "Seg 11: parameter not present in both files. Taking backup of $PAUTH" >> ${LOG}
        fnbkppauth 11
        awk 'FNR==NR{ if (/password/) p=NR; next} 1; FNR==p{ print "password    sufficient    pam_unix.so sha512 shadow try_first_pass use_authtok remember=7" }' ${PAUTH} ${PAUTH} > ${PAUTH}.tmp
        mv -f ${PAUTH}.tmp ${PAUTH}
        echo "Seg 11: CHECKRESULT: APPENDED: parameter added into ${PAUTH} file" >> ${LOG}
else
        grep password ${PAUTH}  | grep sufficient  | grep -q pam_unix.so
        if [ `echo $?` -eq 0 ]; then
                echo "Seg 11: Parameter found in $PAUTH. Checking all values" >> ${LOG}
                grep password ${PAUTH}  | grep sufficient  | grep pam_unix.so | grep sha512 | grep shadow | grep "try_first_pass use_authtok" | grep -q "remember=7"
                if [ `echo $?` -eq 0 ]; then
                        echo "Seg 11: CHECKRESULT: PASS : Remember value for password is set to 7 already" >> ${LOG}
                else
                        fnbkppauth 11
                        sed 's/^password\s*sufficient\s*pam_unix.so.*$/password    sufficient    pam_unix.so sha512 shadow try_first_pass use_authtok remember=7/' ${PAUTH} > ${PAUTH}.tmp
                        mv -f ${PAUTH}.tmp ${PAUTH}
                        echo "Seg 11: CHECKRESULT: MODIFIED : ${PAUTH} modified to meet requirements" >> ${LOG}
                fi
        else
                echo "Seg 11: Parameter found in $SAUTH. Checking all values" >> ${LOG}
                grep password ${SAUTH}  | grep sufficient  | grep pam_unix.so | grep sha512 | grep shadow | grep "try_first_pass use_authtok" | grep -q "remember=7"
                if [ `echo $?` -eq 0 ]; then
                        echo "Seg 11: CHECKRESULT: PASS : Remember value for password is set to 7 already" >> ${LOG}
                else
                        fnbkpsauth 11
                        sed 's/^password\s*sufficient\s*pam_unix.so.*$/password    sufficient    pam_unix.so sha512 shadow try_first_pass use_authtok remember=7/' ${SAUTH} > ${SAUTH}.tmp
                        mv -f ${SAUTH}.tmp ${SAUTH}
                        echo "Seg 11: CHECKRESULT: MODIFIED : Different value. Alterted the value to requirement" >> ${LOG}
                fi
        fi
fi

}

fnrsyslogincap ()
{
######################################################
#SEGMENT 12: Syslog/Rsyslog should capture all info  #
######################################################
echo "CHECK 12: BEGINS at `date`" >> ${LOG}

if [ -f ${RSYSLOG} ]; then SYSFILE=${RSYSLOG}
elif [ -f ${SYSLOG} ]; then SYSFILE=${SYSLOG};
else SYSFILE=${RSYSLOG}; fi

echo "Seg 12: Checking ${SYSFILE} for required parameters"
echo "Seg 12: Checking ${SYSFILE} for required parameters" >> ${LOG}

if [ ! -f ${SYSFILE} ]; then
        echo "Seg 12: CHECKRESULT: SKIP: There is no ${SYSFILE} file. Skipping this check" >> ${LOG}
else
		echo "Seg 12.1: Checking if all required logs are saved in messages file" >> ${LOG}
		cat ${SYSFILE} | grep -v ^# | grep messages | grep "*.info" | grep mail.none | grep authpriv.none | grep -q cron.none
        if [ `echo $?` -eq 0 ]; then
                echo "Seg 12.1: CHECKRESULT: PASS : All requested parameter already exists in ${SYSFILE}" >> ${LOG}
        else
                echo "Seg 12.1: Required parameters doest not exists. Taking backup" >> ${LOG}
                fnbkprsys 12
                num=`grep -n "/var/log/messages" $SYSFILE | grep -v "#" | head -1 | cut -d':' -f1`
				sed -i "${num}s/.*/*.info,mail.none,authpriv.none,cron.none        -\/var\/log\/messages/" ${SYSFILE}
                cat ${SYSFILE} | grep -v ^# | grep messages | grep "*.info" | grep mail.none | grep authpriv.none | grep -q cron.none
                if [ `echo $?` -eq 0 ]; then
                        echo "Seg 12.1: CHECKRESULT: MODIFIED : ${SYSFILE} has been modifiled to meet requirements" >> ${LOG}
                else
                        echo "Seg 12.1: CHECKRESULT: Something is wrong. CHECK MANUALLY" >> ${LOG}
                                 echo "Seg 12: Reverted the original file from Backup. No changes made" >> ${LOG}
                                 file=`echo ${SYSFILE} | cut -d/ -f3`
                                 cp -p ${BDIR}/$file ${SYSFILE}
                fi
        fi
		echo "Seg 12.2: Checking authpriv in secure entry" >> ${LOG}
		cat ${SYSFILE} | grep -v ^# | grep secure | grep -q "authpriv.*"
		if [ `echo $?` -eq 0 ]; then
			echo "Seg 12.2: CHECKRESULT: PASS: Required parameter already exists in ${SYSFILE}" >> ${LOG}
		else
			cat ${SYSFILE} | grep -v ^# | grep -q secure
			if [ `echo $?` -eq 0 ]; then
				fnbkprsys 12
				num=`grep -n "/var/log/secure" $SYSFILE | grep -v "#" | head -1 | cut -d':' -f1`
				sed -i "${num}s/.*/authpriv.*           -\/var\/log\/secure" ${SYSFILE}
				cat ${SYSFILE} | grep -v ^# | grep secure | grep -q "authpriv.*"
					if [ `echo $?` -eq 0 ]; then
						echo "Seg 12.2: CHECKRESULT: MODIFIED : ${SYSFILE} has been modifiled to meet requirements" >> ${LOG}
					else
						echo "Seg 12.2: CHECKRESULT: Something is wrong. CHECK MANUALLY" >> ${LOG}
						echo "Seg 12.2: Reverted the original file from Backup. No changes made" >> ${LOG}
                                 file=`echo ${SYSFILE} | cut -d/ -f3`
                                 cp -p ${BDIR}/$file ${SYSFILE}
					fi
			fi
		fi
		
		
fi
}

fnauthcomplaint ()
{
################################################################
#SEGMENT 13: File ${PAUTH} or ${SAUTH} should capture all info #
################################################################
echo "CHECK 13: BEGINS at `date`" >> ${LOG}
echo "Seg 13: Checking if ${PAUTH} or ${SAUTH} has required parameters"
echo "Seg 13: Checking if ${PAUTH} or ${SAUTH} has required parameters" >> ${LOG}

fnsubmagic ()
{
grep ^auth $PAUTH | grep required | grep pam_tally | grep -v ^# | grep -v pam_tally2 | grep -q "no_magic_root"
if [ `echo $?` -eq 0 ]; then
        echo "Seg 13.${count}: CHECKRESULT: PASS: no_magic_root already exists in $PAUTH}" >> ${LOG}
else
        fnbkppauth
        awk 'FNR==NR{ if (/auth/) p=NR; next} 1; FNR==p{ print "auth        required      pam_tally.so no_magic_root" }' ${PAUTH} ${PAUTH} > ${PAUTH}.tmp
        mv -f ${PAUTH}.tmp ${PAUTH}
        echo "Seg 13.${count}: CHECKRESULT: MODIFIED: no_magic_root has been appended to $PAUTH" >> ${LOG}
fi
}


fnsubmagicsys ()
{
grep ^auth $SAUTH | grep required | grep pam_tally | grep -v ^# | grep -v pam_tally2 | grep -q "no_magic_root"
if [ `echo $?` -eq 0 ]; then
        echo "Seg 13.${count}: CHECKRESULT: PASS: no_magic_root already exists in $SAUTH}" >> ${LOG}
else
        fnbkpsauth
        awk 'FNR==NR{ if (/auth/) p=NR; next} 1; FNR==p{ print "auth        required      pam_tally.so no_magic_root" }' ${SAUTH} ${SAUTH} > ${SAUTH}.tmp
        mv -f ${SAUTH}.tmp ${SAUTH}
        echo "Seg 13.${count}: CHECKRESULT: MODIFIED: no_magic_root has been appended to $SAUTH" >> ${LOG}
fi
}



fnsubpamdeny ()
{
grep ^auth $PAUTH | grep required | grep pam_tally | grep -v ^# | grep -v pam_tally2 | grep -q "deny=5"
if [ `echo $?` -eq 0 ]; then
        echo "Seg 13.${count}: CHECKRESULT: PASS: deny=5 already exists in $PAUTH}" >> ${LOG}
else
        fnbkppauth
        grep ^auth $PAUTH | grep required | grep pam_tally | grep -v ^# | grep -v pam_tally2 | grep -q "deny="
        if [ `echo $?` -eq 0 ]; then
                num=`grep -n ^auth $PAUTH | grep required | grep pam_tally | grep -v ^# | grep -v pam_tally2 | grep "deny="|cut -d: -f1`
                sed -i "${num}s/\(auth\s*required\s*pam_tally.so\s*deny\).*$/auth        required      pam_tally.so deny=5/" $PAUTH
                echo "Seg 13.${count}: CHECKRESULT: MODIFIED: deny=5 has been replaced to $PAUTH" >> ${LOG}
        else
                awk 'FNR==NR{ if (/auth/) p=NR; next} 1; FNR==p{ print "auth        required      pam_tally.so deny=5" }' ${PAUTH} ${PAUTH} > ${PAUTH}.tmp
                mv -f ${PAUTH}.tmp ${PAUTH}
                echo "Seg 13.${count}: CHECKRESULT: MODIFIED: deny=5 has been appended to $PAUTH" >> ${LOG}
        fi
fi
}

fnsubpamdenysys ()
{
grep ^auth $SAUTH | grep required | grep pam_tally | grep -v ^# | grep -v pam_tally2 | grep -q "deny=5"
if [ `echo $?` -eq 0 ]; then
        echo "Seg 13.${count}: CHECKRESULT: PASS: deny=5 already exists in $SAUTH}" >> ${LOG}
else
        fnbkpsauth
        grep ^auth $SAUTH | grep required | grep pam_tally | grep -v ^# | grep -v pam_tally2 | grep -q "deny="
        if [ `echo $?` -eq 0 ]; then
                num=`grep -n ^auth $SAUTH | grep required | grep pam_tally | grep -v ^# | grep -v pam_tally2 | grep "deny="|cut -d: -f1`
                sed -i "${num}s/\(auth\s*required\s*pam_tally.so\s*deny\).*$/auth        required      pam_tally.so deny=5/" ${SAUTH}
                echo "Seg 13.${count}: CHECKRESULT: MODIFIED: deny=5 has been replaced to $SAUTH" >> ${LOG}
        else
                awk 'FNR==NR{ if (/auth/) p=NR; next} 1; FNR==p{ print "auth        required      pam_tally.so deny=5" }' ${SAUTH} ${SAUTH} > ${SAUTH}.tmp
                mv -f ${SAUTH}.tmp ${SAUTH}
                echo "Seg 13.${count}: CHECKRESULT: MODIFIED: deny=5 has been appended to $SAUTH" >> ${LOG}
        fi
fi
}

fnsubpam2deny ()
{
grep ^auth $PAUTH | grep required | grep pam_tally2.so | grep -v ^# | grep -q "deny=5"
if [ `echo $?` -eq 0 ]; then
        echo "Seg 13.${count}: CHECKRESULT: PASS: deny=5 for pam_tally2 already exists in $PAUTH}" >> ${LOG}
else
        fnbkppauth
        grep ^auth $PAUTH | grep required | grep pam_tally2.so | grep -v ^# | grep -q "deny="
        if [ `echo $?` -eq 0 ]; then
                num=`grep -n ^auth $PAUTH | grep required | grep pam_tally2.so | grep -v ^# | grep "deny=" | cut -d: -f1`
                cp -p $PAUTH $TMPPAUTH
				sed -i '4s/.*deny=//p' $TMPPAUTH
				tval=`sed -n '4p' /tmp/system-auth.tmp | awk '{print substr($0,0,1)}'`
				sed -i "${num}s/deny=${tval}/deny=5/" $PAUTH
                echo "Seg 13.${count}: CHECKRESULT: MODIFIED: deny=5 for pam_tally2 has been replaced to $PAUTH" >> ${LOG}
        else
                awk 'FNR==NR{ if (/auth/) p=NR; next} 1; FNR==p{ print "auth        required      pam_tally2.so deny=5" }' ${PAUTH} ${PAUTH} > ${PAUTH}.tmp
                mv -f ${PAUTH}.tmp ${PAUTH}
                echo "Seg 13.${count}: CHECKRESULT: APPENDED: deny=5 for pam_tally2 has been appended to $PAUTH" >> ${LOG}
        fi
fi
}

fnsubpam2denysys ()
{
grep ^auth $SAUTH | grep required | grep pam_tally2.so | grep -v ^# | grep -q "deny=5"
if [ `echo $?` -eq 0 ]; then
        echo "Seg 13.${count}: CHECKRESULT: PASS: deny=5 for pam_tally2 already exists in $SAUTH}" >> ${LOG}
else
        fnbkppauth
        grep ^auth $SAUTH | grep required | grep pam_tally2.so | grep -v ^# | grep -q "deny="
        if [ `echo $?` -eq 0 ]; then
                num=`grep -n ^auth $SAUTH | grep required | grep pam_tally2.so | grep -v ^# | grep "deny=" | cut -d: -f1`
				cp -p $SAUTH $TMPSAUTH
				sed -i '4s/.*deny=//p' $TMPSAUTH
				tval=`sed -n '4p' /tmp/system-auth.tmp | awk '{print substr($0,0,1)}'`
				sed -i "${num}s/deny=${tval}/deny=5/" $SAUTH
                echo "Seg 13.${count}: CHECKRESULT: MODIFIED: deny=5 for pam_tally2 has been replaced to $SAUTH" >> ${LOG}
        else
                awk 'FNR==NR{ if (/auth/) p=NR; next} 1; FNR==p{ print "auth        required      pam_tally2.so deny=5" }' ${SAUTH} ${SAUTH} > ${SAUTH}.tmp
                mv -f ${SAUTH}.tmp ${SAUTH}
                echo "Seg 13.${count}: CHECKRESULT: APPENDED: deny=5 for pam_tally2 has been appended to $SAUTH" >> ${LOG}
        fi
fi
}

count=1
grep ^auth $PAUTH $SAUTH | grep required | grep pam_tally | grep -v ^# | grep -v pam_tally2 | grep -q "no_magic_root"
if [ `echo $?` -eq 0 ]; then
        echo "Seg 13.${count}: CHECKRESULT: PASS: no_magic_root already exists" >> ${LOG}
elif [ `grep ^auth $SAUTH | grep required | grep pam_tally | grep -v ^# | grep -v pam_tally2 | grep "no_magic_root" | wc -l` -eq 1 ]; then
        fnsubmagicsys
else
        fnsubmagic
fi
count=$((count+1))

grep ^auth $PAUTH $SAUTH | grep required | grep pam_tally | grep -v ^# | grep -v pam_tally2 | grep -q "deny=5"
if [ `echo $?` -eq 0 ]; then
        echo "Seg 13.${count}: CHECKRESULT: PASS: deny=5 already exists" >> ${LOG}
elif [ `grep ^auth $SAUTH | grep required | grep pam_tally | grep -v ^# | grep -v pam_tally2 | grep "deny=" | wc -l` -eq 1 ]; then
        fnsubpamdenysys
else
        fnsubpamdeny
fi
count=$((count+1))

grep ^auth $PAUTH $SAUTH | grep required | grep pam_tally2.so | grep -v ^# | grep -q "deny=5"
if [ `echo $?` -eq 0 ]; then
        echo "Seg 13.${count}: CHECKRESULT: PASS: deny=5 for pam_tally2 already" >> ${LOG}
elif [ `grep ^auth $SAUTH | grep required | grep pam_tally2.so | grep -v ^# | grep "deny=" | wc -l` -eq 1 ]; then
        fnsubpam2denysys
else
        fnsubpam2deny
fi
count=$((count+1))
}




## Main Script Begins Here

echo " "
echo "CCSFIX script execution started"
echo " "
sleep 1

fnhome
#fnsshroot
fnuveperm
fnsysctl
fninit
fnumask
fnlogrotate
fnpamauth
fnpamctrlval
fnsyspass
fnpassremember
fnrsyslogincap
cat /etc/redhat-release | grep -q "6."
if [ `echo $?` -eq 0 ]; then
        fnauthcomplaint
else
        echo "Seg 13: Checking of $PAUTH & $SAUTH has required parameter for fnauthcomplaint"
        echo "Seg 13: CHECKRESULT: SKIP: This is not RHEL 6. Hence skipping check for fnauthcomplaint" >> ${LOG}
fi


echo " "
echo "CCSFIX script execution completed. Below is the summary of the run."
echo " "
echo "################################################################################################################"
echo "Backup files taken for this execution is located in : ${BDIR}"
echo "Log directory for this run : ${DIR}"
echo "Log file for this run : ${LOG}"
echo " "
echo "# Script Result: If you don't see ERROR here, then you are good"
grep CHECKRESULT ${LOG}
echo "################################################################################################################"
echo " "
