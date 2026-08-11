module Api
  module V1
    # ArtifactsController exposes artifact metadata, temporary signed URLs and
    # deletion (Part 8). AWS credentials are never exposed — clients receive a
    # short-lived presigned URL and stream directly from S3. When running
    # without AWS (development), signed URLs fall back to the authenticated
    # /artifacts/:id/file endpoint which streams the local file.
    #
    #   GET    /artifacts/:id      metadata
    #   GET    /artifacts/:id/url  temporary signed URL
    #   GET    /artifacts/:id/file stream local bytes (no AWS configured)
    #   DELETE /artifacts/:id      delete from storage + database
    #   POST   /artifacts/:id/retry  re-enqueue a failed upload
    #
    # Every action is project-scoped: an artifact is only visible when its
    # project belongs to the current user's team (or the user is an admin).
    class ArtifactsController < ApplicationController
      include Authenticatable

      before_action :set_artifact, except: [:index]

      # GET /artifacts — the caller's recent artifacts across their projects,
      # newest first. Used by the global artifacts page.
      def index
        artifacts = Artifact
          .where(job: visible_jobs)
          .order(created_at: :desc)
          .limit(200)

        render json: { artifacts: artifacts.map { |artifact| artifact_response(artifact) } }
      end

      def show
        render json: { artifact: artifact_response(@artifact) }
      end

      # GET /artifacts/:id/url — a presigned S3 GET URL valid for
      # artifact_signed_url_ttl seconds (default 15 minutes). Local storage has
      # no signed URLs, so url is null and the frontend falls back to /file.
      def url
        expires_in = signed_url_ttl
        signed = StorageService.adapter.signed_url(@artifact.s3_key, expires_in: expires_in)
        render json: {
          url: signed,
          expires_in: expires_in,
          storage_backend: StorageService.storage_backend
        }
      end

      # GET /artifacts/:id/file — used by the local backend and as the
      # fallback when no signed URL exists. With S3 configured, we redirect to
      # a signed URL instead of proxying large binaries through Rails.
      def file
        if StorageService.adapter == S3StorageService
          redirect_to StorageService.adapter.signed_url(@artifact.s3_key), allow_other_host: true
          return
        end

        @artifact_path = ArtifactStore.resolve(@artifact.path)
        return render json: { error: "Artifact file missing" }, status: :not_found unless File.exist?(@artifact_path)

        send_file(
          @artifact_path,
          filename: File.basename(@artifact.path),
          type: content_type,
          disposition: "inline"
        )
      end

      # DELETE /artifacts/:id — removes the object from storage (best-effort,
      # so a missing remote object never blocks deleting the record) and the DB.
      def destroy
        StorageService.adapter.delete(@artifact.s3_key)
      rescue StandardError => e
        Rails.logger.warn("[ArtifactsController] Remote delete failed for ##{@artifact.id}: #{e.message}")
      ensure
        @artifact.destroy!
        head :no_content
      end

      # POST /artifacts/:id/retry — flips a failed/pending artifact back to
      # pending and re-enqueues its upload job.
      def retry
        if @artifact.uploaded?
          render json: { artifact: artifact_response(@artifact), message: "Artifact already uploaded" }
          return
        end

        @artifact.mark_uploading!
        ArtifactUploadJob.perform_async(@artifact.id)
        render json: { artifact: artifact_response(@artifact.reload) }
      end

      private

      def set_artifact
        @artifact = Artifact.where(job: visible_jobs).find_by(id: params[:id])
        return if @artifact

        render json: { error: "Artifact not found" }, status: :not_found
      end

      def visible_jobs
        Job.where(test_run: TestRun.where(project: visible_projects))
      end

      def visible_projects
        if current_user.admin?
          Project.all
        else
          Project.where(user: current_user).or(Project.where(team: current_user.team))
        end
      end

      def signed_url_ttl
        ENV.fetch("ARTIFACT_SIGNED_URL_TTL") {
          Rails.configuration.executehub.fetch("artifact_signed_url_ttl", 900)
        }.to_i
      end

      def artifact_response(artifact)
        {
          id: artifact.id,
          job_id: artifact.job_id,
          test_run_id: artifact.test_run_id,
          artifact_type: artifact.artifact_type,
          file_name: artifact.file_name,
          s3_key: artifact.s3_key,
          content_type: artifact.content_type || content_type_for(artifact),
          file_size: artifact.size,
          checksum: artifact.checksum,
          status: artifact.status,
          storage_backend: StorageService.storage_backend,
          created_at: artifact.created_at
        }
      end

      def content_type_for(artifact)
        case artifact.artifact_type
        when "screenshot" then "image/png"
        when "video" then "video/webm"
        when "trace" then "application/zip"
        when "log" then "text/plain"
        when "report" then "application/json"
        else "application/octet-stream"
        end
      end

      def content_type
        case @artifact.artifact_type
        when "screenshot" then "image/png"
        when "video" then "video/webm"
        when "trace" then "application/zip"
        when "log" then "text/plain"
        when "report" then "application/json"
        else "application/octet-stream"
        end
      end
    end
  end
end
