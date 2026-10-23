package midreview2

// Item32 is fixture data for the mid-review merge test.
func Item32(x int) int {
	if x < 0 {
		x = -x
	}
	return x + 32
}

// Helper32_0 returns its argument.
func Helper32_0(v int) int {
	return v
}

// Helper32_1 returns its argument.
func Helper32_1(v int) int {
	return v
}
