// Copyright (c) 2026 Benjamin Borbe All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package example

import (
	"errors"
	"fmt"
)

// DoSomething demonstrates a string sanitizer.
// Throwaway helper for spec 033 E2E test — exercises pr-reviewer review-POST path.
func DoSomething(input string) (string, error) {
	if input == "" {
		return "", errors.New("input cannot be empty")
	}
	fmt.Println("processing:", input)
	return input, nil
}
