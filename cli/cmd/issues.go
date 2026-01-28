package cmd

import (
	"fmt"
	"os"
	"text/tabwriter"

	"fruitfly/internal/client"

	"github.com/spf13/cobra"
)

var issuesCmd = &cobra.Command{
	Use:   "issues",
	Short: "Manage issues",
	Long:  `List, create, update, and delete issues.`,
}

var issuesListCmd = &cobra.Command{
	Use:   "list",
	Short: "List all issues",
	Run:   runIssuesList,
}

var issuesGetCmd = &cobra.Command{
	Use:   "get <id>",
	Short: "Get an issue by ID",
	Args:  cobra.ExactArgs(1),
	Run:   runIssuesGet,
}

var issuesCreateCmd = &cobra.Command{
	Use:   "create",
	Short: "Create a new issue",
	Run:   runIssuesCreate,
}

var issuesUpdateCmd = &cobra.Command{
	Use:   "update <id>",
	Short: "Update an issue",
	Args:  cobra.ExactArgs(1),
	Run:   runIssuesUpdate,
}

var issuesDeleteCmd = &cobra.Command{
	Use:   "delete <id>",
	Short: "Delete an issue",
	Args:  cobra.ExactArgs(1),
	Run:   runIssuesDelete,
}

var (
	issueTitle       string
	issueDescription string
	issueType        string
	issueStatus      string
	issuePriority    string
	issueProjectID   string
	issueEmail       string
	filterProjectID  string
	filterStatus     string
	filterType       string
)

func init() {
	rootCmd.AddCommand(issuesCmd)
	issuesCmd.AddCommand(issuesListCmd)
	issuesCmd.AddCommand(issuesGetCmd)
	issuesCmd.AddCommand(issuesCreateCmd)
	issuesCmd.AddCommand(issuesUpdateCmd)
	issuesCmd.AddCommand(issuesDeleteCmd)

	// List filters
	issuesListCmd.Flags().StringVar(&filterProjectID, "project", "", "Filter by project ID")
	issuesListCmd.Flags().StringVar(&filterStatus, "status", "", "Filter by status (new, in_progress, archived)")
	issuesListCmd.Flags().StringVar(&filterType, "type", "", "Filter by type (bug, feature_request)")

	// Create flags
	issuesCreateCmd.Flags().StringVar(&issueTitle, "title", "", "Issue title (required)")
	issuesCreateCmd.Flags().StringVar(&issueType, "type", "", "Issue type: bug, feature_request (required)")
	issuesCreateCmd.Flags().StringVar(&issueProjectID, "project", "", "Project ID (required)")
	issuesCreateCmd.Flags().StringVar(&issueDescription, "description", "", "Issue description")
	issuesCreateCmd.Flags().StringVar(&issuePriority, "priority", "", "Priority: low, medium, high, critical")
	issuesCreateCmd.Flags().StringVar(&issueEmail, "email", "", "Submitter email")
	issuesCreateCmd.MarkFlagRequired("title")
	issuesCreateCmd.MarkFlagRequired("type")
	issuesCreateCmd.MarkFlagRequired("project")

	// Update flags
	issuesUpdateCmd.Flags().StringVar(&issueTitle, "title", "", "Issue title")
	issuesUpdateCmd.Flags().StringVar(&issueDescription, "description", "", "Issue description")
	issuesUpdateCmd.Flags().StringVar(&issueType, "type", "", "Issue type: bug, feature_request")
	issuesUpdateCmd.Flags().StringVar(&issueStatus, "status", "", "Status: new, in_progress, archived")
	issuesUpdateCmd.Flags().StringVar(&issuePriority, "priority", "", "Priority: low, medium, high, critical")
	issuesUpdateCmd.Flags().StringVar(&issueEmail, "email", "", "Submitter email")
}

func runIssuesList(cmd *cobra.Command, args []string) {
	c := getClient()

	opts := &client.ListIssuesOptions{
		ProjectID: filterProjectID,
		Status:    filterStatus,
		Type:      filterType,
	}

	issues, err := c.ListIssues(opts)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	if len(issues) == 0 {
		fmt.Println("No issues found.")
		return
	}

	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	fmt.Fprintln(w, "ID\tTITLE\tTYPE\tSTATUS\tPRIORITY")
	for _, i := range issues {
		fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%s\n", i.ID, i.Title, i.Type, i.Status, i.Priority)
	}
	w.Flush()
}

func runIssuesGet(cmd *cobra.Command, args []string) {
	c := getClient()

	issue, err := c.GetIssue(args[0])
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("ID:          %s\n", issue.ID)
	fmt.Printf("Title:       %s\n", issue.Title)
	fmt.Printf("Type:        %s\n", issue.Type)
	fmt.Printf("Status:      %s\n", issue.Status)
	fmt.Printf("Priority:    %s\n", issue.Priority)
	fmt.Printf("Project ID:  %s\n", issue.ProjectID)
	if issue.Description != nil {
		fmt.Printf("Description: %s\n", *issue.Description)
	}
	if issue.SubmitterEmail != nil {
		fmt.Printf("Email:       %s\n", *issue.SubmitterEmail)
	}
	fmt.Printf("Created:     %s\n", issue.InsertedAt)
	fmt.Printf("Updated:     %s\n", issue.UpdatedAt)
}

func runIssuesCreate(cmd *cobra.Command, args []string) {
	c := getClient()

	req := &client.IssueRequest{
		Title:     issueTitle,
		Type:      issueType,
		ProjectID: issueProjectID,
	}
	if issueDescription != "" {
		req.Description = &issueDescription
	}
	if issuePriority != "" {
		req.Priority = &issuePriority
	}
	if issueEmail != "" {
		req.SubmitterEmail = &issueEmail
	}

	issue, err := c.CreateIssue(req)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Created issue: %s (%s)\n", issue.Title, issue.ID)
}

func runIssuesUpdate(cmd *cobra.Command, args []string) {
	c := getClient()

	req := &client.IssueUpdateRequest{}
	hasChanges := false

	if issueTitle != "" {
		req.Title = &issueTitle
		hasChanges = true
	}
	if issueDescription != "" {
		req.Description = &issueDescription
		hasChanges = true
	}
	if issueType != "" {
		req.Type = &issueType
		hasChanges = true
	}
	if issueStatus != "" {
		req.Status = &issueStatus
		hasChanges = true
	}
	if issuePriority != "" {
		req.Priority = &issuePriority
		hasChanges = true
	}
	if issueEmail != "" {
		req.SubmitterEmail = &issueEmail
		hasChanges = true
	}

	if !hasChanges {
		fmt.Fprintln(os.Stderr, "Error: at least one update flag is required")
		os.Exit(1)
	}

	issue, err := c.UpdateIssue(args[0], req)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Updated issue: %s (%s)\n", issue.Title, issue.ID)
}

func runIssuesDelete(cmd *cobra.Command, args []string) {
	c := getClient()

	if err := c.DeleteIssue(args[0]); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("Issue deleted.")
}
