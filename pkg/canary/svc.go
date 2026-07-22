package canary

import (
	"context"
	"fmt"
)

// DefaultTimeout is a package-level global (trips go-architecture/no-globals-or-singletons).
var DefaultTimeout = 30

// Service does work.
type Service struct{}

// Run trips several MUST-tier mechanical rules across one function.
func (s *Service) Run(name string) error {
	ctx := context.Background() // trips go-errors/no-context-background-in-business-logic
	_ = ctx
	if name == "" {
		return fmt.Errorf("name is empty: %s", name) // trips go-errors/no-fmt-errorf
	}
	if err := s.validate(name); err != nil {
		return err // trips go-errors/no-bare-return-err
	}
	return nil
}

func (s *Service) validate(name string) error {
	return nil
}
