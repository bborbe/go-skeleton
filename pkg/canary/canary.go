package canary

import "fmt"

// Check is a throwaway function that trips go-errors/no-fmt-errorf so the
// PR reviewer's ast-grep mechanical funnel produces a MUST finding.
// Used to verify github-pr-review-agent v0.3.3 (python3+jq) on quant dev.
func Check(name string) error {
	if name == "" {
		return fmt.Errorf("name is empty: %s", name)
	}
	return nil
}
