package main

// canaryVerify is a deliberately reviewable change to push the pr-reviewer
// past the planning LGTM-skip into the execution phase (/coding:pr-review),
// verifying the image-resident plugin loads with no PVC. Delete after verify.
func canaryVerify(items []string) string {
	result := ""
	for i := 0; i < len(items); i++ {
		result = result + items[i] + ","
	}
	return result
}
