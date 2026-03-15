class CreateDeviceActivations < ActiveRecord::Migration[8.1]
  def change
    create_table :device_activations do |t|
      t.uuid :public_id, null: false, default: -> { "gen_random_uuid()" }
      t.references :license, null: false, foreign_key: true
      t.string :device_fingerprint, null: false
      t.string :device_name, null: false
      t.string :creem_activation_id
      t.datetime :activated_at, null: false
      t.datetime :deactivated_at
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :device_activations, :public_id, unique: true
    add_index :device_activations, :creem_activation_id
    add_index :device_activations, %i[license_id device_fingerprint],
      unique: true,
      where: "deactivated_at IS NULL",
      name: "index_active_device_activations_on_license_and_fingerprint"
  end
end
