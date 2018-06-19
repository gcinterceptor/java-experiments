package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"sort"
	"strconv"
	"strings"

	"gonum.org/v1/gonum/stat"
)

func main() {
	f, err := os.Open(os.Args[1])
	if err != nil {
		log.Fatalf("Error opening file: %q", err)
	}
	defer f.Close()

	fmt.Println("timestamp,p50_ms,p99_ms")
	scanner := bufio.NewScanner(f)

	previousSec := 0
	var requestTimes []float64
	for counter := 0; scanner.Scan(); counter++ {
		rec := strings.Split(scanner.Text(), ";")
		if rec[1] != "200" {
			continue
		}
		switch {
		case counter == 0:
			// Header.
			continue
		case counter == 1:
			previousSec, err = strconv.Atoi(strings.Split(rec[0], ".")[0])
			if err != nil {
				log.Fatalf("Error getting prevSec: %q", err)
			}
		default:
			sec, err := strconv.Atoi(strings.Split(rec[0], ".")[0])
			if err != nil {
				log.Fatalf("Error getting sec: %q", err)
			}
			if sec != previousSec {
				sort.Float64s(requestTimes)
				p50 := stat.Quantile(0.5, stat.Empirical, requestTimes, nil)
				p999 := stat.Quantile(0.999, stat.Empirical, requestTimes, nil)
				fmt.Printf("%d,%.0f,%.0f\n", sec, p50, p999)
				requestTimes = nil
				previousSec = sec
			}
		}
		rt, err := strconv.ParseFloat(rec[2], 64)
		if err != nil {
			log.Fatalf("Getting parsing request time: %q", err)
		}
		requestTimes = append(requestTimes, rt*1000)
	}
	// check for errors
	if err = scanner.Err(); err != nil {
		log.Fatal(err)
	}
}
