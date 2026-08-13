module Api
  module V1
    # User-facing DeploymentGate API. The gate is created automatically when a
    # CI TestRun completes; approve/reject are the only mutations and they ONLY
    # change the gate state — no actual deployment happens in this phase.
    class DeploymentGatesController < ApplicationController
      include Authenticatable

      before_action :set_gate, only: [:show, :approve, :reject]
      before_action :authorize_release, only: [:approve, :reject]

      # GET /api/v1/deployment_gates/:id
      def show
        render json: { deployment_gate: gate_response(@gate) }
      end

      # POST /api/v1/deployment_gates/:id/approve — human release.
      def approve
        return render json: { error: "Gate is not pending" }, status: :unprocessable_entity unless @gate.pending?

        @gate.approve!
        mark_pipeline_passed
        DashboardEventService.deployment_gate_approved(@gate)
        notify("Deployment gate approved", "#{pipeline_name} was approved for release by #{current_user.email}.")
        notify_jenkins("gate APPROVED (manual)")
        render json: { deployment_gate: gate_response(@gate) }
      end

      # POST /api/v1/deployment_gates/:id/reject — human block.
      def reject
        return render json: { error: "Gate is not pending" }, status: :unprocessable_entity unless @gate.pending?

        @gate.block!("Rejected manually by #{current_user.email}")
        mark_pipeline_blocked
        DashboardEventService.deployment_gate_blocked(@gate)
        notify("Deployment gate rejected", "#{pipeline_name} was rejected for release by #{current_user.email}.")
        notify_jenkins("gate BLOCKED (manual reject)")
        render json: { deployment_gate: gate_response(@gate) }
      end

      private

      def set_gate
        @gate = DeploymentGate.where(project: visible_projects).find_by(id: params[:id])
        render json: { error: "Deployment gate not found" }, status: :not_found unless @gate
      end

      def authorize_release
        return if current_user.admin? || current_user.developer?

        render json: { error: "You do not have permission to approve or reject releases" }, status: :forbidden
      end

      def visible_projects
        if current_user.admin?
          Project.all
        else
          Project.where(user: current_user).or(Project.where(team: current_user.team))
        end
      end

      def pipeline_name
        @gate.pipeline&.name || "Pipeline ##{@gate.pipeline_id}"
      end

      def mark_pipeline_passed
        @gate.pipeline&.update!(status: :passed)
        DashboardEventService.pipeline_completed(@gate.pipeline) if @gate.pipeline
      end

      def mark_pipeline_blocked
        @gate.pipeline&.update!(status: :blocked)
        DashboardEventService.pipeline_completed(@gate.pipeline) if @gate.pipeline
      end

      def notify(title, description)
        NotificationService.notify(project: @gate.project, title: title, description: description,
                                   category: :deployment_gate, pipeline: @gate.pipeline,
                                   test_run: @gate.test_run)
      end

      # Best-effort reflection of the decision inside Jenkins (never fatal).
      def notify_jenkins(suffix)
        build = @gate.pipeline&.builds&.last
        return unless build

        JenkinsService.set_build_description(build.jenkins_build_number, "ExecuteHub — #{suffix}")
      rescue StandardError => e
        Rails.logger.warn("[DeploymentGatesController] Jenkins notify failed: #{e.message}")
      end

      def gate_response(gate)
        {
          id: gate.id,
          project_id: gate.project_id,
          pipeline_id: gate.pipeline_id,
          test_run_id: gate.test_run_id,
          status: gate.status,
          reason: gate.reason,
          requires_approval: gate.requires_approval,
          decided_at: gate.decided_at,
          created_at: gate.created_at
        }
      end
    end
  end
end