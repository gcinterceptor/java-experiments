#!/bin/bash

set -x

./altosim --al_datapackage=../../../results/1i/al_datapackage.json --resource=gci_lh_sf_1 --warmup=240s > sim_input_gci_lh_sf.csv
./altosim --al_datapackage=../../../results/1i/al_datapackage.json --resource=gci_lh_sl_1 --warmup=240s > sim_input_gci_lh_sl.csv
./altosim --al_datapackage=../../../results/1i/al_datapackage.json --resource=gci_hh_sf_1 --warmup=240s > sim_input_gci_hh_sf.csv
./altosim --al_datapackage=../../../results/1i/al_datapackage.json --resource=gci_hh_sl_1 --warmup=240s > sim_input_gci_hh_sl.csv
./altosim --al_datapackage=../../../results/1i/al_datapackage.json --resource=nogci_lh_sf_1 --warmup=240s > sim_input_nogci_lh_sf.csv
./altosim --al_datapackage=../../../results/1i/al_datapackage.json --resource=nogci_lh_sl_1 --warmup=240s > sim_input_nogci_lh_sl.csv
./altosim --al_datapackage=../../../results/1i/al_datapackage.json --resource=nogci_hh_sf_1 --warmup=240s > sim_input_nogci_hh_sf.csv
./altosim --al_datapackage=../../../results/1i/al_datapackage.json --resource=nogci_hh_sl_1 --warmup=240s > sim_input_nogci_hh_sl.csv

zip sim_input.zip sim_input*.csv
