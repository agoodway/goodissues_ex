defmodule FF.Monitoring.AlertRuleEvaluator do
  @moduledoc """
  Evaluates heartbeat alert rules against ping payloads.

  Rules use ANY-match semantics: if any single rule fires, the overall
  result is `:fail`. All rules must pass for a `:pass` result. Missing
  fields, unsupported types, and type mismatches cause the rule to be
  skipped (not treated as a failure).

  ## Supported operators

  `eq`, `neq`, `gt`, `gte`, `lt`, `lte` — applied to JSON scalars
  (strings, numbers, booleans, null).
  """

  @doc """
  Evaluates a list of alert rules against a payload map.

  Returns `:pass` if no rules fire, `:fail` if any rule matches.

  `duration_ms` is injected into the payload before evaluation if
  provided, overriding any client-supplied value.
  """
  def evaluate([], _payload), do: :pass

  def evaluate(rules, payload) when is_list(rules) do
    if Enum.any?(rules, &rule_matches?(&1, payload)) do
      :fail
    else
      :pass
    end
  end

  def evaluate(_rules, _payload), do: :pass

  @doc """
  Merges server-computed `duration_ms` into the payload map, overriding
  any client-supplied value. Returns the original payload if duration is nil.
  """
  def inject_duration(payload, nil), do: payload || %{}
  def inject_duration(nil, duration_ms), do: %{"duration_ms" => duration_ms}
  def inject_duration(payload, duration_ms), do: Map.put(payload, "duration_ms", duration_ms)

  defp rule_matches?(%{"field" => field, "op" => op, "value" => expected}, payload)
       when is_map(payload) do
    case Map.fetch(payload, field) do
      {:ok, actual} -> compare(op, actual, expected)
      :error -> false
    end
  end

  defp rule_matches?(_, _), do: false

  defp compare("eq", actual, expected), do: actual == expected
  defp compare("neq", actual, expected), do: actual != expected

  defp compare("gt", actual, expected) when is_number(actual) and is_number(expected),
    do: actual > expected

  defp compare("gte", actual, expected) when is_number(actual) and is_number(expected),
    do: actual >= expected

  defp compare("lt", actual, expected) when is_number(actual) and is_number(expected),
    do: actual < expected

  defp compare("lte", actual, expected) when is_number(actual) and is_number(expected),
    do: actual <= expected

  # Type mismatch or unsupported comparison — skip the rule
  defp compare(_, _, _), do: false
end
