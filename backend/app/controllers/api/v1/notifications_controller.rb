module Api
  module V1
    # User-facing notifications API: list (filtered by project/unread), read a
    # single one, or mark everything read. Creation flows through
    # NotificationService (used by CI services/workers), never this controller.
    class NotificationsController < ApplicationController
      include Authenticatable

      before_action :set_notification, only: [:show, :read]

      # GET /api/v1/notifications?project_id=&unread=true
      def index
        records = visible_notifications
        records = records.where(project_id: params[:project_id]) if params[:project_id].present?
        records = records.unread if params[:unread] == "true"
        render json: {
          notifications: records.recent.limit(100).map { |n| notification_response(n) }
        }
      end

      # GET /api/v1/notifications/:id
      def show
        render json: { notification: notification_response(@notification) }
      end

      # PATCH /api/v1/notifications/:id/read
      def read
        NotificationService.mark_read(@notification)
        render json: { notification: notification_response(@notification) }
      end

      # POST /api/v1/notifications/read_all
      def read_all
        scope = if params[:project_id].present?
                  visible_notifications.where(project_id: params[:project_id])
                else
                  visible_notifications
                end
        NotificationService.mark_all_read_for(scope)
        render json: { updated: true }
      end

      private

      def set_notification
        @notification = visible_notifications.find_by(id: params[:id])
        render json: { error: "Notification not found" }, status: :not_found unless @notification
      end

      def visible_notifications
        Notification.where(project: visible_projects)
      end

      def visible_projects
        if current_user.admin?
          Project.all
        else
          Project.where(user: current_user).or(Project.where(team: current_user.team))
        end
      end

      def notification_response(notification)
        {
          id: notification.id,
          project_id: notification.project_id,
          test_run_id: notification.test_run_id,
          pipeline_id: notification.pipeline_id,
          title: notification.title,
          description: notification.description,
          category: notification.category,
          read: notification.read?,
          created_at: notification.created_at
        }
      end
    end
  end
end
