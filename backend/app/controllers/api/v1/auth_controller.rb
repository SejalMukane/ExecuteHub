module Api
  module V1
    class AuthController < ApplicationController
      include Authenticatable

      skip_before_action :authenticate_user, only: [:register, :login]

      def register
        user = User.new(register_params)
        if user.save
          token = JwtService.encode(user_id: user.id)
          render json: { user: user_response(user), token: token }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def login
        user = User.find_by(email: params[:email])
        if user&.authenticate(params[:password])
          token = JwtService.encode(user_id: user.id)
          render json: { user: user_response(user), token: token }
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end

      def logout
        head :no_content
      end

      def me
        render json: { user: user_response(current_user) }
      end

      def update_profile
        user = current_user
        updates = update_params
        updates.delete(:password) if updates[:password].blank?

        if user.update(updates)
          render json: { user: user_response(user) }
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def register_params
        params.permit(:name, :email, :password, :password_confirmation)
      end

      def update_params
        params.permit(:name, :email, :password, :password_confirmation)
      end

      def user_response(user)
        {
          id: user.id,
          name: user.name,
          email: user.email,
          created_at: user.created_at
        }
      end
    end
  end
end
