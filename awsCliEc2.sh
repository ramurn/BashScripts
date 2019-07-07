#!/bin/bash

#Author: Raja T
#Usage: To control AWS instances based in USAGE tag
#Version: 1.1 # July 07 2019

# Version Information
# 1.0 : Initial script to start/stop/report EC2 instances based on Usage TAG
# 1.1 : Added Terminate and Deploy functions

USAGE=$2
PATH=$PATH:/Library/Frameworks/Python.framework/Versions/3.7/bin

fn_helpMain()
{
echo " ";
echo "SYNTAX: <script> <option> [<sub-option>]";
echo "SAMPLE: <script> start <USAGEKEY>";
echo " ";
echo "Valid OPTIONS are: start|stop|terminate|report";
echo " ";
echo "More Information on Option";
echo "<script> start <usage-key>         # Start EC2 instances using TAG";
echo "<script> stop <usage-key>          # Stop EC2 instaces using TAG";
echo "<script> terminate <usage-key>     # Terminate EC2 instances using TAG";
echo "<script> report [<usage-key>]      # Report EC2 instaces for ALL or TAGed instances";
echo "<script> deploy                    # Deploy EC2 instances in interactive mode";
echo " ";
}

fn_helpTags()
{
  echo "EC2 instances are tagged with following usage. Re-run the script with any of the below value"; echo "";
  aws ec2 describe-instances --query 'Reservations[].Instances[].[Tags[?Key==`Usage`] | [0].Value]' --output text | sort -u; echo ""; exit 1;
}

fn_startInst()
{
echo " ";
if [ -z "${USAGE}" ]; then
  fn_helpTags
else
  aws ec2 describe-instances --filter "Name=tag:Usage,Values=${USAGE}" --query "Reservations[*].Instances[*].[InstanceId]" --output text | while read INST; do aws ec2 start-instances --instance-id ${INST}; done;
fi
}

fn_stopInst()
{
echo " ";
if [ -z "${USAGE}" ]; then
  fn_helpTags
else
  aws ec2 describe-instances --filter "Name=tag:Usage,Values=${USAGE}" --query "Reservations[*].Instances[*].[InstanceId]" --output text | while read INST; do aws ec2 stop-instances --instance-id ${INST}; done;
fi
}

fn_termInst()
{
echo " ";
if [ -z "${USAGE}" ]; then
  fn_helpTags
else
  aws ec2 describe-instances --filter "Name=tag:Usage,Values=${USAGE}" --query "Reservations[*].Instances[*].[InstanceId]" --output text | while read INST; do aws ec2 terminate-instances --instance-id ${INST}; done;
fi
}

fn_reportInst()
{
echo " ";
if [ -z "${USAGE}" ]; then
  aws ec2 describe-instances --query 'Reservations[].Instances[].[Tags[?Key==`Name`] | [0].Value,InstanceId,PublicIpAddress,State.Name,InstanceType,ImageId]' --output table
else
  aws ec2 describe-instances --filter "Name=tag:Usage,Values=${USAGE}" --query 'Reservations[].Instances[].[Tags[?Key==`Name`] | [0].Value,InstanceId,PublicIpAddress,State.Name,InstanceType,ImageId]' --output table
fi
}

fn_deployInst()
{
echo " ";
aws ec2 describe-images --owner self --query "Images[*].[ImageId,Description]" --output table; echo "";
echo -e "Enter the custom AMI image to create instance : \c";
read CAMI; echo "";
echo -e "Enter the number of instances you want to create : \c";
read DCOUNT; echo "";
echo -e "Enter the desired Instance Size [t2.small|t2.large]: \c";
read ISIZE; echo "";
aws ec2 run-instances --image-id ${CAMI} --count ${DCOUNT} --instance-type ${ISIZE} --key-name TeamNinja --security-group-ids sg-0a6fc7085d35b1106
}

# Main

if [ $# -eq 0 ]; then fn_helpMain; exit 1; fi
if [ "$1" == "help" ]; then fn_helpMain; exit 0; else OPTION="$1"; fi
case ${OPTION} in
start) fn_startInst;;
stop) fn_stopInst;;
terminate) fn_termInst;;
report) fn_reportInst;;
deploy) fn_deployInst;;
*)fn_helpMain; exit 1;;
esac
