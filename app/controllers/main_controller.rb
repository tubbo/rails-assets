class MainController < ApplicationController
  before_action :redirect_to_https, only: ['home']

  def home
    render(json: request.env.inspect) && return if params[:debug]
  end

  def status
    @pending_index = Version.includes(:component).pending_index.load

    @pending_builds = Sidekiq::Queue.new('default').map(&:as_json).map { |i| i['item']['args'] }

    @failed_jobs = FailedJob.all.to_a
  end

  def dependencies
    if params[:gems].blank?
      gems = []
    else
      gem_names = params[:gems].to_s.split(',')

      # TODO: Enable this in future. For now bundler sends all gems
      # instead only ones defined in source block.
      # invalid_gemfile = gem_names.find { |e| !e.start_with?(GEM_PREFIX) }.present?

      invalid_gemfile = !gem_names.include?('bundler')

      if false

        message = ''"
          Due to security vulnerability non-block source syntax is now strongly discouraged!

          Please require bundler >= 1.8.4 and specify sources in blocks as follows:

          ```
          source 'https://rubygems.org'

          gem 'bundler', '>= 1.8.4'

          gem 'rails'
          # The rest of RubyGems gems...

          source 'https://#{Rails.configuration.x.hostname}' do
            gem 'rails-assets-angular'
            # The rest of RailsAssets gems...
          end
          ```
        "''.strip_heredoc

        render text: message,
               status: :unprocessable_entity

        return
      end

      gem_names = gem_names.select { |e| e.start_with?(GEM_PREFIX) }
      gem_names = gem_names.map { |e| e.gsub(GEM_PREFIX, '') }

      gem_names.each do |name|
        next unless Component.needs_build?(name)
        begin
          ::BuildVersion.new.perform(name, 'latest')
        rescue Exception => e
          Rails.logger.error(e)
        end

        ::UpdateComponent.perform_async(name)
      end

      Reindex.new.perform if Version.pending_index.count > 0

      gems = Component.where(name: gem_names).to_a.flat_map do |component|
        component.versions.builded.map do |v|
          {
            name:         "#{GEM_PREFIX}#{component.name}",
            platform:     'ruby',
            number:       v.string,
            dependencies: v.dependencies || {}
          }
        end
      end

      Rails.logger.info(params)
      Rails.logger.info(gems)
    end

    respond_to do |format|
      format.all { render text: Marshal.dump(gems) }
      format.json { render json: gems }
    end
  end

  def packages
    render file: Rails.root.join('public', 'packages.json'),
           layout: false
  end

  def package
    render json: {
      type: 'alias',
      url: indexed_packages[params[:name]]['url']
    }
  end

  def indexed_packages
    @indexed_packages ||= JSON.parse(
      File.read(Rails.root.join('public', 'packages.json'))
    ).index_by { |p| p['name'] }
  end

  private

  def redirect_to_https
    redirect_to protocol: 'https://' unless request.ssl? || can_skip_https
  end

  def can_skip_https
    [request.local?, Rails.env.staging?, Rails.env.development?].any?
  end
end
