defmodule GI.Monitoring.AlertRuleEvaluatorTest do
  use ExUnit.Case, async: true

  alias GI.Monitoring.AlertRuleEvaluator

  describe "evaluate/2" do
    test "returns :pass with empty rules" do
      assert AlertRuleEvaluator.evaluate([], %{}) == :pass
    end

    test "returns :pass when no rules match" do
      rules = [%{"field" => "rows", "op" => "lt", "value" => 100}]
      assert AlertRuleEvaluator.evaluate(rules, %{"rows" => 500}) == :pass
    end

    test "returns :fail when a rule matches" do
      rules = [%{"field" => "rows", "op" => "lt", "value" => 100}]
      assert AlertRuleEvaluator.evaluate(rules, %{"rows" => 50}) == :fail
    end

    test "ANY-match: one failing rule out of many" do
      rules = [
        %{"field" => "rows", "op" => "lt", "value" => 100},
        %{"field" => "errors", "op" => "gt", "value" => 0}
      ]

      assert AlertRuleEvaluator.evaluate(rules, %{"rows" => 500, "errors" => 3}) == :fail
    end

    test "skips rule on missing field" do
      rules = [%{"field" => "missing", "op" => "gt", "value" => 0}]
      assert AlertRuleEvaluator.evaluate(rules, %{"other" => 1}) == :pass
    end

    test "skips rule on type mismatch" do
      rules = [%{"field" => "count", "op" => "gt", "value" => 100}]
      assert AlertRuleEvaluator.evaluate(rules, %{"count" => "not_a_number"}) == :pass
    end

    test "eq operator" do
      rules = [%{"field" => "status", "op" => "eq", "value" => "error"}]
      assert AlertRuleEvaluator.evaluate(rules, %{"status" => "error"}) == :fail
      assert AlertRuleEvaluator.evaluate(rules, %{"status" => "ok"}) == :pass
    end

    test "neq operator" do
      rules = [%{"field" => "status", "op" => "neq", "value" => "ok"}]
      assert AlertRuleEvaluator.evaluate(rules, %{"status" => "error"}) == :fail
      assert AlertRuleEvaluator.evaluate(rules, %{"status" => "ok"}) == :pass
    end

    test "gte and lte operators" do
      rules = [%{"field" => "count", "op" => "gte", "value" => 10}]
      assert AlertRuleEvaluator.evaluate(rules, %{"count" => 10}) == :fail
      assert AlertRuleEvaluator.evaluate(rules, %{"count" => 9}) == :pass

      rules = [%{"field" => "count", "op" => "lte", "value" => 10}]
      assert AlertRuleEvaluator.evaluate(rules, %{"count" => 10}) == :fail
      assert AlertRuleEvaluator.evaluate(rules, %{"count" => 11}) == :pass
    end

    test "boolean comparison with eq" do
      rules = [%{"field" => "success", "op" => "eq", "value" => false}]
      assert AlertRuleEvaluator.evaluate(rules, %{"success" => false}) == :fail
      assert AlertRuleEvaluator.evaluate(rules, %{"success" => true}) == :pass
    end

    test "null comparison with eq" do
      rules = [%{"field" => "result", "op" => "eq", "value" => nil}]
      assert AlertRuleEvaluator.evaluate(rules, %{"result" => nil}) == :fail
      assert AlertRuleEvaluator.evaluate(rules, %{"result" => "ok"}) == :pass
    end

    test "returns :pass with nil rules" do
      assert AlertRuleEvaluator.evaluate(nil, %{}) == :pass
    end

    test "returns :pass with nil payload" do
      rules = [%{"field" => "x", "op" => "gt", "value" => 0}]
      assert AlertRuleEvaluator.evaluate(rules, nil) == :pass
    end
  end

  describe "inject_duration/2" do
    test "injects duration_ms into payload" do
      result = AlertRuleEvaluator.inject_duration(%{"foo" => 1}, 5000)
      assert result["duration_ms"] == 5000
      assert result["foo"] == 1
    end

    test "overrides client-supplied duration_ms" do
      result = AlertRuleEvaluator.inject_duration(%{"duration_ms" => 1}, 5000)
      assert result["duration_ms"] == 5000
    end

    test "returns empty map when nil duration and nil payload" do
      assert AlertRuleEvaluator.inject_duration(nil, nil) == %{}
    end

    test "returns payload unchanged when nil duration" do
      payload = %{"foo" => 1}
      assert AlertRuleEvaluator.inject_duration(payload, nil) == payload
    end

    test "creates payload map when payload nil but duration present" do
      result = AlertRuleEvaluator.inject_duration(nil, 5000)
      assert result == %{"duration_ms" => 5000}
    end
  end
end
