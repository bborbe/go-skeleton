package midreview2

// Item25 is fixture data for the mid-review merge test.
func Item25(x int) int {
	if x < 0 {
		x = -x
	}
	return x + 25
}

// Helper25_0 returns its argument.
func Helper25_0(v int) int {
	return v
}

// Helper25_1 returns its argument.
func Helper25_1(v int) int {
	return v
}
