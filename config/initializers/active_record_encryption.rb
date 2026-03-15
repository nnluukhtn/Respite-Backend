default_primary_key = "2574b3d9b0b1e7d30c80d68ff572ef95f1e459e2ee5077670caeed8099eb7ac2"
default_deterministic_key = "9aa00dd1b850dd2bf8e3da7d6f3de0486a5d88f56ea21557c1e5812db4bf4ed1"
default_key_derivation_salt = "f344dd76165d722ec8bf597fef42175f"

Rails.application.configure do
  config.active_record.encryption.primary_key = ENV.fetch(
    "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY",
    default_primary_key
  )
  config.active_record.encryption.deterministic_key = ENV.fetch(
    "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY",
    default_deterministic_key
  )
  config.active_record.encryption.key_derivation_salt = ENV.fetch(
    "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT",
    default_key_derivation_salt
  )
end
