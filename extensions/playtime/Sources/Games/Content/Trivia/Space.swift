extension Games.QuizBank {
    static let space = """
        # space.red-planet space 1
        en: Which planet is called the Red Planet? | Mars | Venus | Jupiter | Mercury
        fr: Quelle planète surnomme-t-on la planète rouge ? | Mars | Vénus | Jupiter | Mercure
        es: ¿Qué planeta es conocido como el planeta rojo? | Marte | Venus | Júpiter | Mercurio
        de: Welcher Planet wird der Rote Planet genannt? | Mars | Venus | Jupiter | Merkur
        it: Quale pianeta è chiamato il pianeta rosso? | Marte | Venere | Giove | Mercurio
        pt: Qual planeta é chamado de planeta vermelho? | Marte | Vênus | Júpiter | Mercúrio
        ja: 「赤い惑星」と呼ばれるのは？ | 火星 | 金星 | 木星 | 水星
        ko: '붉은 행성'이라고 불리는 행성은? | 화성 | 금성 | 목성 | 수성
        zh: 被称为“红色星球”的是哪颗行星？ | 火星 | 金星 | 木星 | 水星
        ar: أي كوكب يُلقّب بالكوكب الأحمر؟ | المريخ | الزهرة | المشتري | عطارد

        # space.largest-planet space 1
        en: What is the largest planet in our solar system? | Jupiter | Saturn | Neptune | Earth
        fr: Quelle est la plus grande planète du système solaire ? | Jupiter | Saturne | Neptune | La Terre
        es: ¿Cuál es el planeta más grande del sistema solar? | Júpiter | Saturno | Neptuno | La Tierra
        de: Welcher ist der größte Planet unseres Sonnensystems? | Jupiter | Saturn | Neptun | Die Erde
        it: Qual è il pianeta più grande del sistema solare? | Giove | Saturno | Nettuno | La Terra
        pt: Qual é o maior planeta do sistema solar? | Júpiter | Saturno | Netuno | A Terra
        ja: 太陽系でいちばん大きな惑星は？ | 木星 | 土星 | 海王星 | 地球
        ko: 태양계에서 가장 큰 행성은? | 목성 | 토성 | 해왕성 | 지구
        zh: 太阳系最大的行星是哪颗？ | 木星 | 土星 | 海王星 | 地球
        ar: ما أكبر كوكب في مجموعتنا الشمسية؟ | المشتري | زحل | نبتون | الأرض

        # space.sunlight-travel space 2
        en: How long does sunlight take to reach Earth? | About 8 minutes | About 8 seconds | About 8 hours | About 8 days
        fr: Combien de temps la lumière du Soleil met-elle pour atteindre la Terre ? | Environ 8 minutes | Environ 8 secondes | Environ 8 heures | Environ 8 jours
        es: ¿Cuánto tarda la luz del Sol en llegar a la Tierra? | Unos 8 minutos | Unos 8 segundos | Unas 8 horas | Unos 8 días
        de: Wie lange braucht das Sonnenlicht bis zur Erde? | Etwa 8 Minuten | Etwa 8 Sekunden | Etwa 8 Stunden | Etwa 8 Tage
        it: Quanto impiega la luce del Sole ad arrivare sulla Terra? | Circa 8 minuti | Circa 8 secondi | Circa 8 ore | Circa 8 giorni
        pt: Quanto tempo a luz do Sol leva para chegar à Terra? | Cerca de 8 minutos | Cerca de 8 segundos | Cerca de 8 horas | Cerca de 8 dias
        ja: 太陽の光が地球に届くまでにかかる時間は？ | 約8分 | 約8秒 | 約8時間 | 約8日
        ko: 햇빛이 지구에 닿는 데 걸리는 시간은? | 약 8분 | 약 8초 | 약 8시간 | 약 8일
        zh: 阳光到达地球大约需要多久？ | 约8分钟 | 约8秒 | 约8小时 | 约8天
        ar: كم يستغرق ضوء الشمس ليصل إلى الأرض؟ | نحو 8 دقائق | نحو 8 ثوانٍ | نحو 8 ساعات | نحو 8 أيام

        # space.closest-star space 2
        en: Which star is closest to Earth? | The Sun | Proxima Centauri | Sirius | Polaris
        fr: Quelle étoile est la plus proche de la Terre ? | Le Soleil | Proxima du Centaure | Sirius | L'étoile Polaire
        es: ¿Qué estrella está más cerca de la Tierra? | El Sol | Próxima Centauri | Sirio | La estrella Polar
        de: Welcher Stern ist der Erde am nächsten? | Die Sonne | Proxima Centauri | Sirius | Der Polarstern
        it: Qual è la stella più vicina alla Terra? | Il Sole | Proxima Centauri | Sirio | La stella polare
        pt: Qual estrela está mais perto da Terra? | O Sol | Próxima Centauri | Sírius | A estrela Polar
        ja: 地球にいちばん近い恒星は？ | 太陽 | プロキシマ・ケンタウリ | シリウス | 北極星
        ko: 지구에서 가장 가까운 별은? | 태양 | 프록시마 센타우리 | 시리우스 | 북극성
        zh: 离地球最近的恒星是哪颗？ | 太阳 | 比邻星 | 天狼星 | 北极星
        ar: ما أقرب نجم إلى الأرض؟ | الشمس | بروكسيما قنطورس | الشعرى اليمانية | النجم القطبي

        # space.mars-moons space 2
        *: 2 | 0 | 1 | 4
        en: How many moons does Mars have?
        fr: Combien de lunes Mars possède-t-elle ?
        es: ¿Cuántas lunas tiene Marte?
        de: Wie viele Monde hat der Mars?
        it: Quante lune ha Marte?
        pt: Quantas luas Marte tem?
        ja: 火星の衛星はいくつ？
        ko: 화성의 위성은 몇 개일까요?
        zh: 火星有几颗卫星？
        ar: كم قمرًا للمريخ؟

        # space.our-galaxy space 1
        en: What is the name of our galaxy? | The Milky Way | Andromeda | Triangulum | Sombrero
        fr: Comment s'appelle notre galaxie ? | La Voie lactée | Andromède | Le Triangle | Le Sombrero
        es: ¿Cómo se llama nuestra galaxia? | La Vía Láctea | Andrómeda | Triángulo | Sombrero
        de: Wie heißt unsere Galaxie? | Die Milchstraße | Andromeda | Dreiecksnebel | Sombrero
        it: Come si chiama la nostra galassia? | La Via Lattea | Andromeda | Triangolo | Sombrero
        pt: Como se chama a nossa galáxia? | A Via Láctea | Andrômeda | Triângulo | Sombrero
        ja: 私たちの銀河の名前は？ | 天の川銀河 | アンドロメダ銀河 | さんかく座銀河 | ソンブレロ銀河
        ko: 우리 은하의 이름은? | 우리은하(은하수) | 안드로메다은하 | 삼각형자리은하 | 솜브레로은하
        zh: 我们所在的星系叫什么？ | 银河系 | 仙女座星系 | 三角座星系 | 草帽星系
        ar: ما اسم مجرتنا؟ | درب التبانة | أندروميدا | المثلث | السمبريرو

        # space.bright-rings space 1
        en: Which planet is famous for its bright rings? | Saturn | Jupiter | Uranus | Neptune
        fr: Quelle planète est célèbre pour ses anneaux brillants ? | Saturne | Jupiter | Uranus | Neptune
        es: ¿Qué planeta es famoso por sus anillos brillantes? | Saturno | Júpiter | Urano | Neptuno
        de: Welcher Planet ist für seine hellen Ringe bekannt? | Saturn | Jupiter | Uranus | Neptun
        it: Quale pianeta è famoso per i suoi anelli luminosi? | Saturno | Giove | Urano | Nettuno
        pt: Qual planeta é famoso por seus anéis brilhantes? | Saturno | Júpiter | Urano | Netuno
        ja: 明るい環で有名な惑星は？ | 土星 | 木星 | 天王星 | 海王星
        ko: 밝은 고리로 유명한 행성은? | 토성 | 목성 | 천왕성 | 해왕성
        zh: 哪颗行星以明亮的光环闻名？ | 土星 | 木星 | 天王星 | 海王星
        ar: أي كوكب يشتهر بحلقاته اللامعة؟ | زحل | المشتري | أورانوس | نبتون

        # space.nearest-sun space 1
        en: Which planet is closest to the Sun? | Mercury | Venus | Earth | Mars
        fr: Quelle planète est la plus proche du Soleil ? | Mercure | Vénus | La Terre | Mars
        es: ¿Qué planeta está más cerca del Sol? | Mercurio | Venus | La Tierra | Marte
        de: Welcher Planet ist der Sonne am nächsten? | Merkur | Venus | Die Erde | Mars
        it: Quale pianeta è il più vicino al Sole? | Mercurio | Venere | La Terra | Marte
        pt: Qual planeta fica mais perto do Sol? | Mercúrio | Vênus | A Terra | Marte
        ja: 太陽にいちばん近い惑星は？ | 水星 | 金星 | 地球 | 火星
        ko: 태양에 가장 가까운 행성은? | 수성 | 금성 | 지구 | 화성
        zh: 离太阳最近的行星是哪颗？ | 水星 | 金星 | 地球 | 火星
        ar: ما أقرب كوكب إلى الشمس؟ | عطارد | الزهرة | الأرض | المريخ

        # space.hottest-planet space 2
        en: Which planet is the hottest? | Venus | Mercury | Mars | Jupiter
        fr: Quelle est la planète la plus chaude ? | Vénus | Mercure | Mars | Jupiter
        es: ¿Cuál es el planeta más caliente? | Venus | Mercurio | Marte | Júpiter
        de: Welcher Planet ist der heißeste? | Venus | Merkur | Mars | Jupiter
        it: Qual è il pianeta più caldo? | Venere | Mercurio | Marte | Giove
        pt: Qual é o planeta mais quente? | Vênus | Mercúrio | Marte | Júpiter
        ja: いちばん暑い惑星は？ | 金星 | 水星 | 火星 | 木星
        ko: 가장 뜨거운 행성은? | 금성 | 수성 | 화성 | 목성
        zh: 哪颗行星最热？ | 金星 | 水星 | 火星 | 木星
        ar: ما أشد الكواكب حرارة؟ | الزهرة | عطارد | المريخ | المشتري

        # space.first-moonwalk space 1
        en: Who was the first person to walk on the Moon? | Neil Armstrong | Buzz Aldrin | Yuri Gagarin | Michael Collins
        fr: Qui a été le premier à marcher sur la Lune ? | Neil Armstrong | Buzz Aldrin | Youri Gagarine | Michael Collins
        es: ¿Quién fue la primera persona en caminar sobre la Luna? | Neil Armstrong | Buzz Aldrin | Yuri Gagarin | Michael Collins
        de: Wer betrat als erster Mensch den Mond? | Neil Armstrong | Buzz Aldrin | Juri Gagarin | Michael Collins
        it: Chi fu il primo a camminare sulla Luna? | Neil Armstrong | Buzz Aldrin | Jurij Gagarin | Michael Collins
        pt: Quem foi a primeira pessoa a andar na Lua? | Neil Armstrong | Buzz Aldrin | Yuri Gagarin | Michael Collins
        ja: 月面を初めて歩いた人は？ | ニール・アームストロング | バズ・オルドリン | ユーリ・ガガーリン | マイケル・コリンズ
        ko: 달 위를 처음 걸은 사람은? | 닐 암스트롱 | 버즈 올드린 | 유리 가가린 | 마이클 콜린스
        zh: 第一个在月球上行走的人是谁？ | 尼尔·阿姆斯特朗 | 巴兹·奥尔德林 | 尤里·加加林 | 迈克尔·柯林斯
        ar: من أول إنسان مشى على القمر؟ | نيل أرمسترونغ | باز ألدرين | يوري غاغارين | مايكل كولينز

        # space.first-human space 2
        en: Who was the first human in space, in 1961? | Yuri Gagarin | Neil Armstrong | Alan Shepard | John Glenn
        fr: Qui a été le premier humain dans l'espace, en 1961 ? | Youri Gagarine | Neil Armstrong | Alan Shepard | John Glenn
        es: ¿Quién fue el primer ser humano en el espacio, en 1961? | Yuri Gagarin | Neil Armstrong | Alan Shepard | John Glenn
        de: Wer war 1961 der erste Mensch im Weltraum? | Juri Gagarin | Neil Armstrong | Alan Shepard | John Glenn
        it: Chi fu il primo essere umano nello spazio, nel 1961? | Jurij Gagarin | Neil Armstrong | Alan Shepard | John Glenn
        pt: Quem foi o primeiro ser humano no espaço, em 1961? | Yuri Gagarin | Neil Armstrong | Alan Shepard | John Glenn
        ja: 1961年に人類で初めて宇宙へ行ったのは？ | ユーリ・ガガーリン | ニール・アームストロング | アラン・シェパード | ジョン・グレン
        ko: 1961년 인류 최초로 우주에 간 사람은? | 유리 가가린 | 닐 암스트롱 | 앨런 셰퍼드 | 존 글렌
        zh: 1961年第一个进入太空的人是谁？ | 尤里·加加林 | 尼尔·阿姆斯特朗 | 艾伦·谢泼德 | 约翰·格伦
        ar: من أول إنسان صعد إلى الفضاء عام 1961؟ | يوري غاغارين | نيل أرمسترونغ | آلان شيبرد | جون غلين

        # space.planet-count space 1
        *: 8 | 7 | 9 | 10
        en: How many planets are in our solar system?
        fr: Combien de planètes compte notre système solaire ?
        es: ¿Cuántos planetas hay en nuestro sistema solar?
        de: Wie viele Planeten hat unser Sonnensystem?
        it: Quanti pianeti ci sono nel nostro sistema solare?
        pt: Quantos planetas há no nosso sistema solar?
        ja: 太陽系の惑星はいくつ？
        ko: 태양계의 행성은 몇 개일까요?
        zh: 太阳系有几颗行星？
        ar: كم كوكبًا في مجموعتنا الشمسية؟

        # space.pluto space 2
        en: Since 2006, what is Pluto classed as? | A dwarf planet | A moon | A comet | A star
        fr: Depuis 2006, comment Pluton est-elle classée ? | Planète naine | Lune | Comète | Étoile
        es: Desde 2006, ¿cómo se clasifica Plutón? | Planeta enano | Luna | Cometa | Estrella
        de: Als was gilt Pluto seit 2006? | Als Zwergplanet | Als Mond | Als Komet | Als Stern
        it: Dal 2006, come è classificato Plutone? | Pianeta nano | Luna | Cometa | Stella
        pt: Desde 2006, como Plutão é classificado? | Planeta anão | Lua | Cometa | Estrela
        ja: 2006年から冥王星は何に分類されている？ | 準惑星 | 衛星 | 彗星 | 恒星
        ko: 2006년부터 명왕성은 무엇으로 분류될까요? | 왜소행성 | 위성 | 혜성 | 항성
        zh: 自2006年起，冥王星被归为什么？ | 矮行星 | 卫星 | 彗星 | 恒星
        ar: منذ عام 2006، كيف يُصنَّف بلوتو؟ | كوكب قزم | قمر | مذنّب | نجم

        # space.moon-orbit space 2
        en: About how long does the Moon take to go around Earth? | About 27 days | About 7 days | About 1 day | About 365 days
        fr: En combien de temps environ la Lune fait-elle le tour de la Terre ? | Environ 27 jours | Environ 7 jours | Environ 1 jour | Environ 365 jours
        es: ¿Cuánto tarda más o menos la Luna en dar la vuelta a la Tierra? | Unos 27 días | Unos 7 días | Un día | Unos 365 días
        de: Wie lange braucht der Mond ungefähr für eine Runde um die Erde? | Etwa 27 Tage | Etwa 7 Tage | Etwa 1 Tag | Etwa 365 Tage
        it: Più o meno quanto impiega la Luna a girare intorno alla Terra? | Circa 27 giorni | Circa 7 giorni | Circa 1 giorno | Circa 365 giorni
        pt: Mais ou menos quanto tempo a Lua leva para dar a volta na Terra? | Cerca de 27 dias | Cerca de 7 dias | Cerca de 1 dia | Cerca de 365 dias
        ja: 月が地球を1周するのにかかる時間はおよそ？ | 約27日 | 約7日 | 約1日 | 約365日
        ko: 달이 지구를 한 바퀴 도는 데 걸리는 시간은 대략? | 약 27일 | 약 7일 | 약 1일 | 약 365일
        zh: 月球绕地球一圈大约需要多久？ | 约27天 | 约7天 | 约1天 | 约365天
        ar: كم يستغرق القمر تقريبًا ليدور حول الأرض؟ | نحو 27 يومًا | نحو 7 أيام | نحو يوم واحد | نحو 365 يومًا

        # space.earth-year space 1
        en: How long does Earth take to go around the Sun? | About 365 days | About 30 days | About 24 hours | About 100 days
        fr: Combien de temps la Terre met-elle pour faire le tour du Soleil ? | Environ 365 jours | Environ 30 jours | Environ 24 heures | Environ 100 jours
        es: ¿Cuánto tarda la Tierra en dar la vuelta al Sol? | Unos 365 días | Unos 30 días | Unas 24 horas | Unos 100 días
        de: Wie lange braucht die Erde für eine Runde um die Sonne? | Etwa 365 Tage | Etwa 30 Tage | Etwa 24 Stunden | Etwa 100 Tage
        it: Quanto impiega la Terra a girare intorno al Sole? | Circa 365 giorni | Circa 30 giorni | Circa 24 ore | Circa 100 giorni
        pt: Quanto tempo a Terra leva para dar a volta no Sol? | Cerca de 365 dias | Cerca de 30 dias | Cerca de 24 horas | Cerca de 100 dias
        ja: 地球が太陽のまわりを1周するのにかかる時間は？ | 約365日 | 約30日 | 約24時間 | 約100日
        ko: 지구가 태양을 한 바퀴 도는 데 걸리는 시간은? | 약 365일 | 약 30일 | 약 24시간 | 약 100일
        zh: 地球绕太阳一圈需要多久？ | 约365天 | 约30天 | 约24小时 | 约100天
        ar: كم تستغرق الأرض لتدور حول الشمس؟ | نحو 365 يومًا | نحو 30 يومًا | نحو 24 ساعة | نحو 100 يوم

        # space.earth-spin space 1
        en: About how long does Earth take to spin once on its axis? | 24 hours | 12 hours | 7 days | 365 days
        fr: En combien de temps environ la Terre fait-elle un tour sur elle-même ? | 24 heures | 12 heures | 7 jours | 365 jours
        es: ¿Cuánto tarda más o menos la Tierra en girar una vez sobre sí misma? | 24 horas | 12 horas | 7 días | 365 días
        de: Wie lange braucht die Erde ungefähr für eine Drehung um sich selbst? | 24 Stunden | 12 Stunden | 7 Tage | 365 Tage
        it: Più o meno quanto impiega la Terra a fare un giro su sé stessa? | 24 ore | 12 ore | 7 giorni | 365 giorni
        pt: Mais ou menos quanto tempo a Terra leva para girar uma vez em torno de si? | 24 horas | 12 horas | 7 dias | 365 dias
        ja: 地球が1回自転するのにかかる時間はおよそ？ | 24時間 | 12時間 | 7日 | 365日
        ko: 지구가 한 번 자전하는 데 걸리는 시간은 대략? | 24시간 | 12시간 | 7일 | 365일
        zh: 地球自转一圈大约需要多久？ | 24小时 | 12小时 | 7天 | 365天
        ar: كم تستغرق الأرض تقريبًا لتدور دورة واحدة حول محورها؟ | 24 ساعة | 12 ساعة | 7 أيام | 365 يومًا

        # space.great-red-spot space 2
        en: On which planet is the Great Red Spot, a giant storm? | Jupiter | Mars | Saturn | Neptune
        fr: Sur quelle planète se trouve la Grande Tache rouge, une tempête géante ? | Jupiter | Mars | Saturne | Neptune
        es: ¿En qué planeta está la Gran Mancha Roja, una tormenta gigante? | Júpiter | Marte | Saturno | Neptuno
        de: Auf welchem Planeten tobt der Große Rote Fleck, ein riesiger Sturm? | Jupiter | Mars | Saturn | Neptun
        it: Su quale pianeta si trova la Grande Macchia Rossa, una tempesta gigante? | Giove | Marte | Saturno | Nettuno
        pt: Em qual planeta fica a Grande Mancha Vermelha, uma tempestade gigante? | Júpiter | Marte | Saturno | Netuno
        ja: 巨大な嵐「大赤斑」があるのはどの惑星？ | 木星 | 火星 | 土星 | 海王星
        ko: 거대한 폭풍인 '대적점'이 있는 행성은? | 목성 | 화성 | 토성 | 해왕성
        zh: 巨型风暴“大红斑”在哪颗行星上？ | 木星 | 火星 | 土星 | 海王星
        ar: على أي كوكب توجد البقعة الحمراء العظيمة، وهي عاصفة عملاقة؟ | المشتري | المريخ | زحل | نبتون

        # space.sun-is space 1
        en: What is the Sun? | A star | A planet | A comet | A galaxy
        fr: Qu'est-ce que le Soleil ? | Une étoile | Une planète | Une comète | Une galaxie
        es: ¿Qué es el Sol? | Una estrella | Un planeta | Un cometa | Una galaxia
        de: Was ist die Sonne? | Ein Stern | Ein Planet | Ein Komet | Eine Galaxie
        it: Che cos'è il Sole? | Una stella | Un pianeta | Una cometa | Una galassia
        pt: O que é o Sol? | Uma estrela | Um planeta | Um cometa | Uma galáxia
        ja: 太陽とは何？ | 恒星 | 惑星 | 彗星 | 銀河
        ko: 태양은 무엇일까요? | 별(항성) | 행성 | 혜성 | 은하
        zh: 太阳是什么？ | 恒星 | 行星 | 彗星 | 星系
        ar: ما الشمس؟ | نجم | كوكب | مذنّب | مجرة

        # space.light-year space 2
        en: What does a light-year measure? | Distance | Time | Brightness | Speed
        fr: Que mesure une année-lumière ? | Une distance | Une durée | Une luminosité | Une vitesse
        es: ¿Qué mide un año luz? | Una distancia | Un tiempo | Un brillo | Una velocidad
        de: Was misst ein Lichtjahr? | Eine Entfernung | Eine Zeitdauer | Eine Helligkeit | Eine Geschwindigkeit
        it: Che cosa misura un anno luce? | Una distanza | Un tempo | Una luminosità | Una velocità
        pt: O que um ano-luz mede? | Distância | Tempo | Brilho | Velocidade
        ja: 1光年が表すのは？ | 距離 | 時間 | 明るさ | 速さ
        ko: 1광년은 무엇을 나타내는 단위일까요? | 거리 | 시간 | 밝기 | 속도
        zh: 光年是什么的单位？ | 距离 | 时间 | 亮度 | 速度
        ar: ماذا تقيس السنة الضوئية؟ | المسافة | الزمن | السطوع | السرعة

        # space.first-satellite space 2
        en: What was the first artificial satellite, launched in 1957? | Sputnik 1 | Explorer 1 | Apollo 11 | Hubble
        fr: Quel fut le premier satellite artificiel, lancé en 1957 ? | Spoutnik 1 | Explorer 1 | Apollo 11 | Hubble
        es: ¿Cuál fue el primer satélite artificial, lanzado en 1957? | Sputnik 1 | Explorer 1 | Apolo 11 | Hubble
        de: Wie hieß der erste künstliche Satellit, gestartet 1957? | Sputnik 1 | Explorer 1 | Apollo 11 | Hubble
        it: Qual è stato il primo satellite artificiale, lanciato nel 1957? | Sputnik 1 | Explorer 1 | Apollo 11 | Hubble
        pt: Qual foi o primeiro satélite artificial, lançado em 1957? | Sputnik 1 | Explorer 1 | Apollo 11 | Hubble
        ja: 1957年に打ち上げられた最初の人工衛星は？ | スプートニク1号 | エクスプローラー1号 | アポロ11号 | ハッブル
        ko: 1957년에 발사된 최초의 인공위성은? | 스푸트니크 1호 | 익스플로러 1호 | 아폴로 11호 | 허블
        zh: 1957年发射的第一颗人造卫星是什么？ | 斯普特尼克1号 | 探险者1号 | 阿波罗11号 | 哈勃
        ar: ما أول قمر صناعي أُطلق عام 1957؟ | سبوتنيك 1 | إكسبلورر 1 | أبولو 11 | هابل

        # space.iss space 1
        en: What is the ISS? | A space station | A telescope | A rocket | A Moon base
        fr: Qu'est-ce que l'ISS ? | Une station spatiale | Un télescope | Une fusée | Une base lunaire
        es: ¿Qué es la ISS (EEI)? | Una estación espacial | Un telescopio | Un cohete | Una base lunar
        de: Was ist die ISS? | Eine Raumstation | Ein Teleskop | Eine Rakete | Eine Mondbasis
        it: Che cos'è la ISS? | Una stazione spaziale | Un telescopio | Un razzo | Una base lunare
        pt: O que é a ISS (EEI)? | Uma estação espacial | Um telescópio | Um foguete | Uma base lunar
        ja: ISSとは何？ | 宇宙ステーション | 望遠鏡 | ロケット | 月面基地
        ko: ISS는 무엇일까요? | 우주 정거장 | 망원경 | 로켓 | 달 기지
        zh: ISS是什么？ | 空间站 | 望远镜 | 火箭 | 月球基地
        ar: ما محطة ISS؟ | محطة فضائية | تلسكوب | صاروخ | قاعدة على القمر

        # space.hubble space 2
        en: What is Hubble? | A space telescope | A rocket | A Mars rover | A space station
        fr: Qu'est-ce que Hubble ? | Un télescope spatial | Une fusée | Un robot martien | Une station spatiale
        es: ¿Qué es el Hubble? | Un telescopio espacial | Un cohete | Un explorador marciano | Una estación espacial
        de: Was ist Hubble? | Ein Weltraumteleskop | Eine Rakete | Ein Marsrover | Eine Raumstation
        it: Che cos'è Hubble? | Un telescopio spaziale | Un razzo | Un rover marziano | Una stazione spaziale
        pt: O que é o Hubble? | Um telescópio espacial | Um foguete | Um robô de Marte | Uma estação espacial
        ja: ハッブルとは何？ | 宇宙望遠鏡 | ロケット | 火星探査車 | 宇宙ステーション
        ko: 허블은 무엇일까요? | 우주 망원경 | 로켓 | 화성 탐사차 | 우주 정거장
        zh: 哈勃是什么？ | 太空望远镜 | 火箭 | 火星车 | 空间站
        ar: ما هابل؟ | تلسكوب فضائي | صاروخ | مركبة جوّالة على المريخ | محطة فضائية

        # space.on-its-side space 3
        en: Which planet spins almost on its side? | Uranus | Neptune | Venus | Mars
        fr: Quelle planète tourne presque couchée sur le côté ? | Uranus | Neptune | Vénus | Mars
        es: ¿Qué planeta gira casi tumbado de lado? | Urano | Neptuno | Venus | Marte
        de: Welcher Planet dreht sich fast auf der Seite liegend? | Uranus | Neptun | Venus | Mars
        it: Quale pianeta ruota quasi sdraiato su un fianco? | Urano | Nettuno | Venere | Marte
        pt: Qual planeta gira quase deitado de lado? | Urano | Netuno | Vênus | Marte
        ja: ほぼ横倒しの状態で自転している惑星は？ | 天王星 | 海王星 | 金星 | 火星
        ko: 거의 옆으로 누운 채 자전하는 행성은? | 천왕성 | 해왕성 | 금성 | 화성
        zh: 哪颗行星几乎是“躺着”自转的？ | 天王星 | 海王星 | 金星 | 火星
        ar: أي كوكب يدور وهو مائل على جانبه تقريبًا؟ | أورانوس | نبتون | الزهرة | المريخ

        # space.apollo-11 space 1
        en: Which mission first landed people on the Moon? | Apollo 11 | Apollo 13 | Gemini 4 | Vostok 1
        fr: Quelle mission a posé les premiers humains sur la Lune ? | Apollo 11 | Apollo 13 | Gemini 4 | Vostok 1
        es: ¿Qué misión llevó por primera vez personas a la Luna? | Apolo 11 | Apolo 13 | Gemini 4 | Vostok 1
        de: Mit welcher Mission landeten zum ersten Mal Menschen auf dem Mond? | Apollo 11 | Apollo 13 | Gemini 4 | Wostok 1
        it: Quale missione portò per la prima volta degli uomini sulla Luna? | Apollo 11 | Apollo 13 | Gemini 4 | Vostok 1
        pt: Qual missão levou pessoas à Lua pela primeira vez? | Apollo 11 | Apollo 13 | Gemini 4 | Vostok 1
        ja: 初めて人類を月面に着陸させたミッションは？ | アポロ11号 | アポロ13号 | ジェミニ4号 | ボストーク1号
        ko: 처음으로 사람을 달에 착륙시킨 임무는? | 아폴로 11호 | 아폴로 13호 | 제미니 4호 | 보스토크 1호
        zh: 首次把人送上月球的是哪次任务？ | 阿波罗11号 | 阿波罗13号 | 双子座4号 | 东方1号
        ar: ما المهمة التي أنزلت البشر على القمر أول مرة؟ | أبولو 11 | أبولو 13 | جيميني 4 | فوستوك 1

        # space.comet space 2
        en: What is a comet mostly made of? | Ice and dust | Molten rock | Burning gas | Pure iron
        fr: De quoi une comète est-elle surtout faite ? | De glace et de poussière | De roche en fusion | De gaz en feu | De fer pur
        es: ¿De qué está hecho sobre todo un cometa? | Hielo y polvo | Roca fundida | Gas en llamas | Hierro puro
        de: Woraus besteht ein Komet hauptsächlich? | Aus Eis und Staub | Aus geschmolzenem Gestein | Aus brennendem Gas | Aus reinem Eisen
        it: Di che cosa è fatta soprattutto una cometa? | Ghiaccio e polvere | Roccia fusa | Gas in fiamme | Ferro puro
        pt: Do que um cometa é feito principalmente? | Gelo e poeira | Rocha derretida | Gás em chamas | Ferro puro
        ja: 彗星はおもに何でできている？ | 氷とちり | 溶けた岩 | 燃えるガス | 純粋な鉄
        ko: 혜성은 주로 무엇으로 이루어져 있을까요? | 얼음과 먼지 | 녹은 암석 | 불타는 가스 | 순수한 철
        zh: 彗星主要由什么组成？ | 冰和尘埃 | 熔岩 | 燃烧的气体 | 纯铁
        ar: مِمّ يتكوّن المذنّب في الغالب؟ | الجليد والغبار | الصخور المنصهرة | الغاز المشتعل | الحديد الخالص

        # space.moon-gravity space 3
        en: Compared with Earth, how strong is gravity on the Moon? | About one sixth | About half | About the same | About twice
        fr: Par rapport à la Terre, quelle est la gravité sur la Lune ? | Environ un sixième | Environ la moitié | À peu près la même | Environ le double
        es: Comparada con la de la Tierra, ¿cómo es la gravedad en la Luna? | Más o menos un sexto | Más o menos la mitad | Casi igual | Más o menos el doble
        de: Wie stark ist die Schwerkraft auf dem Mond im Vergleich zur Erde? | Etwa ein Sechstel | Etwa die Hälfte | Etwa gleich | Etwa doppelt so stark
        it: Rispetto alla Terra, quanto è forte la gravità sulla Luna? | Circa un sesto | Circa la metà | Più o meno uguale | Circa il doppio
        pt: Em comparação com a Terra, qual é a gravidade na Lua? | Cerca de um sexto | Cerca da metade | Quase a mesma | Cerca do dobro
        ja: 地球と比べて、月の重力はどのくらい？ | 約6分の1 | 約半分 | ほぼ同じ | 約2倍
        ko: 지구와 비교해 달의 중력은 어느 정도일까요? | 약 6분의 1 | 약 절반 | 거의 같다 | 약 2배
        zh: 与地球相比，月球的重力有多大？ | 约六分之一 | 约一半 | 差不多一样 | 约两倍
        ar: مقارنةً بالأرض، كم تبلغ الجاذبية على القمر؟ | نحو السدس | نحو النصف | تقريبًا مثلها | نحو الضعف

        # space.sun-age space 3
        en: About how old is the Sun? | About 4.6 billion years | About 4.6 million years | About 460 million years | About 46 billion years
        fr: Quel âge le Soleil a-t-il environ ? | Environ 4,6 milliards d'années | Environ 4,6 millions d'années | Environ 460 millions d'années | Environ 46 milliards d'années
        es: ¿Qué edad tiene más o menos el Sol? | Unos 4600 millones de años | Unos 4,6 millones de años | Unos 460 millones de años | Unos 46 000 millones de años
        de: Wie alt ist die Sonne ungefähr? | Etwa 4,6 Milliarden Jahre | Etwa 4,6 Millionen Jahre | Etwa 460 Millionen Jahre | Etwa 46 Milliarden Jahre
        it: Più o meno quanti anni ha il Sole? | Circa 4,6 miliardi di anni | Circa 4,6 milioni di anni | Circa 460 milioni di anni | Circa 46 miliardi di anni
        pt: Mais ou menos qual é a idade do Sol? | Cerca de 4,6 bilhões de anos | Cerca de 4,6 milhões de anos | Cerca de 460 milhões de anos | Cerca de 46 bilhões de anos
        ja: 太陽の年齢はおよそ？ | 約46億年 | 約460万年 | 約4億6000万年 | 約460億年
        ko: 태양의 나이는 대략? | 약 46억 년 | 약 460만 년 | 약 4억 6000만 년 | 약 460억 년
        zh: 太阳大约有多少岁？ | 约46亿年 | 约460万年 | 约4.6亿年 | 约460亿年
        ar: كم عمر الشمس تقريبًا؟ | نحو 4.6 مليار سنة | نحو 4.6 مليون سنة | نحو 460 مليون سنة | نحو 46 مليار سنة

        # space.venus-moons space 3
        *: 0 | 1 | 2 | 3
        en: How many moons does Venus have?
        fr: Combien de lunes Vénus possède-t-elle ?
        es: ¿Cuántas lunas tiene Venus?
        de: Wie viele Monde hat die Venus?
        it: Quante lune ha Venere?
        pt: Quantas luas Vênus tem?
        ja: 金星の衛星はいくつ？
        ko: 금성의 위성은 몇 개일까요?
        zh: 金星有几颗卫星？
        ar: كم قمرًا لكوكب الزهرة؟

        # space.olympus-mons space 3
        en: Olympus Mons, a giant volcano, is on which planet? | Mars | Venus | Earth | Mercury
        fr: Olympus Mons, un volcan géant, se trouve sur quelle planète ? | Mars | Vénus | La Terre | Mercure
        es: ¿En qué planeta está el Olympus Mons, un volcán gigante? | Marte | Venus | La Tierra | Mercurio
        de: Auf welchem Planeten steht der Riesenvulkan Olympus Mons? | Mars | Venus | Erde | Merkur
        it: Su quale pianeta si trova Olympus Mons, un vulcano gigante? | Marte | Venere | La Terra | Mercurio
        pt: Em qual planeta fica o Monte Olimpo (Olympus Mons), um vulcão gigante? | Marte | Vênus | A Terra | Mercúrio
        ja: 巨大な火山オリンポス山があるのはどの惑星？ | 火星 | 金星 | 地球 | 水星
        ko: 거대한 화산 올림푸스산이 있는 행성은? | 화성 | 금성 | 지구 | 수성
        zh: 巨型火山奥林匹斯山在哪颗行星上？ | 火星 | 金星 | 地球 | 水星
        ar: على أي كوكب يقع أوليمبوس مونس، البركان العملاق؟ | المريخ | الزهرة | الأرض | عطارد

        # space.titan space 3
        en: Titan is a moon of which planet? | Saturn | Jupiter | Uranus | Neptune
        fr: Titan est une lune de quelle planète ? | Saturne | Jupiter | Uranus | Neptune
        es: ¿De qué planeta es luna Titán? | Saturno | Júpiter | Urano | Neptuno
        de: Titan ist ein Mond welches Planeten? | Saturn | Jupiter | Uranus | Neptun
        it: Titano è una luna di quale pianeta? | Saturno | Giove | Urano | Nettuno
        pt: Titã é uma lua de qual planeta? | Saturno | Júpiter | Urano | Netuno
        ja: タイタンはどの惑星の衛星？ | 土星 | 木星 | 天王星 | 海王星
        ko: 타이탄은 어느 행성의 위성일까요? | 토성 | 목성 | 천왕성 | 해왕성
        zh: 土卫六（泰坦）是哪颗行星的卫星？ | 土星 | 木星 | 天王星 | 海王星
        ar: تيتان قمرٌ لأي كوكب؟ | زحل | المشتري | أورانوس | نبتون

        # space.galilean-moons space 3
        en: Io, Europa and Ganymede are moons of which planet? | Jupiter | Saturn | Mars | Neptune
        fr: Io, Europe et Ganymède sont des lunes de quelle planète ? | Jupiter | Saturne | Mars | Neptune
        es: ¿De qué planeta son lunas Ío, Europa y Ganímedes? | Júpiter | Saturno | Marte | Neptuno
        de: Io, Europa und Ganymed sind Monde welches Planeten? | Jupiter | Saturn | Mars | Neptun
        it: Io, Europa e Ganimede sono lune di quale pianeta? | Giove | Saturno | Marte | Nettuno
        pt: Io, Europa e Ganimedes são luas de qual planeta? | Júpiter | Saturno | Marte | Netuno
        ja: イオ、エウロパ、ガニメデはどの惑星の衛星？ | 木星 | 土星 | 火星 | 海王星
        ko: 이오, 유로파, 가니메데는 어느 행성의 위성일까요? | 목성 | 토성 | 화성 | 해왕성
        zh: 木卫一、木卫二和木卫三是哪颗行星的卫星？ | 木星 | 土星 | 火星 | 海王星
        ar: آيو ويوروبا وغانيميد أقمارٌ لأي كوكب؟ | المشتري | زحل | المريخ | نبتون

        # space.north-star space 2
        en: Which star is known as the North Star? | Polaris | Sirius | Vega | Betelgeuse
        fr: Quelle étoile appelle-t-on l'étoile Polaire ? | Polaris | Sirius | Véga | Bételgeuse
        es: ¿Qué estrella se conoce como la estrella Polar? | Polaris | Sirio | Vega | Betelgeuse
        de: Welcher Stern ist als Polarstern bekannt? | Polaris | Sirius | Wega | Beteigeuze
        it: Quale stella è nota come stella polare? | Polaris | Sirio | Vega | Betelgeuse
        pt: Que estrela é conhecida como estrela Polar? | Polaris | Sírius | Vega | Betelgeuse
        ja: 北極星として知られる星は？ | ポラリス | シリウス | ベガ | ベテルギウス
        ko: 북극성으로 알려진 별은? | 폴라리스 | 시리우스 | 베가 | 베텔게우스
        zh: 被称为北极星的是哪颗星？ | 勾陈一 | 天狼星 | 织女星 | 参宿四
        ar: أي نجم يُعرف بالنجم القطبي؟ | بولاريس | الشعرى اليمانية | النسر الواقع | منكب الجوزاء

        # space.full-moon space 1
        en: What do we call the Moon when its whole face is lit? | A full moon | A new moon | A crescent moon | A quarter moon
        fr: Comment appelle-t-on la Lune quand toute sa face est éclairée ? | La pleine lune | La nouvelle lune | Le croissant | Le quartier
        es: ¿Cómo se llama la Luna cuando se ve toda su cara iluminada? | Luna llena | Luna nueva | Luna creciente | Cuarto de luna
        de: Wie nennt man den Mond, wenn seine ganze Seite beleuchtet ist? | Vollmond | Neumond | Mondsichel | Halbmond
        it: Come si chiama la Luna quando tutta la sua faccia è illuminata? | Luna piena | Luna nuova | Falce di luna | Quarto di luna
        pt: Como se chama a Lua quando toda a sua face está iluminada? | Lua cheia | Lua nova | Lua crescente | Quarto de lua
        ja: 月の面がすべて光って見えるときの名前は？ | 満月 | 新月 | 三日月 | 半月
        ko: 달의 앞면 전체가 밝게 보일 때를 무엇이라고 할까요? | 보름달 | 그믐달 | 초승달 | 반달
        zh: 月亮整个圆面都被照亮时叫什么？ | 满月 | 新月 | 月牙 | 半月
        ar: ماذا نسمّي القمر حين يُضاء وجهه كله؟ | البدر | المحاق | الهلال | التربيع

        # space.solar-eclipse space 2
        en: In a solar eclipse, what passes between the Sun and Earth? | The Moon | Venus | Mars | A comet
        fr: Lors d'une éclipse de Soleil, qu'est-ce qui passe entre le Soleil et la Terre ? | La Lune | Vénus | Mars | Une comète
        es: En un eclipse solar, ¿qué pasa entre el Sol y la Tierra? | La Luna | Venus | Marte | Un cometa
        de: Was schiebt sich bei einer Sonnenfinsternis zwischen Sonne und Erde? | Der Mond | Die Venus | Der Mars | Ein Komet
        it: In un'eclissi di Sole, che cosa passa tra il Sole e la Terra? | La Luna | Venere | Marte | Una cometa
        pt: Num eclipse solar, o que passa entre o Sol e a Terra? | A Lua | Vênus | Marte | Um cometa
        ja: 日食のとき、太陽と地球のあいだに入るのは？ | 月 | 金星 | 火星 | 彗星
        ko: 일식 때 태양과 지구 사이에 들어오는 것은? | 달 | 금성 | 화성 | 혜성
        zh: 日食时，什么从太阳和地球之间经过？ | 月球 | 金星 | 火星 | 彗星
        ar: في كسوف الشمس، ما الذي يمرّ بين الشمس والأرض؟ | القمر | الزهرة | المريخ | مذنّب

        # space.earth-third space 1
        en: Counting from the Sun, which planet is Earth? | The third | The second | The fourth | The fifth
        fr: En partant du Soleil, quelle planète est la Terre ? | La troisième | La deuxième | La quatrième | La cinquième
        es: Contando desde el Sol, ¿qué planeta es la Tierra? | El tercero | El segundo | El cuarto | El quinto
        de: Der wievielte Planet von der Sonne aus ist die Erde? | Der dritte | Der zweite | Der vierte | Der fünfte
        it: Contando dal Sole, che pianeta è la Terra? | Il terzo | Il secondo | Il quarto | Il quinto
        pt: Contando a partir do Sol, que planeta é a Terra? | O terceiro | O segundo | O quarto | O quinto
        ja: 太陽から数えて、地球は何番目の惑星？ | 3番目 | 2番目 | 4番目 | 5番目
        ko: 태양에서부터 세면 지구는 몇 번째 행성일까요? | 세 번째 | 두 번째 | 네 번째 | 다섯 번째
        zh: 从太阳往外数，地球是第几颗行星？ | 第三颗 | 第二颗 | 第四颗 | 第五颗
        ar: بالعدّ من الشمس، ما ترتيب كوكب الأرض؟ | الثالث | الثاني | الرابع | الخامس

        # space.farthest-planet space 2
        en: Which planet is farthest from the Sun? | Neptune | Uranus | Saturn | Jupiter
        fr: Quelle planète est la plus éloignée du Soleil ? | Neptune | Uranus | Saturne | Jupiter
        es: ¿Qué planeta está más lejos del Sol? | Neptuno | Urano | Saturno | Júpiter
        de: Welcher Planet ist am weitesten von der Sonne entfernt? | Neptun | Uranus | Saturn | Jupiter
        it: Quale pianeta è il più lontano dal Sole? | Nettuno | Urano | Saturno | Giove
        pt: Qual planeta fica mais longe do Sol? | Netuno | Urano | Saturno | Júpiter
        ja: 太陽からいちばん遠い惑星は？ | 海王星 | 天王星 | 土星 | 木星
        ko: 태양에서 가장 먼 행성은? | 해왕성 | 천왕성 | 토성 | 목성
        zh: 离太阳最远的行星是哪颗？ | 海王星 | 天王星 | 土星 | 木星
        ar: ما أبعد كوكب عن الشمس؟ | نبتون | أورانوس | زحل | المشتري

        # space.laika space 3
        en: Which dog was the first animal to orbit Earth, in 1957? | Laika | Belka | Strelka | Rex
        fr: Quelle chienne a été le premier animal en orbite autour de la Terre, en 1957 ? | Laïka | Belka | Strelka | Rex
        es: ¿Qué perra fue el primer animal en orbitar la Tierra, en 1957? | Laika | Belka | Strelka | Rex
        de: Welche Hündin umkreiste 1957 als erstes Tier die Erde? | Laika | Belka | Strelka | Rex
        it: Quale cagnolina fu il primo animale in orbita intorno alla Terra, nel 1957? | Laika | Belka | Strelka | Rex
        pt: Que cadela foi o primeiro animal a orbitar a Terra, em 1957? | Laika | Belka | Strelka | Rex
        ja: 1957年、動物で初めて地球を周回した犬は？ | ライカ | ベルカ | ストレルカ | レックス
        ko: 1957년 동물 최초로 지구 궤도를 돈 개는? | 라이카 | 벨카 | 스트렐카 | 렉스
        zh: 1957年首个进入地球轨道的动物是哪只狗？ | 莱卡 | 贝尔卡 | 斯特雷尔卡 | 雷克斯
        ar: ما الكلبة التي كانت أول حيوان يدور حول الأرض عام 1957؟ | لايكا | بيلكا | ستريلكا | ريكس

        # space.sun-made-of space 3
        en: What is the Sun mostly made of? | Hydrogen | Oxygen | Iron | Carbon
        fr: De quoi le Soleil est-il surtout composé ? | D'hydrogène | D'oxygène | De fer | De carbone
        es: ¿De qué está hecho sobre todo el Sol? | Hidrógeno | Oxígeno | Hierro | Carbono
        de: Woraus besteht die Sonne hauptsächlich? | Aus Wasserstoff | Aus Sauerstoff | Aus Eisen | Aus Kohlenstoff
        it: Di che cosa è fatto soprattutto il Sole? | Idrogeno | Ossigeno | Ferro | Carbonio
        pt: Do que o Sol é feito principalmente? | Hidrogênio | Oxigênio | Ferro | Carbono
        ja: 太陽はおもに何でできている？ | 水素 | 酸素 | 鉄 | 炭素
        ko: 태양은 주로 무엇으로 이루어져 있을까요? | 수소 | 산소 | 철 | 탄소
        zh: 太阳主要由什么组成？ | 氢 | 氧 | 铁 | 碳
        ar: مِمّ تتكوّن الشمس في الغالب؟ | الهيدروجين | الأكسجين | الحديد | الكربون

        # space.asteroid-belt space 3
        en: The main asteroid belt lies between which two planets? | Mars and Jupiter | Earth and Mars | Jupiter and Saturn | Venus and Earth
        fr: Entre quelles planètes se trouve la ceinture principale d'astéroïdes ? | Mars et Jupiter | La Terre et Mars | Jupiter et Saturne | Vénus et la Terre
        es: ¿Entre qué dos planetas está el cinturón principal de asteroides? | Marte y Júpiter | La Tierra y Marte | Júpiter y Saturno | Venus y la Tierra
        de: Zwischen welchen Planeten liegt der Asteroidengürtel? | Mars und Jupiter | Erde und Mars | Jupiter und Saturn | Venus und Erde
        it: Tra quali pianeti si trova la fascia principale degli asteroidi? | Marte e Giove | Terra e Marte | Giove e Saturno | Venere e Terra
        pt: Entre quais planetas fica o cinturão principal de asteroides? | Marte e Júpiter | Terra e Marte | Júpiter e Saturno | Vênus e Terra
        ja: 小惑星帯があるのはどの惑星のあいだ？ | 火星と木星 | 地球と火星 | 木星と土星 | 金星と地球
        ko: 주요 소행성대는 어느 두 행성 사이에 있을까요? | 화성과 목성 | 지구와 화성 | 목성과 토성 | 금성과 지구
        zh: 主小行星带位于哪两颗行星之间？ | 火星和木星 | 地球和火星 | 木星和土星 | 金星和地球
        ar: بين أي كوكبين يقع حزام الكويكبات الرئيسي؟ | المريخ والمشتري | الأرض والمريخ | المشتري وزحل | الزهرة والأرض

        # space.first-woman space 3
        en: Who was the first woman in space, in 1963? | Valentina Tereshkova | Sally Ride | Mae Jemison | Svetlana Savitskaya
        fr: Qui fut la première femme dans l'espace, en 1963 ? | Valentina Terechkova | Sally Ride | Mae Jemison | Svetlana Savitskaïa
        es: ¿Quién fue la primera mujer en el espacio, en 1963? | Valentina Tereshkova | Sally Ride | Mae Jemison | Svetlana Savítskaya
        de: Wer war 1963 die erste Frau im Weltraum? | Walentina Tereschkowa | Sally Ride | Mae Jemison | Swetlana Sawizkaja
        it: Chi fu la prima donna nello spazio, nel 1963? | Valentina Tereškova | Sally Ride | Mae Jemison | Svetlana Savickaja
        pt: Quem foi a primeira mulher no espaço, em 1963? | Valentina Tereshkova | Sally Ride | Mae Jemison | Svetlana Savitskaya
        ja: 1963年に宇宙へ行った最初の女性は？ | ワレンチナ・テレシコワ | サリー・ライド | メイ・ジェミソン | スベトラーナ・サビツカヤ
        ko: 1963년 우주에 간 최초의 여성은? | 발렌티나 테레시코바 | 샐리 라이드 | 메이 제미슨 | 스베틀라나 사비츠카야
        zh: 1963年进入太空的第一位女性是谁？ | 瓦莲京娜·捷列什科娃 | 萨莉·莱德 | 梅·杰米森 | 斯维特兰娜·萨维茨卡娅
        ar: من أول امرأة صعدت إلى الفضاء عام 1963؟ | فالنتينا تيريشكوفا | سالي رايد | ماي جيميسون | سفيتلانا سافيتسكايا
        """
}
