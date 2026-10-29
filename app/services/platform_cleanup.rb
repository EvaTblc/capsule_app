class PlatformCleanup
  # Que faire de la plateforme enregistrée sur un jeu :
  # - [:ok, valeur]       déjà une plateforme de l'appli (ou vide) : rien à faire
  # - [:fix, nouvelle]    nom IGDB reconnu : à remplacer par la plateforme de l'appli
  # - [:list, valeur]     liste de plusieurs plateformes (ancien bug) : à corriger à la main
  # - [:unknown, valeur]  inconnue : à corriger à la main

  def self.verdict(platform)
    translation = VideoGameDetail::IGDB_PLATFORMS[platform]
    if platform.blank?
      [ :ok, platform ]
    elsif VideoGameDetail::PLATFORMS.include?(platform)
      [ :ok, platform ]
    elsif platform.include?(",")
      [ :list, platform ]
    elsif translation
      [ :fix, translation ]
    else
      [ :unknown, platform ]
    end
  end
end
