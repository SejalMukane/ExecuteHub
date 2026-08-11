module Api
  module V1
    # AnalyticsController serves the aggregated analytics dashboards
    # (Part 13-14, 17). All heavy lifting lives in TestAnalyticsService which
    # uses database aggregation — the controller stays thin.
    #
    #   GET /analytics                        global overview + history
    #   GET /projects/:project_id/analytics   project-scoped overview + history
    class AnalyticsController < ApplicationController
      include Authenticatable

      def overview
        render json: TestAnalyticsService.global(days: days)
      end

      def project
        project = visible_projects.find_by(id: params[:project_id])
        unless project
          render json: { error: "Project not found" }, status: :not_found
          return
        end

        render json: TestAnalyticsService.for_project(project, days: days)
      end

      private

      def days
        (params[:days] || 30).to_i.clamp(1, 365)
      end

      def visible_projects
        if current_user.admin?
          Project.all
        else
          Project.where(user: current_user).or(Project.where(team: current_user.team))
        end
      end
    end
  end
end
