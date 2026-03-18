class CreateClaimTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :claim_tokens do |t|
      t.uuid :public_id, null: false, default: -> { "gen_random_uuid()" }
      t.references :license, foreign_key: true
      t.references :checkout_session, foreign_key: true
      t.string :purpose, null: false, default: "desktop_return"
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :claim_tokens, :public_id, unique: true
    add_index :claim_tokens, :token_digest, unique: true
  end
end
