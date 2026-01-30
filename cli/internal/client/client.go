package client

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"

	"fruitfly/internal/config"
)

type Client struct {
	baseURL    string
	apiKey     string
	httpClient *http.Client
}

func New(cfg *config.Config) *Client {
	return &Client{
		baseURL: cfg.BaseURL,
		apiKey:  cfg.APIKey,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

func (c *Client) do(method, path string, body interface{}, result interface{}) error {
	var bodyReader io.Reader
	if body != nil {
		jsonBytes, err := json.Marshal(body)
		if err != nil {
			return fmt.Errorf("failed to encode request body: %w", err)
		}
		bodyReader = bytes.NewReader(jsonBytes)
	}

	fullURL := c.baseURL + path
	req, err := http.NewRequest(method, fullURL, bodyReader)
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+c.apiKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode >= 400 {
		var errResp ErrorResponse
		if json.Unmarshal(respBody, &errResp) == nil && errResp.Errors.Detail != "" {
			return fmt.Errorf("API error (%d): %s", resp.StatusCode, errResp.Errors.Detail)
		}
		return fmt.Errorf("API error (%d): %s", resp.StatusCode, string(respBody))
	}

	if result != nil && len(respBody) > 0 {
		if err := json.Unmarshal(respBody, result); err != nil {
			return fmt.Errorf("failed to decode response: %w", err)
		}
	}

	return nil
}

// Error types
type ErrorResponse struct {
	Errors struct {
		Detail string `json:"detail"`
	} `json:"errors"`
}

// Project types
type Project struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	Description *string `json:"description"`
	InsertedAt  string  `json:"inserted_at"`
	UpdatedAt   string  `json:"updated_at"`
}

type ProjectListResponse struct {
	Data []Project `json:"data"`
}

type ProjectResponse struct {
	Data Project `json:"data"`
}

type ProjectRequest struct {
	Name        string  `json:"name"`
	Description *string `json:"description,omitempty"`
}

// Issue types
type Issue struct {
	ID             string  `json:"id"`
	Number         int     `json:"number"`
	Key            *string `json:"key"`
	Title          string  `json:"title"`
	Description    *string `json:"description"`
	Type           string  `json:"type"`
	Status         string  `json:"status"`
	Priority       string  `json:"priority"`
	ProjectID      string  `json:"project_id"`
	SubmitterID    string  `json:"submitter_id"`
	SubmitterEmail *string `json:"submitter_email"`
	ArchivedAt     *string `json:"archived_at"`
	InsertedAt     string  `json:"inserted_at"`
	UpdatedAt      string  `json:"updated_at"`
}

type IssueListResponse struct {
	Data []Issue `json:"data"`
}

type IssueResponse struct {
	Data Issue `json:"data"`
}

type IssueRequest struct {
	Title          string  `json:"title"`
	Type           string  `json:"type"`
	ProjectID      string  `json:"project_id"`
	Description    *string `json:"description,omitempty"`
	Status         *string `json:"status,omitempty"`
	Priority       *string `json:"priority,omitempty"`
	SubmitterEmail *string `json:"submitter_email,omitempty"`
}

type IssueUpdateRequest struct {
	Title          *string `json:"title,omitempty"`
	Description    *string `json:"description,omitempty"`
	Type           *string `json:"type,omitempty"`
	Status         *string `json:"status,omitempty"`
	Priority       *string `json:"priority,omitempty"`
	SubmitterEmail *string `json:"submitter_email,omitempty"`
}

// Project methods
func (c *Client) ListProjects() ([]Project, error) {
	var resp ProjectListResponse
	if err := c.do("GET", "/api/v1/projects", nil, &resp); err != nil {
		return nil, err
	}
	return resp.Data, nil
}

func (c *Client) GetProject(id string) (*Project, error) {
	var resp ProjectResponse
	if err := c.do("GET", "/api/v1/projects/"+id, nil, &resp); err != nil {
		return nil, err
	}
	return &resp.Data, nil
}

func (c *Client) CreateProject(req *ProjectRequest) (*Project, error) {
	var resp ProjectResponse
	if err := c.do("POST", "/api/v1/projects", req, &resp); err != nil {
		return nil, err
	}
	return &resp.Data, nil
}

func (c *Client) UpdateProject(id string, req *ProjectRequest) (*Project, error) {
	var resp ProjectResponse
	if err := c.do("PATCH", "/api/v1/projects/"+id, req, &resp); err != nil {
		return nil, err
	}
	return &resp.Data, nil
}

func (c *Client) DeleteProject(id string) error {
	return c.do("DELETE", "/api/v1/projects/"+id, nil, nil)
}

// Issue methods
type ListIssuesOptions struct {
	ProjectID string
	Status    string
	Type      string
}

func (c *Client) ListIssues(opts *ListIssuesOptions) ([]Issue, error) {
	path := "/api/v1/issues"
	if opts != nil {
		params := url.Values{}
		if opts.ProjectID != "" {
			params.Set("project_id", opts.ProjectID)
		}
		if opts.Status != "" {
			params.Set("status", opts.Status)
		}
		if opts.Type != "" {
			params.Set("type", opts.Type)
		}
		if len(params) > 0 {
			path += "?" + params.Encode()
		}
	}

	var resp IssueListResponse
	if err := c.do("GET", path, nil, &resp); err != nil {
		return nil, err
	}
	return resp.Data, nil
}

func (c *Client) GetIssue(id string) (*Issue, error) {
	var resp IssueResponse
	if err := c.do("GET", "/api/v1/issues/"+id, nil, &resp); err != nil {
		return nil, err
	}
	return &resp.Data, nil
}

func (c *Client) CreateIssue(req *IssueRequest) (*Issue, error) {
	var resp IssueResponse
	if err := c.do("POST", "/api/v1/issues", req, &resp); err != nil {
		return nil, err
	}
	return &resp.Data, nil
}

func (c *Client) UpdateIssue(id string, req *IssueUpdateRequest) (*Issue, error) {
	var resp IssueResponse
	if err := c.do("PATCH", "/api/v1/issues/"+id, req, &resp); err != nil {
		return nil, err
	}
	return &resp.Data, nil
}

func (c *Client) DeleteIssue(id string) error {
	return c.do("DELETE", "/api/v1/issues/"+id, nil, nil)
}

// Tracking Error types
type TrackingError struct {
	ID               string       `json:"id"`
	IssueID          string       `json:"issue_id"`
	Kind             string       `json:"kind"`
	Reason           string       `json:"reason"`
	SourceLine       string       `json:"source_line"`
	SourceFunction   string       `json:"source_function"`
	Status           string       `json:"status"`
	Fingerprint      string       `json:"fingerprint"`
	LastOccurrenceAt string       `json:"last_occurrence_at"`
	Muted            bool         `json:"muted"`
	InsertedAt       string       `json:"inserted_at"`
	UpdatedAt        string       `json:"updated_at"`
	OccurrenceCount  int          `json:"occurrence_count,omitempty"`
	Occurrences      []Occurrence `json:"occurrences,omitempty"`
}

type Occurrence struct {
	ID          string                 `json:"id"`
	Reason      string                 `json:"reason"`
	Context     map[string]interface{} `json:"context"`
	Breadcrumbs []interface{}          `json:"breadcrumbs"`
	Stacktrace  Stacktrace             `json:"stacktrace"`
	InsertedAt  string                 `json:"inserted_at"`
}

type Stacktrace struct {
	Lines []StacktraceLine `json:"lines"`
}

type StacktraceLine struct {
	Application string `json:"application"`
	Module      string `json:"module"`
	Function    string `json:"function"`
	Arity       int    `json:"arity"`
	File        string `json:"file"`
	Line        int    `json:"line"`
}

type TrackingErrorListResponse struct {
	Data []TrackingError `json:"data"`
	Meta PaginationMeta  `json:"meta"`
}

type TrackingErrorResponse struct {
	Data TrackingError `json:"data"`
}

type PaginationMeta struct {
	Page       int `json:"page"`
	PerPage    int `json:"per_page"`
	Total      int `json:"total"`
	TotalPages int `json:"total_pages"`
}

type ReportErrorRequest struct {
	ProjectID      string                 `json:"project_id"`
	Kind           string                 `json:"kind"`
	Reason         string                 `json:"reason"`
	SourceLine     string                 `json:"source_line,omitempty"`
	SourceFunction string                 `json:"source_function,omitempty"`
	Fingerprint    string                 `json:"fingerprint"`
	Context        map[string]interface{} `json:"context,omitempty"`
	Breadcrumbs    []interface{}          `json:"breadcrumbs,omitempty"`
	Stacktrace     []StacktraceLine       `json:"stacktrace,omitempty"`
}

type UpdateErrorRequest struct {
	Status *string `json:"status,omitempty"`
	Muted  *bool   `json:"muted,omitempty"`
}

// Tracking Error methods
type ListErrorsOptions struct {
	Status  string
	Muted   *bool
	Page    int
	PerPage int
}

func (c *Client) ListErrors(opts *ListErrorsOptions) (*TrackingErrorListResponse, error) {
	path := "/api/v1/errors"
	if opts != nil {
		params := url.Values{}
		if opts.Status != "" {
			params.Set("status", opts.Status)
		}
		if opts.Muted != nil {
			if *opts.Muted {
				params.Set("muted", "true")
			} else {
				params.Set("muted", "false")
			}
		}
		if opts.Page > 0 {
			params.Set("page", fmt.Sprintf("%d", opts.Page))
		}
		if opts.PerPage > 0 {
			params.Set("per_page", fmt.Sprintf("%d", opts.PerPage))
		}
		if len(params) > 0 {
			path += "?" + params.Encode()
		}
	}

	var resp TrackingErrorListResponse
	if err := c.do("GET", path, nil, &resp); err != nil {
		return nil, err
	}
	return &resp, nil
}

func (c *Client) GetError(id string) (*TrackingError, error) {
	var resp TrackingErrorResponse
	if err := c.do("GET", "/api/v1/errors/"+id, nil, &resp); err != nil {
		return nil, err
	}
	return &resp.Data, nil
}

type SearchErrorsOptions struct {
	Module   string
	Function string
	File     string
	Page     int
	PerPage  int
}

func (c *Client) SearchErrors(opts *SearchErrorsOptions) (*TrackingErrorListResponse, error) {
	path := "/api/v1/errors/search"
	params := url.Values{}
	if opts.Module != "" {
		params.Set("module", opts.Module)
	}
	if opts.Function != "" {
		params.Set("function", opts.Function)
	}
	if opts.File != "" {
		params.Set("file", opts.File)
	}
	if opts.Page > 0 {
		params.Set("page", fmt.Sprintf("%d", opts.Page))
	}
	if opts.PerPage > 0 {
		params.Set("per_page", fmt.Sprintf("%d", opts.PerPage))
	}
	if len(params) > 0 {
		path += "?" + params.Encode()
	}

	var resp TrackingErrorListResponse
	if err := c.do("GET", path, nil, &resp); err != nil {
		return nil, err
	}
	return &resp, nil
}

func (c *Client) ReportError(req *ReportErrorRequest) (*TrackingError, error) {
	var resp TrackingErrorResponse
	if err := c.do("POST", "/api/v1/errors", req, &resp); err != nil {
		return nil, err
	}
	return &resp.Data, nil
}

func (c *Client) UpdateError(id string, req *UpdateErrorRequest) (*TrackingError, error) {
	var resp TrackingErrorResponse
	if err := c.do("PATCH", "/api/v1/errors/"+id, req, &resp); err != nil {
		return nil, err
	}
	return &resp.Data, nil
}
