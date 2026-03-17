class ClaimMailer < ApplicationMailer
  default from: ENV.fetch("CLAIM_MAIL_FROM", "support@example.com")

  def claim_link(email:, claim_url:, license:)
    @claim_url = claim_url
    @license = license
    mail(to: email, subject: "Your Respite license claim link")
  end
end
