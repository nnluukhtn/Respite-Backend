# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :claim_token, :license_key, :license_key_ciphertext,
  :device_fingerprint, :signature, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc
]
