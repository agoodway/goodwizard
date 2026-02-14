%Doctor.Config{
  ignore_modules: [
    ~r/.*Test$/,
    ~r/.*Fixtures$/
  ],
  ignore_paths: [
    "test/",
    "priv/",
    "deps/",
    "_build/"
  ],
  min_module_doc_coverage: 80,
  min_module_spec_coverage: 0,
  min_overall_doc_coverage: 80,
  min_overall_moduledoc_coverage: 100,
  min_overall_spec_coverage: 0,
  raise: false,
  reporter: Doctor.Reporters.Full,
  struct_type_spec_required: false,
  umbrella: false
}
