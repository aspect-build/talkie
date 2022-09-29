// Copyright 2022 Aspect Build Systems, Inc. All rights reserved.
// Original authors: Dylan Martin (dylan@aspect.dev)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
)

type stringListFlags []string

func (i *stringListFlags) String() string {
	return strings.Join(*i, ";")
}

func (i *stringListFlags) Set(value string) error {
	*i = append(*i, strings.Split(value, ";")...)
	return nil
}

var outputFlag string
var bazelStampFilesFlag stringListFlags

func init() {
	flag.StringVar(&outputFlag, "output", "", "The output .json file.")
	flag.Var(&bazelStampFilesFlag, "bazel_stamp_files", "The bazel stamp files you would like to turn into json format")
	flag.Parse()
}

func main() {

	output, err := os.Create(outputFlag)
	if err != nil {
		log.Fatal(err)
	}
	defer output.Close()

	attributes, err := parseStampFiles(bazelStampFilesFlag)
	if err != nil {
		log.Fatal(err)
	}

	outputStructure := map[string]interface{}{
		"workspace_status": attributes,
	}
	outputData, err := json.Marshal(outputStructure)
	if err != nil {
		log.Fatal(err)
	}

	if err := os.WriteFile(outputFlag, outputData, 0444); err != nil {
		log.Fatal(err)
	}
}

func parseStampFiles(bazelStampFilesFlag stringListFlags) (map[string]interface{}, error) {
	var attributes = make(map[string]interface{})
	for _, stampFile := range bazelStampFilesFlag {
		f, err := os.Open(stampFile)
		if err != nil {
			return nil, fmt.Errorf("failed to read bazel stamp files: %w", err)
		}

		scanner := bufio.NewScanner(f)
		for scanner.Scan() {
			line := scanner.Text()
			if line == "" {
				continue
			}

			parts := strings.SplitN(scanner.Text(), " ", 2)
			if len(parts) == 1 {
				attributes[parts[0]] = ""
			} else {
				attributes[parts[0]] = parts[1]
			}
		}
	}
	return attributes, nil
}
