class CreateVendorWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :vendor_webhook_events do |t|
      t.string :vendor, null: false
      t.string :external_event_id, null: false
      t.string :event_type
      t.string :signature
      t.string :processing_status, null: false, default: "received"
      t.datetime :received_at, null: false
      t.datetime :processed_at
      t.text :last_error
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end

    add_index :vendor_webhook_events, %i[vendor external_event_id], unique: true
    add_index :vendor_webhook_events, :event_type
    add_index :vendor_webhook_events, :processing_status
  end
end
