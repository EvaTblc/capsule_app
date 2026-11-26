module WishesHelper
  def wish_price(wish)
    euros(wish.max_price)
  end

  # Prix à la française : « 20 € », mais « 12,50 € » (les centimes seulement s'il y en a)
  def euros(price)
    # Espace insécable avant « € » : le prix ne se coupe jamais en fin de ligne
    number_to_currency(price, precision: price.frac.zero? ? 0 : 2, format: "%n\u00a0%u")
  end

  # Prix maximum dans le champ du formulaire : « 20 » ou « 12.50 », pas « 20.0 » (BigDecimal brut)
  def wish_price_input(wish)
    return if wish.max_price.nil?

    wish.max_price.frac.zero? ? wish.max_price.to_i : format("%.2f", wish.max_price)
  end
end
