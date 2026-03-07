class Admin::BooksController < Admin::BaseController
  before_action :set_book, only: [:show, :edit, :update, :destroy, :approve, :reject, :flag, :unflag]

  def index
    @books = Book.includes(:user).order(created_at: :desc)
    @books = @books.where(submission_status: params[:status]) if params[:status].present?
    @books = @books.flagged if params[:flagged] == 'true'

    @pending_count = Book.pending_review.count
    @flagged_count = Book.flagged.count
  end

  def show
    @labels = @book.labels.includes(:location)
    @finds  = @book.finds.includes(:user)
  end

  def edit; end

  def update
    if @book.update(book_params)
      redirect_to admin_book_path(@book), notice: "Book updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @book.destroy
    redirect_to admin_books_path, notice: "Book deleted."
  end

  def approve
    @book.update!(submission_status: 'approved')
    # Create the label now that we've approved — use preferred location if set
    if @book.preferred_location_id.present? && @book.labels.none?
      Label.create!(
        book:     @book,
        location: @book.preferred_location,
        user:     @book.user
      )
    end
    redirect_back fallback_location: admin_book_path(@book), notice: "✅ Book approved! Label created."
  end

  def reject
    reason = params[:rejection_reason].presence || "Did not meet our submission guidelines."
    @book.update!(submission_status: 'rejected', rejection_reason: reason)
    redirect_back fallback_location: admin_book_path(@book), notice: "Book rejected."
  end

  def flag
    @book.update!(flagged: true)
    redirect_back fallback_location: admin_books_path, notice: "Book flagged for review."
  end

  def unflag
    @book.update!(flagged: false)
    redirect_back fallback_location: admin_books_path, notice: "Flag cleared."
  end

  private

  def set_book
    @book = Book.find(params[:id])
  end

  def book_params
    params.require(:book).permit(:title, :author, :isbn, :status, :front_cover, :back_cover,
                                 :book_condition, :submission_notes, :submission_status,
                                 :rejection_reason, :flagged)
  end
end