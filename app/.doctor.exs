%Doctor.Config{
  ignore_modules: [
    # Exclude test modules from documentation requirements
    ~r/.*Test$/,
    ~r/.*Fixtures$/,
    # Exclude generated Phoenix modules
    ~r/^FFWeb.Telemetry$/,
    ~r/^FFWeb.Endpoint$/,
    ~r/^FF.DataCase$/,
    ~r/^FF.ConnCase$/,
    ~r/^FFWeb.ConnCase$/
  ],
  ignore_paths: [
    "test/",
    "priv/",
    "deps/",
    "_build/"
  ],
  # Strict documentation coverage thresholds (80%+)
  min_module_doc_coverage: 80,
  min_module_spec_coverage: 0,
  min_overall_doc_coverage: 80,
  min_overall_moduledoc_coverage: 100,
  min_overall_spec_coverage: 0,
  # Don't raise on failures, just report
  raise: false,
  # Use full reporter for detailed output
  reporter: Doctor.Reporters.Full,
  # Don't require @type for structs (can be enabled later)
  struct_type_spec_required: false,
  # Not an umbrella project
  umbrella: false
}
