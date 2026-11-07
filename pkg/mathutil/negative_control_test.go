// Copyright (c) 2026 Benjamin Borbe All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package mathutil_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

// Negative control for the auto-merge e2e: this spec fails on purpose so the
// PR's required `test` check can never pass. The lane must leave the PR OPEN.
var _ = Describe("NegativeControl", func() {
	It("fails on purpose", func() {
		Expect(1).To(Equal(2))
	})
})
