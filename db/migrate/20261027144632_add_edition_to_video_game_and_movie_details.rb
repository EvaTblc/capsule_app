class AddEditionToVideoGameAndMovieDetails < ActiveRecord::Migration[8.1]
  def change
    # Édition du produit possédé (« Collector », « Steelbook »...), lue sur la boîte au scan ou saisie à la main
    add_column :video_game_details, :edition, :string
    add_column :movie_details, :edition, :string
  end
end
