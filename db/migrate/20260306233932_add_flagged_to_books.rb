class AddFlaggedToBooks < ActiveRecord::Migration[8.1]
  def change
    add_column :books, :flagged, :boolean
  end
end
