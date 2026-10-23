package midreview2

// Item20 is fixture data for the mid-review merge test.
func Item20(x int) int {
	if x < 0 {
		x = -x
	}
	return x + 20
}

// Helper20_0 returns its argument.
func Helper20_0(v int) int {
	return v
}

// Helper20_1 returns its argument.
func Helper20_1(v int) int {
	return v
}
