defmodule GI.Repo.Migrations.AddTelegramToEventSubscriptionsChannel do
  use Ecto.Migration

  def up do
    drop constraint(:event_subscriptions, :event_subscriptions_channel_check)

    create constraint(:event_subscriptions, :event_subscriptions_channel_check,
             check: "channel IN ('email', 'webhook', 'telegram')"
           )
  end

  def down do
    drop constraint(:event_subscriptions, :event_subscriptions_channel_check)

    create constraint(:event_subscriptions, :event_subscriptions_channel_check,
             check: "channel IN ('email', 'webhook')"
           )
  end
end
