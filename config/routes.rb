RailsAssets::Application.routes.draw do
  get '/packages' => 'main#packages'
  get '/packages/:name' => 'main#package',
      constraints: { name: /[^\/]+/ }

  resources :components, only: [:index, :new, :create] do
    collection do
      get '/:name/rebuild' => 'components#rebuild',
          constraints: { name: /[^\/]+/ }

      get '/:name/:version' => 'components#assets',
          constraints: { version: /[^\/]+/, name: /[^\/]+/ }
    end
  end

  get '/api/v1/dependencies', to: 'main#dependencies'
  resources :donations, only: :create

  require 'sidekiq/web'
  Sidekiq::Web.use(Rack::Auth::Basic) do |user, password|
    [user, password] == [
      'admin', ENV['SIDEKIQ_PASSWORD'] || 'password'
    ]
  end
  mount Sidekiq::Web => '/sidekiq'

  get '/status', to: 'main#status'
  get '/dump', to: 'main#heap_dump'

  root to: 'main#home'

  get '/home', to: redirect('/')
end
