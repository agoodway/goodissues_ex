package config

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/viper"
)

type Config struct {
	BaseURL string `mapstructure:"base_url"`
	APIKey  string `mapstructure:"api_key"`
}

const (
	configDir  = ".fruitfly"
	configFile = "config"
	configType = "yaml"
)

func configPath() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("could not find home directory: %w", err)
	}
	return filepath.Join(home, configDir), nil
}

func Load() (*Config, error) {
	cfgPath, err := configPath()
	if err != nil {
		return nil, err
	}

	viper.SetConfigName(configFile)
	viper.SetConfigType(configType)
	viper.AddConfigPath(cfgPath)

	viper.SetDefault("base_url", "http://localhost:4000")
	viper.SetDefault("api_key", "")

	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return nil, fmt.Errorf("error reading config: %w", err)
		}
	}

	var cfg Config
	if err := viper.Unmarshal(&cfg); err != nil {
		return nil, fmt.Errorf("error parsing config: %w", err)
	}

	return &cfg, nil
}

func Save(cfg *Config) error {
	cfgPath, err := configPath()
	if err != nil {
		return err
	}

	if err := os.MkdirAll(cfgPath, 0700); err != nil {
		return fmt.Errorf("could not create config directory: %w", err)
	}

	viper.Set("base_url", cfg.BaseURL)
	viper.Set("api_key", cfg.APIKey)

	configFilePath := filepath.Join(cfgPath, configFile+"."+configType)
	if err := viper.WriteConfigAs(configFilePath); err != nil {
		return fmt.Errorf("error writing config: %w", err)
	}

	return nil
}

func (c *Config) Validate() error {
	if c.APIKey == "" {
		return fmt.Errorf("API key not configured. Run 'fruitfly configure --api-key <key>' to set it")
	}
	if c.BaseURL == "" {
		return fmt.Errorf("base URL not configured. Run 'fruitfly configure --url <url>' to set it")
	}
	return nil
}
