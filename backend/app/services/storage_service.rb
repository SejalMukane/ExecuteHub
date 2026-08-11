# StorageService is the tiny factory that decides which storage backend the
# application uses. AWS S3 is used when credentials + a bucket are configured;
# otherwise artifacts live on the local filesystem (development mode, tests).
#
# Everything else in the application talks to `StorageService.adapter` and
# never needs to know which backend is active.
class StorageService
  class << self
    # Returns the active backend: S3StorageService or LocalStorageService.
    def adapter
      s3_configured? ? S3StorageService : LocalStorageService
    end

    # "s3" or "local" — surfaced in API responses so the frontend knows whether
    # to use signed URLs or the authenticated file endpoint.
    def storage_backend
      s3_configured? ? "s3" : "local"
    end

    def s3_configured?
      ENV["AWS_ACCESS_KEY_ID"].present? &&
        ENV["AWS_SECRET_ACCESS_KEY"].present? &&
        ENV["AWS_S3_BUCKET"].present?
    end
  end
end
