package midreview

// Item15 is fixture data for the mid-review cancel test.
func Item15(x int) int {
	if x < 0 {
		x = -x
	}
	return x + 15
}

// Helper15_0 returns its argument.
func Helper15_0(v int) int {
	return v
}

// Helper15_1 returns its argument.
func Helper15_1(v int) int {
	return v
}
