// Copyright (c) 2026 Benjamin Borbe All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package handler

import (
	"net/http"
)

// NewReadinessHandler creates an HTTP handler that serves the canonical
// readiness response: HTTP 200 with body `{"status":"ok"}` and
// Content-Type: application/json. It delegates to NewHealthzHandler so the
// liveness and readiness routes cannot drift apart, and it is
// dependency-free: it never touches Kafka, BoltDB, Sentry, or any other
// subsystem.
func NewReadinessHandler() http.Handler {
	return NewHealthzHandler()
}
