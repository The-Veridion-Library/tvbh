class Location < ApplicationRecord
  belongs_to :nominator, class_name: 'User', foreign_key: 'nominated_by', optional: true
  has_many :labels,    dependent: :destroy
  has_many :books,     through: :labels

  NOMINATION_STATUSES = %w[nominated under_review partner declined].freeze
  LOCATION_TYPES      = %w[library bookstore cafe park other].freeze
  TYPE_EMOJI          = { 'library' => '📚', 'bookstore' => '🏪', 'cafe' => '☕', 'park' => '🌳', 'other' => '📍' }.freeze

  validates :name,           presence: true
  validates :address_line_1, presence: true
  validates :city,           presence: true
  validates :state,          presence: true
  validates :location_type,  presence: true
  validates :nomination_status, inclusion: { in: NOMINATION_STATUSES }

  before_validation :set_defaults

  scope :partners,             -> { where(nomination_status: 'partner') }
  scope :pending_nominations,  -> { where(nomination_status: %w[nominated under_review]) }
  scope :nominated,            -> { where(nomination_status: 'nominated') }
  scope :under_review,         -> { where(nomination_status: 'under_review') }
  scope :declined,             -> { where(nomination_status: 'declined') }

  def partner?      = nomination_status == 'partner'
  def nominated?    = nomination_status == 'nominated'
  def under_review? = nomination_status == 'under_review'
  def declined?     = nomination_status == 'declined'

  def full_address
    [address_line_1, address_line_2, city, state, zip_code].compact_blank.join(', ')
  end

  def type_emoji = TYPE_EMOJI[location_type] || '📍'

  def has_active_labels? = labels.active.any?

  private

  def set_defaults
    self.nomination_status ||= 'nominated'
  end
end