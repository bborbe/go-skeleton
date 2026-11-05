// Copyright (c) 2026 Benjamin Borbe All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package handler_test

import (
	"net/http"
	"net/http/httptest"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/bborbe/go-skeleton/pkg/handler"
)

var _ = Describe("ProbeHandler", func() {
	var httpHandler http.Handler

	BeforeEach(func() {
		httpHandler = handler.NewProbeHandler()
	})

	It("returns HTTP 200", func() {
		req := httptest.NewRequest("GET", "/probe", nil)
		resp := httptest.NewRecorder()

		httpHandler.ServeHTTP(resp, req)

		Expect(resp.Code).To(Equal(http.StatusOK))
	})

	It("returns the exact body ok", func() {
		req := httptest.NewRequest("GET", "/probe", nil)
		resp := httptest.NewRecorder()

		httpHandler.ServeHTTP(resp, req)

		// Exactly `ok` — no trailing newline, no surrounding whitespace.
		Expect(resp.Body.String()).To(Equal("ok"))
	})

	It("sets Content-Type to text/plain; charset=utf-8", func() {
		req := httptest.NewRequest("GET", "/probe", nil)
		resp := httptest.NewRecorder()

		httpHandler.ServeHTTP(resp, req)

		Expect(resp.Header().Get("Content-Type")).To(Equal("text/plain; charset=utf-8"))
	})
})
