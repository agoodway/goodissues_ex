defmodule GI.Notifications.WebhookSigner do
  @moduledoc """
  Standard Webhooks compatible HMAC-SHA256 signing.
  """

  @secret_prefix "whsec_"

  @spec generate_secret() :: String.t()
  def generate_secret do
    @secret_prefix <> (24 |> :crypto.strong_rand_bytes() |> Base.encode64(padding: false))
  end

  @spec sign(String.t(), String.t(), String.t() | integer(), String.t()) :: String.t()
  def sign(secret, msg_id, timestamp, body) do
    key = decode_secret!(secret)
    payload = "#{msg_id}.#{timestamp}.#{body}"

    digest =
      :crypto.mac(:hmac, :sha256, key, payload)
      |> Base.encode64(padding: false)

    "v1," <> digest
  end

  @spec secure_compare(String.t(), String.t()) :: boolean()
  def secure_compare(left, right)
      when is_binary(left) and is_binary(right) and byte_size(left) == byte_size(right) do
    Plug.Crypto.secure_compare(left, right)
  end

  def secure_compare(_, _), do: false

  defp decode_secret!(<<@secret_prefix, encoded::binary>>) do
    Base.decode64!(encoded, padding: false)
  end

  defp decode_secret!(secret) do
    raise ArgumentError, "invalid webhook secret: #{inspect(secret)}"
  end
end
