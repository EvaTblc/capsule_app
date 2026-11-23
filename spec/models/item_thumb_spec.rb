require "rails_helper"

RSpec.describe Item, "vignette des photos" do
  it ":thumb réduit la photo en 300 × 400 (au lieu de la photo d'origine, souvent plusieurs Mo)" do
    item = create(:item)
    item.images.attach(io: File.open(Rails.root.join("spec/fixtures/files/figurine.jpg")), filename: "photo.jpg", content_type: "image/jpeg")

    thumb = item.images.first.variant(:thumb).processed
    image = MiniMagick::Image.read(thumb.download)
    expect([ image.width, image.height ]).to eq([ 300, 400 ])
  end
end
