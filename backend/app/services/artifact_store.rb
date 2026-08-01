# ArtifactStore centralizes where execution artifacts live on the local
# filesystem so both workers (writing) and controllers (serving) agree on the
# layout:
#
#   storage/artifacts/job_XX/artifacts/...   (copied out of the container)
#
# The path stored on an Artifact is relative to ArtifactStore.root; resolve()
# maps it back to an absolute path for the artifact file endpoint.
class ArtifactStore
  ROOT = Rails.root.join("storage", "artifacts")

  class << self
    def root
      ROOT
    end

    # Per-job folder: storage/artifacts/job_XX/
    def job_dir(job)
      root.join(format("job_%02d", job.id))
    end

    # Creates the per-job folder so artifacts can be copied into it.
    def prepare(job)
      dir = job_dir(job)
      FileUtils.mkdir_p(dir)
      dir
    end

    # Converts an absolute path into a storage-relative path for the DB.
    def relative(path)
      Pathname.new(path).relative_path_from(root).to_s
    end

    # Converts a stored storage-relative path back to an absolute path.
    def resolve(path)
      root.join(path)
    end
  end
end
