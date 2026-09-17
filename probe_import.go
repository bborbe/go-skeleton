// Copyright (c) 2026 Benjamin Borbe All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

// Blank import pins github.com/bborbe/memorykv as a direct requirement at its
// current (outdated) version, giving the dependency-update agent a real,
// mechanically-bumpable direct dependency to work on.
//
// Probe only — filed for BRO-21882 / Agent Failure Reporting — Dev Run
// Observations (SC3, execution-class failure). Delete this file and the
// branch once the observation is recorded.
import _ "github.com/bborbe/memorykv"
