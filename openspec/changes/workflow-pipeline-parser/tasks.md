## 1. Tokenizer

- [ ] 1.1 Create `lib/goodwizard/workflow/pipeline_parser.ex` module with a private `tokenize/1` function for character-level tokenization
- [ ] 1.2 Implement single-quote and double-quote handling: strip delimiters, preserve inner content, error on unclosed quotes
- [ ] 1.3 Tokenize pipe `|` characters as delimiter tokens (only outside quotes)
- [ ] 1.4 Tokenize `--flag` prefixes as flag tokens distinct from plain words
- [ ] 1.5 Handle whitespace trimming between tokens and around pipe delimiters

## 2. Step Parser

- [ ] 2.1 Implement step type recognition: match first token of each pipe segment against `exec`, `approve`, `openclaw.invoke`
- [ ] 2.2 Return `{:error, reason}` for unrecognized step types with descriptive message

## 3. Flag Parser

- [ ] 3.1 Implement value flag parsing for `--shell`, `--stdin`, `--prompt`, `--limit`, `--item-key`, `--args-json`
- [ ] 3.2 Implement boolean flag parsing for `--preview-from-stdin` and `--each`
- [ ] 3.3 Return `{:error, reason}` for unknown flags and missing flag values

## 4. Pipeline Assembly

- [ ] 4.1 Implement public `PipelineParser.parse/1`: tokenize -> split on pipe -> parse each segment -> assemble `%Pipeline{steps: [...]}`
- [ ] 4.2 Return `{:error, reason}` for empty or whitespace-only input
- [ ] 4.3 Populate each Step struct with parsed type and flag values

## 5. Tests

- [ ] 5.1 Unit tests for tokenizer: quoted strings, unclosed quotes, pipe delimiters, whitespace, empty input
- [ ] 5.2 Unit tests for step type recognition: all three valid types, unknown type error
- [ ] 5.3 Unit tests for flag parsing: each flag individually, boolean vs value, missing value error
- [ ] 5.4 Integration tests for full pipeline parsing: single step, multi-step, real-world examples, all error cases
- [ ] 5.5 Edge case tests: empty quoted strings, flags in different orders, `--args-json` with special characters
