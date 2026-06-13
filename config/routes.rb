# frozen_string_literal: true

Rails.application.routes.draw do
  mount LetterOpenerWeb::Engine, at: '/letter_opener' if Rails.env.development?

  if !Docuseal.multitenant? && defined?(Sidekiq::Web)
    authenticated :user, ->(u) { u.sidekiq? } do
      mount Sidekiq::Web => '/jobs'
    end
  end

  root 'dashboard#index'

  get 'up' => 'rails/health#show'
  get 'manifest' => 'pwa#manifest'

  # -------------------------------------------------
  # ❌ REMOVIDO: DEVise (login local bloqueado)
  # devise_for :users, path: '/', only: %i[sessions passwords],
  #                  controllers: { sessions: 'sessions', passwords: 'passwords' }
  #
  # devise_scope :user do
  #   resource :invitation, only: %i[update] do
  #     get '' => :edit
  #   end
  # end
  # -------------------------------------------------

  # 🔐 SSO ONLY: mantém apenas sessão já autenticada via proxy
  # login passa a ser EXTERNO (Keycloak + oauth2-proxy)

  namespace :api, defaults: { format: :json } do
    resource :user, only: %i[show]
    resources :attachments, only: %i[create]
    resources :submitter_email_clicks, only: %i[create]
    resources :submitter_form_views, only: %i[create]
    resources :submitters, only: %i[index show update]
    resources :submissions, only: %i[index show create destroy]
    resources :templates, only: %i[update show index destroy]
  end

  resources :verify_pdf_signature, only: %i[create]
  resource :mfa_setup, only: %i[show new edit create destroy]
  resources :dashboard, only: %i[index]
  resources :setup, only: %i[index create]
  resource :newsletter, only: %i[show update]

  resources :users, only: %i[new create edit update destroy]
  resource :user_signature, only: %i[edit update destroy]
  resource :user_initials, only: %i[edit update destroy]

  resources :submissions, only: %i[index show destroy]

  resources :templates, only: %i[index new create edit update show destroy]

  resources :folders, controller: 'template_folders', only: %i[show edit update destroy]

  scope '/settings', as: :settings do
    resources :sso, only: %i[index], controller: 'sso_settings'
    resources :account, only: %i[show update destroy]
  end

  match '/mcp', to: 'mcp#call', via: %i[get post]

  get '/js/:filename', to: 'embed_scripts#show', as: :embed_script

  ActiveSupport.run_load_hooks(:routes, self)


  before_action :verify_proxy_source

def verify_proxy_source
  return if Rails.env.development?

  allowed_ips = ["172.18.0.0/16", "127.0.0.1"]

  ip = request.remote_ip

  unless allowed_ips.any? { |net| IPAddr.new(net).include?(ip) }
    render plain: "Forbidden", status: :forbidden
  end
end
end