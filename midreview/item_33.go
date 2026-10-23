package midreview

// Item33 is fixture data for the mid-review cancel test.
func Item33(x int) int {
	if x < 0 {
		x = -x
	}
	return x + 33
}

// Helper33_0 returns its argument.
func Helper33_0(v int) int {
	return v
}

// Helper33_1 returns its argument.
func Helper33_1(v int) int {
	return v
}
