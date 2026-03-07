class AddSeededToBadges < ActiveRecord::Migration[8.1]
  def change
    add_column :badges, :seeded, :boolean
  end
end
