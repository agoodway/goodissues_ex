package cmd

import (
	"fmt"
	"os"
	"text/tabwriter"

	"fruitfly/internal/client"

	"github.com/spf13/cobra"
)

var errorsCmd = &cobra.Command{
	Use:   "errors",
	Short: "Manage tracking errors",
	Long:  `List, search, and update tracking errors.`,
}

var errorsListCmd = &cobra.Command{
	Use:   "list",
	Short: "List all errors",
	Run:   runErrorsList,
}

var errorsGetCmd = &cobra.Command{
	Use:   "get <id>",
	Short: "Get an error by ID",
	Args:  cobra.ExactArgs(1),
	Run:   runErrorsGet,
}

var errorsSearchCmd = &cobra.Command{
	Use:   "search",
	Short: "Search errors by stacktrace",
	Run:   runErrorsSearch,
}

var errorsUpdateCmd = &cobra.Command{
	Use:   "update <id>",
	Short: "Update an error",
	Args:  cobra.ExactArgs(1),
	Run:   runErrorsUpdate,
}

var (
	errorFilterStatus string
	errorFilterMuted  string
	errorPage         int
	errorPerPage      int
	errorSearchModule string
	errorSearchFunc   string
	errorSearchFile   string
	errorUpdateStatus string
	errorUpdateMuted  string
)

func init() {
	rootCmd.AddCommand(errorsCmd)
	errorsCmd.AddCommand(errorsListCmd)
	errorsCmd.AddCommand(errorsGetCmd)
	errorsCmd.AddCommand(errorsSearchCmd)
	errorsCmd.AddCommand(errorsUpdateCmd)

	// List filters
	errorsListCmd.Flags().StringVar(&errorFilterStatus, "status", "", "Filter by status (resolved, unresolved)")
	errorsListCmd.Flags().StringVar(&errorFilterMuted, "muted", "", "Filter by muted status (true, false)")
	errorsListCmd.Flags().IntVar(&errorPage, "page", 0, "Page number")
	errorsListCmd.Flags().IntVar(&errorPerPage, "per-page", 0, "Results per page")

	// Search filters
	errorsSearchCmd.Flags().StringVar(&errorSearchModule, "module", "", "Search by module name")
	errorsSearchCmd.Flags().StringVar(&errorSearchFunc, "function", "", "Search by function name")
	errorsSearchCmd.Flags().StringVar(&errorSearchFile, "file", "", "Search by file path")
	errorsSearchCmd.Flags().IntVar(&errorPage, "page", 0, "Page number")
	errorsSearchCmd.Flags().IntVar(&errorPerPage, "per-page", 0, "Results per page")

	// Update flags
	errorsUpdateCmd.Flags().StringVar(&errorUpdateStatus, "status", "", "Status: resolved, unresolved")
	errorsUpdateCmd.Flags().StringVar(&errorUpdateMuted, "muted", "", "Muted: true, false")
}

func runErrorsList(cmd *cobra.Command, args []string) {
	c := getClient()

	opts := &client.ListErrorsOptions{
		Status:  errorFilterStatus,
		Page:    errorPage,
		PerPage: errorPerPage,
	}
	if errorFilterMuted == "true" {
		muted := true
		opts.Muted = &muted
	} else if errorFilterMuted == "false" {
		muted := false
		opts.Muted = &muted
	}

	resp, err := c.ListErrors(opts)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	if len(resp.Data) == 0 {
		fmt.Println("No errors found.")
		return
	}

	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	fmt.Fprintln(w, "ID\tKIND\tSTATUS\tMUTED\tOCCURRENCES\tLAST SEEN")
	for _, e := range resp.Data {
		fmt.Fprintf(w, "%s\t%s\t%s\t%v\t%d\t%s\n",
			truncateID(e.ID), e.Kind, e.Status, e.Muted, e.OccurrenceCount, e.LastOccurrenceAt)
	}
	w.Flush()

	if resp.Meta.TotalPages > 1 {
		fmt.Printf("\nPage %d of %d (total: %d)\n", resp.Meta.Page, resp.Meta.TotalPages, resp.Meta.Total)
	}
}

func runErrorsGet(cmd *cobra.Command, args []string) {
	c := getClient()

	trackingErr, err := c.GetError(args[0])
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("ID:              %s\n", trackingErr.ID)
	fmt.Printf("Issue ID:        %s\n", trackingErr.IssueID)
	fmt.Printf("Kind:            %s\n", trackingErr.Kind)
	fmt.Printf("Reason:          %s\n", trackingErr.Reason)
	fmt.Printf("Source:          %s in %s\n", trackingErr.SourceFunction, trackingErr.SourceLine)
	fmt.Printf("Status:          %s\n", trackingErr.Status)
	fmt.Printf("Muted:           %v\n", trackingErr.Muted)
	fmt.Printf("Fingerprint:     %s\n", trackingErr.Fingerprint)
	fmt.Printf("Last Occurrence: %s\n", trackingErr.LastOccurrenceAt)
	fmt.Printf("Created:         %s\n", trackingErr.InsertedAt)
	fmt.Printf("Updated:         %s\n", trackingErr.UpdatedAt)

	if len(trackingErr.Occurrences) > 0 {
		fmt.Printf("\nOccurrences (%d):\n", trackingErr.OccurrenceCount)
		for i, occ := range trackingErr.Occurrences {
			fmt.Printf("\n  [%d] %s\n", i+1, occ.InsertedAt)
			fmt.Printf("      Reason: %s\n", occ.Reason)
			if len(occ.Stacktrace.Lines) > 0 {
				fmt.Printf("      Stacktrace:\n")
				for j, line := range occ.Stacktrace.Lines {
					if j >= 5 {
						fmt.Printf("        ... and %d more lines\n", len(occ.Stacktrace.Lines)-5)
						break
					}
					fmt.Printf("        %s.%s/%d (%s:%d)\n",
						line.Module, line.Function, line.Arity, line.File, line.Line)
				}
			}
		}
	}
}

func runErrorsSearch(cmd *cobra.Command, args []string) {
	c := getClient()

	if errorSearchModule == "" && errorSearchFunc == "" && errorSearchFile == "" {
		fmt.Fprintln(os.Stderr, "Error: at least one search filter is required (--module, --function, or --file)")
		os.Exit(1)
	}

	opts := &client.SearchErrorsOptions{
		Module:   errorSearchModule,
		Function: errorSearchFunc,
		File:     errorSearchFile,
		Page:     errorPage,
		PerPage:  errorPerPage,
	}

	resp, err := c.SearchErrors(opts)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	if len(resp.Data) == 0 {
		fmt.Println("No errors found.")
		return
	}

	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	fmt.Fprintln(w, "ID\tKIND\tSOURCE\tSTATUS\tLAST SEEN")
	for _, e := range resp.Data {
		source := fmt.Sprintf("%s in %s", e.SourceFunction, e.SourceLine)
		if len(source) > 40 {
			source = source[:37] + "..."
		}
		fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%s\n",
			truncateID(e.ID), e.Kind, source, e.Status, e.LastOccurrenceAt)
	}
	w.Flush()
}

func runErrorsUpdate(cmd *cobra.Command, args []string) {
	c := getClient()

	req := &client.UpdateErrorRequest{}
	hasChanges := false

	if errorUpdateStatus != "" {
		req.Status = &errorUpdateStatus
		hasChanges = true
	}
	if errorUpdateMuted == "true" {
		muted := true
		req.Muted = &muted
		hasChanges = true
	} else if errorUpdateMuted == "false" {
		muted := false
		req.Muted = &muted
		hasChanges = true
	}

	if !hasChanges {
		fmt.Fprintln(os.Stderr, "Error: at least one update flag is required (--status or --muted)")
		os.Exit(1)
	}

	trackingErr, err := c.UpdateError(args[0], req)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Updated error: %s (status: %s, muted: %v)\n", trackingErr.ID, trackingErr.Status, trackingErr.Muted)
}

func truncateID(id string) string {
	if len(id) > 8 {
		return id[:8]
	}
	return id
}
