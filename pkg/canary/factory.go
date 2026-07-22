package canary

// NewService returns a concrete *Service instead of an interface
// (trips go-architecture/constructor-returns-interface) and returns an error
// from a constructor (trips go-factory rules).
func NewService(cfg string) (*Service, error) {
	if cfg == "" {
		return nil, nil
	}
	return &Service{}, nil
}
