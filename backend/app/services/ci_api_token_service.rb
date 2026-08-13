require "digest"

# CiApiTokenService owns every CiApiToken concern: generating raw tokens,
# hashing them for storage, resolving a token back to its project, and
# rotating/revoking tokens. Tokens:
#
#   - are hashed (SHA-256) in the database
#   - support rotation (old token revoked, new one issued)
#   - support revocation (disabled immediately)
#   - are never shown after creation (only returned by create!/rotate!)
#   - never appear in logs (the plaintext is only held in a local variable)
class CiApiTokenService
  TOKEN_PREFIX = "eh"

  class << self
    # Creates an active token and returns [record, plaintext]. The plaintext
    # MUST be shown to the user immediately — it can never be recovered again.
    def create!(project:, name: "CI Token")
      plaintext = generate_token
      record = project.ci_api_tokens.create!(
        name: name,
        token_prefix: prefix_for(plaintext),
        token_digest: digest(plaintext)
      )
      [record, plaintext]
    end

    # Resolves a raw token to its project (nil when missing/revoked/unknown).
    def authenticate(token_string)
      return nil if token_string.blank?

      record = CiApiToken.active.find_by(token_digest: digest(token_string))
      return nil unless record

      record.touch_used!
      record
    end

    # Revokes the current token and issues a fresh one in its place.
    def rotate!(record)
      revoke!(record)
      create!(project: record.project, name: record.name)
    end

    def revoke!(record)
      record.update!(revoked_at: Time.current)
    end

    def digest(value)
      Digest::SHA256.hexdigest(value.to_s)
    end

    def generate_token
      "#{TOKEN_PREFIX}_#{SecureRandom.hex(24)}"
    end

    # Display-only prefix: the first 11 chars of the raw token (eh_ + 8 hex).
    def prefix_for(plaintext)
      plaintext.to_s[0, 11]
    end
  end
end