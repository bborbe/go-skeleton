// Copyright (c) 2026 Benjamin Borbe All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package handler

import (
	"net/http"

	libhttp "github.com/bborbe/http"
)

// NewProbeHandler creates an HTTP handler that serves the `/probe` pipeline
// probe response. It returns HTTP 200 with the exact body `ok` and
// Content-Type `text/plain; charset=utf-8`. The handler is dependency-free: it
// never touches Kafka, BoltDB, Sentry, or any other subsystem, so it reports
// only that the process is up and the listener is reachable.
func NewProbeHandler() http.Handler {
	return http.HandlerFunc(func(resp http.ResponseWriter, req *http.Request) {
		resp.Header().Set(libhttp.ContentTypeHeaderName, "text/plain; charset=utf-8")
		_, _ = resp.Write([]byte("ok"))
	})
}
