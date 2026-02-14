defmodule Goodwizard.Plugins.PromptSkills.ParserTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Plugins.PromptSkills.Parser

  describe "parse_frontmatter/1" do
    test "extracts name, description, and body" do
      content = """
      ---
      name: deploy
      description: Deploy to production
      ---
      # Deploy Skill

      Run deployments.
      """

      {:ok, metadata, body} = Parser.parse_frontmatter(content)
      assert metadata.name == "deploy"
      assert metadata.description == "Deploy to production"
      assert metadata.meta == %{}
      assert body =~ "# Deploy Skill"
      assert body =~ "Run deployments."
    end

    test "preserves extra fields as meta" do
      content = """
      ---
      name: deploy
      description: Deploy to production
      license: MIT
      metadata:
        author: user
        version: "1.0"
      ---
      Body content
      """

      {:ok, metadata, _body} = Parser.parse_frontmatter(content)
      assert metadata.name == "deploy"
      assert metadata.description == "Deploy to production"

      assert metadata.meta == %{
               "license" => "MIT",
               "metadata" => %{"author" => "user", "version" => "1.0"}
             }
    end

    test "minimal frontmatter with only required fields" do
      content = """
      ---
      name: helper
      description: A helper skill
      ---
      Helper body
      """

      {:ok, metadata, body} = Parser.parse_frontmatter(content)
      assert metadata.name == "helper"
      assert metadata.description == "A helper skill"
      assert metadata.meta == %{}
      assert String.trim(body) == "Helper body"
    end

    test "returns error for missing name field" do
      content = """
      ---
      description: A skill
      ---
      Body
      """

      assert {:error, "missing required field: name"} = Parser.parse_frontmatter(content)
    end

    test "returns error for missing description field" do
      content = """
      ---
      name: test
      ---
      Body
      """

      assert {:error, "missing required field: description"} = Parser.parse_frontmatter(content)
    end

    test "returns error for malformed YAML" do
      content = """
      ---
      name: [invalid
      description: broken yaml {{{
      ---
      Body
      """

      assert {:error, "invalid YAML in frontmatter"} = Parser.parse_frontmatter(content)
    end

    test "returns error when no frontmatter found" do
      content = "# No frontmatter here\nJust markdown."

      assert {:error, "no frontmatter found"} = Parser.parse_frontmatter(content)
    end

    test "strips leading whitespace from body after frontmatter" do
      content = "---\nname: test\ndescription: A test\n---\n\n\nBody content"

      {:ok, _metadata, body} = Parser.parse_frontmatter(content)
      assert body == "Body content"
    end

    test "preserves --- separators in body content" do
      content =
        "---\nname: test\ndescription: A test\n---\nFirst section\n\n---\n\nSecond section"

      {:ok, _metadata, body} = Parser.parse_frontmatter(content)
      assert body =~ "First section"
      assert body =~ "---"
      assert body =~ "Second section"
    end

    test "returns error for empty string input" do
      assert {:error, "no frontmatter found"} = Parser.parse_frontmatter("")
    end

    test "coerces integer name to string via to_string" do
      content = "---\nname: 42\ndescription: A numeric name\n---\nBody"

      {:ok, metadata, _body} = Parser.parse_frontmatter(content)
      assert metadata.name == "42"
      assert is_binary(metadata.name)
    end

    test "handles Windows CRLF line endings" do
      content = "---\r\nname: test\r\ndescription: A test\r\n---\r\nBody content"

      {:ok, metadata, body} = Parser.parse_frontmatter(content)
      assert metadata.name == "test"
      assert metadata.description == "A test"
      assert body == "Body content"
    end

    test "handles multi-byte UTF-8 characters in frontmatter" do
      content = "---\nname: test\ndescription: Déploiement à la production 日本語\n---\nBody with émojis 🚀"

      {:ok, metadata, body} = Parser.parse_frontmatter(content)
      assert metadata.name == "test"
      assert metadata.description == "Déploiement à la production 日本語"
      assert body =~ "🚀"
    end

    test "returns error for frontmatter that is not a YAML mapping" do
      content = "---\n- item1\n- item2\n---\nBody"

      assert {:error, "frontmatter must be a YAML mapping"} = Parser.parse_frontmatter(content)
    end

    test "returns error for only opening delimiter" do
      content = "---\nname: test\ndescription: no closing"

      assert {:error, "no frontmatter found"} = Parser.parse_frontmatter(content)
    end

    test "handles --- with trailing whitespace as closing delimiter" do
      content = "---\nname: test\ndescription: A test\n---   \nBody content"

      {:ok, metadata, body} = Parser.parse_frontmatter(content)
      assert metadata.name == "test"
      assert body == "Body content"
    end
  end

  describe "validate_metadata/1" do
    test "accepts valid name and description" do
      metadata = %{name: "deploy-prod", description: "Deploy to production"}
      assert {:ok, ^metadata} = Parser.validate_metadata(metadata)
    end

    test "rejects name exceeding max length" do
      long_name = String.duplicate("a", 65)
      metadata = %{name: long_name, description: "OK"}
      assert {:error, "name must be at most 64 characters"} = Parser.validate_metadata(metadata)
    end

    test "accepts name at exactly max length" do
      name = String.duplicate("a", 64)
      metadata = %{name: name, description: "OK"}
      assert {:ok, _} = Parser.validate_metadata(metadata)
    end

    test "rejects name with invalid characters" do
      metadata = %{name: "Deploy_Prod", description: "OK"}
      assert {:error, "name must match ^[a-z0-9-]+$"} = Parser.validate_metadata(metadata)
    end

    test "rejects name with uppercase" do
      metadata = %{name: "Deploy", description: "OK"}
      assert {:error, "name must match ^[a-z0-9-]+$"} = Parser.validate_metadata(metadata)
    end

    test "rejects name with spaces" do
      metadata = %{name: "my skill", description: "OK"}
      assert {:error, "name must match ^[a-z0-9-]+$"} = Parser.validate_metadata(metadata)
    end

    test "accepts name with numbers and hyphens" do
      metadata = %{name: "deploy-v2-prod", description: "OK"}
      assert {:ok, _} = Parser.validate_metadata(metadata)
    end

    test "rejects description exceeding max length" do
      long_desc = String.duplicate("a", 1025)
      metadata = %{name: "valid", description: long_desc}

      assert {:error, "description must be at most 1024 characters"} =
               Parser.validate_metadata(metadata)
    end

    test "accepts description at exactly max length" do
      desc = String.duplicate("a", 1024)
      metadata = %{name: "valid", description: desc}
      assert {:ok, _} = Parser.validate_metadata(metadata)
    end
  end
end
