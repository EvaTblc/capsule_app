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

  # Verdict de chaque jeu et corrections noms IGDB - apply: false par défaut
  # pour ne rien enregistrer
  def self.run(apply: false)
    VideoGameDetail.find_each.map do |detail|
      status, value = verdict(detail.platform)
      if apply && status == :fix
        detail.update!(platform: value)
      end
      [ detail, status, value ]
    end
  end
end
