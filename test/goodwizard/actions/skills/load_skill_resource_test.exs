defmodule Goodwizard.Actions.Skills.LoadSkillResourceTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Skills.LoadSkillResource

  defp tmp_skill_dir do
    dir = Path.join(System.tmp_dir!(), "skill_resource_test_#{:rand.uniform(100_000)}")
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
  end
end
