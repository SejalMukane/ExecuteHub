module Api
  module V1
    # ArtifactsController streams execution artifact bytes back to the frontend
    # (screenshot previews, video playback, trace downloads). No S3 yet — files
    # are read from the local ArtifactStore.
    #
    #   GET /artifacts/:id/file
    class ArtifactsController < ApplicationController
      include Authenticatable

      before_action :set_artifact

      def file
        send_file(
          @artifact_path,
          filename: File.basename(@artifact.path),
          type: content_type,
          disposition: "inline"
        )
      end

      private

      def set_artifact
        @artifact = Artifact.where(job: visible_jobs).find_by(id: params[:id])
        unless @artifact
          render json: { error: "Artifact not found" }, status: :not_found
          return
        end

        @artifact_path = ArtifactStore.resolve(@artifact.path)
        render json: { error: "Artifact file missing" }, status: :not_found unless File.exist?(@artifact_path)
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

      def content_type
        case @artifact.artifact_type
        when "screenshot" then "image/png"
        when "video" then "video/webm"
        when "trace" then "application/zip"
        else "application/octet-stream"
        end
      end
    end
  end
end
