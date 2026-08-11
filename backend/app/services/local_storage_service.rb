# LocalStorageService is the development fallback used when AWS is NOT
# configured (Part 24). It mirrors S3StorageService's interface but stores
# files under storage/remote/... on the local filesystem so the whole platform
# keeps working without AWS credentials.
#
# Signed URLs are not meaningful for local files: the Rails API streams them
# through the authenticated /artifacts/:id/file endpoint instead, so
# signed_url returns nil and the frontend falls back to that endpoint.
class LocalStorageService
  ROOT = Rails.root.join("storage", "remote")

  class << self
    def upload(path, key, content_type: nil)
      new.upload(path, key, content_type: content_type)
    end

    def download(key, local_path)
      new.download(key, local_path)
    end

    def signed_url(key, expires_in: 900)
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
    destination = resolve(key)
    FileUtils.mkdir_p(destination.dirname)
    FileUtils.cp(path, destination)
    true
  end

  def download(key, local_path)
    source = resolve(key)
    FileUtils.mkdir_p(File.dirname(local_path))
    FileUtils.cp(source, local_path)
    local_path
  end

  def signed_url(key, expires_in: 900)
    nil
  end

  def delete(key)
    FileUtils.rm_f(resolve(key))
    true
  end

  def exists?(key)
    File.exist?(resolve(key))
  end

  private

  def resolve(key)
    ROOT.join(key)
  end
end
