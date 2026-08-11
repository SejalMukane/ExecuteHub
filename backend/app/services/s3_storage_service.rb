# S3StorageService is the ONLY class that knows how to talk to AWS S3. It
# hides the AWS SDK behind a small, stable interface used by the rest of the
# application (ArtifactUploader, ArtifactCleanupJob, controllers):
#
#   upload(path, key, content_type:)   store a local file under a key
#   download(key, local_path)          fetch a key into a local file
#   signed_url(key, expires_in:)       temporary presigned GET URL (no creds leak)
#   delete(key)                        remove an object
#   exists?(key)                       object presence check
#
# Credentials are NEVER hardcoded — the SDK picks AWS_ACCESS_KEY_ID,
# AWS_SECRET_ACCESS_KEY and AWS_REGION up from the environment via its default
# credential chain. The bucket comes from AWS_S3_BUCKET.
#
# Every SDK failure is wrapped in S3StorageService::S3Error so callers can
# rescue one type instead of knowing every Aws::S3 error class.
class S3StorageService
  # Raised for any AWS S3 operation failure (credentials, missing bucket,
  # network, timeouts). The original message is preserved for retry logic.
  class S3Error < StandardError; end

  DEFAULT_EXPIRES_IN = 900 # seconds (15 minutes)

  class << self
    def upload(path, key, content_type: nil)
      new.upload(path, key, content_type: content_type)
    end

    def download(key, local_path)
      new.download(key, local_path)
    end

    def signed_url(key, expires_in: DEFAULT_EXPIRES_IN)
      new.signed_url(key, expires_in: expires_in)
    end

    def delete(key)
      new.delete(key)
    end

    def exists?(key)
      new.exists?(key)
    end
  end

  def upload(path, key, content_type: nil)
    client.put_object(
      bucket: bucket,
      key: key,
      body: File.open(path, "rb"),
      content_type: content_type
    )
    true
  rescue StandardError => e
    raise wrap(e, "Upload failed for #{key}")
  end

  def download(key, local_path)
    response = client.get_object(bucket: bucket, key: key)
    FileUtils.mkdir_p(File.dirname(local_path))
    File.open(local_path, "wb") do |file|
      response.body.each { |chunk| file.write(chunk) }
    end
    local_path
  rescue StandardError => e
    raise wrap(e, "Download failed for #{key}")
  end

  # Presigned GET URL valid for `expires_in` seconds. The frontend can stream
  # from S3 directly (videos, images) without ever seeing credentials.
  def signed_url(key, expires_in: DEFAULT_EXPIRES_IN)
    presigner.presigned_url(:get_object, bucket: bucket, key: key, expires_in: expires_in)
  rescue StandardError => e
    raise wrap(e, "Signed URL generation failed for #{key}")
  end

  def delete(key)
    client.delete_object(bucket: bucket, key: key)
    true
  rescue StandardError => e
    raise wrap(e, "Delete failed for #{key}")
  end

  def exists?(key)
    client.head_object(bucket: bucket, key: key)
    true
  rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
    false
  rescue StandardError => e
    raise wrap(e, "Existence check failed for #{key}")
  end

  private

  # The client is memoized (thread-safe after first build) and reads credentials
  # from the environment. The bucket is validated eagerly so a missing bucket
  # fails fast with a clear message instead of a confusing SDK error.
  def client
    @client ||= Aws::S3::Client.new(region: region)
  end

  def bucket
    @bucket ||= ENV.fetch("AWS_S3_BUCKET") do
      raise S3Error, "AWS_S3_BUCKET is not configured"
    end
  end

  def presigner
    @presigner ||= Aws::S3::Presigner.new(client: client)
  end

  def region
    ENV.fetch("AWS_REGION", "us-east-1")
  end

  def wrap(error, message)
    S3Error.new("#{message}: #{error.message}")
  end
end
