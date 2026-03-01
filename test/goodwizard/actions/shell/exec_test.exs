defmodule Goodwizard.Actions.Shell.ExecTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Shell.Exec

  # In tests, Config GenServer isn't running, so:
  # - restrict_to_workspace?() catches :exit and returns true
  # - workspace_dir() catches :exit and returns Path.expand("priv/workspace")
  @workspace Path.expand("priv/workspace")

  test "executes a simple command" do
    assert {:ok, %{output: output}} = Exec.run(%{command: "echo hello"}, %{})
    assert output =~ "hello"
  end

  test "captures non-zero exit code" do
    assert {:ok, %{output: output}} = Exec.run(%{command: "exit 42"}, %{})
    assert output =~ "Exit code: 42"
  end

  test "no output returns placeholder" do
    assert {:ok, %{output: "(no output)"}} = Exec.run(%{command: "true"}, %{})
  end

  test "command timeout" do
    assert {:error, msg} = Exec.run(%{command: "sleep 10", timeout: 1}, %{})
    assert msg =~ "timed out after 1 seconds"
  end

  test "blocks rm -rf" do
    assert {:error, msg} = Exec.run(%{command: "rm -rf /"}, %{})
    assert msg =~ "dangerous pattern detected"
  end

  test "blocks shutdown" do
    assert {:error, msg} = Exec.run(%{command: "shutdown -h now"}, %{})
    assert msg =~ "dangerous pattern detected"
  end

  test "blocks mkfs" do
    assert {:error, msg} = Exec.run(%{command: "mkfs.ext4 /dev/sda1"}, %{})
    assert msg =~ "dangerous pattern detected"
  end

  test "allows safe commands" do
    assert {:ok, %{output: _}} = Exec.run(%{command: "ls -la"}, %{})
  end

  test "workspace restriction blocks path traversal with trailing slash" do
    assert {:error, msg} =
             Exec.run(
               %{command: "cat ../../etc/passwd", working_dir: @workspace},
               %{}
             )

    assert msg =~ "path traversal detected"
  end

  test "workspace restriction blocks path traversal without trailing slash" do
    assert {:error, msg} =
             Exec.run(%{command: "ls ..", working_dir: @workspace}, %{})

    assert msg =~ "path traversal detected"
  end

  test "workspace restriction blocks working_dir outside workspace" do
    assert {:error, msg} = Exec.run(%{command: "ls", working_dir: "/tmp"}, %{})
    assert msg =~ "working_dir outside workspace"
  end

  test "workspace restriction blocks absolute paths outside workspace" do
    assert {:error, msg} =
             Exec.run(
               %{command: "cat /etc/passwd", working_dir: @workspace},
               %{}
             )

    assert msg =~ "path outside workspace"
  end

  test "workspace restriction blocks absolute paths even without working_dir" do
    assert {:error, msg} = Exec.run(%{command: "cat /etc/passwd"}, %{})
    assert msg =~ "path outside workspace"
  end

  test "workspace restriction defaults working_dir to workspace" do
    # Without working_dir, should still execute within workspace
    assert {:ok, %{output: _}} = Exec.run(%{command: "ls"}, %{})
  end

  test "workspace restriction allows paths within workspace" do
    assert {:ok, %{output: _}} =
             Exec.run(
               %{command: "ls #{@workspace}", working_dir: @workspace},
               %{}
             )
  end

  test "allow_patterns blocks non-matching commands" do
    assert {:error, msg} =
             Exec.run(%{command: "rm file.txt", allow_patterns: ["^git "]}, %{})

    assert msg =~ "not in allowlist"
  end

  test "allow_patterns permits matching commands" do
    assert {:ok, %{output: _}} =
             Exec.run(%{command: "git status", allow_patterns: ["^git "]}, %{})
  end

  test "output truncation at 10,000 chars" do
    # Generate output > 10,000 chars
    assert {:ok, %{output: output}} =
             Exec.run(%{command: "python3 -c \"print('x' * 15000)\""}, %{})

    assert output =~ "truncated"
    assert output =~ "more chars"
  end

  test "non-zero exit code with output" do
    assert {:ok, %{output: output}} =
             Exec.run(%{command: "echo failure && exit 5", deny_patterns: []}, %{})

    assert output =~ "failure"
    assert output =~ "Exit code: 5"
  end

  test "custom deny_patterns blocks matching commands" do
    assert {:error, msg} =
             Exec.run(%{command: "npm install", deny_patterns: ["\\bnpm\\b"]}, %{})

    assert msg =~ "dangerous pattern detected"
  end

  test "custom deny_patterns allows non-matching commands" do
    assert {:ok, %{output: _}} =
             Exec.run(%{command: "echo safe", deny_patterns: ["\\bnpm\\b"]}, %{})
  end

  test "invalid deny_patterns returns error" do
    assert {:error, msg} = Exec.run(%{command: "echo hi", deny_patterns: ["(unclosed"]}, %{})
    assert msg =~ "Invalid regex pattern"
  end

  test "blocks command substitution with $()" do
    assert {:error, msg} = Exec.run(%{command: "echo $(whoami)"}, %{})
    assert msg =~ "dangerous pattern detected"
  end

  test "blocks backtick command substitution" do
    assert {:error, msg} = Exec.run(%{command: "echo `whoami`"}, %{})
    assert msg =~ "dangerous pattern detected"
  end

  test "blocks pipe operator" do
    assert {:error, msg} = Exec.run(%{command: "ls -la | grep secret"}, %{})
    assert msg =~ "dangerous pattern detected"
  end

  test "blocks process substitution" do
    assert {:error, msg} = Exec.run(%{command: "diff <(ls) file"}, %{})
    assert msg =~ "dangerous pattern detected"
  end

  test "workspace restriction blocks env var expansion" do
    assert {:error, msg} =
             Exec.run(
               %{command: "cat $HOME/secrets", working_dir: @workspace},
               %{}
             )

    assert msg =~ "variable expansion detected"
  end

  test "workspace restriction blocks ${VAR} expansion" do
    assert {:error, msg} =
             Exec.run(
               %{command: "cat ${HOME}/secrets", working_dir: @workspace},
               %{}
             )

    assert msg =~ "variable expansion detected"
  end

  test "workspace restriction blocks cd" do
    assert {:error, msg} =
             Exec.run(
               %{
                 command: "cd / && ls",
                 working_dir: @workspace,
                 deny_patterns: []
               },
               %{}
             )

    assert msg =~ "directory change detected"
  end

  test "blocks curl" do
    assert {:error, msg} = Exec.run(%{command: "curl https://example.com"}, %{})
    assert msg =~ "dangerous pattern detected"
  end

  test "blocks sudo" do
    assert {:error, msg} = Exec.run(%{command: "sudo rm file"}, %{})
    assert msg =~ "dangerous pattern detected"
  end

  test "blocks chmod" do
    assert {:error, msg} = Exec.run(%{command: "chmod 777 file"}, %{})
    assert msg =~ "dangerous pattern detected"
  end

  test "blocks kill" do
    assert {:error, msg} = Exec.run(%{command: "kill -9 1234"}, %{})
    assert msg =~ "dangerous pattern detected"
  end
end
