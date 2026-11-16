class IgdbFrenchTitle < ApplicationRecord
  before_validation :normalize_name

  validates :normalized_name, presence: true
  validates :igdb_id, presence: true, uniqueness: true
  validates :igdb_game_id, presence: true
  validates :name, presence: true

  def self.sync
    offset = 0
    loop do
      page = IgdbService.post("alternative_names", %(fields name,game; where comment = "French title"; sort id asc; limit 500; offset #{offset};))
      raise "IGDB n'a pas répondu (offset #{offset})" unless page
      page.each do |title|
        find_or_initialize_by(igdb_id: title["id"]).update!(igdb_game_id: title["game"], name: title["name"])
      end
      break if page.size < 500
      offset += 500
    end
    count
  end

  private

  def normalize_name
    self.normalized_name = IgdbService.normalize_title(name)
  end
end
