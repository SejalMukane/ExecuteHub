module Api
  module V1
    class QueueController < ApplicationController
      include Authenticatable

      # GET /api/v1/queue — queue dashboard statistics.
      def show
        render json: { queue: QueueDashboard.call }
      end
    end
  end
end
