class Badge < ApplicationRecord
  has_many :user_badges, dependent: :destroy
  has_many :users, through: :user_badges

  TYPES = %w[finds hidden points manual].freeze

  validates :name, presence: true, uniqueness: true
  validates :badge_type, inclusion: { in: TYPES }
  validates :threshold, numericality: { greater_than: 0 }, unless: :manual?

  def manual?
    badge_type == 'manual'
  end

  def deletable?
    !seeded?
  end
end