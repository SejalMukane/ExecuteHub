require "openssl"

class GithubWebhookSignature
  def self.valid?(secret, body, signature_header)
    return false if secret.blank? || signature_header.blank?

    expected = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret, body.to_s)}"
    Rack::Utils.secure_compare(expected, signature_header.to_s.strip)
  end
end
