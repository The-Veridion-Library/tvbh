class Admin::UserBadgesController < Admin::BaseController
  before_action :set_badge

  def create
    user = User.find(params[:user_id])
    unless UserBadge.exists?(user: user, badge: @badge)
      UserBadge.create!(user: user, badge: @badge, awarded_at: Time.current)
    end
    redirect_back fallback_location: admin_badges_path, notice: "Badge awarded to #{user.username}."
  end

  def destroy
    user_badge = UserBadge.find(params[:id])
    user_badge.destroy
    redirect_back fallback_location: admin_badges_path, notice: "Badge revoked."
  end

  private

  def set_badge
    @badge = Badge.find(params[:badge_id])
  end
end