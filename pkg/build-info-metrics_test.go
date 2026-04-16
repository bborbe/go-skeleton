// Copyright (c) 2026 Benjamin Borbe All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package pkg_test

import (
	"time"

	libtime "github.com/bborbe/time"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/prometheus/client_golang/prometheus/testutil"

	"github.com/bborbe/go-skeleton/pkg"
)

var _ = Describe("BuildInfoMetrics", func() {
	It("NewBuildInfoMetrics returns a non-nil BuildInfoMetrics", func() {
		Expect(pkg.NewBuildInfoMetrics()).NotTo(BeNil())
	})

	It("SetBuildInfo records the build timestamp as Unix time on the gauge", func() {
		metrics := pkg.NewBuildInfoMetrics()
		buildDate := libtime.DateTime(time.Date(2026, time.January, 2, 3, 4, 5, 0, time.UTC))
		metrics.SetBuildInfo(&buildDate)
		got := testutil.ToFloat64(pkg.BuildInfoGaugeForTest)
		Expect(got).To(Equal(float64(buildDate.Unix())))
	})

	It("SetBuildInfo does not write when buildDate is nil", func() {
		metrics := pkg.NewBuildInfoMetrics()
		sentinel := libtime.DateTime(time.Date(2020, time.June, 15, 0, 0, 0, 0, time.UTC))
		metrics.SetBuildInfo(&sentinel)
		before := testutil.ToFloat64(pkg.BuildInfoGaugeForTest)
		Expect(before).To(Equal(float64(sentinel.Unix())))
		metrics.SetBuildInfo(nil)
		Expect(testutil.ToFloat64(pkg.BuildInfoGaugeForTest)).To(Equal(before))
	})
})
