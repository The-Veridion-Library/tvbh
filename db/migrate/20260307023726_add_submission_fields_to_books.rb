class AddSubmissionFieldsToBooks < ActiveRecord::Migration[8.1]
  def change
    add_column :books, :book_condition, :string
    add_column :books, :front_cover, :string
    add_column :books, :back_cover, :string
    add_column :books, :submission_notes, :text
    add_column :books, :preferred_location_id, :integer
    add_column :books, :submission_status, :string
    add_column :books, :rejection_reason, :text
  end
end
