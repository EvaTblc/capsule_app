# Écrans d'entrée (accueil, connexion, inscription, mot de passe) : style « autocollants » de l'identité Capsule
# (contours encre, ombres franches). Classes communes, pour que les formulaires restent identiques d'un écran à l'autre
module EntryHelper
  ENTRY_FIELD = "block border-[2.5px] border-ink rounded-[14px] bg-[#faf7ff] px-3.5 pt-1.5 pb-1 " \
                "focus-within:border-purple-700 focus-within:ring-2 focus-within:ring-purple-300".freeze
  ENTRY_LABEL = "block text-xs font-extrabold text-purple-800 leading-tight".freeze
  ENTRY_INPUT = "block w-full h-[28px] border-0 bg-transparent p-0 font-sans text-base text-ink " \
                "placeholder:text-[#6b6478] focus:outline-none focus:ring-0".freeze
  ENTRY_BUTTON = "w-full h-14 border-[2.5px] border-ink rounded-2xl bg-purple-700 text-white text-[19px] font-extrabold " \
                 "shadow-[4px_4px_0_var(--color-ink)] cursor-pointer transition-transform " \
                 "active:translate-x-0.5 active:translate-y-0.5 active:shadow-[2px_2px_0_var(--color-ink)]".freeze
  ENTRY_LINK = "font-extrabold text-purple-800 hover:text-purple-950".freeze

  def entry_field_class = ENTRY_FIELD
  def entry_label_class = ENTRY_LABEL
  def entry_input_class = ENTRY_INPUT
  def entry_button_class = ENTRY_BUTTON
  def entry_link_class = ENTRY_LINK
end
