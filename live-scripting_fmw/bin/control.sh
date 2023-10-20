#!/bin/bash
#==================================================
# control.sh
# Script to control a Oracle Forms and Reports Domain on a sinlge server.
# Feature:
# - LOGFILE Name static or with date
# - Usage messages, showing all options
#==================================================

##### Choose Logfile Name  
#LOGFILE=$0.$(date +"%Y%m%d_%H%M%S").log;
LOGFILE=$0.log; 



usage()
{
        echo "USAGE: $0 OPTIONS"
        echo "Control AdminServer and NodeManager of this domain. Use the WLS Administration Console to control the managed servers"
        echo "OPTIONS:"
        echo "   status:     Display running processes of this domain."
        echo "   startAdmin: starting the AdminServer using the shell script under the DOMAIN_HOME"
        echo "   startNodemanager: start the nodemanager using the shell script under the DOMAIN_HOME"
        echo "   stopNodemanager: stop the nodemanager using the shell script under the DOMAIN_HOME"
        echo "   log_report: print a log file report for this domain. Use Parameter -u to print Options."
        echo "   kill:       kill all server of this domain with kill -9 including the nodemanager"
        echo "Example:"
        echo "          sh $0 status"
        echo "          sh $0 startAdmin"
        echo "          sh $0 log_report -u"
}
	
#================================================
# FUNCTIONS OF THIS SCRIPT
#==================================================


#-------------------------------------------------
# status: Print information about all running servers and the nodemanager
#
# paramters:    none
#
#--------------------------------------------------

status()
{
	printf "RUNNING SERVERS: \n"

	printf "PID\tPROCESSAGE\tSERVER\tDOMAIN \n"
	ps auxwww | grep -v grep | egrep "weblogic.NodeManager|weblogic.Name="| grep $MIDDLEWARE_HOME |  while read line
	do
		# We get the PID and check if the process was started in the DOMAIN_HOME
		myPID=`echo "$line" | awk '{print $2}'`

		# Calculate process age (this produces wrong results with large numbers)
		## proccesscreated=$(stat -c %Z /proc/$myPID)
		## now=$( perl -e "print time")
		## prage=$[ (now - proccesscreated)/60  ]

		# Calculate process age using ps and etime
		etimes=$(ps -o etimes= -p $myPID)
    prage=$[ (etimes)/60  ]

		# get the start directory
		nmSTARTPATH=`pwdx $myPID | awk '{print $2}'`
		# check process by start path
		if [[ "$DOMAIN_HOME" == "$nmSTARTPATH" ]];
		then
		  # Handle Weblogic Server Processes
			weblogicName=$(echo $line | awk 'match( $0, /weblogic.Name=[a-zA-Z0-9_.]+/ ) { print substr($0, RSTART, RLENGTH )}')
			weblogicHome=$(echo "$line" | awk 'match( $0, /weblogic.home=[a-zA-Z0-9_.]+/ ) { print substr($0, RSTART, RLENGTH )}')
			printf "%s\t%s mins\t%s\t%s\n" $myPID $prage $weblogicName  $DOMAIN_HOME
		elif [[ "$DOMAIN_HOME/nodemanager" == "$nmSTARTPATH" ]]; then
			# Handle NodeManager
			nodemanager=$(echo $line | awk 'match( $0, /weblogic.NodeManager/ ) { print substr($0, RSTART, RLENGTH )}')
			weblogicHome=$(echo "$line" | awk 'match( $0, /weblogic.home=[a-zA-Z0-9_.]+/ ) { print substr($0, RSTART, RLENGTH )}')
			printf "%s\t%s mins\t%s\t\t%s\n" $myPID $prage $nodemanager  $DOMAIN_HOME

		fi

	done	

}

#-------------------------------------------------
# myKill: Kill all processes of the domain including the nodemanager. This is a hard kill with Signal -9.
#         The Nodemanager is stoped first to prevent reboot of the servers.
# paramters:    none
#
#--------------------------------------------------

myKill()
{

	printf "STOPPING NODEMANAGER \n"
	nodemanager stop > /dev/null
	sleep 1
	
	printf "KILLING SERVERS: \n"
	ps auxwww | grep -v grep | grep weblogic.Name= | grep $MIDDLEWARE_HOME |  while read line
	do
		# We get the PID and check if the process was started in the DOMAIN_HOME
		
		myPID=`echo "$line" | awk '{print $2}'`
		# get the start directory
		nmSTARTPATH=`pwdx $myPID | awk '{print $2}'`
		if [ "$nmSTARTPATH" = "$DOMAIN_HOME" ] 
		then
			echo "Killing PID=$myPID ..."
			kill -9 $myPID
		fi

	done	
	
	#printf "STARTING NODEMANAGER\n"
	#nodemanager start > /dev/null
	
}





#-------------------------------------------------
# log_report: print a log report for the weblogic logfiles on this machine in this domain
#                   it uses the perl script wls_weblogic-log-analysis.pl
# paramters:    Options string which is feed into the perl script
#               Default: -war, i.e print number of error, warnings, alers
#--------------------------------------------------
log_report(){

	# if $1 is not set we set the default
	if [ -z ${1+x} ]; then 
		OPTIONS="-war"
	else
		OPTIONS=$1	
	fi
	LOG_ROOT="$DOMAIN_HOME/servers"
	for logfile in $(find ${LOG_ROOT} -name *.log | egrep "AdminServer\.log|WLS_REPORTS\.log|ifw_server2\.log|ifw_server1\.log" | sort); do
		echo "${logfile}:"
		perl wls_weblogic-log-analysis.pl ${OPTIONS} $logfile
	done
		
}

#-------------------------------------------------
# nodemanager: start or stop the nodemanager using the shell Scripts in Domain Home
#
# paramters:   start|stop
#
#--------------------------------------------------
nodemanager(){
  CUR_DIR=$(pwd)
  cd $DOMAIN_HOME
  case "$1" in
  'start')
          echo "Starting the NodeManager ..."
          nohup ./bin/startNodeManager.sh  > NodeManager.out 2>&1 &
          ;;
  'stop')
          echo "Stopping the NodeManager ..."
          ./bin/stopNodeManager.sh
          ;;
  *)
      echo "Error in nodemanager(): $1 is not a valid paramter!";
          ;;
  esac
  cd $CUR_DIR
}

#-------------------------------------------------
# startAdmin: start the AdminServer with nohup using the shell Scripts in Domain Home
#
# paramters: none
#
#--------------------------------------------------
startAdmin(){
  CUR_DIR=$(pwd)
  cd $DOMAIN_HOME

  # check for running AdminServer
  ADMIN_PROC=$(ps -aelf | grep [w]eblogic.Name=AdminServer)
  if [ ! -z "$ADMIN_PROC" ];
  then
    echo "The AdminServer is already running!"
  else
    echo "Starting the AdminServer ..."
    nohup ./startWebLogic.sh > AdminServer.out 2>&1 &
  fi

  cd $CUR_DIR
}



#==================================================
# MAIN SECTION
#==================================================

# Setup Evironment
export DOMAIN_HOME=/opt/install/domains/osb_domain
export MIDDLEWARE_HOME=/opt/install/fmw


case "$1" in
'status')
        status;
        ;;
'kill')
        myKill;
        ;;
'startNodemanager')
        nodemanager start;
        ;;
'stopNodemanager')
        nodemanager stop;
        ;;
'log_report')
        log_report $2;
        ;;
'startAdmin')
        startAdmin;
        ;;
'usage')
        usage;
        ;;

*)
    usage;
        ;;
esac
exit 0








