module Api
  module V1
    class ProjectsController < ApplicationController
      include Authenticatable

      before_action :set_project, only: [:show, :update, :destroy]
      before_action :authorize_write, only: [:create, :update, :destroy]

      def index
        projects = visible_projects.order(created_at: :desc)
        render json: { projects: projects.map { |p| project_response(p) } }
      end

      def show
        render json: { project: project_response(@project) }
      end

      def create
        team = current_user.team || create_default_team
        project = Project.new(project_params.merge(user: current_user, team: team))

        if project.save
          render json: { project: project_response(project) }, status: :created
        else
          render json: { errors: project.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @project.update(project_params)
          render json: { project: project_response(@project) }
        else
          render json: { errors: @project.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @project.destroy
        head :no_content
      end

      private

      def set_project
        @project = visible_projects.find_by(id: params[:id])
        render json: { error: "Project not found" }, status: :not_found unless @project
      end

      def visible_projects
        if current_user.admin?
          Project.all
        else
          Project.where(user: current_user).or(Project.where(team: current_user.team))
        end
      end

      def authorize_write
        return if current_user.admin? || current_user.developer?
        render json: { error: "You do not have permission to modify projects" }, status: :forbidden
      end

      def create_default_team
        team = Team.create!(name: "#{current_user.name}'s Team")
        current_user.update!(team: team)
        team
      end

      def project_params
        params.require(:project).permit(:name, :description, :repository_url)
      end

      def project_response(project)
        {
          id: project.id,
          name: project.name,
          description: project.description,
          repository_url: project.repository_url,
          team_id: project.team_id,
          user_id: project.user_id,
          created_at: project.created_at
        }
      end
    end
  end
end
