defmodule Goodwizard.ErrorFormatterTest do
  use ExUnit.Case, async: true

  alias Goodwizard.ErrorFormatter
  alias ReqLLM.Error.API

  describe "ReqLLM.Error.API.Request" do
    test "usage limit with date" do
      error =
        API.Request.exception(
          reason:
            "Your organization has exceeded its usage limits. You can regain access on 2026-03-01 at 00:00 UTC.",
          status: 400
        )

      assert ErrorFormatter.format(error) ==
               "I've hit my API usage limit. Access resets on 2026-03-01 at 00:00 UTC.."
    end

    test "usage limit without date" do
      error =
        API.Request.exception(
          reason: "Your organization has exceeded its usage limits.",
          status: 429
        )

      assert ErrorFormatter.format(error) ==
               "I've hit my API usage limit. Please try again later."
    end

    test "rate limit" do
      error =
        API.Request.exception(
          reason: "Rate Limited - Too many requests",
          status: 429
        )

      assert ErrorFormatter.format(error) ==
               "I'm being rate-limited by my AI provider. Please wait a moment and try again."
    end

    test "generic 400 error" do
      error =
        API.Request.exception(
          reason: "Bad Request - Invalid parameters",
          status: 400
        )

      assert ErrorFormatter.format(error) ==
               "Request rejected by AI provider: Bad Request - Invalid parameters"
    end

    test "401 unauthorized" do
      error = API.Request.exception(reason: "Unauthorized", status: 401)

      assert ErrorFormatter.format(error) ==
               "I'm having trouble authenticating with my AI provider. Please check the API key configuration."
    end

    test "403 forbidden" do
      error = API.Request.exception(reason: "Forbidden", status: 403)

      assert ErrorFormatter.format(error) ==
               "I'm having trouble authenticating with my AI provider. Please check the API key configuration."
    end

    test "500 server error" do
      error = API.Request.exception(reason: "Internal Server Error", status: 500)

      assert ErrorFormatter.format(error) ==
               "My AI provider is experiencing issues (HTTP 500). Please try again shortly."
    end

    test "503 server error" do
      error = API.Request.exception(reason: "Service Unavailable", status: 503)

      assert ErrorFormatter.format(error) ==
               "My AI provider is experiencing issues (HTTP 503). Please try again shortly."
    end

    test "generic API error with reason" do
      error = API.Request.exception(reason: "Something went wrong", status: nil)

      assert ErrorFormatter.format(error) == "AI provider error: Something went wrong"
    end
  end

  describe "ReqLLM.Error.API.Response" do
    test "formats response error" do
      error = API.Response.exception(reason: "Unexpected format")

      assert ErrorFormatter.format(error) ==
               "I received an unexpected response from my AI provider. Please try again."
    end
  end

  describe "ReqLLM.Error.API.JSONDecode" do
    test "formats JSON decode error" do
      error = API.JSONDecode.exception(message: "unexpected token")

      assert ErrorFormatter.format(error) ==
               "I received a malformed response from my AI provider. Please try again."
    end
  end

  describe "ReqLLM.Error.API.Stream" do
    test "formats stream error" do
      error = API.Stream.exception(reason: "connection reset")
      assert ErrorFormatter.format(error) == "Streaming error: connection reset"
    end
  end

  describe "Jido executor error maps" do
    test "execution_error with string" do
      assert ErrorFormatter.format(%{error: "something failed", type: :execution_error}) ==
               "something failed"
    end

    test "exception error with usage limit string" do
      assert ErrorFormatter.format(%{
               error: "Your organization has exceeded its usage limits.",
               type: :exception
             }) == "I've hit my API usage limit. Please try again later."
    end
  end

  describe "simple types" do
    test ":timeout atom" do
      assert ErrorFormatter.format(:timeout) == "The request timed out. Please try again."
    end

    test "string passthrough" do
      assert ErrorFormatter.format("Something broke") == "Something broke"
    end

    test "string with usage limit" do
      assert ErrorFormatter.format("exceeded usage limit") ==
               "I've hit my API usage limit. Please try again later."
    end

    test "string with rate limit" do
      assert ErrorFormatter.format("hit the rate limit") ==
               "I'm being rate-limited by my AI provider. Please wait a moment and try again."
    end

    test "string with timed out" do
      assert ErrorFormatter.format("request timed out") ==
               "The request timed out. Please try again."
    end

    test "other atom" do
      assert ErrorFormatter.format(:connection_refused) == "Connection refused"
    end

    test "generic exception" do
      assert ErrorFormatter.format(%RuntimeError{message: "boom"}) == "boom"
    end

    test "unknown term" do
      assert ErrorFormatter.format({:weird, :thing}) ==
               "An unexpected error occurred. Please try again."
    end
  end
end
