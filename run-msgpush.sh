#!/bin/bash
# IMPORTANT: This script requires pidstats (part of sysstas package).

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
    START_PROXY=""
    SERVER_PORT=3000
else
    USE_GCI="true"
    FILE_NAME_SUFFIX="gci"
    START_PROXY="killall gci-proxy 2>/dev/null; nohup ./gci-proxy >unavailability.csv 2>/dev/null & sleep 10s;"
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
echo "CONNECTIONS: ${CONNECTIONS:=2}"
echo "JVMARGS: ${JVMARGS:=-XX:+UseParallelGC -XX:NewRatio=1}"
FILE_NAME_SUFFIX="${FILE_NAME_SUFFIX}${SUFFIX}"
echo "WRK:${WRK:=wrk}"
echo "INSTANCES:${INSTANCES:=}"


for round in `seq ${ROUND_START} ${ROUND_END}`
do
    echo ""
    echo "round ${round}: Bringing up server instances..."
    for instance in ${INSTANCES};
    do
        ssh ${instance} "${START_PROXY} killall java 2>/dev/null; rm gc.log shed.csv 2>/dev/null; killall pidstat 2>/dev/null; USE_GCI=${USE_GCI} SHED_RATIO_CSV_FILE=shed.csv WINDOW_SIZE=${WINDOW_SIZE} MSG_SIZE=${MSG_SIZE} nohup java -server -Xlog:gc* -Xlog:gc:gc.log ${JVMARGS} -jar -Dserver.port=${SERVER_PORT} msgpush.jar >msgpush.out 2>msgpush.err & nohup pidstat -C java 1 | grep java | sed s/,/./g |  awk '{if (\$0 ~ /[0-9]/) { print \$1\",\"\$2\",\"\$3\",\"\$4\",\"\$5\",\"\$6\",\"\$7\",\"\$8\",\"\$9; }  }'> cpu.csv 2>/dev/null &"
    done

    sleep 5
    echo "round ${round}: Done. Starting load test..."
    ssh ${LB} "sudo rm /var/log/nginx/*.log;  sudo systemctl restart nginx; killall wrk 2>/dev/null; ${WRK} -t${THREADS} -c${CONNECTIONS} -d${EXPERIMENT_DURATION} -R${THROUGHPUT} --latency --timeout=15s http://localhost > ~/wrk_${FILE_NAME_SUFFIX}_${round}.out; cp /var/log/nginx/access.log ~/al_${FILE_NAME_SUFFIX}_${round}.log; cp /var/log/nginx/error.log ~/nginx_error_${FILE_NAME_SUFFIX}_${round}.log"

    echo "round ${round}: Done. Putting server instances down..."
    i=0
    for instance in ${INSTANCES};
    do
        cmd="killall java; killall gci-proxy; killall pidstat; mv cpu.csv cpu_${FILE_NAME_SUFFIX}_${i}_${round}.csv; mv gc.log gc_${FILE_NAME_SUFFIX}_${i}_${round}.log; mv shed.csv shed_${FILE_NAME_SUFFIX}_${i}_${round}.csv"
        ssh ${instance} "$cmd"
        ((i++))
    done

    echo "round ${round}: Done. Copying results and cleaning up instances..."
    scp ${LB}:~/\{*log,*.out\} ${OUTPUT_DIR}
    ssh ${LB} "rm *.log; rm *.out"
    sed -i '1i timestamp;status;request_time;upstream_response_time' ${OUTPUT_DIR}/al_${FILE_NAME_SUFFIX}_${round}.log

    i=0
    for instance in ${INSTANCES};
    do
        scp ${instance}:~/\{cpu*.csv,gc*.log,shed*.csv\} ${OUTPUT_DIR}
        sed -i '1i time,ampm,uid,pid,usr,system,guest,cpu,cpuid' ${OUTPUT_DIR}/cpu_${FILE_NAME_SUFFIX}_${i}_${round}.csv
        ssh ${instance} "rm ~/cpu*.csv ~/gc*.log ~/shed*.csv"
        ((i++))
    done
    echo "round ${round}: Finished."
    echo ""
    sleep 5s
done
