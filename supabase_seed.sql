-- Supabase seed file for Memorezar suggestion_packs
-- Generated from ios/Memorezar/Data/Models/SuggestionPack.swift

CREATE TABLE IF NOT EXISTS suggestion_packs (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  cover_search_query TEXT,
  cover_url TEXT,
  version INTEGER NOT NULL DEFAULT 1,
  sort_order INTEGER NOT NULL DEFAULT 0,
  translations JSONB,
  quotes JSONB NOT NULL
);

-- Migration: add translations column if table already exists
-- ALTER TABLE suggestion_packs ADD COLUMN IF NOT EXISTS translations JSONB;

-- Pack 1: Ruhi Book 1 Unit 1
INSERT INTO suggestion_packs (id, name, description, cover_search_query, cover_url, version, sort_order, quotes)
VALUES (
  'ruhi-book1-unit1',
  'Ruhi Book 1: Reflections on the Life of the Spirit — Unit 1',
  'Quotations on the spiritual life, truthfulness, kindness, and backbiting.',
  'spiritual meditation light',
  'https://tcaaozzijpgbaqzpnahl.supabase.co/storage/v1/object/public/pack-covers/ruhi_book1.jpg',
  1,
  0,
  $$[
    {
      "title": "The betterment of the world",
      "text": "The betterment of the world can be accomplished through pure and goodly deeds, through commendable and seemly conduct.",
      "translations": {
        "es": {"title": "El mejoramiento del mundo", "text": "El mejoramiento del mundo puede ser logrado por medio de hechos puros y hermosos, por medio de una conducta loable y correcta."},
        "fr": {"title": "L'amélioration du monde", "text": "L'amélioration du monde peut être réalisée par des actes bons et purs, par une conduite louable et bienséante."},
        "it": {"title": "Il miglioramento del mondo", "text": "Il miglioramento del mondo può ottenersi mediante azioni pure e sante e una condotta lodevole e decorosa."},
        "nl": {"title": "De verbetering van de wereld", "text": "De verbetering van de wereld kan worden verwezenlijkt door zuivere en voortreffelijke daden, door lofwaardig en betamelijk gedrag."}
      }
    },
    {
      "title": "Beware, O people of Bahá",
      "text": "Beware, O people of Bahá, lest ye walk in the ways of them whose words differ from their deeds.",
      "translations": {
        "es": {"title": "Cuidaos, oh pueblo de Bahá", "text": "Cuidaos, oh pueblo de Bahá, no sea que andéis por las sendas de aquellos cuyas palabras difieren de sus hechos."},
        "fr": {"title": "Gardez-vous, ô peuple de Bahá", "text": "Gardez-vous, ô peuple de Bahá, de marcher dans les voies de ceux dont les actes démentent les paroles."},
        "it": {"title": "Badate, o genti di Bahá", "text": "Badate, o genti di Bahá, a non seguire le orme di coloro le cui parole differiscono dalle loro azioni."},
        "nl": {"title": "Hoed u, o volk van Bahá", "text": "Hoed u, o volk van Bahá, dat gij niet de wegen bewandelt van hen wier woorden verschillen van hun daden."}
      }
    },
    {
      "title": "O Son of Being! Bring thyself to account",
      "text": "O Son of Being! Bring thyself to account each day ere thou art summoned to a reckoning; for death, unheralded, shall come upon thee and thou shalt be called to give account for thy deeds.",
      "translations": {
        "es": {"title": "¡Oh Hijo del Ser! Pídete cuentas", "text": "¡Oh Hijo del Ser! Pídete cuentas a ti mismo cada día, antes de ser llamado a rendirlas; pues la muerte te llegará sin aviso y habrás de responder por tus hechos."},
        "fr": {"title": "Ô fils de l'existence ! Fais ton examen", "text": "Ô fils de l'existence ! Fais ton examen de conscience chaque jour avant d'être appelé à comparaître en jugement."},
        "it": {"title": "O Figlio dell'Essere! Fa' ogni giorno", "text": "O Figlio dell'Essere! Fa' ogni giorno un esame di coscienza prima che tu sia chiamato a render conto di te stesso..."},
        "nl": {"title": "O Zoon van het Bestaan! Geef u rekenschap", "text": "O Zoon van het Bestaan! Geef u iedere dag rekenschap van uw doen en laten, eer gij ter verantwoording wordt geroepen…"}
      }
    },
    {
      "title": "Let deeds, not words",
      "text": "Say: O brethren! Let deeds, not words, be your adorning.",
      "translations": {
        "es": {"title": "Sean los hechos, no las palabras", "text": "Decid: ¡Oh hermanos! Sean los hechos, no las palabras, vuestro adorno."},
        "fr": {"title": "Que les actes et non les mots", "text": "Dites : ô frères, que les actes et non les mots soient votre ornement !"},
        "it": {"title": "Opere e non parole", "text": "Dite, fratelli! Opere e non parole siano il vostro ornamento."},
        "nl": {"title": "Laat daden, niet woorden", "text": "Hoor o broeders! Laat daden, niet woorden u sieren."}
      }
    },
    {
      "title": "Holy words and pure deeds",
      "text": "Holy words and pure and goodly deeds ascend unto the heaven of celestial glory.",
      "translations": {
        "es": {"title": "Las palabras santas y los hechos puros", "text": "Las palabras santas y los hechos puros y buenos ascienden al cielo de la gloria celestial."},
        "fr": {"title": "De pieuses paroles", "text": "De pieuses paroles, des actes purs et saints, s'élèvent jusqu'au ciel de la gloire divine."},
        "it": {"title": "Le sante parole", "text": "Le sante parole e le azioni pure e pie ascendono al paradiso della gloria celestiale."},
        "nl": {"title": "Heilige woorden en zuivere daden", "text": "Heilige woorden en zuivere, voortreffelijke daden stijgen op naar de hemel van goddelijke heerlijkheid."}
      }
    },
    {
      "title": "Truthfulness is the foundation",
      "text": "Truthfulness is the foundation of all human virtues.",
      "translations": {
        "es": {"title": "La veracidad es la base", "text": "La veracidad es la base de todas las virtudes humanas."},
        "fr": {"title": "La véracité est le fondement", "text": "La véracité est le fondement de toutes les vertus humaines."},
        "it": {"title": "La sincerità è la base", "text": "La sincerità è la base di tutte le virtù umane."},
        "nl": {"title": "Waarheidsliefde is de grondslag", "text": "Waarheidsliefde is de grondslag van alle menselijke deugden."}
      }
    },
    {
      "title": "Without truthfulness, progress is impossible",
      "text": "Without truthfulness progress and success, in all the worlds of God, are impossible for any soul.",
      "translations": {
        "es": {"title": "Sin la veracidad, el progreso es irrealizable", "text": "Sin la veracidad, el progreso y el buen éxito, en todos los mundos de Dios, son irrealizables para cualquier alma."},
        "fr": {"title": "Sans la véracité", "text": "Sans la véracité, le progrès et le succès, dans tous les mondes de Dieu, sont impossibles pour toute âme."},
        "it": {"title": "Senza sincerità", "text": "Senza sincerità è impossibile alcun progresso o successo nei mondi di Dio."},
        "nl": {"title": "Zonder waarheidsliefde", "text": "Zonder waarheidsliefde zijn vooruitgang en succes in alle werelden van God onmogelijk voor een ziel."}
      }
    },
    {
      "title": "Beautify your tongues",
      "text": "Beautify your tongues, O people, with truthfulness, and adorn your souls with the ornament of honesty.",
      "translations": {
        "es": {"title": "Hermosead vuestras lenguas", "text": "Hermosead vuestras lenguas, oh pueblo, con la veracidad, y adornad vuestras almas con el ornamento de la honestidad."},
        "fr": {"title": "Parez vos langues de la véracité", "text": "Parez vos langues de la véracité, ô peuple, et ornez vos âmes de la parure de l'honnêteté."},
        "it": {"title": "Abbellite le vostre lingue", "text": "Abbellite le vostre lingue con la sincerità, o uomini, e adornate le vostre anime con la gemma dell'onestà."},
        "nl": {"title": "Sier uw tong met waarheidsliefde", "text": "O mensen, sier uw tong met waarheidsliefde en tooi uw ziel met het kleinood van eerlijkheid."}
      }
    },
    {
      "title": "Let your eye be chaste",
      "text": "Let your eye be chaste, your hand faithful, your tongue truthful and your heart enlightened.",
      "translations": {
        "es": {"title": "Sea casto tu ojo", "text": "Sea casto tu ojo, fiel tu mano, veraz tu lengua y tu corazón iluminado."},
        "fr": {"title": "Que vos yeux soient chastes", "text": "Que vos yeux soient chastes, votre main fidèle, votre langue véridique et votre cœur éclairé."},
        "it": {"title": "Sia casto il vostro occhio", "text": "Sia casto il vostro occhio, fedele la mano, verace la lingua e illuminato il cuore."},
        "nl": {"title": "Laat uw oog kuis zijn", "text": "Laat uw oog kuis zijn, uw hand betrouwbaar, uw tong waarheidsgetrouw en uw hart verlicht."}
      }
    },
    {
      "title": "They who dwell within the tabernacle",
      "text": "They who dwell within the tabernacle of God, and are established upon the seats of everlasting glory, will refuse, though they be dying of hunger, to stretch their hands to seize unlawfully the property of their neighbor, however vile and worthless he may be.",
      "translations": {
        "es": {"title": "Quienes moran dentro del tabernáculo de Dios", "text": "Quienes moran dentro del tabernáculo de Dios, y están establecidos en los asientos de gloria sempiterna, se rehusarían, aunque estuviesen muriendo de hambre, a extender las manos para apoderarse ilegítimamente de los bienes de su prójimo, por vil e indigno que éste fuere."},
        "fr": {"title": "Ceux qui demeurent sous la tente de Dieu", "text": "Ceux qui demeurent sous la tente de Dieu, qui sont installés sur le siège de gloire éternelle refuseront, mourraient-ils de faim, de mettre la main sur les biens de leur voisin, aussi vil et méprisable qu'il soit, et de se les approprier illégalement."},
        "it": {"title": "Coloro che dimorano nel tabernacolo di Dio", "text": "Coloro che dimorano nel tabernacolo di Dio e si sono assisi sui seggi della gloria eterna, anche se muoiono di fame, si rifiutano di allungar la mano per impadronirsi illecitamente dei beni del prossimo, per quanto vile e insignificante egli sia."},
        "nl": {"title": "Zij die in de Tabernakel Gods verblijven", "text": "Zij die in de Tabernakel Gods verblijven en gevestigd zijn op de zetels van eeuwigdurende heerlijkheid zullen, ook al sterven zij van de honger, weigeren hun arm uit te strekken om het eigendom van hun naaste onrechtmatig in beslag te nemen, hoe verachtelijk en nietswaardig deze ook moge zijn."}
      }
    },
    {
      "title": "A kindly tongue",
      "text": "A kindly tongue is the lodestone of the hearts of men. It is the bread of the spirit, it clotheth the words with meaning, it is the fountain of the light of wisdom and understanding...",
      "translations": {
        "es": {"title": "Una lengua amable", "text": "Una lengua amable es el imán de los corazones de los hombres. Es el pan del espíritu, reviste las palabras de significado, es la fuente de la luz de la sabiduría y el entendimiento..."},
        "fr": {"title": "Un langage bienveillant", "text": "Un langage bienveillant est l'aimant qui attire le cœur des hommes. C'est le pain de l'esprit, il revêt les mots de signification, il est la source de la lumière de sagesse et de compréhension."},
        "it": {"title": "Una lingua benevola", "text": "Una lingua benevola è una calamita per i cuori degli uomini e pane per lo spirito, riveste di significato le parole ed è sorgente della luce della saggezza e della comprensione..."},
        "nl": {"title": "Een aangename spraak", "text": "Een aangename spraak is de magneet van 's mensen hart. Ze is het brood van de geest, ze geeft betekenis aan de woorden, ze is de bron van het licht van wijsheid en begrip…"}
      }
    },
    {
      "title": "Conflict and contention are not permitted",
      "text": "O ye beloved of the Lord! In this sacred Dispensation, conflict and contention are in no wise permitted. Every aggressor deprives himself of God's grace.",
      "translations": {
        "es": {"title": "El conflicto y la contienda no están permitidos", "text": "¡Oh amados del Señor! En esta sagrada Dispensación, el conflicto y la contienda no están en modo alguno permitidos. Todo agresor se priva a sí mismo de la gracia de Dios."},
        "fr": {"title": "Les conflits et les discordes sont interdits", "text": "O vous, bien-aimés du Seigneur ! En cette dispensation sacrée, les conflits et les discordes sont rigoureusement interdits. Tout agresseur se prive de la grâce de Dieu."},
        "it": {"title": "I conflitti e le contese non sono permessi", "text": "O amati del Signore! In questa sacra Dispensazione i conflitti e le contese non sono in alcun modo permessi. Ogni aggressore si priva della grazia di Dio."},
        "nl": {"title": "Tweedracht en strijd zijn niet toegestaan", "text": "O gij geliefden des Heren! In deze heilige Beschikking zijn tweedracht en strijd op generlei wijze toegestaan. Iedereen die daarop een aanval doet, berooft zichzelf van Gods genade."}
      }
    },
    {
      "title": "Nothing can inflict greater harm",
      "text": "Nothing whatever can, in this Day, inflict a greater harm upon this Cause than dissension and strife, contention, estrangement and apathy, among the loved ones of God.",
      "translations": {
        "es": {"title": "Nada puede infligir mayor daño", "text": "Nada, absolutamente nada, puede en este Día infligir mayor daño a esta Causa que la disensión y la contienda, la pugna, el alejamiento y la apatía entre los amados de Dios."},
        "fr": {"title": "Absolument rien ne peut nuire davantage", "text": "Absolument rien, en ce jour, ne peut nuire davantage à cette cause que la discorde, les dissensions, les disputes, la désaffection et l'apathie chez les aimés de Dieu."},
        "it": {"title": "Assolutamente nulla può infliggere", "text": "Assolutamente nulla può, in questo Giorno, infliggere un danno maggiore a questa Causa, della discordia e della lotta, delle contese, dell'estraniamento e dell'apatia fra gli amati di Dio."},
        "nl": {"title": "Niets kan groter schade toebrengen", "text": "In deze Dag kan niets groter schade aan deze Zaak toebrengen dan tweedracht en strijd, twist, vervreemding en apathie onder de geliefden van God."}
      }
    },
    {
      "title": "Do not be content with friendship in words",
      "text": "Do not be content with showing friendship in words alone, let your heart burn with loving-kindness for all who may cross your path.",
      "translations": {
        "es": {"title": "No os contentéis con demostrar amistad", "text": "No os contentéis con demostrar amistad solo con palabras; dejad que vuestro corazón se encienda con amorosa bondad hacia todos los que se crucen en vuestro camino."},
        "fr": {"title": "Ne vous contentez pas des paroles amicales", "text": "Ne vous contentez pas des paroles amicales, mais que votre cœur soit embrasé par une affectueuse bonté envers tous ceux qui peuvent croiser votre chemin."},
        "it": {"title": "Non vi accontentate di mostrare amicizia", "text": "Non vi accontentate di mostrare amicizia solamente a parole. Fate che il vostro cuore arda di amorevole gentilezza per tutti quelli che incontrate sul vostro cammino."},
        "nl": {"title": "Wees niet tevreden met vriendschap in woorden", "text": "Wees niet tevreden met het tonen van vriendschap in woorden alléén, maar laat uw hart branden van liefdevolle toegenegenheid jegens allen die uw weg mogen kruisen."}
      }
    },
    {
      "title": "A thought of war",
      "text": "When a thought of war comes, oppose it by a stronger thought of peace. A thought of hatred must be destroyed by a more powerful thought of love.",
      "translations": {
        "es": {"title": "Un pensamiento de guerra", "text": "Cuando se os presente un pensamiento de guerra, oponedle un pensamiento más fuerte de paz. Un pensamiento de odio debe ser destruido por un pensamiento más poderoso de amor."},
        "fr": {"title": "À une pensée de guerre", "text": "À une pensée de guerre, opposez une plus forte pensée de paix. Une pensée de haine doit être détruite par une puissante pensée d'amour."},
        "it": {"title": "Un pensiero di guerra", "text": "Quando viene un pensiero di guerra, opponetegli un più forte pensiero di pace. Un pensiero d'odio deve essere distrutto da un più potente pensiero d'amore."},
        "nl": {"title": "Een oorlogsgedachte", "text": "Wanneer een oorlogsgedachte opkomt, bestrijd deze met een sterkere vredes-gedachte. Een haatdragende gedachte moet worden vernietigd door een krachtiger gedachte van liefde."}
      }
    },
    {
      "title": "Backbiting quencheth the light",
      "text": "...backbiting quencheth the light of the heart, and extinguisheth the life of the soul.",
      "translations": {
        "es": {"title": "La murmuración apaga la luz", "text": "...la murmuración apaga la luz del corazón y extingue la vida del alma."},
        "fr": {"title": "La médisance éteint le feu du cœur", "text": "...la médisance éteint le feu du cœur et étouffe la vie de l'âme."},
        "it": {"title": "La maldicenza spegne la luce", "text": "...la maldicenza spegne la luce del cuore e distrugge la vita dell'anima."},
        "nl": {"title": "Kwaadspreken dooft het licht", "text": "…kwaadspreken dooft het licht van het hart en blust het leven van de ziel."}
      }
    },
    {
      "title": "Breathe not the sins of others",
      "text": "Breathe not the sins of others so long as thou art thyself a sinner.",
      "translations": {
        "es": {"title": "No murmures los pecados de otros", "text": "¡Oh Hijo del Hombre! No murmures los pecados de otros mientras seas tú mismo un pecador. Si desobedecieres este mandamiento, serás maldito, y de esto doy Yo testimonio."},
        "fr": {"title": "Ne souffle mot des péchés des autres", "text": "Ne souffle mot des péchés des autres aussi longtemps que tu es toi-même un pécheur."},
        "it": {"title": "Non palesare i peccati altrui", "text": "Non palesare i peccati altrui perché anche tu sei un peccatore."},
        "nl": {"title": "Gewaag niet van de zonden van anderen", "text": "Gewaag niet van de zonden van anderen zolang gij zelf een zondaar zijt."}
      }
    },
    {
      "title": "Speak no evil",
      "text": "Speak no evil, that thou mayest not hear it spoken unto thee, and magnify not the faults of others that thine own faults may not appear great...",
      "translations": {
        "es": {"title": "No hables mal", "text": "No hables mal, para que no lo oigas dicho a ti, y no magnifiques las faltas de los demás para que tus propias faltas no parezcan grandes..."},
        "fr": {"title": "Ne dis pas de mal", "text": "Ne dis pas de mal afin de ne pas en entendre dire à toi, ne grossis pas les fautes des autres pour que les tiennes ne paraissent pas graves..."},
        "it": {"title": "Non dire il male", "text": "Non dire il male, affinché tu possa non udire il male che ti vien detto, e non esagerare le colpe degli altri, affinché le tue possano non apparire grandi..."},
        "nl": {"title": "Spreek geen kwaad", "text": "Spreek geen kwaad, opdat het niet tegen u gesproken wordt en overdrijf niet de fouten van anderen, opdat uw eigen fouten niet groot lijken…"}
      }
    },
    {
      "title": "O Son of Being! How couldst thou forget",
      "text": "O Son of Being! How couldst thou forget thine own faults and busy thyself with the faults of others? Whoso doeth this is accursed of Me.",
      "translations": {
        "es": {"title": "¡Oh Hijo del Ser! ¿Cómo has podido olvidar", "text": "¡Oh Hijo del Ser! ¿Cómo has podido olvidar tus propias faltas y ocuparte de las faltas de los demás? Quien así actúa es maldecido por Mí."},
        "fr": {"title": "Ô fils de l'existence ! Comment peux-tu oublier", "text": "Ô fils de l'existence ! Comment peux-tu oublier tes propres défauts et t'occuper de ceux d'autrui ?"},
        "it": {"title": "O Figlio dell'Essere! Come hai potuto", "text": "O Figlio dell'Essere! Come hai potuto dimenticare i tuoi falli e occuparti dei falli altrui? Chiunque fa ciò è da Me maledetto."},
        "nl": {"title": "O Zoon van het Bestaan! Hoe kunt gij", "text": "O Zoon van het Bestaan! Hoe kunt gij uw eigen fouten vergeten en u met de fouten van anderen inlaten?"}
      }
    },
    {
      "title": "Immerse yourselves in the ocean",
      "text": "Immerse yourselves in the ocean of My words, that ye may unravel its secrets, and discover all the pearls of wisdom that lie hid in its depths.",
      "translations": {
        "es": {"title": "Sumergíos en el océano de Mis palabras", "text": "Sumergíos en el océano de Mis palabras, para que descifréis sus secretos y descubráis todas las perlas de sabiduría que se hallan ocultas en sus profundidades."},
        "fr": {"title": "Immergez-vous dans l'océan de mes paroles", "text": "Immergez-vous dans l'océan de mes paroles afin d'en pénétrer les secrets et de découvrir toutes les perles de sagesse que recèlent ses profondeurs."},
        "it": {"title": "Immergetevi nell'oceano delle Mie parole", "text": "Immergetevi nell'oceano delle Mie parole per districarne i segreti e scoprire le perle di saggezza celate nelle sue profondità."},
        "nl": {"title": "Dompel u in de oceaan", "text": "Dompel u in de oceaan van Mijn woorden, opdat gij de geheimen ervan moogt ontrafelen en alle parelen van wijsheid die in de diepten daarvan verborgen liggen, moogt ontdekken."}
      }
    }
  ]$$::jsonb
);

-- Pack 2: Mark Twain
INSERT INTO suggestion_packs (id, name, description, cover_search_query, cover_url, version, sort_order, quotes)
VALUES (
  'mark-twain-quotes',
  'Mark Twain: Wit & Wisdom',
  'The most memorable quotes from America''s greatest humorist.',
  'mark twain vintage literature',
  'https://tcaaozzijpgbaqzpnahl.supabase.co/storage/v1/object/public/pack-covers/mark_twain.jpg',
  1,
  1,
  $$[
    {"title": "The secret of getting ahead", "text": "The secret of getting ahead is getting started.", "translations": null},
    {"title": "Whenever you find yourself on the side of the majority", "text": "Whenever you find yourself on the side of the majority, it is time to pause and reflect.", "translations": null},
    {"title": "Twenty years from now", "text": "Twenty years from now you will be more disappointed by the things that you didn't do than by the ones you did do. So throw off the bowlines. Sail away from the safe harbor. Catch the trade winds in your sails. Explore. Dream. Discover.", "translations": null},
    {"title": "The man who does not read", "text": "The man who does not read has no advantage over the man who cannot read.", "translations": null},
    {"title": "Kindness is the language", "text": "Kindness is the language which the deaf can hear and the blind can see.", "translations": null},
    {"title": "If you tell the truth", "text": "If you tell the truth, you don't have to remember anything.", "translations": null},
    {"title": "Courage is resistance to fear", "text": "Courage is resistance to fear, mastery of fear, not absence of fear.", "translations": null},
    {"title": "The two most important days", "text": "The two most important days in your life are the day you are born and the day you find out why.", "translations": null},
    {"title": "Keep away from people who belittle", "text": "Keep away from people who try to belittle your ambitions. Small people always do that, but the really great make you feel that you, too, can become great.", "translations": null},
    {"title": "I have never let my schooling", "text": "I have never let my schooling interfere with my education.", "translations": null}
  ]$$::jsonb
);

-- Pack 3: Einstein
INSERT INTO suggestion_packs (id, name, description, cover_search_query, cover_url, version, sort_order, quotes)
VALUES (
  'einstein-quotes',
  'Albert Einstein: Genius & Imagination',
  'Iconic quotes from the mind that reshaped our understanding of the universe.',
  'albert einstein physics science',
  'https://tcaaozzijpgbaqzpnahl.supabase.co/storage/v1/object/public/pack-covers/einstein.jpg',
  1,
  2,
  $$[
    {"title": "Imagination is more important", "text": "Imagination is more important than knowledge. Knowledge is limited. Imagination encircles the world.", "translations": null},
    {"title": "Life is like riding a bicycle", "text": "Life is like riding a bicycle. To keep your balance, you must keep moving.", "translations": null},
    {"title": "Try not to become a man of success", "text": "Try not to become a man of success, but rather try to become a man of value.", "translations": null},
    {"title": "The important thing is not to stop questioning", "text": "The important thing is not to stop questioning. Curiosity has its own reason for existing.", "translations": null},
    {"title": "In the middle of difficulty", "text": "In the middle of difficulty lies opportunity.", "translations": null},
    {"title": "A person who never made a mistake", "text": "A person who never made a mistake never tried anything new.", "translations": null},
    {"title": "Logic will get you from A to B", "text": "Logic will get you from A to B. Imagination will take you everywhere.", "translations": null},
    {"title": "The world is a dangerous place", "text": "The world is a dangerous place to live, not because of the people who are evil, but because of the people who don't do anything about it.", "translations": null},
    {"title": "Strive not to be a success", "text": "Strive not to be a success, but rather to be of value.", "translations": null},
    {"title": "We cannot solve our problems", "text": "We cannot solve our problems with the same thinking we used when we created them.", "translations": null}
  ]$$::jsonb
);
