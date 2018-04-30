package main

import (
	"bufio"
	"encoding/csv"
	"flag"
	"fmt"
	"log"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"
)

var (
	shedFiles = flag.String("shed_files", "", "Comma-separated list of shed files.")
	gcFiles   = flag.String("gc_files", "", "Comma-separated list of gc log files.")
	warmup    = flag.Duration("warmup", 120*time.Second, "Duration of the warmup time")
)

func main() {
	flag.Parse()

	shedSlice := strings.Split(*shedFiles, ",")
	gcSlice := strings.Split(*gcFiles, ",")
	if len(shedSlice) != len(gcSlice) {
		panic("shed_files and gc_files must have the same number of elements.")
	}

	for i := range gcSlice {
		gcEntries := readGCLog(gcSlice[i])
		shedEntries := readCSVRows(shedSlice[i])
		shedIndex := 1
		var elapsed, totalTime int64
		var proc, shed string
		for _, entry := range gcEntries {
			if entry.Reason == "System.gc()" && entry.Type == "Young" {
				procShed := shedEntries[shedIndex]
				proc = procShed[0]
				shed = procShed[1]
				elapsed = int64(entry.Elapsed.Seconds() * 1000)
				totalTime = int64(entry.Duration.Seconds() * 1000)
				shedIndex++
			} else if entry.Reason == "System.gc()" && entry.Type == "Full" && elapsed > int64((*warmup).Seconds()*1000) {
				totalTime += int64(entry.Duration.Seconds() * 1000)
				fmt.Printf("%d,%s,%s,%d\n", elapsed, proc, shed, totalTime)
			}
		}
	}
}

func readCSVRows(p string) [][]string {
	f, err := os.Open(p)
	if err != nil {
		panic(err)
	}
	defer f.Close()
	reader := csv.NewReader(f)
	rows, err := reader.ReadAll()
	if err != nil {
		panic(err)
	}
	return rows
}

type gcLogEntry struct {
	Elapsed   time.Duration
	ID        uint64
	Type      string
	Reason    string
	GenBefore uint64
	GenAfter  uint64
	GenTotal  uint64
	Duration  time.Duration
}

var gcRegexp = regexp.MustCompile("\\[(.*s)\\].* GC\\((\\d+)\\) Pause (.*) \\((.*)\\) (\\d+)M->(\\d+)M\\((\\d+)M\\) \\(.*\\) (.*)$")

func readGCLog(p string) []gcLogEntry {
	f, err := os.Open(p)
	if err != nil {
		panic(err)
	}
	defer f.Close()
	var ret []gcLogEntry
	scanner := bufio.NewScanner(f)
	scanner.Split(bufio.ScanLines)
	scanner.Scan() // Ignoring first line.
	for scanner.Scan() {
		ret = append(ret, parseEntry(scanner.Text()))
	}
	if err := scanner.Err(); err != nil {
		log.Fatal(err)
	}
	return ret
}

func parseEntry(s string) gcLogEntry {
	result := gcRegexp.FindStringSubmatch(s)
	if len(result) != 9 {
		panic(fmt.Sprintf("Invalid gc entry: %s %v", s, result))
	}
	elapsed, err := time.ParseDuration(result[1])
	if err != nil {
		panic(err)
	}
	dur, err := time.ParseDuration(result[8])
	if err != nil {
		panic(fmt.Sprintf("Err: %q, Row:%s", err, s))
	}
	entry := gcLogEntry{
		Elapsed:   elapsed,
		ID:        mustParseUint(result[2]),
		Type:      result[3],
		Reason:    result[4],
		GenBefore: mustParseUint(result[5]),
		GenAfter:  mustParseUint(result[6]),
		GenTotal:  mustParseUint(result[7]),
		Duration:  dur,
	}
	return entry
}

func mustParseFloat(s string) float64 {
	r, err := strconv.ParseFloat(s, 64)
	if err != nil {
		panic(err)
	}
	return r
}

func mustParseUint(s string) uint64 {
	r, err := strconv.ParseUint(s, 10, 64)
	if err != nil {
		panic(err)
	}
	return r
}
