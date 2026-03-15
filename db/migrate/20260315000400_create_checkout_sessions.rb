class CreateCheckoutSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :checkout_sessions do |t|
      t.uuid :public_id, null: false, default: -> { "gen_random_uuid()" }
      t.references :license, foreign_key: true
      t.string :variant_key, null: false
      t.string :status, null: false, default: "pending"
      t.string :creem_checkout_id
      t.string :creem_request_id
      t.string :creem_product_id
      t.text :hosted_checkout_url
      t.string :customer_email
      t.datetime :claimable_at
      t.datetime :claimed_at
      t.datetime :expires_at
      t.text :last_error
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :checkout_sessions, :public_id, unique: true
    add_index :checkout_sessions, :creem_checkout_id, unique: true, where: "creem_checkout_id IS NOT NULL"
    add_index :checkout_sessions, :creem_request_id, unique: true, where: "creem_request_id IS NOT NULL"
    add_index :checkout_sessions, :variant_key
  end
end
