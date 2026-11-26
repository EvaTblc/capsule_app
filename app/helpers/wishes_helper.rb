module WishesHelper
  def wish_price(wish)
    number_to_currency(wish.max_price, precision: wish.max_price.frac.zero? ? 0 : 2)
  end

  # Prix maximum dans le champ du formulaire : « 20 » ou « 12.50 », pas « 20.0 » (BigDecimal brut)
  def wish_price_input(wish)
    return if wish.max_price.nil?

    wish.max_price.frac.zero? ? wish.max_price.to_i : format("%.2f", wish.max_price)
  end
end
