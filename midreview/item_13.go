package midreview

// Item13 is fixture data for the mid-review cancel test.
func Item13(x int) int {
	if x < 0 {
		x = -x
	}
	return x + 13
}

// Helper13_0 returns its argument.
func Helper13_0(v int) int {
	return v
}

// Helper13_1 returns its argument.
func Helper13_1(v int) int {
	return v
}
