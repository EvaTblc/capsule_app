namespace :platforms do
  desc "Remplace les noms de plateformes IGDB par ceux de l'appli et signale celles à corriger à la main. " \
       "Mode essai par défaut (rien n'est enregistré) ; APPLY=1 pour écrire"
  task cleanup: :environment do
    apply = ENV["APPLY"] == "1"
    puts apply ? "Mode réel : les changements sont enregistrés." : "Mode essai : rien n'est enregistré (APPLY=1 pour écrire)."

    results = PlatformCleanup.run(apply: apply)
    results.each do |detail, status, value|
      next if status == :ok
      line = "« #{status.to_s.ljust(8)} ##{detail.id} #{detail.item&.title} »"
      line += status == :fix ? " → #{value}" : " : #{value}"
      puts line
    end
    puts "\nBilan : #{results.map { |_detail, status, _value| status }.tally.map { |status, count| "#{status} #{count}" }.join(', ')}"
  end
end
