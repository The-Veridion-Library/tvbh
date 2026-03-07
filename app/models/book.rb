class Book < ApplicationRecord
  belongs_to :user
  belongs_to :preferred_location, class_name: 'Location', optional: true
  has_many :labels, dependent: :destroy
  has_many :locations, through: :labels
  has_many :finds, dependent: :destroy

  SUBMISSION_STATUSES = %w[pending_review approved rejected].freeze
  CONDITIONS          = %w[like_new good acceptable poor].freeze

  validates :title,  presence: true
  validates :author, presence: true
  validates :status, inclusion: { in: %w[hidden found] }
  validates :submission_status, inclusion: { in: SUBMISSION_STATUSES }
  validates :book_condition,    inclusion: { in: CONDITIONS }, allow_blank: true

  before_validation :set_defaults

  scope :approved,       -> { where(submission_status: 'approved') }
  scope :pending_review, -> { where(submission_status: 'pending_review') }
  scope :rejected,       -> { where(submission_status: 'rejected') }
  scope :flagged,        -> { where(flagged: true) }

  def approved?   = submission_status == 'approved'
  def pending?    = submission_status == 'pending_review'
  def rejected?   = submission_status == 'rejected'

  def condition_label
    { 'like_new' => 'Like New', 'good' => 'Good', 'acceptable' => 'Acceptable', 'poor' => 'Poor' }[book_condition] || book_condition.to_s.humanize
  end

  private

  def set_defaults
    self.status           ||= 'hidden'
    self.submission_status ||= 'pending_review'
  end
end