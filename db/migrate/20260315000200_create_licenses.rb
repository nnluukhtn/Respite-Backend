class CreateLicenses < ActiveRecord::Migration[8.1]
  def change
    create_table :licenses do |t|
      t.uuid :public_id, null: false, default: -> { "gen_random_uuid()" }
      t.string :creem_product_id
      t.string :creem_variant_id
      t.string :creem_customer_id
      t.string :creem_order_id
      t.string :creem_license_id
      t.text :license_key_ciphertext
      t.string :license_key_digest
      t.string :license_key_last4
      t.string :license_type, null: false
      t.integer :max_activations
      t.integer :current_activations_count, null: false, default: 0
      t.string :status, null: false, default: "pending"
      t.string :customer_email
      t.datetime :expires_at
      t.datetime :revoked_at
      t.datetime :refunded_at
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :licenses, :public_id, unique: true
    add_index :licenses, :creem_order_id
    add_index :licenses, :creem_product_id
    add_index :licenses, :creem_customer_id
    add_index :licenses, :creem_license_id, unique: true
    add_index :licenses, :license_key_digest, unique: true, where: "license_key_digest IS NOT NULL"
    add_index :licenses, :customer_email
  end
end
