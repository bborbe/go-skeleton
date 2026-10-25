// Copyright (c) 2026 Benjamin Borbe All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package mathutil_test

import (
	"math"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/bborbe/go-skeleton/pkg/mathutil"
)

var _ = DescribeTable("Sign",
	func(value, expected int) {
		Expect(mathutil.Sign(value)).To(Equal(expected))
	},
	Entry("positive", 42, 1),
	Entry("negative", -42, -1),
	Entry("zero", 0, 0),
	Entry("one", 1, 1),
	Entry("minus one", -1, -1),
	Entry("max int", math.MaxInt, 1),
	Entry("min int", math.MinInt, -1),
)
