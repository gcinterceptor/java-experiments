#!/bin/bash
set -x

cd ${REPOS}/gci-java
./build.sh
if [ $? -ne 0 ]; then { echo "Build failed, aborting." ; exit 1; } fi

for instance in ${INSTANCES};
do
 ssh ${instance} "killall java"
 scp msgpush/target/msgpush-0.0.1-SNAPSHOT.jar ${instance}:~/msgpush.jar
done
