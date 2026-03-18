class CreateDeviceActivations < ActiveRecord::Migration[8.1]
  def change
    create_table :device_activations do |t|
      t.uuid :public_id, null: false, default: -> { "gen_random_uuid()" }
      t.references :license, null: false, foreign_key: true
      t.string :instance_name, null: false
      t.string :creem_instance_id
      t.string :instance_status
      t.datetime :activated_at, null: false
      t.datetime :deactivated_at
      t.datetime :last_validated_at
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :device_activations, :public_id, unique: true
    add_index :device_activations, :creem_instance_id
    add_index :device_activations, %i[license_id creem_instance_id],
      unique: true,
      where: "deactivated_at IS NULL AND creem_instance_id IS NOT NULL",
      name: "index_active_device_activations_on_license_and_instance"
  end
end
