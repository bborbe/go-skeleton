package midreview

// Item36 is fixture data for the mid-review cancel test.
func Item36(x int) int {
	if x < 0 {
		x = -x
	}
	return x + 36
}

// Helper36_0 returns its argument.
func Helper36_0(v int) int {
	return v
}

// Helper36_1 returns its argument.
func Helper36_1(v int) int {
	return v
}
