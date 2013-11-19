#!/bin/bash

###############################################################################
#
# This script runs first the RUBBoS browsing mix, then the read/write mix 
# for each rubbos.properties_XX specified where XX is the number of emulated
# clients. Note that the rubbos.properties_XX files must be configured
# with the corresponding number of clients.
# In particular set the following variables in rubis.properties_XX:
# httpd_use_version = Servlets
# workload_number_of_clients_per_node = XX/number of client machines
# workload_transition_table = yourPath/RUBBoS/workload/transitions.txt 
#
# This script should be run from the RUBBoS/bench directory on the local 
# client machine. 
# Results will be generated in the RUBBoS/bench directory.
#
################################################################################

# How many Tomcats? 1, 2 or 3?
SCALE=1

TOMCAT1=54.205.112.161
TOMCAT2=10.0.0.1
TOMCAT3=10.0.0.1

CLIENT=54.205.107.240
NGINX=54.227.101.173
MYSQL=54.204.198.69

DATE=$(date +"%F")

enable_servers () {
  case "$SCALE" in
    "1")
        sed -i -r -e 's/#?servlets_server = '$TOMCAT1'$/servlets_server = '$TOMCAT1'/' Client/rubbos.properties
        sed -i -r -e 's/#?servlets_server = '$TOMCAT1','$TOMCAT2'$/#servlets_server = '$TOMCAT1','$TOMCAT2'/' Client/rubbos.properties
        sed -i -r -e 's/#?servlets_server = '$TOMCAT1','$TOMCAT2','$TOMCAT3'$/#servlets_server = '$TOMCAT1','$TOMCAT2','$TOMCAT3'/' Client/rubbos.properties
        ;;
    "2")
        sed -i -r -e 's/#?servlets_server = '$TOMCAT1'$/#servlets_server = '$TOMCAT1'/' Client/rubbos.properties
        sed -i -r -e 's/#?servlets_server = '$TOMCAT1','$TOMCAT2'$/servlets_server = '$TOMCAT1','$TOMCAT2'/' Client/rubbos.properties
        sed -i -r -e 's/#?servlets_server = '$TOMCAT1','$TOMCAT2','$TOMCAT3'$/#servlets_server = '$TOMCAT1','$TOMCAT2','$TOMCAT3'/' Client/rubbos.properties
        ;;
    "3")
        sed -i -r -e 's/#?servlets_server = '$TOMCAT1'$/#servlets_server = '$TOMCAT1'/' Client/rubbos.properties
        sed -i -r -e 's/#?servlets_server = '$TOMCAT1','$TOMCAT2'$/#servlets_server = '$TOMCAT1','$TOMCAT2'/' Client/rubbos.properties
        sed -i -r -e 's/#?servlets_server = '$TOMCAT1','$TOMCAT2','$TOMCAT3'$/servlets_server = '$TOMCAT1','$TOMCAT2','$TOMCAT3'/' Client/rubbos.properties
        ;;
    *)
        :
        ;;
  esac
}

start_servers () {
  echo "Starting server 1..."
  ssh $TOMCAT1 -n -l vagrant /home/vagrant/tomcat/bin/startup.sh
  case "$SCALE" in
    "2")
        echo "Starting server 2..."
        ssh $TOMCAT2 -n -l vagrant /home/vagrant/tomcat/bin/startup.sh
        ;;
    "3")
        echo "Starting server 2..."
        ssh $TOMCAT2 -n -l vagrant /home/vagrant/tomcat/bin/startup.sh
        echo "Starting server 3..."
        ssh $TOMCAT3 -n -l vagrant /home/vagrant/tomcat/bin/startup.sh
        ;;
    *)
        :
        ;;
  esac

  echo "Waiting server start completion..."
  sleep 90
  echo "Server starts complete."
}

stop_servers () {
  echo "Stopping server 1..."
  ssh $TOMCAT1 -n -l vagrant /home/vagrant/tomcat/bin/shutdown.sh
  case "$SCALE" in
    "2")
        echo "Stopping server 2..."
        ssh $TOMCAT2 -n -l vagrant /home/vagrant/tomcat/bin/shutdown.sh
        ;;
    "3")
        echo "Stopping server 2..."
        ssh $TOMCAT2 -n -l vagrant /home/vagrant/tomcat/bin/shutdown.sh
        echo "Stopping server 3..."
        ssh $TOMCAT3 -n -l vagrant /home/vagrant/tomcat/bin/shutdown.sh
        ;;
    *)
        :
        ;;
  esac

  echo "Waiting server stop completion..."
  sleep 10
  echo "Server stop complete."
}

enable_stats () {
  turn_on_stats_on () {
    # Delete old stats files
    ssh $1 "sudo rm -rf /var/log/sysstat/*"

    # Enable sysstat
    ssh $1 "sudo sed -i -e 's/ENABLED=\"false\"/ENABLED=\"true\"/g' /etc/default/sysstat"

  }

  echo Enabling sysstat on target hosts...

  for HOST in "$MYSQL" "$NGINX" "$TOMCAT1" "$CLIENT"
  do
    turn_on_stats_on $HOST
  done

  if [ "$SCALE" -eq 2 ]; then
    turn_on_stats_on $TOMCAT2
  fi
  if [ "$SCALE" -eq 3 ]; then
    turn_on_stats_on $TOMCAT3
  fi

  echo Ok, stats turned on. 
}

disable_stats () {
  turn_off_stats_on () {
    # Disable sysstat
    ssh $1 "sudo sed -i -e 's/ENABLED=\"true\"/ENABLED=\"false\"/g' /etc/default/sysstat"
  }

  echo Disabling sysstat on target hosts...

  for HOST in "$MYSQL" "$NGINX" "$TOMCAT1" "$CLIENT"
  do
    turn_off_stats_on $HOST
  done

  if [ "$SCALE" -eq 2 ]; then
    turn_off_stats_on $TOMCAT2
  fi
  if [ "$SCALE" -eq 3 ]; then
    turn_off_stats_on $TOMCAT3
  fi

  echo Ok, stats turned off.

}

collect_stats () {
  TEST_RESULTS_DIR=./Client/bench/w"$1"s"$2"
  if [ ! -e $TEST_RESULTS_DIR ]; then
    mkdir -p $TEST_RESULTS_DIR
  fi
  LOG_FILE=$TEST_RESULTS_DIR/w"$1"s"$2"-$DATE-$START.log
  AVG_IDLE_CPU=0
  AVG_MEM_USED=0

  get_stats () {
    # Brings sysstat binary log files from remote host
    STATS_FILE=$TEST_RESULTS_DIR/$1.stats
    scp $1:/var/log/sysstat/sa* $STATS_FILE > /dev/null
    AVG_IDLE_CPU=$(sar -f $STATS_FILE -s $START -e $FINISH | tail -1 | awk '{print $8}')
    AVG_MEM_USED=$(sar -r -f $STATS_FILE -s $START -e $FINISH | tail -1 | awk '{print $3}')
  }

  echo Preparing log file...
  echo "RUBBoS workload test: $1 simulated users targeting $2 application servers" > $LOG_FILE
  echo Start: $DATE $START   -    Finish: $DATE $FINISH >> $LOG_FILE
  

  for HOST in "$MYSQL" "$NGINX" "$TOMCAT1" "$CLIENT"
  do
    get_stats $HOST
    echo $HOST stats: CPU Idle: $AVG_IDLE_CPU%    Memory Used: $AVG_MEM_USED% >> $LOG_FILE
  done

  if [ "$SCALE" -eq 2 ]; then
    HOST=$TOMCAT2
    get_stats $HOST
    echo $HOST stats: CPU Idle: $AVG_IDLE_CPU%    Memory Used: $AVG_MEM_USED% >> $LOG_FILE
  fi
  if [ "$SCALE" -eq 3 ]; then
    HOST=$TOMCAT3
    get_stats $HOST
    echo $HOST stats: CPU Idle: $AVG_IDLE_CPU%    Memory Used: $AVG_MEM_USED%" >> $LOG_FILE
  fi

  echo "End of test results" >> $LOG_FILE

}

run_test () {
  cd Client
  echo "Starting read/write tests..."

  make emulator 

#  for i in {1..60}
#  do
#    sleep 1
#    echo $i
#  done

  cd ..
  echo "RUBBoS test complete!"
}

echo "Configuring tests for $SCALE application servers"

# Go back to RUBBoS root directory
cd ..

# Browse only mix
#echo "Preparing read-only operations transition mixes..."
#cp ./workload/browse_only_transitions.txt ./workload/user_transitions.txt
#cp ./workload/browse_only_transitions.txt ./workload/author_transitions.txt

# Read/write mix
echo "Preparing read/write operations transition mixes..."
cp ./workload/user_default_transitions.txt ./workload/user_transitions.txt
cp ./workload/author_default_transitions.txt ./workload/author_transitions.txt


# rubbos.properties_100 rubbos.properties_200 rubbos.properties_300 rubbos.properties_400 rubbos.properties_500 rubbos.properties_600 rubbos.properties_700 rubbos.properties_800 rubbos.properties_900 rubbos.properties_1000
for workload in 100
do
  echo "Ready to run $workload users workload"

  cp bench/rubbos.properties_$workload Client/rubbos.properties
  sed -i -r -e 's/httpd_hostname = (([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])/httpd_hostname = '$NGINX'/' Client/rubbos.properties
  sed -i -r -e 's/database_server = (([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])/database_server = '$MYSQL'/' Client/rubbos.properties

  enable_servers

  start_servers

  enable_stats

  START=$(date +"%H:%M:%S")
  run_test
  FINISH=$(date +"%H:%M:%S")

  disable_stats

  stop_servers

  collect_stats $workload $SCALE
done

