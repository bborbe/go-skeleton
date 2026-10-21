// Copyright (c) 2026 Benjamin Borbe All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package handler

import (
	"net/http"
)

// NewReadinessHandler creates an HTTP handler that serves the canonical readiness
// response. It returns HTTP 200 with body `{"status":"ok"}` and
// Content-Type: application/json. The handler is dependency-free: it never
// touches Kafka, BoltDB, Sentry, or any other subsystem, so it can only ever
// fail by reporting "the process is down" (process exit / listener gone).
//
// The contract is identical to NewHealthzHandler; this implementation delegates
// to it to avoid future drift between the two routes.
func NewReadinessHandler() http.Handler {
	return NewHealthzHandler()
}
