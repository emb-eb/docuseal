# frozen_string_literal: true

class ApplicationController < ActionController::Base
  before_action :verify_proxy_source
  before_action :verify_sso!
  before_action :load_current_user

  helper_method :current_user, :current_account

  private

  # =========================
  # 🔐 PROXY SECURITY
  # =========================
  def verify_proxy_source
    return if Rails.env.development?

    allowed_cidrs = [
      IPAddr.new("172.18.0.0/16"),
      IPAddr.new("127.0.0.1")
    ]

    ip = IPAddr.new(request.remote_ip) rescue nil
    return if ip && allowed_cidrs.any? { |net| net.include?(ip) }

    render plain: "Forbidden (invalid proxy)", status: :forbidden
  end

  # =========================
  # 🔐 SSO HARD LOCK
  # =========================
  def verify_sso!
    return if sso_email.present?

    render plain: "SSO REQUIRED", status: :unauthorized
  end

  # =========================
  # 🔐 TRUSTED HEADERS ONLY
  # =========================
  def sso_email
    request.headers["HTTP_X_AUTH_REQUEST_EMAIL"] ||
      request.headers["HTTP_X_FORWARDED_EMAIL"]
  end

  # =========================
  # 👤 USER LOADING (NO AUTO CREATE)
  # =========================
  def load_current_user
    email = sso_email&.downcase&.strip
    return if email.blank?

    @current_user = User.find_by(email: email)

    return if @current_user

    render plain: "User not provisioned", status: :forbidden
  end

  # =========================
  # CURRENT USER
  # =========================
  def current_user
    @current_user
  end

  # =========================
  # ACCOUNT
  # =========================
  def current_account
    current_user&.account
  end
end