package cmd

import (
	"fmt"
	"os"
	"text/tabwriter"

	"fruitfly/internal/client"
	"fruitfly/internal/config"

	"github.com/spf13/cobra"
)

var projectsCmd = &cobra.Command{
	Use:   "projects",
	Short: "Manage projects",
	Long:  `List, create, update, and delete projects.`,
}

var projectsListCmd = &cobra.Command{
	Use:   "list",
	Short: "List all projects",
	Run:   runProjectsList,
}

var projectsGetCmd = &cobra.Command{
	Use:   "get <id>",
	Short: "Get a project by ID",
	Args:  cobra.ExactArgs(1),
	Run:   runProjectsGet,
}

var projectsCreateCmd = &cobra.Command{
	Use:   "create",
	Short: "Create a new project",
	Run:   runProjectsCreate,
}

var projectsUpdateCmd = &cobra.Command{
	Use:   "update <id>",
	Short: "Update a project",
	Args:  cobra.ExactArgs(1),
	Run:   runProjectsUpdate,
}

var projectsDeleteCmd = &cobra.Command{
	Use:   "delete <id>",
	Short: "Delete a project",
	Args:  cobra.ExactArgs(1),
	Run:   runProjectsDelete,
}

var (
	projectName        string
	projectDescription string
)

func init() {
	rootCmd.AddCommand(projectsCmd)
	projectsCmd.AddCommand(projectsListCmd)
	projectsCmd.AddCommand(projectsGetCmd)
	projectsCmd.AddCommand(projectsCreateCmd)
	projectsCmd.AddCommand(projectsUpdateCmd)
	projectsCmd.AddCommand(projectsDeleteCmd)

	projectsCreateCmd.Flags().StringVar(&projectName, "name", "", "Project name (required)")
	projectsCreateCmd.Flags().StringVar(&projectDescription, "description", "", "Project description")
	projectsCreateCmd.MarkFlagRequired("name")

	projectsUpdateCmd.Flags().StringVar(&projectName, "name", "", "Project name")
	projectsUpdateCmd.Flags().StringVar(&projectDescription, "description", "", "Project description")
}

func getClient() *client.Client {
	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading config: %v\n", err)
		os.Exit(1)
	}

	if err := cfg.Validate(); err != nil {
		fmt.Fprintf(os.Stderr, "Configuration error: %v\n", err)
		os.Exit(1)
	}

	return client.New(cfg)
}

func runProjectsList(cmd *cobra.Command, args []string) {
	c := getClient()

	resp, err := c.ListProjects()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	if len(resp.Data) == 0 {
		fmt.Println("No projects found.")
		return
	}

	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	fmt.Fprintln(w, "ID\tNAME\tDESCRIPTION\tCREATED")
	for _, p := range resp.Data {
		desc := ""
		if p.Description != nil {
			desc = *p.Description
		}
		fmt.Fprintf(w, "%s\t%s\t%s\t%s\n", p.ID, p.Name, desc, p.InsertedAt)
	}
	w.Flush()

	if resp.Meta.TotalPages > 1 {
		fmt.Printf("\nPage %d of %d (total: %d)\n", resp.Meta.Page, resp.Meta.TotalPages, resp.Meta.Total)
	}
}

func runProjectsGet(cmd *cobra.Command, args []string) {
	c := getClient()

	project, err := c.GetProject(args[0])
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("ID:          %s\n", project.ID)
	fmt.Printf("Name:        %s\n", project.Name)
	if project.Description != nil {
		fmt.Printf("Description: %s\n", *project.Description)
	}
	fmt.Printf("Created:     %s\n", project.InsertedAt)
	fmt.Printf("Updated:     %s\n", project.UpdatedAt)
}

func runProjectsCreate(cmd *cobra.Command, args []string) {
	c := getClient()

	req := &client.ProjectRequest{
		Name: projectName,
	}
	if projectDescription != "" {
		req.Description = &projectDescription
	}

	project, err := c.CreateProject(req)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Created project: %s (%s)\n", project.Name, project.ID)
}

func runProjectsUpdate(cmd *cobra.Command, args []string) {
	c := getClient()

	req := &client.ProjectRequest{}
	hasChanges := false

	if projectName != "" {
		req.Name = projectName
		hasChanges = true
	}
	if projectDescription != "" {
		req.Description = &projectDescription
		hasChanges = true
	}

	if !hasChanges {
		fmt.Fprintln(os.Stderr, "Error: at least one of --name or --description is required")
		os.Exit(1)
	}

	// If only description is provided, we need to get the current name
	if projectName == "" {
		existing, err := c.GetProject(args[0])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		req.Name = existing.Name
	}

	project, err := c.UpdateProject(args[0], req)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Updated project: %s (%s)\n", project.Name, project.ID)
}

func runProjectsDelete(cmd *cobra.Command, args []string) {
	c := getClient()

	if err := c.DeleteProject(args[0]); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("Project deleted.")
}
