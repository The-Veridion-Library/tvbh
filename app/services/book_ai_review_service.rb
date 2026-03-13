require 'net/http'
require 'json'

CONTENT_POLICY_TEXT = <<~POLICY.freeze
  THE VERIDION BOOK HUNT — CONTENT POLICY

  Books we welcome:
  - Fiction and non-fiction for general audiences
  - Children's, YA, middle-grade, educational, scientific, historical, reference, cookbooks, craft, travel, hobby
  - Classic and contemporary literature, any language

  Books we DO NOT accept:
  - Explicit/adult sexual content or graphic nudity
  - Hate speech or content promoting discrimination/violence based on protected characteristics
  - Detailed instructions for weapons, explosives, illegal drugs, or serious harm
  - Content designed to harass or threaten specific individuals
  - Books submitted with false information about title, author, or condition

  Physical condition standards (minimum: Acceptable):
  - Like New: no wear, clean pages
  - Good: minor wear, no missing pages, no heavy markings
  - Acceptable: visible wear OK, pages intact and readable
  - Poor: generally rejected (unless rare/special)

  Automatic rejection triggers:
  - Strong offensive odor (heavy mold, chemicals, smoke damage)
  - Missing significant pages
  - Extensive writing/highlighting that impairs readability
  - Water damage making the book unreadable

  Disclosed minor issues (light mustiness, pencil notes, minor highlighting) are generally acceptable.
POLICY

class BookAiReviewService
  HACK_CLUB_AI_URL = 'https://ai.hackclub.com/proxy/v1/chat/completions'.freeze
  OPEN_LIBRARY_API_URL = 'https://openlibrary.org/api/books'.freeze
  OPEN_LIBRARY_SEARCH_URL = 'https://openlibrary.org/search.json'.freeze
  GOOGLE_BOOKS_API_URL = 'https://www.googleapis.com/books/v1/volumes'.freeze
  OPEN_LIBRARY_USER_AGENT = 'The Veridion Book Hunt (theveridionbookhunt@gmail.com)'.freeze
  MODEL            = 'qwen/qwen3-next-80b-a3b-instruct'.freeze

  def initialize(book)
    @book = book
  end

  # Non-streaming: runs to completion, saves result, used by background job
  def call
    result = ''
    stream { |chunk| result += chunk }
    @book.update_columns(ai_review: result, ai_reviewed_at: Time.current)
  rescue => e
    Rails.logger.error "[BookAiReviewService] Failed for book #{@book.id}: #{e.message}"
    @book.update_columns(
      ai_review: "AI review failed: #{e.message}",
      ai_reviewed_at: Time.current
    )
  end

  # Streaming: yields text chunks as they arrive, does NOT save — caller handles persistence
  def stream(&block)
    evidence = fetch_book_evidence

    if evidence[:hard_reject]
      yield build_hard_reject_review(evidence)
      return
    end

    api_key = ENV.fetch('HACK_CLUB_AI_KEY', nil)
    unless api_key
      yield "⚠️ AI review skipped — HACK_CLUB_AI_KEY environment variable not set."
      return
    end

    uri  = URI(HACK_CLUB_AI_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.read_timeout = 180
    http.open_timeout = 15

    request = Net::HTTP::Post.new(uri)
    request['Content-Type']  = 'application/json'
    request['Authorization'] = "Bearer #{api_key}"
    request.body = JSON.generate({
      model:    MODEL,
      messages: [{ role: 'user', content: build_prompt(evidence) }],
      temperature: 0.3,
      max_tokens:  900,
      stream:      true
    })

    http.request(request) do |response|
      response.read_body do |raw_chunk|
        raw_chunk.split("\n").each do |line|
          next unless line.start_with?('data: ')
          payload = line[6..]
          next if payload.strip == '[DONE]'
          begin
            parsed = JSON.parse(payload)
            content = parsed.dig('choices', 0, 'delta', 'content')
            yield content if content.present?
          rescue JSON::ParserError
            # skip malformed SSE lines
          end
        end
      end
    end
  end

  private

  def build_prompt(evidence)
    <<~PROMPT
      You are a content moderation assistant for The Veridion Book Hunt, a community book-sharing game.
      Your job is to pre-screen book submissions and produce a structured review for a human admin.

      Do NOT make final approve/reject decisions — only surface findings and flag concerns.
      Be concise. Use plain language. Format your response using Markdown with ## headers and bullet points.
      For bullet points, use "~ " at the start of each bullet line (NOT "- ").
      Never use hyphen bullets. Hyphens may appear inside titles/subtitles and should stay plain text.
      If you need an inline separator in prose, use an em dash (—) instead of a hyphen (-).
      IMPORTANT VALIDATION RULES:
      1) Use the JSON evidence below from OpenLibrary + Google Books API lookups.
      2) Validate title and author consistency against API results.
      3) If a provided ISBN is not found by BOTH OpenLibrary and Google Books ISBN queries, recommendation MUST be LIKELY REJECT.
      4) If ISBN check digit is invalid, recommendation MUST be LIKELY REJECT.

      ---
      CONTENT POLICY:
      #{CONTENT_POLICY_TEXT}

      ---
      SUBMISSION TO REVIEW:
      Title: #{@book.title}
      Author: #{@book.author}
      ISBN: #{@book.isbn.presence || 'Not provided'}
      Condition declared: #{@book.condition_label.presence || 'Not specified'}
      Maturity rating (from Google Books): #{@book.maturity_rating.presence || 'Unknown'}
      Submission notes from user: #{@book.submission_notes.presence || 'None'}

      ---
      API EVIDENCE (analyze this JSON):
      ISBN normalized: #{evidence[:isbn_normalized].presence || 'N/A'}
      ISBN check digit valid: #{evidence[:isbn_check_digit_valid].nil? ? 'N/A' : evidence[:isbn_check_digit_valid]}
      ISBN found in OpenLibrary: #{evidence[:isbn_found_openlibrary]}
      ISBN found in Google Books: #{evidence[:isbn_found_google_books]}
      Title/author appears consistent with API records: #{evidence[:title_author_consistent]}

      OpenLibrary (ISBN lookup):
      #{pretty_json(evidence[:openlibrary_isbn])}

      OpenLibrary (title+author search):
      #{pretty_json(evidence[:openlibrary_search])}

      Google Books (ISBN query):
      #{pretty_json(evidence[:google_books_isbn])}

      Google Books (title+author query):
      #{pretty_json(evidence[:google_books_search])}

      Suggested summary source text (if available):
      #{evidence[:summary_source].presence || 'No summary text available in API responses.'}

      ---
      YOUR REVIEW — respond in exactly this Markdown format. IMPORTANT: always put a blank line between a heading and its content, and between sections. Use "~ " bullets where needed:

      ## Book Lookup

      [What is publicly known about this title and author? Is the title/author combination real and recognized? Any notable content concerns from public knowledge?]

      ## Policy Check

      [Does this submission appear to comply with the content policy? List any specific concerns or red flags. If none, say "No concerns identified."]

  ## Book Summary

  [Write a 2-4 sentence summary of the book using the API JSON above. If no reliable summary exists, say that clearly.]

      ## Condition Assessment

      [Based on the declared condition and submission notes, does the physical condition seem acceptable? Note any disclosed issues.]

      ## Fraud Signals

      [Any signs this submission might be fraudulent? E.g. nonsensical title, mismatched author/title, invalid ISBN check digit, suspicious notes. If none, say "None detected."]

      ## Recommendation

      [Write ONLY ONE of these three exact words on a line by itself: LOOKS GOOD, NEEDS HUMAN ATTENTION, or LIKELY REJECT — then on the next line, write one sentence explaining why.]
    PROMPT
  end

  def fetch_book_evidence
    isbn_normalized = normalize_isbn(@book.isbn)
    isbn_check_digit_valid = if isbn_normalized.present?
      valid_isbn13?(isbn_normalized) || valid_isbn10?(isbn_normalized)
    end

    openlibrary_isbn = isbn_normalized.present? ? fetch_openlibrary_isbn(isbn_normalized) : {}
    google_books_isbn = isbn_normalized.present? ? fetch_google_books("isbn:#{isbn_normalized}") : {}
    openlibrary_search = fetch_openlibrary_search(@book.title, @book.author)
    google_books_search = fetch_google_books("intitle:#{@book.title} inauthor:#{@book.author}")

    isbn_found_openlibrary = isbn_present_in_openlibrary?(openlibrary_isbn)
    isbn_found_google_books = isbn_present_in_google?(google_books_isbn)
    isbn_missing_in_apis = isbn_normalized.present? && !isbn_found_openlibrary && !isbn_found_google_books
    isbn_missing_from_submission = isbn_normalized.blank?

    best_title = first_present(
      dig_openlibrary_title(openlibrary_isbn),
      dig_google_title(google_books_isbn),
      dig_openlibrary_title(openlibrary_search),
      dig_google_title(google_books_search)
    )

    best_author = first_present(
      dig_openlibrary_author(openlibrary_isbn),
      dig_google_author(google_books_isbn),
      dig_openlibrary_author(openlibrary_search),
      dig_google_author(google_books_search)
    )

    title_author_consistent = title_author_match?(@book.title, best_title) && title_author_match?(@book.author, best_author)

    {
      isbn_normalized: isbn_normalized,
      isbn_check_digit_valid: isbn_check_digit_valid,
      isbn_found_openlibrary: isbn_found_openlibrary,
      isbn_found_google_books: isbn_found_google_books,
      title_author_consistent: title_author_consistent,
      openlibrary_isbn: summarize_openlibrary_payload(openlibrary_isbn),
      openlibrary_search: summarize_openlibrary_search(openlibrary_search),
      google_books_isbn: summarize_google_payload(google_books_isbn),
      google_books_search: summarize_google_payload(google_books_search),
      summary_source: extract_summary_text(openlibrary_isbn, google_books_isbn, openlibrary_search, google_books_search),
      hard_reject: isbn_missing_from_submission || isbn_missing_in_apis || (isbn_normalized.present? && isbn_check_digit_valid == false)
    }
  end

  def build_hard_reject_review(evidence)
    <<~MD
      ## Book Lookup

      ~ OpenLibrary and Google Books API ISBN lookups did not validate the submitted record.
      ~ Submitted title/author could not be confidently confirmed from API evidence.

      ## Policy Check

      ~ Content policy cannot be fully assessed without reliable bibliographic validation.

      ## Book Summary

      No reliable summary available because the submitted ISBN did not resolve to a valid record in OpenLibrary or Google Books.

      ## Condition Assessment

      Declared condition "#{@book.condition_label.presence || 'Not specified'}" noted.

      ## Fraud Signals

      ~ ISBN normalized: #{evidence[:isbn_normalized].presence || 'N/A'}
      ~ ISBN check digit valid: #{evidence[:isbn_check_digit_valid].nil? ? 'N/A' : evidence[:isbn_check_digit_valid]}
      ~ OpenLibrary ISBN hit: #{evidence[:isbn_found_openlibrary]}
      ~ Google Books ISBN hit: #{evidence[:isbn_found_google_books]}

      ## Recommendation

      LIKELY REJECT
      Provided ISBN is invalid or does not exist in OpenLibrary and Google Books, so this submission fails bibliographic verification.
    MD
  end

  def fetch_openlibrary_isbn(isbn)
    params = URI.encode_www_form(bibkeys: "ISBN:#{isbn}", format: 'json', jscmd: 'data')
    fetch_json("#{OPEN_LIBRARY_API_URL}?#{params}")
  end

  def fetch_openlibrary_search(title, author)
    params = URI.encode_www_form(title: title.to_s, author: author.to_s, limit: 5)
    fetch_json("#{OPEN_LIBRARY_SEARCH_URL}?#{params}")
  end

  def fetch_google_books(query)
    params = URI.encode_www_form(q: query.to_s, maxResults: 5, printType: 'books')
    fetch_json("#{GOOGLE_BOOKS_API_URL}?#{params}")
  end

  def fetch_json(url)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 8
    http.read_timeout = 12
    req = Net::HTTP::Get.new(uri)
    req['Accept'] = 'application/json'
    req['User-Agent'] = OPEN_LIBRARY_USER_AGENT
    response = http.request(req)
    return {} unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.warn "[BookAiReviewService] Evidence fetch failed for #{url}: #{e.class} #{e.message}"
    {}
  end

  def summarize_openlibrary_payload(payload)
    return {} unless payload.is_a?(Hash)
    key, data = payload.first
    return {} unless data.is_a?(Hash)
    {
      key: key,
      title: data['title'],
      authors: Array(data['authors']).map { |a| a['name'] }.compact,
      publish_date: data['publish_date'],
      publishers: Array(data['publishers']).map { |p| p['name'] }.compact,
      number_of_pages: data['number_of_pages'],
      subjects: Array(data['subjects']).map { |s| s['name'] }.compact.first(8),
      excerpt: data.dig('excerpts', 0, 'text')
    }.compact
  end

  def summarize_openlibrary_search(payload)
    docs = Array(payload['docs']).first(5)
    {
      num_found: payload['numFound'],
      docs: docs.map do |doc|
        {
          title: doc['title'],
          author_name: Array(doc['author_name']).first(3),
          first_publish_year: doc['first_publish_year'],
          isbn: Array(doc['isbn']).first(3)
        }.compact
      end
    }
  end

  def summarize_google_payload(payload)
    items = Array(payload['items']).first(5)
    {
      total_items: payload['totalItems'],
      items: items.map do |item|
        info = item['volumeInfo'] || {}
        {
          title: info['title'],
          subtitle: info['subtitle'],
          authors: Array(info['authors']).first(4),
          published_date: info['publishedDate'],
          categories: Array(info['categories']).first(4),
          maturity_rating: info['maturityRating'],
          description: info['description']&.slice(0, 700),
          industry_identifiers: Array(info['industryIdentifiers']).first(4)
        }.compact
      end
    }
  end

  def isbn_present_in_openlibrary?(payload)
    payload.is_a?(Hash) && payload.any?
  end

  def isbn_present_in_google?(payload)
    payload.is_a?(Hash) && payload['totalItems'].to_i > 0
  end

  def dig_openlibrary_title(payload)
    if payload.is_a?(Hash) && payload.key?('docs')
      payload.dig('docs', 0, 'title')
    else
      payload.values.first.is_a?(Hash) ? payload.values.first['title'] : nil
    end
  end

  def dig_openlibrary_author(payload)
    if payload.is_a?(Hash) && payload.key?('docs')
      Array(payload.dig('docs', 0, 'author_name')).first
    else
      authors = payload.values.first.is_a?(Hash) ? payload.values.first['authors'] : nil
      Array(authors).first.is_a?(Hash) ? Array(authors).first['name'] : nil
    end
  end

  def dig_google_title(payload)
    payload.dig('items', 0, 'volumeInfo', 'title')
  end

  def dig_google_author(payload)
    Array(payload.dig('items', 0, 'volumeInfo', 'authors')).first
  end

  def extract_summary_text(*payloads)
    payloads.each do |payload|
      description = payload.dig('items', 0, 'volumeInfo', 'description') if payload.is_a?(Hash)
      return description.to_s.slice(0, 900) if description.present?

      excerpt = payload.values.first.dig('excerpts', 0, 'text') if payload.is_a?(Hash) && payload.values.first.is_a?(Hash)
      return excerpt.to_s.slice(0, 900) if excerpt.present?
    end
    nil
  end

  def normalize_isbn(isbn)
    isbn.to_s.gsub(/[^0-9Xx]/, '').upcase.presence
  end

  def valid_isbn13?(isbn)
    return false unless isbn.to_s.match?(/\A\d{13}\z/)
    digits = isbn.chars.map(&:to_i)
    sum = digits[0...12].each_with_index.sum { |d, i| i.even? ? d : d * 3 }
    check = (10 - (sum % 10)) % 10
    check == digits[12]
  end

  def valid_isbn10?(isbn)
    return false unless isbn.to_s.match?(/\A\d{9}[\dX]\z/)
    digits = isbn.chars.map { |c| c == 'X' ? 10 : c.to_i }
    checksum = digits.each_with_index.sum { |d, i| d * (10 - i) }
    (checksum % 11).zero?
  end

  def title_author_match?(submitted, found)
    return false if submitted.blank? || found.blank?
    submitted_norm = normalize_text(submitted)
    found_norm = normalize_text(found)
    submitted_norm == found_norm || submitted_norm.include?(found_norm) || found_norm.include?(submitted_norm)
  end

  def normalize_text(text)
    text.to_s.downcase.gsub(/[^a-z0-9\s]/, ' ').squeeze(' ').strip
  end

  def first_present(*values)
    values.find(&:present?)
  end

  def pretty_json(value)
    return '{}' if value.blank?
    JSON.pretty_generate(value)
  rescue StandardError
    value.to_s
  end
end
