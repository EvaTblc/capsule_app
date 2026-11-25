# Écrans d'entrée (accueil, connexion, inscription, mot de passe) : style « Pilule » de l'identité Capsule
# (fond blanc cassé, champs arrondis, boutons en forme de capsule). Classes communes, pour que les formulaires restent
# identiques d'un écran à l'autre
module EntryHelper
  ENTRY_LABEL = "block mb-1.5 px-1 text-[13px] font-semibold text-stone-700".freeze
  ENTRY_INPUT = "block w-full h-[50px] rounded-2xl border-[1.5px] border-stone-200 bg-white px-4 text-base text-ink " \
                "placeholder:text-gray-500 focus:outline-none focus:border-purple-600 focus:ring-2 focus:ring-purple-200".freeze
  ENTRY_BUTTON = "w-full h-14 rounded-full bg-ink text-white text-[17px] font-bold cursor-pointer hover:bg-black " \
                 "flex items-center justify-center gap-2.5".freeze
  ENTRY_LINK = "font-bold text-ink underline-offset-2 hover:text-purple-800 hover:underline".freeze

  ARROW = '<svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" ' \
          'stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14M13 6l6 6-6 6"/></svg>'.html_safe.freeze

  def entry_label_class = ENTRY_LABEL
  def entry_input_class = ENTRY_INPUT
  def entry_button_class = ENTRY_BUTTON
  def entry_link_class = ENTRY_LINK

  # Texte du bouton principal, suivi de la pastille violette à flèche (signature des boutons Capsule)
  def entry_button_content(label)
    safe_join([ label, tag.span(ARROW, aria: { hidden: true },
                                class: "w-[30px] h-[30px] rounded-full bg-purple-700 flex items-center justify-center") ])
  end

  def entry_submit(form, label)
    form.button(type: "submit", class: entry_button_class) { entry_button_content(label) }
  end
end
