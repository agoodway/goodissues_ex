defmodule GI.VaultTest do
  use ExUnit.Case, async: true

  describe "encrypt/decrypt" do
    test "round-trips a binary value" do
      plaintext = "secret-bot-token-123"
      {:ok, ciphertext} = GI.Vault.encrypt(plaintext)
      assert ciphertext != plaintext
      {:ok, decrypted} = GI.Vault.decrypt(ciphertext)
      assert decrypted == plaintext
    end

    test "produces different ciphertext for same plaintext (nonce varies)" do
      plaintext = "same-value"
      {:ok, ct1} = GI.Vault.encrypt(plaintext)
      {:ok, ct2} = GI.Vault.encrypt(plaintext)
      assert ct1 != ct2
    end
  end
end
