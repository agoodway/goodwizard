defmodule Goodwizard.Actions.Skills.LoadSkillResourceTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Skills.LoadSkillResource

  defp tmp_skill_dir do
    dir = Path.join(System.tmp_dir!(), "skill_resource_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    dir
  end

  describe "run/2" do
    test "reads valid resource file" do
      dir = tmp_skill_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      File.write!(Path.join(dir, "deploy.sh"), "#!/bin/bash\necho deploy")

      skills = [
        %{name: "deploy", dir: dir, content: "body", resources: ["deploy.sh"]}
      ]

      context = %{state: %{prompt_skills: %{skills: skills}}}
      params = %{skill_name: "deploy", resource: "deploy.sh"}

      assert {:ok, %{content: content, filename: "deploy.sh"}} =
               LoadSkillResource.run(params, context)

      assert content == "#!/bin/bash\necho deploy"
    end

    test "rejects resource not in indexed list" do
      dir = tmp_skill_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      skills = [
        %{name: "deploy", dir: dir, content: "body", resources: ["deploy.sh"]}
      ]

      context = %{state: %{prompt_skills: %{skills: skills}}}
      params = %{skill_name: "deploy", resource: "secret.env"}

      assert {:error, "resource not found: secret.env"} =
               LoadSkillResource.run(params, context)
    end

    test "returns error for unknown skill name" do
      context = %{state: %{prompt_skills: %{skills: []}}}
      params = %{skill_name: "nonexistent", resource: "file.txt"}

      assert {:error, "skill not found: nonexistent"} =
               LoadSkillResource.run(params, context)
    end

    test "prevents path traversal via indexed resource list" do
      dir = tmp_skill_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      skills = [
        %{name: "deploy", dir: dir, content: "body", resources: ["deploy.sh"]}
      ]

      context = %{state: %{prompt_skills: %{skills: skills}}}
      params = %{skill_name: "deploy", resource: "../../etc/passwd"}

      assert {:error, "resource not found: ../../etc/passwd"} =
               LoadSkillResource.run(params, context)
    end

    test "returns error when prompt_skills not in state" do
      context = %{state: %{}}
      params = %{skill_name: "test", resource: "file.txt"}

      assert {:error, "skill not found: test"} =
               LoadSkillResource.run(params, context)
    end

    test "rejects symlink pointing outside skill directory" do
      dir = tmp_skill_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      # Create an external file and a symlink to it
      external_dir = Path.join(System.tmp_dir!(), "external_#{System.unique_integer([:positive])}")
      File.mkdir_p!(external_dir)
      external_file = Path.join(external_dir, "secret.txt")
      File.write!(external_file, "secret data")
      on_exit(fn -> File.rm_rf!(external_dir) end)

      symlink_path = Path.join(dir, "escape.txt")
      File.ln_s!(external_file, symlink_path)

      skills = [
        %{name: "deploy", dir: dir, content: "body", resources: ["escape.txt"]}
      ]

      context = %{state: %{prompt_skills: %{skills: skills}}}
      params = %{skill_name: "deploy", resource: "escape.txt"}

      assert {:error, "resource path escapes skill directory"} =
               LoadSkillResource.run(params, context)
    end

    test "rejects resource file exceeding size limit" do
      dir = tmp_skill_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      # Create a large file (just over the 1MB limit)
      large_path = Path.join(dir, "big.bin")
      File.write!(large_path, :binary.copy(<<0>>, 1_024 * 1_024 + 1))

      skills = [
        %{name: "deploy", dir: dir, content: "body", resources: ["big.bin"]}
      ]

      context = %{state: %{prompt_skills: %{skills: skills}}}
      params = %{skill_name: "deploy", resource: "big.bin"}

      assert {:error, "resource file too large:" <> _} =
               LoadSkillResource.run(params, context)
    end

    test "returns error when resource file does not exist on disk" do
      dir = tmp_skill_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      # File is in the resources list but doesn't exist on disk
      skills = [
        %{name: "deploy", dir: dir, content: "body", resources: ["missing.txt"]}
      ]

      context = %{state: %{prompt_skills: %{skills: skills}}}
      params = %{skill_name: "deploy", resource: "missing.txt"}

      assert {:error, "failed to read resource:" <> _} =
               LoadSkillResource.run(params, context)
    end
  end
end
