package midreview2

// Item16 is fixture data for the mid-review merge test.
func Item16(x int) int {
	if x < 0 {
		x = -x
	}
	return x + 16
}

// Helper16_0 returns its argument.
func Helper16_0(v int) int {
	return v
}

// Helper16_1 returns its argument.
func Helper16_1(v int) int {
	return v
}
