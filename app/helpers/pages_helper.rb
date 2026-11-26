# Profil (style « Pilule »)
module PagesHelper
  # Pastille d'un ami sans photo : une teinte douce par personne (toujours la même), avec l'initiale de son e-mail
  AVATAR_TINTS = [
    "bg-pink-100 text-pink-800", "bg-teal-100 text-teal-800", "bg-amber-100 text-amber-800",
    "bg-blue-100 text-blue-800", "bg-violet-100 text-violet-800", "bg-emerald-100 text-emerald-800"
  ].freeze

  def avatar_tint(user) = AVATAR_TINTS[user.id.to_i % AVATAR_TINTS.size]

  # Pastille ronde d'une personne : sa photo de profil (Google) si elle en a une, sinon son initiale
  def person_avatar(user, size: "w-10 h-10")
    if user.avatar_url.present?
      tag.img(src: user.avatar_url, alt: "", class: "#{size} shrink-0 rounded-full object-cover")
    else
      tag.span(user.email[0].upcase, aria: { hidden: true },
               class: "#{size} shrink-0 rounded-full #{avatar_tint(user)} font-extrabold flex items-center justify-center")
    end
  end
end
