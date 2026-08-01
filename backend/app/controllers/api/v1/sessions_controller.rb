module Api
  module V1
    class SessionsController < ApplicationController
      include Authenticatable

      def start
        browser_name = params[:browser_name].presence || "Chrome"
        session = BrowserSession.new(
          user: current_user,
          browser_name: browser_name,
          status: "running",
          start_time: Time.current
        )

        if session.save
          render json: { session: session_response(session) }, status: :created
        else
          render json: { errors: session.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def index
        sessions = current_user.browser_sessions.order(created_at: :desc)
        render json: { sessions: sessions.map { |s| session_response(s) } }
      end

      def images
        images = BrowserImage.order(:name)
        render json: { browser_images: images.map { |i| image_response(i) } }
      end

      def destroy
        session = current_user.browser_sessions.find_by(id: params[:id])
        return render json: { error: "Session not found" }, status: :not_found unless session

        session.update(status: "terminated", end_time: Time.current)
        render json: { session: session_response(session) }
      end

      private

      def image_response(image)
        {
          id: image.id,
          name: image.name,
          version: image.version,
          tag: image.tag
        }
      end

      def session_response(session)
        {
          id: session.id,
          browser_name: session.browser_name,
          status: session.status,
          start_time: session.start_time,
          end_time: session.end_time,
          container_id: session.container_id,
          elapsed: session.elapsed,
          created_at: session.created_at
        }
      end
    end
  end
end
