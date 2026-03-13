class Admin::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  layout 'admin'

  private

  # Ensures every ## heading has a blank line before and after it.
  # Uses the exact known heading names so there's no ambiguity.
  AI_HEADINGS = [
    'Book Lookup', 'Policy Check', 'Book Summary', 'Condition Assessment', 'Fraud Signals', 'Recommendation',
    'Venue Research', 'Chain or Independent\\?', 'Existing Book Programs',
    'Address Validation', 'Suitability Assessment', 'Concerns'
  ].freeze

  AI_HEADING_PATTERNS = [
    [/Book\s*Lookup/i, 'Book Lookup'],
    [/Policy\s*Check/i, 'Policy Check'],
    [/Book\s*Summary/i, 'Book Summary'],
    [/Condition(?:\s*Assessment)?/i, 'Condition Assessment'],
    [/Fraud\s*Signals/i, 'Fraud Signals'],
    [/Recommendation/i, 'Recommendation'],
    [/Venue\s*Research/i, 'Venue Research'],
    [/Chain\s*or\s*Independent\??/i, 'Chain or Independent?'],
    [/Existing\s*Book\s*Programs/i, 'Existing Book Programs'],
    [/Address\s*Validation/i, 'Address Validation'],
    [/Suitability\s*Assessment/i, 'Suitability Assessment'],
    [/Concerns/i, 'Concerns']
  ].freeze

  def normalize_ai_markdown(text)
    return '' if text.blank?

    normalized = text.to_s.dup
    normalized.gsub!("\r\n", "\n")
    normalized.gsub!("\r", "\n")
    normalized.gsub!(/([^\n])(##\s*)/, "\\1\n\n\\2")

    AI_HEADING_PATTERNS.each do |pattern, canonical|
      normalized.gsub!(/^\s*##\s*#{pattern}\s*:?([^\n]*)$/i) do
        trailing = Regexp.last_match(1).to_s.strip
        trailing.present? ? "## #{canonical}\n\n#{trailing}" : "## #{canonical}"
      end
    end

    AI_HEADINGS.each do |heading|
      normalized.gsub!(/([^\n])(## #{Regexp.escape(heading)})/, "\\1\n\n\\2")
      normalized.gsub!(/(## #{Regexp.escape(heading)})([^\n])/, "\\1\n\n\\2")
    end

    normalized.gsub!(/^\s*~\s+/, '- ')
    normalized.gsub!(/([.!?:])\s*-\s+(?=[A-Z0-9])/, "\\1\n- ")
    normalized.gsub!(/\n{3,}/, "\n\n")
    normalized.strip
  end
end