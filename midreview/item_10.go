package midreview

// Item10 is fixture data for the mid-review cancel test.
func Item10(x int) int {
	if x < 0 {
		x = -x
	}
	return x + 10
}

// Helper10_0 returns its argument.
func Helper10_0(v int) int {
	return v
}

// Helper10_1 returns its argument.
func Helper10_1(v int) int {
	return v
}
