// Copyright (c) 2026 Benjamin Borbe All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package braceutil finds balanced brace spans in text.
package braceutil

import "strings"

// LastBalancedBrace returns the byte offsets of the last balanced '{' ... '}'
// span in s. It anchors on the final '}' and walks backward, tracking depth,
// to its matching '{'. Returns ok=false when there is no '}' or the braces are
// unbalanced.
//
// The walk is byte-level: a '}' increments depth and a '{' decrements it, so
// the matching open brace is the position where depth returns to zero. Braces
// that appear inside string literals are NOT treated specially — callers that
// need string-aware matching must strip literals first.
func LastBalancedBrace(s string) (start, end int, ok bool) {
	end = strings.LastIndexByte(s, '}')
	if end < 0 {
		return 0, 0, false
	}
	depth := 0
	for i := end; i >= 0; i-- {
		switch s[i] {
		case '}':
			depth++
		case '{':
			depth--
			if depth == 0 {
				return i, end, true
			}
		}
	}
	return 0, 0, false
}
