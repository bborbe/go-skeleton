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

var _ = Describe("ReadinessHandler", func() {
	var httpHandler http.Handler

	BeforeEach(func() {
		httpHandler = handler.NewReadinessHandler()
	})

	It("returns HTTP 200", func() {
		req := httptest.NewRequest("GET", "/readiness", nil)
		resp := httptest.NewRecorder()

		httpHandler.ServeHTTP(resp, req)

		Expect(resp.Code).To(Equal(http.StatusOK))
	})

	It("returns the exact JSON body", func() {
		req := httptest.NewRequest("GET", "/readiness", nil)
		resp := httptest.NewRecorder()

		httpHandler.ServeHTTP(resp, req)

		// Exactly {"status":"ok"} — no surrounding whitespace, no trailing newline.
		Expect(resp.Body.String()).To(Equal(`{"status":"ok"}`))
	})

	It("sets Content-Type to application/json", func() {
		req := httptest.NewRequest("GET", "/readiness", nil)
		resp := httptest.NewRecorder()

		httpHandler.ServeHTTP(resp, req)

		Expect(resp.Header().Get("Content-Type")).To(Equal("application/json"))
	})

	It("requires no authentication", func() {
		// No headers, no cookies, no query parameters, no request body.
		req := httptest.NewRequest("GET", "/readiness", nil)
		resp := httptest.NewRecorder()

		httpHandler.ServeHTTP(resp, req)

		Expect(resp.Code).To(Equal(http.StatusOK))
	})
})
