class CreateDecidimUserExtensions < ActiveRecord::Migration[5.2]
  def change
    create_table :decidim_user_extensions do |t|
      t.string :address
      t.integer :birth_year
      t.integer :gender
      t.string :occupation
      t.references :decidim_user, foreign_key: true

      t.timestamps
    end
  end
end
