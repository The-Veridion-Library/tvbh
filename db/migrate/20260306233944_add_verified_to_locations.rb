class AddVerifiedToLocations < ActiveRecord::Migration[8.1]
  def change
    add_column :locations, :verified, :boolean
    add_column :locations, :verified_at, :datetime
    add_column :locations, :verified_by, :integer
  end
end
