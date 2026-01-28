package cmd

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	"fruitfly/internal/config"

	"github.com/spf13/cobra"
)

var configureCmd = &cobra.Command{
	Use:   "configure",
	Short: "Configure Fruitfly CLI settings",
	Long:  `Configure the Fruitfly CLI with your API base URL and API key.`,
	Run:   runConfigure,
}

var configureShowCmd = &cobra.Command{
	Use:   "show",
	Short: "Show current configuration",
	Run:   runConfigureShow,
}

var (
	flagURL    string
	flagAPIKey string
)

func init() {
	rootCmd.AddCommand(configureCmd)
	configureCmd.AddCommand(configureShowCmd)

	configureCmd.Flags().StringVar(&flagURL, "url", "", "API base URL")
	configureCmd.Flags().StringVar(&flagAPIKey, "api-key", "", "API key")
}

func runConfigure(cmd *cobra.Command, args []string) {
	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading config: %v\n", err)
		os.Exit(1)
	}

	// If flags are provided, use them
	if flagURL != "" || flagAPIKey != "" {
		if flagURL != "" {
			cfg.BaseURL = flagURL
		}
		if flagAPIKey != "" {
			cfg.APIKey = flagAPIKey
		}

		if err := config.Save(cfg); err != nil {
			fmt.Fprintf(os.Stderr, "Error saving config: %v\n", err)
			os.Exit(1)
		}
		fmt.Println("Configuration saved.")
		return
	}

	// Interactive mode
	reader := bufio.NewReader(os.Stdin)

	fmt.Printf("Base URL [%s]: ", cfg.BaseURL)
	urlInput, _ := reader.ReadString('\n')
	urlInput = strings.TrimSpace(urlInput)
	if urlInput != "" {
		cfg.BaseURL = urlInput
	}

	fmt.Print("API Key: ")
	keyInput, _ := reader.ReadString('\n')
	keyInput = strings.TrimSpace(keyInput)
	if keyInput != "" {
		cfg.APIKey = keyInput
	}

	if err := config.Save(cfg); err != nil {
		fmt.Fprintf(os.Stderr, "Error saving config: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("Configuration saved.")
}

func runConfigureShow(cmd *cobra.Command, args []string) {
	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading config: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Base URL: %s\n", cfg.BaseURL)
	if cfg.APIKey != "" {
		// Mask the API key, showing only the prefix and last 4 characters
		masked := maskAPIKey(cfg.APIKey)
		fmt.Printf("API Key:  %s\n", masked)
	} else {
		fmt.Println("API Key:  (not set)")
	}
}

func maskAPIKey(key string) string {
	if len(key) <= 8 {
		return "****"
	}
	prefix := ""
	if strings.HasPrefix(key, "pk_") || strings.HasPrefix(key, "sk_") {
		prefix = key[:3]
		key = key[3:]
	}
	if len(key) <= 4 {
		return prefix + "****"
	}
	return prefix + "****" + key[len(key)-4:]
}
