class LocationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @partner_locations  = Location.partners.order(:name)
    @my_nominations     = current_user.nominations.order(created_at: :desc) if current_user.respond_to?(:nominations)
    # Fallback if nominations association not set up yet:
    @my_nominations ||= Location.where(nominated_by: current_user.id).order(created_at: :desc)
  end

  def new
    @location = Location.new
  end

  def create
    @location = Location.new(location_params)
    @location.nominated_by = current_user.id
    @location.nomination_status = 'nominated'

    if @location.latitude.to_f.zero? || @location.longitude.to_f.zero?
      coords = geocode_address(@location.full_address)
      if coords
        @location.latitude  = coords[:lat]
        @location.longitude = coords[:lng]
      end
    end

    if @location.save
      redirect_to locations_path, notice: "Thanks for the nomination! We'll reach out to #{@location.name} and keep you posted."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def location_params
    params.require(:location).permit(
      :name, :location_type,
      :address_line_1, :address_line_2,
      :city, :state, :zip_code,
      :latitude, :longitude,
      :website, :contact_name, :nomination_notes
    )
  end

  def geocode_address(address)
    require 'net/http'
    require 'json'
    query  = URI.encode_www_form(q: address, format: 'json', limit: 1)
    uri    = URI("https://nominatim.openstreetmap.org/search?#{query}")
    http   = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req    = Net::HTTP::Get.new(uri)
    req['User-Agent'] = 'TheVeridionBookHunt/1.0'
    results = JSON.parse(http.request(req).body)
    results.any? ? { lat: results[0]['lat'].to_f, lng: results[0]['lon'].to_f } : nil
  rescue => e
    Rails.logger.error "Geocoding failed: #{e.message}"
    nil
  end
end