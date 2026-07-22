// Copyright (c) 2026 Benjamin Borbe All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package braceutil_test

import (
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestBraceutil(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Braceutil Suite")
}
