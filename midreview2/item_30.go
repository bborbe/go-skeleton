package midreview2

// Item30 is fixture data for the mid-review merge test.
func Item30(x int) int {
	if x < 0 {
		x = -x
	}
	return x + 30
}

// Helper30_0 returns its argument.
func Helper30_0(v int) int {
	return v
}

// Helper30_1 returns its argument.
func Helper30_1(v int) int {
	return v
}
