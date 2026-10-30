// Copyright (c) 2026 Benjamin Borbe All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package mathutil

// Sign reports whether value is negative, zero or positive: -1, 0 or 1.
// It exists so callers can branch on direction without repeating the
// three-way comparison, and it is defined for every int including the
// minimum value (unlike a negation-based implementation).
func Sign(value int) int {
	switch {
	case value < 0:
		return -1
	case value > 0:
		return 1
	default:
		return 0
	}
}
