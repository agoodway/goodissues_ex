package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "goodissues",
	Short: "GoodIssues CLI application",
	Long:  `GoodIssues is a CLI application built with Cobra.`,
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("Welcome to GoodIssues! Use --help to see available commands.")
	},
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func init() {
	rootCmd.Flags().BoolP("verbose", "v", false, "verbose output")
}
