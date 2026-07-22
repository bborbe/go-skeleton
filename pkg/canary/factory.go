package canary

func NewService(cfg string) (*Service, error) {
	if cfg == "" {
		return nil, nil
	}
	return &Service{}, nil
}
