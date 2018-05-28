#!/bin/bash

date
set -x

# Expected Parameters:
# Example:
# LB="3.3.3.3"
# INSTANCES="1.1.1.1 2.2.2.2"
# USE_GCI="true"

# TODO(danielfireman): Check parameters.

# GCI on/off switcher.
if [ "$USE_GCI" == "false" ];
then
	FILE_NAME_SUFFIX="nogci"
	SERVER_PORT=3000
else
	USE_GCI="true"
	FILE_NAME_SUFFIX="gci"
	SERVER_PORT=8080
fi

# Experiment configuration
echo "OUTPUT_DIR: ${OUTPUT_DIR:=/tmp/2instances}"
mkdir -p "$OUTPUT_DIR"
echo "ROUND_START: ${ROUND_START:=1}"
echo "ROUND_END: ${ROUND_END:=1}"
echo "USE_GCI: ${USE_GCI}"
echo "EXPERIMENT_DURATION: ${EXPERIMENT_DURATION:=120s}"
echo "MSG_SIZE: ${MSG_SIZE:=204800}"
echo "THROUGHPUT: ${THROUGHPUT:=80}"
echo "WINDOW_SIZE: ${WINDOW_SIZE:=1}"
echo "SUFFIX: ${SUFFIX:=}"
echo "THREADS: ${THREADS:=1}"
echo "JVMARGS: ${JVMARGS:=}"
FILE_NAME_SUFFIX="${FILE_NAME_SUFFIX}${SUFFIX}"
echo "LOAD_CLIENT:${LOAD_CLIENT:=hey}"
echo "INSTANCES:${INSTANCES:=}"
echo "SLEEP_TIME_MS:${SLEEP_TIME_MS:=5}"

for round in `seq ${ROUND_START} ${ROUND_END}`
do
	#ssh -i ~/fireman.sururu.key ubuntu@10.11.23.9 "sudo virsh shutdown vm2; sleep 5; sudo virsh start vm2; sleep 30"
	echo ""
	date
	echo ""
	echo "round ${round}: Bringing up server instances..."
	for instance in ${INSTANCES};
	do
		ssh ${instance} "killall gci-proxy 2>/dev/null; killall java 2>/dev/null; rm gc.log shed.csv st.csv 2>/dev/null; killall mon.sh 2>/dev/null; USE_GCI=${USE_GCI} PORT=${SERVER_PORT} SHED_RATIO_CSV_FILE=shed.csv WINDOW_SIZE=${WINDOW_SIZE} MSG_SIZE=${MSG_SIZE} COMPUTING_TIME_MS=${COMPUTING_TIME_MS} SLEEP_TIME_MS=${SLEEP_TIME_MS} YOUNG_GEN=${YOUNG_GEN} nohup java ${JVMARGS} -Dserver.port=${SERVER_PORT} -jar  msgpush.jar  >msgpush.out 2>msgpush.err & nohup ./mon.sh >cpu.csv 2>/dev/null &"
	done 

	if [ "$USE_GCI" == "true" ]; 
	then
		ssh ${PROXY} "killall gci-proxy 2>/dev/null; rm proxy.* 2>/dev/null; GODEBUG=gctrace=1 nohup ./gci-proxy -url=http://10.11.23.250:8080 >proxy.out 2>proxy.err & sleep 5s;"
		ssh ${LB} "sudo cp nginx.gci.conf /etc/nginx/nginx.conf"
	else
		ssh ${LB} "sudo cp nginx.nogci.conf /etc/nginx/nginx.conf"

	fi

	sleep 5
	echo "round ${round}: Done. Starting load test..."
	ssh ${LB} "sudo rm /var/log/nginx/*.log;  sudo systemctl restart nginx; killall vegeta >/dev/null 2>&1; ${LOAD_CLIENT} >~/client_${FILE_NAME_SUFFIX}_${round}.out 2>~/client_${FILE_NAME_SUFFIX}_${round}.err; cp /var/log/nginx/access.log ~/al_${FILE_NAME_SUFFIX}_${round}.log; cp /var/log/nginx/error.log ~/nginx_error_${FILE_NAME_SUFFIX}_${round}.log"

	echo "round ${round}: Done. Putting server instances down..."
	i=0
	for instance in ${INSTANCES};
	do
		cmd="killall java; killall gci-proxy; killall mon.sh; mv cpu.csv cpu_${FILE_NAME_SUFFIX}_${i}_${round}.csv; mv gc.log gc_${FILE_NAME_SUFFIX}_${i}_${round}.log; mv shed.csv shed_${FILE_NAME_SUFFIX}_${i}_${round}.csv; mv st.csv st_${FILE_NAME_SUFFIX}_${i}_${round}.csv; mv proxy_latency.csv proxy_latency_${FILE_NAME_SUFFIX}_${i}_${round}.csv"
		ssh ${instance} "$cmd"
		((i++))
	done

	echo "round ${round}: Done. Copying results and cleaning up instances..."
	scp ${LB}:~/\{*log,*.out,*.err\} ${OUTPUT_DIR}
	ssh ${LB} "rm *.log; rm *.out *.err"
	sed -i '1i timestamp;status;request_time;upstream_response_time' ${OUTPUT_DIR}/al_${FILE_NAME_SUFFIX}_${round}.log

	if [ "$USE_GCI" == "true" ];
	then
		ssh ${PROXY} "killall gci-proxy 2>/dev/null; rm proxy.* 2>/dev/null"
	fi

	i=0
	for instance in ${INSTANCES};
	do
		scp ${instance}:~/\{cpu*.csv,gc*.log,shed*.csv,st*.csv,proxy_latency*.csv\} ${OUTPUT_DIR}
		ssh ${instance} "rm ~/cpu*.csv ~/gc*.log ~/shed*.csv ~/st*.csv ~/proxy_latency*.csv *.err"
		((i++))
	done
	echo "round ${round}: Finished."
	echo ""
	date
	sleep 5s
done
