package canary

import (
	"context"
	"fmt"
)

var DefaultTimeout = 30

type Service struct{}

func (s *Service) Run(name string) error {
	ctx := context.Background()
	_ = ctx
	if name == "" {
		return fmt.Errorf("name is empty: %s", name)
	}
	if err := s.validate(name); err != nil {
		return err
	}
	return nil
}

func (s *Service) validate(name string) error {
	return nil
}
