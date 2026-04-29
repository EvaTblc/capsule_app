class AddDescriptionToMovieDetails < ActiveRecord::Migration[8.1]
  def change
    add_column :movie_details, :description, :text
  end
end
