#!/bin/bash

##Purpose: Monitor wlsagent. Script will start Wlsgent if not running. Report if duplicate process running. 
##DATE: 25-Jan-2017

LOG=/u01/appl/wlsagent/wlsagent-script.log


echo "ALERT: Script begins at `date`" >> $LOG

if [ `/bin/ps -flu wlsagent | /bin/grep java | /bin/grep 9999 | wc -l` = 0 ]

then

     echo "ERROR: Agent not running. Starting agent " >> $LOG
     /app/data/wlsagent/agent.start 9999

   if [ `echo $?` = 0 ];
      then echo "ALERT: wlsagent started successfully and running with PID `/bin/ps -flu wlsagent | /bin/grep java | /bin/grep 9999 | awk '{print $4}'`" >> $LOG;
      else echo "FATAL: wlsagent not started. Check manually" >> $LOG;
   fi

else

if [ `/bin/ps -flu wlsagent | /bin/grep java | /bin/grep 9090 | wc -l` = 1 ]
then
   echo "ALERT: wlsagent is already runing with PID `/bin/ps -flu wlsagent | /bin/grep java | /bin/grep 9090 | awk '{print $4}'`. Exiting script without any changes" >> $LOG
else
echo "ERROR: Too many java processes running as wlsagent. Check Manually" >> $LOG
fi

fi
