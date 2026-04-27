// Package config loads and validates piboard YAML configuration.
package config

import (
	"fmt"
	"net/url"
	"os"

	"gopkg.in/yaml.v3"
)

type Config struct {
	PrometheusURL            string          `yaml:"prometheus_url"`
	PollIntervalSeconds      int             `yaml:"poll_interval_seconds"`
	ListenAddr               string          `yaml:"listen_addr"`
	Services                 []ServiceConfig `yaml:"services"`
	ProxmoxNodes             []NodeConfig    `yaml:"proxmox_nodes"`
	DegradedThresholdSeconds float64         `yaml:"degraded_threshold_seconds"`
}

type ServiceConfig struct {
	Name   string `yaml:"name"`
	Target string `yaml:"target"`
	Job    string `yaml:"job"`
}

type NodeConfig struct {
	Name string `yaml:"name"`
	ID   string `yaml:"id"`
}

// Load reads and validates a config file at the given path.
func Load(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("reading config: %w", err)
	}

	var cfg Config
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return nil, fmt.Errorf("parsing config: %w", err)
	}

	if err := cfg.validate(); err != nil {
		return nil, fmt.Errorf("invalid config: %w", err)
	}

	return &cfg, nil
}

func (c *Config) validate() error {
	if c.PrometheusURL == "" {
		return fmt.Errorf("prometheus_url is required")
	}

	u, err := url.Parse(c.PrometheusURL)
	if err != nil {
		return fmt.Errorf("prometheus_url is not a valid URL: %w", err)
	}
	if u.Scheme != "http" && u.Scheme != "https" {
		return fmt.Errorf("prometheus_url must use http or https scheme")
	}

	if c.PollIntervalSeconds < 5 || c.PollIntervalSeconds > 300 {
		return fmt.Errorf("poll_interval_seconds must be between 5 and 300")
	}

	if c.ListenAddr == "" {
		return fmt.Errorf("listen_addr is required")
	}

	if len(c.Services) == 0 {
		return fmt.Errorf("at least one service must be defined")
	}

	for i, svc := range c.Services {
		if svc.Name == "" || svc.Target == "" || svc.Job == "" {
			return fmt.Errorf("service[%d]: name, target, and job are all required", i)
		}
	}

	// Default degraded threshold
	if c.DegradedThresholdSeconds <= 0 {
		c.DegradedThresholdSeconds = 3.0
	}

	return nil
}
