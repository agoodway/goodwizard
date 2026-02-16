## ADDED Requirements

### Requirement: Convert bold markdown to HTML
The formatter SHALL convert `**text**` to `<b>text</b>`.

#### Scenario: Simple bold text
- **WHEN** the input contains `**hello**`
- **THEN** the output contains `<b>hello</b>`

#### Scenario: Bold with surrounding text
- **WHEN** the input is `This is **important** news`
- **THEN** the output is `This is <b>important</b> news`

#### Scenario: Multiple bold segments
- **WHEN** the input contains `**first** and **second**`
- **THEN** the output contains `<b>first</b> and <b>second</b>`

### Requirement: Convert italic markdown to HTML
The formatter SHALL convert `*text*` to `<i>text</i>`. The formatter SHALL NOT convert underscore-based italic (`_text_`).

#### Scenario: Simple italic text
- **WHEN** the input contains `*hello*`
- **THEN** the output contains `<i>hello</i>`

#### Scenario: Underscore italic is not converted
- **WHEN** the input contains `_hello_`
- **THEN** the output contains `_hello_` unchanged

#### Scenario: Snake case words are preserved
- **WHEN** the input contains `config_file_path`
- **THEN** the output contains `config_file_path` unchanged

### Requirement: Convert bold-italic markdown to HTML
The formatter SHALL convert `***text***` to `<b><i>text</i></b>`. This pattern MUST be processed before bold and italic individually.

#### Scenario: Bold-italic text
- **WHEN** the input contains `***important***`
- **THEN** the output contains `<b><i>important</i></b>`

### Requirement: Convert strikethrough markdown to HTML
The formatter SHALL convert `~~text~~` to `<s>text</s>`.

#### Scenario: Strikethrough text
- **WHEN** the input contains `~~removed~~`
- **THEN** the output contains `<s>removed</s>`

### Requirement: Convert inline code to HTML
The formatter SHALL convert `` `code` `` to `<code>code</code>`. Content inside inline code MUST have HTML entities escaped and MUST NOT have markdown conversion applied.

#### Scenario: Simple inline code
- **WHEN** the input contains `` `hello` ``
- **THEN** the output contains `<code>hello</code>`

#### Scenario: Markdown inside inline code is not converted
- **WHEN** the input contains `` `**not bold**` ``
- **THEN** the output contains `<code>**not bold**</code>`

#### Scenario: HTML entities inside inline code are escaped
- **WHEN** the input contains `` `a < b && c > d` ``
- **THEN** the output contains `<code>a &lt; b &amp;&amp; c &gt; d</code>`

### Requirement: Convert fenced code blocks to HTML
The formatter SHALL convert fenced code blocks to `<pre>` tags. When a language is specified, the formatter SHALL use `<pre><code class="language-X">content</code></pre>`. Content inside code blocks MUST have HTML entities escaped and MUST NOT have markdown conversion applied.

#### Scenario: Code block without language
- **WHEN** the input contains a fenced code block with no language identifier
- **THEN** the output wraps the content in `<pre>content</pre>`

#### Scenario: Code block with language
- **WHEN** the input contains a fenced code block with language `elixir`
- **THEN** the output wraps the content in `<pre><code class="language-elixir">content</code></pre>`

#### Scenario: Markdown inside code block is preserved
- **WHEN** a fenced code block contains `**bold** and *italic*`
- **THEN** the output preserves `**bold** and *italic*` as literal text (HTML-escaped)

#### Scenario: HTML entities inside code block are escaped
- **WHEN** a fenced code block contains `<div>hello</div>`
- **THEN** the output contains `&lt;div&gt;hello&lt;/div&gt;`

### Requirement: Convert links to HTML
The formatter SHALL convert `[text](url)` to `<a href="url">text</a>`.

#### Scenario: Simple link
- **WHEN** the input contains `[Click here](https://example.com)`
- **THEN** the output contains `<a href="https://example.com">Click here</a>`

#### Scenario: Link with special characters in URL
- **WHEN** the input contains `[API docs](https://example.com/api?v=2&format=json)`
- **THEN** the output contains a valid `<a>` tag with the URL preserved

### Requirement: Convert blockquotes to HTML
The formatter SHALL convert lines starting with `> ` to `<blockquote>` tags. Consecutive blockquote lines SHALL be grouped into a single `<blockquote>` element.

#### Scenario: Single blockquote line
- **WHEN** the input contains `> This is quoted`
- **THEN** the output contains `<blockquote>This is quoted</blockquote>`

#### Scenario: Multi-line blockquote
- **WHEN** the input contains consecutive lines `> line one` and `> line two`
- **THEN** the output wraps both lines in a single `<blockquote>line one\nline two</blockquote>`

### Requirement: Escape HTML entities in plain text
The formatter SHALL escape `&`, `<`, and `>` as `&amp;`, `&lt;`, `&gt;` in all text outside of generated HTML tags. Escaping MUST occur before markdown-to-HTML conversion to avoid escaping the formatter's own tags.

#### Scenario: Ampersand in text
- **WHEN** the input contains `Tom & Jerry`
- **THEN** the output contains `Tom &amp; Jerry`

#### Scenario: Angle brackets in text
- **WHEN** the input contains `x < 5 and y > 3`
- **THEN** the output contains `x &lt; 5 and y &gt; 3`

#### Scenario: Entities are not double-escaped
- **WHEN** the input contains no HTML entities
- **THEN** the output does not contain double-escaped sequences like `&amp;amp;`

### Requirement: Plain text passthrough
The formatter SHALL return plain text (no markdown) with only HTML entity escaping applied.

#### Scenario: No markdown in input
- **WHEN** the input is `Hello, how are you today?`
- **THEN** the output is `Hello, how are you today?`

#### Scenario: Empty string
- **WHEN** the input is an empty string
- **THEN** the output is an empty string

### Requirement: Graceful handling of unmatched markers
The formatter SHALL leave unmatched or malformed markdown markers as literal text (HTML-escaped).

#### Scenario: Single asterisk without closing
- **WHEN** the input contains `This has a * but no closing`
- **THEN** the output preserves the `*` as literal text

#### Scenario: Unmatched double asterisks
- **WHEN** the input contains `This is **unclosed`
- **THEN** the output preserves `**` as literal text
