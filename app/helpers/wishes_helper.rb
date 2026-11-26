module WishesHelper

  def wish_price(wish)
    number_to_currency(wish.max_price, precision: wish.max_price.frac.zero? ? 0 : 2)
  end
end
