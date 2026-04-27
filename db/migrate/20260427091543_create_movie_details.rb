class CreateMovieDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :movie_details do |t|
      t.string :director
      t.integer :year
      t.string :studio
      t.string :format

      t.timestamps
    end
  end
end
