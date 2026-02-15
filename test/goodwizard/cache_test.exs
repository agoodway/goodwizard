defmodule Goodwizard.CacheTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Cache

  describe "basic operations" do
    test "put and get a value" do
      assert :ok = Cache.put("key1", "value1")
      assert "value1" == Cache.get("key1")
    end

    test "missing key returns nil" do
      assert nil == Cache.get("nonexistent")
    end

    test "delete removes a key" do
      Cache.put("key2", "value2")
      assert "value2" == Cache.get("key2")

      assert :ok = Cache.delete("key2")
      assert nil == Cache.get("key2")
    end

    test "has_key? returns true for existing key" do
      Cache.put("key3", "value3")
      assert Cache.has_key?("key3")
    end

    test "has_key? returns false for missing key" do
      refute Cache.has_key?("missing_key")
    end

    test "TTL expiry removes entry" do
      Cache.put("ttl_key", "ttl_value", ttl: :timer.seconds(1))
      assert "ttl_value" == Cache.get("ttl_key")

      Process.sleep(1_100)
      assert nil == Cache.get("ttl_key")
    end
  end
end
