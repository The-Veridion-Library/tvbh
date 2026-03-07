class Admin::LocationsController < Admin::BaseController
  before_action :set_location, only: [:show, :edit, :update, :destroy, :set_status]

  def index
    @locations = Location.includes(:nominator).order(:nomination_status, :name)
    @locations = @locations.where(nomination_status: params[:status]) if params[:status].present?
    @locations = @locations.where(location_type: params[:type]) if params[:type].present?
    @pending_count = Location.pending_nominations.count
  end

  def show
    @labels = @location.labels.includes(:book)
  end

  def edit; end

  def update
    if @location.update(location_params)
      redirect_to admin_location_path(@location), notice: "Location updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @location.has_active_labels?
      redirect_to admin_location_path(@location), alert: "Cannot delete — this location has active labels."
    else
      @location.destroy
      redirect_to admin_locations_path, notice: "Location deleted."
    end
  end

  def set_status
    new_status = params[:nomination_status]
    unless Location::NOMINATION_STATUSES.include?(new_status)
      redirect_back fallback_location: admin_locations_path, alert: "Invalid status."
      return
    end

    if new_status == 'declined' && @location.has_active_labels?
      redirect_back fallback_location: admin_location_path(@location),
        alert: "Cannot decline — this location has active labels. Resolve those first."
      return
    end

    @location.update!(nomination_status: new_status)
    notice = case new_status
             when 'partner'      then "✅ #{@location.name} is now a partner location!"
             when 'under_review' then "Marked as under review."
             when 'declined'     then "Location declined."
             else "Status updated."
             end
    redirect_back fallback_location: admin_location_path(@location), notice: notice
  end

  private

  def set_location
    @location = Location.find(params[:id])
  end

  def location_params
    params.require(:location).permit(
      :name, :location_type, :address_line_1, :address_line_2,
      :city, :state, :zip_code, :latitude, :longitude,
      :website, :contact_name, :nomination_notes, :nomination_status
    )
  end
end