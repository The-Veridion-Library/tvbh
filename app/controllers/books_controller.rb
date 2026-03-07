class BooksController < ApplicationController
  before_action :authenticate_user!

  def index
    # Only show approved books publicly
    @books = Book.approved.includes(:user, :labels).order(created_at: :desc)
    # Also show the current user's pending/rejected books to themselves
    @my_pending  = current_user.books.pending_review.order(created_at: :desc)
    @my_rejected = current_user.books.rejected.order(created_at: :desc)
  end

  def new
    @book = Book.new
    @locations = Location.partners.order(:name)
  end

  def create
    @book = current_user.books.build(book_params)
    # No label created yet — admin must approve first
    if @book.save
      redirect_to book_path(@book), notice: "Thanks! Your submission is under review. We'll notify you once it's approved."
    else
      @locations = Location.partners.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @book = Book.find(params[:id])
    # Only owner or admin can see pending/rejected books
    unless @book.approved? || @book.user == current_user || current_user.admin?
      redirect_to books_path, alert: "That book isn't available."
      return
    end

    # Only show QR if approved AND owner
    if @book.approved? && @book.user == current_user
      @label = @book.labels.active.last
      if @label
        qr = RQRCode::QRCode.new(scan_find_url(@label.qr_code))
        @qr_svg = qr.as_svg(
          offset: 0, color: "000",
          shape_rendering: "crispEdges",
          module_size: 4, standalone: true
        )
      end
    end
  end

  def report
    @book = Book.find(params[:id])
    @book.update!(flagged: true)
    redirect_to book_path(@book), notice: "Book reported. Our team will review it."
  end

  private

  def book_params
    params.require(:book).permit(
      :title, :author, :isbn,
      :book_condition,
      :front_cover, :back_cover,
      :submission_notes,
      :preferred_location_id
    )
  end
end