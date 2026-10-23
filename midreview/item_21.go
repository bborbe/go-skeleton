package midreview

// Item21 is fixture data for the mid-review cancel test.
func Item21(x int) int {
	if x < 0 {
		x = -x
	}
	return x + 21
}

// Helper21_0 returns its argument.
func Helper21_0(v int) int {
	return v
}

// Helper21_1 returns its argument.
func Helper21_1(v int) int {
	return v
}
