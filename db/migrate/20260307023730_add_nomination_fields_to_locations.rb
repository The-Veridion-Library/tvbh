class AddNominationFieldsToLocations < ActiveRecord::Migration[8.1]
  def change
    add_column :locations, :nomination_status, :string
    add_column :locations, :website, :string
    add_column :locations, :contact_name, :string
    add_column :locations, :nomination_notes, :text
    add_column :locations, :nominated_by, :integer
  end
end
