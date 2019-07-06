#!/bin/bash

USAGE=${2:-Java-Developers-Lab}
descImg='aws ec2 describe-images --owner self --query "Images[*].[ImageId,Description]"'
descInst='aws ec2 describe-instances --filter "Name=tag:Usage,Values=${USAGE}" --query "Reservations[*].Instances[*].[InstanceId,ImageId,State.Name,PublicIpAddress,InstanceType]"'


fn_helpMain()
{
echo "<script> <option> [<sub-option>]"
echo " "
echo "Sample: <script> deploy"
echo " "
echo "Supported Options"
echo "deploy|start|stop|report"
echo " "
}

fn_startInst()
{
echo ""
}

fn_stopInst()
{
echo ""
}

fn_termInst()
{
echo ""
}

fn_reportInst()
{
echo " ";
echo "$USAGE"
#aws ec2 describe-instances --filter "Name=tag:Usage,Values=${USAGE}" --query "Reservations[*].Instances[*].[InstanceId,ImageId,State.Name,PublicIpAddress,InstanceType]" --output table
${descInst} --output table
}

fn_deployInst()
{
echo ""
}

fn_amiImages()
{
echo ""
}



if [ $# -eq 0 ]; then fn_helpMain; exit 1; fi
if [ "$1" == "help" ]; then fn_helpMain; exit 0; else OPTION="$1"; fi
case ${OPTION} in
start) fn_startInst;;
stop) fn_stopInst;;
terminate) fn_termInst;;
report) fn_reportInst;;
deploy) fn_deployInst;;
images) fn_amiImages;;
*)fn_helpMain; exit 1;;
esac

