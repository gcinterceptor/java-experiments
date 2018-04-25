# altosim

This tool converts custom formatted NGINXs acesslogs into a CSV which is going to be consumed by gci-simulator. The NGINX format is: `log_format exp '$msec;$status;$request_time;$upstream_response_time';`.

* [Example of accesslog datapackage](https://github.com/gcinterceptor/java-experiments/blob/master/results/2i/al_datackage.json)

* [Linux binary download](https://drive.google.com/open?id=1rNc4qk4zIuu3-lEAtfiKZ8BXRXKogsXR)

* Example of usage:

```sh
./altosim --al_datapackage=../../../2i/al_datackage.json --resource=gci --warmup=120s > sim_gci.csv
```