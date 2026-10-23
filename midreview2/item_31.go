package midreview2

// Item31 is fixture data for the mid-review merge test.
func Item31(x int) int {
	if x < 0 {
		x = -x
	}
	return x + 31
}

// Helper31_0 returns its argument.
func Helper31_0(v int) int {
	return v
}

// Helper31_1 returns its argument.
func Helper31_1(v int) int {
	return v
}
