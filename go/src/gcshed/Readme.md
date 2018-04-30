# gcshed

Consolidates GC and shed information

* [Linux binary download](https://drive.google.com/open?id=1d7bPdFvMxL_u3nPFjN3wLar3CVt46L1v)

* Usage example:

```sh
./gcshed --shed_files=shed_1.csv,shed_2.csv --gc_files=gc_1.log,gc_2.log,gc_3.log
 ```

The output is CSV-formatted which the following columns:
* Duration (in millis)
* Number of requests processed before this collection
* Number of requests shed during the unavailability period
* Run ID (which referencing each of the passed-in file)