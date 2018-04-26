// Package to process accesslogs and produce a CSV that will be consumed by gci-simulator.
//
// Usage example:
// ./altosim --al_datapackage=../../../2i/al_datackage.json --resource=gci --warmup=120s > sim_gci.csv
package main

import (
	"flag"
	"fmt"
	"strings"
	"time"

	"github.com/frictionlessdata/datapackage-go/datapackage"
	"github.com/frictionlessdata/tableschema-go/csv"
)

var (
	alPkg    = flag.String("al_datapackage", "", "Path to access logs.")
	warmup   = flag.Duration("warmup", 120*time.Second, "Duration of the warmup time")
	resource = flag.String("resource", "gci", "Comma-separated list of resource names (e.g. gci, nogci1,nogci2")
)

type entry struct {
	Timestamp   float64 `tableheader:"timestamp"`
	Status      int32   `tableheader:"status"`
	RequestTime float64 `tableheader:"request_time"`
}

func main() {
	flag.Parse()
	al, err := datapackage.Load(*alPkg)
	if err != nil {
		panic(err)
	}

	resources := strings.Split(*resource, ",")
	for _, r := range resources {
		var entries []entry
		gci := al.GetResource(r)
		if gci == nil {
			panic(fmt.Sprintf("Resource not found: %s", r))
		}
		if err := gci.Cast(&entries, csv.Delimiter(';'), csv.LoadHeaders()); err != nil {
			panic(err)
		}

		fmt.Println("timestamp,status,request_time") // Output header.

		first := entries[0].Timestamp * 1000 // Converting to ms.
		delta := float64(*warmup / 1e6)      // Converting to ms.
		for _, e := range entries {
			e.Timestamp = e.Timestamp * 1000
			if e.Timestamp >= first+delta {
				fmt.Printf("%d,%d,%d\n", int64(e.Timestamp), e.Status, int64(e.RequestTime*1000)) // Converting request time to ms.
			}
		}
	}
}
