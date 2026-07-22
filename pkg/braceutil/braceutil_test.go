// Copyright (c) 2026 Benjamin Borbe All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package braceutil_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/bborbe/go-skeleton/pkg/braceutil"
)

var _ = DescribeTable("LastBalancedBrace",
	func(input string, expectedStart, expectedEnd int, expectedOK bool) {
		start, end, ok := braceutil.LastBalancedBrace(input)
		Expect(ok).To(Equal(expectedOK))
		if expectedOK {
			Expect(start).To(Equal(expectedStart))
			Expect(end).To(Equal(expectedEnd))
		}
	},
	Entry("simple object", "{}", 0, 1, true),
	Entry("nested object", "{a{b}}", 0, 5, true),
	Entry("prose then object", "hello {x}", 6, 8, true),
	Entry("last of two objects", "{a} {b}", 4, 6, true),
	Entry("deeply nested braces", "{{{{x}}}}", 0, 8, true),
	Entry("single closing brace", "}", 0, 0, false),
	Entry("consecutive closing braces without opening", "}}}", 0, 0, false),
	Entry("no closing brace", "{ open only", 0, 0, false),
	Entry("no braces at all", "plain text", 0, 0, false),
)
