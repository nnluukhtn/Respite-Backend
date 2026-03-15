class ClaimTokenIssuer
  def self.call(license: nil, checkout_session: nil, expires_in: 30.minutes, metadata: {})
    claim_token, raw_token = ClaimToken.issue!(
      license:,
      checkout_session:,
      expires_in:,
      metadata:
    )

    {
      record: claim_token,
      token: raw_token,
      claim_url: claim_url_for(raw_token)
    }
  end

  def self.claim_url_for(raw_token)
    base_url = ENV.fetch("CLAIM_LINK_BASE_URL", "respite://claim")
    separator = base_url.include?("?") ? "&" : "?"
    "#{base_url}#{separator}token=#{CGI.escape(raw_token)}"
  end
end
