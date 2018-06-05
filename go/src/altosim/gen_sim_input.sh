#!/bin/bash

set -x

rm, *.csv

for i in `seq 1 4`; do ./altosim --al_datapackage=/home/fireman/repos/java-experiments/results/1i/al_datapackage.json --resource=gci_sf_$i --warmup=240s > sim_input_gci_sf_$i.csv; done
for i in `seq 1 4`; do ./altosim --al_datapackage=/home/fireman/repos/java-experiments/results/1i/al_datapackage.json --resource=gci_sl_$i --warmup=240s > sim_input_gci_sl_$i.csv; done
for i in `seq 1 4`; do ./altosim --al_datapackage=/home/fireman/repos/java-experiments/results/1i/al_datapackage.json --resource=nogci_sf_$i --warmup=240s > sim_input_gci_sf_$i.csv; done
for i in `seq 1 4`; do ./altosim --al_datapackage=/home/fireman/repos/java-experiments/results/1i/al_datapackage.json --resource=nogci_sl_$i --warmup=240s > sim_input_gci_sl_$i.csv; done


zip sim_input.zip sim_input*.csv
