#!/bin/bash

ssh ${LOAD_BALANCER} "sudo apt-get install nginx -y"
scp nginx.conf ${LOAD_BALANCER}:./
ssh ${LOAD_BALANCER} "sudo mv nginx.conf ../../etc/nginx/"
