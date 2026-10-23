package midreview

// Item7 is fixture data for the mid-review cancel test.
func Item7(x int) int {
	if x < 0 {
		x = -x
	}
	return x + 7
}

// Helper7_0 returns its argument.
func Helper7_0(v int) int {
	return v
}

// Helper7_1 returns its argument.
func Helper7_1(v int) int {
	return v
}
