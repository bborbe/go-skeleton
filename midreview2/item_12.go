package midreview2

// Item12 is fixture data for the mid-review merge test.
func Item12(x int) int {
	if x < 0 {
		x = -x
	}
	return x + 12
}

// Helper12_0 returns its argument.
func Helper12_0(v int) int {
	return v
}

// Helper12_1 returns its argument.
func Helper12_1(v int) int {
	return v
}
