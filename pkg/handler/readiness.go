// Copyright (c) 2026 Benjamin Borbe All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package handler

import "net/http"

// NewReadinessHandler creates an HTTP handler that serves the canonical readiness
// response. It delegates to NewHealthzHandler so both probe routes serve the
// identical `{"status":"ok"}` JSON contract and cannot drift apart. The handler is
// dependency-free: it performs no backend calls and reports only that the process
// is up and accepting traffic.
func NewReadinessHandler() http.Handler {
	return NewHealthzHandler()
}
