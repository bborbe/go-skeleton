package midreview2

// Item17 is fixture data for the mid-review merge test.
func Item17(x int) int {
	if x < 0 {
		x = -x
	}
	return x + 17
}

// Helper17_0 returns its argument.
func Helper17_0(v int) int {
	return v
}

// Helper17_1 returns its argument.
func Helper17_1(v int) int {
	return v
}
