extension Games.QuizBank {
    // Tunisia and the Mediterranean: the founder's pick, a topic of its own.
    static let mediterranean = """
        # med.tunisia-capital mediterranean 1
        en: What is the capital of Tunisia? | Tunis | Sfax | Sousse | Kairouan
        fr: Quelle est la capitale de la Tunisie ? | Tunis | Sfax | Sousse | Kairouan
        es: ¿Cuál es la capital de Túnez? | Túnez (la ciudad) | Sfax | Susa | Kairuán
        de: Was ist die Hauptstadt Tunesiens? | Tunis | Sfax | Sousse | Kairouan
        it: Qual è la capitale della Tunisia? | Tunisi | Sfax | Susa | Kairouan
        pt: Qual é a capital da Tunísia? | Túnis | Sfax | Sousse | Kairouan
        ja: チュニジアの首都は？ | チュニス | スファックス | スース | カイルアン
        ko: 튀니지의 수도는? | 튀니스 | 스팍스 | 수스 | 카이루안
        zh: 突尼斯的首都是哪里？ | 突尼斯市 | 斯法克斯 | 苏塞 | 凯鲁万
        ar: ما عاصمة تونس؟ | تونس العاصمة | صفاقس | سوسة | القيروان

        # med.carthage mediterranean 2
        en: Ancient Carthage stood in which country of today? | Tunisia | Libya | Egypt | Morocco
        fr: L'antique Carthage se trouvait dans quel pays d'aujourd'hui ? | La Tunisie | La Libye | L'Égypte | Le Maroc
        es: ¿En qué país actual estaba la antigua Cartago? | Túnez | Libia | Egipto | Marruecos
        de: In welchem heutigen Land lag das antike Karthago? | Tunesien | Libyen | Ägypten | Marokko
        it: In quale Paese di oggi sorgeva l'antica Cartagine? | Tunisia | Libia | Egitto | Marocco
        pt: Em que país de hoje ficava a antiga Cartago? | Tunísia | Líbia | Egito | Marrocos
        ja: 古代都市カルタゴがあったのは、今のどの国？ | チュニジア | リビア | エジプト | モロッコ
        ko: 고대 카르타고는 오늘날 어느 나라에 있었을까요? | 튀니지 | 리비아 | 이집트 | 모로코
        zh: 古迦太基位于今天的哪个国家？ | 突尼斯 | 利比亚 | 埃及 | 摩洛哥
        ar: في أي دولة حالية كانت قرطاج القديمة؟ | تونس | ليبيا | مصر | المغرب

        # med.hannibal mediterranean 2
        en: Hannibal, who crossed the Alps with elephants, was a general of which city? | Carthage | Rome | Athens | Sparta
        fr: Hannibal, qui a franchi les Alpes avec des éléphants, était un général de quelle cité ? | Carthage | Rome | Athènes | Sparte
        es: ¿De qué ciudad era general Aníbal, que cruzó los Alpes con elefantes? | Cartago | Roma | Atenas | Esparta
        de: Hannibal, der mit Elefanten die Alpen überquerte, war Feldherr welcher Stadt? | Karthago | Rom | Athen | Sparta
        it: Annibale, che attraversò le Alpi con gli elefanti, era un generale di quale città? | Cartagine | Roma | Atene | Sparta
        pt: Aníbal, que atravessou os Alpes com elefantes, era general de qual cidade? | Cartago | Roma | Atenas | Esparta
        ja: ゾウを連れてアルプスを越えたハンニバルは、どの都市の将軍？ | カルタゴ | ローマ | アテネ | スパルタ
        ko: 코끼리를 이끌고 알프스를 넘은 한니발은 어느 도시의 장군이었을까요? | 카르타고 | 로마 | 아테네 | 스파르타
        zh: 带着大象翻越阿尔卑斯山的汉尼拔是哪座城市的将军？ | 迦太基 | 罗马 | 雅典 | 斯巴达
        ar: حنبعل، الذي عبر جبال الألب بالفيلة، كان قائدًا لأي مدينة؟ | قرطاج | روما | أثينا | إسبرطة

        # med.sidi-bou-said mediterranean 2
        en: The Tunisian village of Sidi Bou Said is famous for houses in which colours? | White and blue | Red and yellow | Pink and green | Black and gold
        fr: Le village tunisien de Sidi Bou Saïd est célèbre pour ses maisons de quelles couleurs ? | Blanc et bleu | Rouge et jaune | Rose et vert | Noir et or
        es: ¿De qué colores son las casas que hacen famoso al pueblo tunecino de Sidi Bou Said? | Blanco y azul | Rojo y amarillo | Rosa y verde | Negro y dorado
        de: In welchen Farben sind die berühmten Häuser des tunesischen Dorfes Sidi Bou Said? | Weiß und Blau | Rot und Gelb | Rosa und Grün | Schwarz und Gold
        it: Di quali colori sono le case che rendono famoso il villaggio tunisino di Sidi Bou Said? | Bianco e blu | Rosso e giallo | Rosa e verde | Nero e oro
        pt: A vila tunisiana de Sidi Bou Said é famosa por casas de quais cores? | Branco e azul | Vermelho e amarelo | Rosa e verde | Preto e dourado
        ja: チュニジアのシディ・ブ・サイドは何色の家並みで有名？ | 白と青 | 赤と黄 | ピンクと緑 | 黒と金
        ko: 튀니지의 마을 시디 부 사이드는 어떤 색의 집들로 유명할까요? | 흰색과 파란색 | 빨간색과 노란색 | 분홍색과 초록색 | 검은색과 금색
        zh: 突尼斯的西迪布赛义德村以什么颜色的房子闻名？ | 白色和蓝色 | 红色和黄色 | 粉色和绿色 | 黑色和金色
        ar: بأي لونين تشتهر بيوت قرية سيدي بوسعيد التونسية؟ | الأبيض والأزرق | الأحمر والأصفر | الوردي والأخضر | الأسود والذهبي

        # med.el-jem mediterranean 3
        en: El Jem, in Tunisia, is known for a huge Roman what? | Amphitheatre | Aqueduct | Lighthouse | Bridge
        fr: Quel immense monument romain trouve-t-on à El Jem, en Tunisie ? | Un amphithéâtre | Un aqueduc | Un phare | Un pont
        es: ¿Qué enorme monumento romano hay en El Jem, en Túnez? | Un anfiteatro | Un acueducto | Un faro | Un puente
        de: Welches riesige römische Bauwerk steht in El Djem in Tunesien? | Ein Amphitheater | Ein Aquädukt | Ein Leuchtturm | Eine Brücke
        it: Quale enorme monumento romano si trova a El Jem, in Tunisia? | Un anfiteatro | Un acquedotto | Un faro | Un ponte
        pt: Que grande construção romana fica em El Jem, na Tunísia? | Um anfiteatro | Um aqueduto | Um farol | Uma ponte
        ja: チュニジアのエル・ジェムで有名な巨大なローマ時代の建物は？ | 円形闘技場 | 水道橋 | 灯台 | 橋
        ko: 튀니지의 엘젬은 거대한 로마 시대의 무엇으로 유명할까요? | 원형 경기장 | 수도교 | 등대 | 다리
        zh: 突尼斯的杰姆以一座巨大的古罗马什么建筑闻名？ | 圆形竞技场 | 引水渠 | 灯塔 | 桥
        ar: تشتهر الجم في تونس بأي معلم روماني ضخم؟ | المسرح المدرّج (الكولوسيوم) | قناة مياه | منارة | جسر

        # med.tunisia-continent mediterranean 1
        en: On which continent is Tunisia? | Africa | Europe | Asia | South America
        fr: Sur quel continent se trouve la Tunisie ? | L'Afrique | L'Europe | L'Asie | L'Amérique du Sud
        es: ¿En qué continente está Túnez? | África | Europa | Asia | América del Sur
        de: Auf welchem Kontinent liegt Tunesien? | Afrika | Europa | Asien | Südamerika
        it: In quale continente si trova la Tunisia? | Africa | Europa | Asia | Sud America
        pt: Em que continente fica a Tunísia? | África | Europa | Ásia | América do Sul
        ja: チュニジアがある大陸は？ | アフリカ | ヨーロッパ | アジア | 南アメリカ
        ko: 튀니지가 있는 대륙은? | 아프리카 | 유럽 | 아시아 | 남아메리카
        zh: 突尼斯位于哪个大洲？ | 非洲 | 欧洲 | 亚洲 | 南美洲
        ar: في أي قارة تقع تونس؟ | أفريقيا | أوروبا | آسيا | أمريكا الجنوبية

        # med.tunisia-desert mediterranean 2
        en: Which desert covers the south of Tunisia? | The Sahara | The Gobi | The Kalahari | The Namib
        fr: Quel désert couvre le sud de la Tunisie ? | Le Sahara | Le désert de Gobi | Le Kalahari | Le Namib
        es: ¿Qué desierto cubre el sur de Túnez? | El Sahara | El Gobi | El Kalahari | El Namib
        de: Welche Wüste bedeckt den Süden Tunesiens? | Die Sahara | Die Gobi | Die Kalahari | Die Namib
        it: Quale deserto copre il sud della Tunisia? | Il Sahara | Il Gobi | Il Kalahari | Il Namib
        pt: Que deserto cobre o sul da Tunísia? | O Saara | O Gobi | O Kalahari | O Namibe
        ja: チュニジアの南部に広がる砂漠は？ | サハラ砂漠 | ゴビ砂漠 | カラハリ砂漠 | ナミブ砂漠
        ko: 튀니지 남부를 덮고 있는 사막은? | 사하라 사막 | 고비 사막 | 칼라하리 사막 | 나미브 사막
        zh: 突尼斯南部被哪片沙漠覆盖？ | 撒哈拉沙漠 | 戈壁沙漠 | 卡拉哈里沙漠 | 纳米布沙漠
        ar: أي صحراء تغطي جنوب تونس؟ | الصحراء الكبرى | صحراء غوبي | صحراء كالاهاري | صحراء ناميب

        # med.tatooine mediterranean 2
        en: Scenes of the planet Tatooine in Star Wars were filmed in which country? | Tunisia | Morocco | Egypt | Jordan
        fr: Les scènes de la planète Tatooine de Star Wars ont été tournées dans quel pays ? | La Tunisie | Le Maroc | L'Égypte | La Jordanie
        es: ¿En qué país se rodaron las escenas del planeta Tatooine de Star Wars? | Túnez | Marruecos | Egipto | Jordania
        de: In welchem Land wurden Szenen des Planeten Tatooine aus Star Wars gedreht? | Tunesien | Marokko | Ägypten | Jordanien
        it: In quale Paese furono girate le scene del pianeta Tatooine di Star Wars? | Tunisia | Marocco | Egitto | Giordania
        pt: Em que país foram filmadas as cenas do planeta Tatooine, de Star Wars? | Tunísia | Marrocos | Egito | Jordânia
        ja: 『スター・ウォーズ』の惑星タトゥイーンの場面が撮影された国は？ | チュニジア | モロッコ | エジプト | ヨルダン
        ko: '스타워즈'의 행성 타투인 장면을 촬영한 나라는? | 튀니지 | 모로코 | 이집트 | 요르단
        zh: 《星球大战》中塔图因星球的场景是在哪个国家拍摄的？ | 突尼斯 | 摩洛哥 | 埃及 | 约旦
        ar: في أي بلد صُوّرت مشاهد كوكب تاتوين في «حرب النجوم»؟ | تونس | المغرب | مصر | الأردن

        # med.djerba mediterranean 2
        en: What is Djerba, in Tunisia? | An island | A mountain | A river | A lake
        fr: Qu'est-ce que Djerba, en Tunisie ? | Une île | Une montagne | Un fleuve | Un lac
        es: ¿Qué es Yerba (Djerba), en Túnez? | Una isla | Una montaña | Un río | Un lago
        de: Was ist Djerba in Tunesien? | Eine Insel | Ein Berg | Ein Fluss | Ein See
        it: Che cos'è Djerba, in Tunisia? | Un'isola | Una montagna | Un fiume | Un lago
        pt: O que é Djerba, na Tunísia? | Uma ilha | Uma montanha | Um rio | Um lago
        ja: チュニジアのジェルバとは何？ | 島 | 山 | 川 | 湖
        ko: 튀니지의 제르바는 무엇일까요? | 섬 | 산 | 강 | 호수
        zh: 突尼斯的杰尔巴是什么？ | 一座岛 | 一座山 | 一条河 | 一个湖
        ar: ما جربة في تونس؟ | جزيرة | جبل | نهر | بحيرة

        # med.couscous mediterranean 1
        en: Couscous is made from what? | Semolina (durum wheat) | Rice | Corn | Potato
        fr: Avec quoi le couscous est-il fait ? | De la semoule de blé dur | Du riz | Du maïs | De la pomme de terre
        es: ¿De qué está hecho el cuscús? | Sémola de trigo duro | Arroz | Maíz | Patata
        de: Woraus wird Couscous gemacht? | Aus Hartweizengrieß | Aus Reis | Aus Mais | Aus Kartoffeln
        it: Con che cosa si fa il cuscus? | Semola di grano duro | Riso | Mais | Patate
        pt: O cuscuz marroquino (couscous) é feito de quê? | Sêmola de trigo duro | Arroz | Milho | Batata
        ja: クスクスは何からつくられる？ | デュラム小麦のセモリナ | 米 | トウモロコシ | ジャガイモ
        ko: 쿠스쿠스는 무엇으로 만들까요? | 듀럼밀 세몰리나 | 쌀 | 옥수수 | 감자
        zh: 古斯米（库斯库斯）是用什么做的？ | 硬粒小麦粗粒粉 | 大米 | 玉米 | 土豆
        ar: مِمّ يُصنع الكسكسي؟ | سميد القمح الصلب | الأرز | الذرة | البطاطا

        # med.harissa mediterranean 2
        en: Harissa, the Tunisian paste, is made mainly from what? | Hot chili peppers | Olives | Dates | Chickpeas
        fr: La harissa, la pâte tunisienne, est faite surtout avec quoi ? | Des piments forts | Des olives | Des dattes | Des pois chiches
        es: ¿Con qué se hace sobre todo la harissa, la pasta tunecina? | Guindillas picantes | Aceitunas | Dátiles | Garbanzos
        de: Woraus besteht die tunesische Paste Harissa hauptsächlich? | Aus scharfen Chilischoten | Aus Oliven | Aus Datteln | Aus Kichererbsen
        it: Con che cosa si fa soprattutto l'harissa, la salsa tunisina? | Peperoncini piccanti | Olive | Datteri | Ceci
        pt: A harissa, pasta tunisiana, é feita principalmente de quê? | Pimentas picantes | Azeitonas | Tâmaras | Grão-de-bico
        ja: チュニジアの調味料ハリッサのおもな材料は？ | 辛い唐辛子 | オリーブ | ナツメヤシ | ひよこ豆
        ko: 튀니지 양념 하리사의 주재료는? | 매운 고추 | 올리브 | 대추야자 | 병아리콩
        zh: 突尼斯辣酱（哈里萨）主要用什么做？ | 辣椒 | 橄榄 | 椰枣 | 鹰嘴豆
        ar: مِمّ تُصنع الهريسة التونسية أساسًا؟ | الفلفل الحار | الزيتون | التمر | الحمّص

        # med.olive-oil mediterranean 2
        en: Tunisia is one of the world's biggest producers of what? | Olive oil | Coffee | Rice | Tea
        fr: La Tunisie est l'un des plus grands producteurs mondiaux de quoi ? | D'huile d'olive | De café | De riz | De thé
        es: Túnez es uno de los mayores productores del mundo de… | Aceite de oliva | Café | Arroz | Té
        de: Tunesien ist einer der größten Erzeuger der Welt von… | Olivenöl | Kaffee | Reis | Tee
        it: La Tunisia è uno dei maggiori produttori al mondo di… | Olio d'oliva | Caffè | Riso | Tè
        pt: A Tunísia é um dos maiores produtores do mundo de quê? | Azeite de oliva | Café | Arroz | Chá
        ja: チュニジアが世界有数の生産国となっているものは？ | オリーブオイル | コーヒー | 米 | 茶
        ko: 튀니지가 세계적인 생산국으로 손꼽히는 것은? | 올리브유 | 커피 | 쌀 | 차
        zh: 突尼斯是世界上哪种产品的主要生产国之一？ | 橄榄油 | 咖啡 | 大米 | 茶叶
        ar: تونس من أكبر منتجي أي سلعة في العالم؟ | زيت الزيتون | البن | الأرز | الشاي

        # med.deglet-nour mediterranean 3
        en: Deglet Nour is a famous variety of which fruit grown in Tunisia? | Dates | Figs | Olives | Oranges
        fr: La Deglet Nour est une célèbre variété de quel fruit cultivé en Tunisie ? | La datte | La figue | L'olive | L'orange
        es: ¿De qué fruta cultivada en Túnez es variedad la famosa Deglet Nour? | Dátil | Higo | Aceituna | Naranja
        de: Deglet Nour ist eine berühmte Sorte welcher Frucht aus Tunesien? | Dattel | Feige | Olive | Orange
        it: Deglet Nour è una famosa varietà di quale frutto coltivato in Tunisia? | Dattero | Fico | Oliva | Arancia
        pt: Deglet Nour é uma famosa variedade de qual fruta cultivada na Tunísia? | Tâmara | Figo | Azeitona | Laranja
        ja: デグレット・ヌールはチュニジアで育つ何の有名な品種？ | ナツメヤシ（デーツ） | イチジク | オリーブ | オレンジ
        ko: 데글렛 누르는 튀니지에서 나는 어떤 과일의 유명한 품종일까요? | 대추야자 | 무화과 | 올리브 | 오렌지
        zh: “德格莱特·努尔”是突尼斯出产的哪种水果的著名品种？ | 椰枣 | 无花果 | 橄榄 | 橙子
        ar: «دقلة نور» صنف شهير من أي ثمرة تُزرع في تونس؟ | التمر | التين | الزيتون | البرتقال

        # med.tunisian-dinar mediterranean 2
        en: What is the currency of Tunisia? | The dinar | The dirham | The pound | The euro
        fr: Quelle est la monnaie de la Tunisie ? | Le dinar | Le dirham | La livre | L'euro
        es: ¿Cuál es la moneda de Túnez? | El dinar | El dírham | La libra | El euro
        de: Wie heißt die Währung Tunesiens? | Dinar | Dirham | Pfund | Euro
        it: Qual è la moneta della Tunisia? | Il dinaro | Il dirham | La sterlina | L'euro
        pt: Qual é a moeda da Tunísia? | O dinar | O dirham | A libra | O euro
        ja: チュニジアの通貨は？ | ディナール | ディルハム | ポンド | ユーロ
        ko: 튀니지의 화폐는? | 디나르 | 디르함 | 파운드 | 유로
        zh: 突尼斯的货币是什么？ | 第纳尔 | 迪拉姆 | 镑 | 欧元
        ar: ما عملة تونس؟ | الدينار | الدرهم | الجنيه | اليورو

        # med.jasmine mediterranean 2
        en: Which flower is a well-loved symbol of Tunisia? | Jasmine | Tulip | Lotus | Edelweiss
        fr: Quelle fleur est un symbole très aimé de la Tunisie ? | Le jasmin | La tulipe | Le lotus | L'edelweiss
        es: ¿Qué flor es un querido símbolo de Túnez? | El jazmín | El tulipán | El loto | La flor de nieve
        de: Welche Blume ist ein beliebtes Symbol Tunesiens? | Jasmin | Tulpe | Lotus | Edelweiß
        it: Quale fiore è un simbolo amato della Tunisia? | Il gelsomino | Il tulipano | Il loto | La stella alpina
        pt: Que flor é um símbolo querido da Tunísia? | O jasmim | A tulipa | O lótus | O edelvais
        ja: チュニジアで愛されるシンボルの花は？ | ジャスミン | チューリップ | ハス | エーデルワイス
        ko: 튀니지에서 사랑받는 상징인 꽃은? | 재스민 | 튤립 | 연꽃 | 에델바이스
        zh: 哪种花是突尼斯深受喜爱的象征？ | 茉莉花 | 郁金香 | 莲花 | 雪绒花
        ar: أي زهرة رمزٌ محبوب لتونس؟ | الياسمين | التوليب | اللوتس | الإديلفايس

        # med.largest-island mediterranean 2
        en: What is the largest island in the Mediterranean? | Sicily | Sardinia | Cyprus | Crete
        fr: Quelle est la plus grande île de la Méditerranée ? | La Sicile | La Sardaigne | Chypre | La Crète
        es: ¿Cuál es la isla más grande del Mediterráneo? | Sicilia | Cerdeña | Chipre | Creta
        de: Welches ist die größte Insel im Mittelmeer? | Sizilien | Sardinien | Zypern | Kreta
        it: Qual è l'isola più grande del Mediterraneo? | La Sicilia | La Sardegna | Cipro | Creta
        pt: Qual é a maior ilha do Mediterrâneo? | Sicília | Sardenha | Chipre | Creta
        ja: 地中海でいちばん大きな島は？ | シチリア島 | サルデーニャ島 | キプロス島 | クレタ島
        ko: 지중해에서 가장 큰 섬은? | 시칠리아섬 | 사르데냐섬 | 키프로스섬 | 크레타섬
        zh: 地中海最大的岛屿是哪个？ | 西西里岛 | 撒丁岛 | 塞浦路斯岛 | 克里特岛
        ar: ما أكبر جزيرة في البحر المتوسط؟ | صقلية | سردينيا | قبرص | كريت

        # med.gibraltar mediterranean 2
        en: The Strait of Gibraltar links the Mediterranean with what? | The Atlantic Ocean | The Red Sea | The Black Sea | The Indian Ocean
        fr: Le détroit de Gibraltar relie la Méditerranée à quoi ? | L'océan Atlantique | La mer Rouge | La mer Noire | L'océan Indien
        es: ¿Con qué une el estrecho de Gibraltar al Mediterráneo? | El océano Atlántico | El mar Rojo | El mar Negro | El océano Índico
        de: Womit verbindet die Straße von Gibraltar das Mittelmeer? | Mit dem Atlantik | Mit dem Roten Meer | Mit dem Schwarzen Meer | Mit dem Indischen Ozean
        it: Con che cosa collega il Mediterraneo lo stretto di Gibilterra? | L'oceano Atlantico | Il mar Rosso | Il mar Nero | L'oceano Indiano
        pt: O estreito de Gibraltar liga o Mediterrâneo a quê? | Ao oceano Atlântico | Ao mar Vermelho | Ao mar Negro | Ao oceano Índico
        ja: ジブラルタル海峡が地中海とつないでいるのは？ | 大西洋 | 紅海 | 黒海 | インド洋
        ko: 지브롤터 해협은 지중해를 어디와 이어 줄까요? | 대서양 | 홍해 | 흑해 | 인도양
        zh: 直布罗陀海峡把地中海与什么连接起来？ | 大西洋 | 红海 | 黑海 | 印度洋
        ar: بماذا يصل مضيق جبل طارق البحر المتوسط؟ | المحيط الأطلسي | البحر الأحمر | البحر الأسود | المحيط الهندي

        # med.suez mediterranean 2
        en: The Suez Canal links the Mediterranean with which sea? | The Red Sea | The Black Sea | The Caspian Sea | The North Sea
        fr: Le canal de Suez relie la Méditerranée à quelle mer ? | La mer Rouge | La mer Noire | La mer Caspienne | La mer du Nord
        es: ¿Con qué mar une el canal de Suez al Mediterráneo? | El mar Rojo | El mar Negro | El mar Caspio | El mar del Norte
        de: Mit welchem Meer verbindet der Suezkanal das Mittelmeer? | Mit dem Roten Meer | Mit dem Schwarzen Meer | Mit dem Kaspischen Meer | Mit der Nordsee
        it: Con quale mare collega il Mediterraneo il canale di Suez? | Il mar Rosso | Il mar Nero | Il mar Caspio | Il mare del Nord
        pt: O canal de Suez liga o Mediterrâneo a qual mar? | Ao mar Vermelho | Ao mar Negro | Ao mar Cáspio | Ao mar do Norte
        ja: スエズ運河が地中海とつないでいる海は？ | 紅海 | 黒海 | カスピ海 | 北海
        ko: 수에즈 운하는 지중해를 어느 바다와 이어 줄까요? | 홍해 | 흑해 | 카스피해 | 북해
        zh: 苏伊士运河把地中海与哪个海连接起来？ | 红海 | 黑海 | 里海 | 北海
        ar: بأي بحر تصل قناة السويس البحر المتوسط؟ | البحر الأحمر | البحر الأسود | بحر قزوين | بحر الشمال

        # med.etna mediterranean 2
        en: Mount Etna, an active volcano, is on which island? | Sicily | Sardinia | Corsica | Crete
        fr: L'Etna, un volcan actif, se trouve sur quelle île ? | La Sicile | La Sardaigne | La Corse | La Crète
        es: ¿En qué isla está el Etna, un volcán activo? | Sicilia | Cerdeña | Córcega | Creta
        de: Auf welcher Insel liegt der aktive Vulkan Ätna? | Sizilien | Sardinien | Korsika | Kreta
        it: Su quale isola si trova l'Etna, un vulcano attivo? | Sicilia | Sardegna | Corsica | Creta
        pt: Em que ilha fica o Etna, um vulcão ativo? | Sicília | Sardenha | Córsega | Creta
        ja: 活火山エトナ山がある島は？ | シチリア島 | サルデーニャ島 | コルシカ島 | クレタ島
        ko: 활화산 에트나산이 있는 섬은? | 시칠리아섬 | 사르데냐섬 | 코르시카섬 | 크레타섬
        zh: 活火山埃特纳火山在哪个岛上？ | 西西里岛 | 撒丁岛 | 科西嘉岛 | 克里特岛
        ar: على أي جزيرة يقع بركان إتنا النشط؟ | صقلية | سردينيا | كورسيكا | كريت

        # med.corsica mediterranean 2
        en: The island of Corsica belongs to which country? | France | Italy | Spain | Greece
        fr: À quel pays appartient la Corse ? | La France | L'Italie | L'Espagne | La Grèce
        es: ¿A qué país pertenece la isla de Córcega? | Francia | Italia | España | Grecia
        de: Zu welchem Land gehört die Insel Korsika? | Frankreich | Italien | Spanien | Griechenland
        it: A quale Paese appartiene la Corsica? | Francia | Italia | Spagna | Grecia
        pt: A ilha da Córsega pertence a qual país? | França | Itália | Espanha | Grécia
        ja: コルシカ島はどの国の島？ | フランス | イタリア | スペイン | ギリシャ
        ko: 코르시카섬은 어느 나라에 속할까요? | 프랑스 | 이탈리아 | 스페인 | 그리스
        zh: 科西嘉岛属于哪个国家？ | 法国 | 意大利 | 西班牙 | 希腊
        ar: لأي دولة تتبع جزيرة كورسيكا؟ | فرنسا | إيطاليا | إسبانيا | اليونان

        # med.malta-capital mediterranean 2
        en: What is the capital of Malta? | Valletta | Mdina | Nicosia | Palermo
        fr: Quelle est la capitale de Malte ? | La Valette | Mdina | Nicosie | Palerme
        es: ¿Cuál es la capital de Malta? | La Valeta | Mdina | Nicosia | Palermo
        de: Was ist die Hauptstadt Maltas? | Valletta | Mdina | Nikosia | Palermo
        it: Qual è la capitale di Malta? | La Valletta | Mdina | Nicosia | Palermo
        pt: Qual é a capital de Malta? | Valeta | Mdina | Nicósia | Palermo
        ja: マルタの首都は？ | バレッタ | イムディーナ | ニコシア | パレルモ
        ko: 몰타의 수도는? | 발레타 | 임디나 | 니코시아 | 팔레르모
        zh: 马耳他的首都是哪里？ | 瓦莱塔 | 姆迪纳 | 尼科西亚 | 巴勒莫
        ar: ما عاصمة مالطا؟ | فاليتا | مدينا | نيقوسيا | باليرمو

        # med.acropolis mediterranean 1
        en: In which city is the Acropolis? | Athens | Rome | Istanbul | Alexandria
        fr: Dans quelle ville se trouve l'Acropole ? | Athènes | Rome | Istanbul | Alexandrie
        es: ¿En qué ciudad está la Acrópolis? | Atenas | Roma | Estambul | Alejandría
        de: In welcher Stadt liegt die Akropolis? | Athen | Rom | Istanbul | Alexandria
        it: In quale città si trova l'Acropoli? | Atene | Roma | Istanbul | Alessandria
        pt: Em que cidade fica a Acrópole? | Atenas | Roma | Istambul | Alexandria
        ja: アクロポリスがある都市は？ | アテネ | ローマ | イスタンブール | アレクサンドリア
        ko: 아크로폴리스가 있는 도시는? | 아테네 | 로마 | 이스탄불 | 알렉산드리아
        zh: 雅典卫城在哪座城市？ | 雅典 | 罗马 | 伊斯坦布尔 | 亚历山大
        ar: في أي مدينة يقع الأكروبوليس؟ | أثينا | روما | إسطنبول | الإسكندرية

        # med.pharos mediterranean 2
        en: The famous ancient lighthouse, the Pharos, stood in which city? | Alexandria | Carthage | Athens | Rhodes
        fr: Le célèbre phare antique, le Phare, se dressait dans quelle ville ? | Alexandrie | Carthage | Athènes | Rhodes
        es: ¿En qué ciudad estaba el famoso faro antiguo, el Faro? | Alejandría | Cartago | Atenas | Rodas
        de: In welcher Stadt stand der berühmte antike Leuchtturm Pharos? | Alexandria | Karthago | Athen | Rhodos
        it: In quale città sorgeva il famoso faro antico, il Faro? | Alessandria | Cartagine | Atene | Rodi
        pt: Em que cidade ficava o famoso farol antigo, o Farol? | Alexandria | Cartago | Atenas | Rodes
        ja: 古代の有名な灯台「ファロス島の大灯台」があった都市は？ | アレクサンドリア | カルタゴ | アテネ | ロドス
        ko: 고대의 유명한 등대 '파로스 등대'가 있던 도시는? | 알렉산드리아 | 카르타고 | 아테네 | 로도스
        zh: 著名的古代法罗斯灯塔位于哪座城市？ | 亚历山大 | 迦太基 | 雅典 | 罗得岛
        ar: في أي مدينة كانت منارة فاروس القديمة الشهيرة؟ | الإسكندرية | قرطاج | أثينا | رودس

        # med.colossus mediterranean 3
        en: The Colossus, a giant ancient statue, stood on which island? | Rhodes | Crete | Sicily | Malta
        fr: Le Colosse, une statue antique géante, se dressait sur quelle île ? | Rhodes | La Crète | La Sicile | Malte
        es: ¿En qué isla estaba el Coloso, una estatua antigua gigante? | Rodas | Creta | Sicilia | Malta
        de: Auf welcher Insel stand der Koloss, eine riesige antike Statue? | Rhodos | Kreta | Sizilien | Malta
        it: Su quale isola sorgeva il Colosso, una statua antica gigante? | Rodi | Creta | Sicilia | Malta
        pt: Em que ilha ficava o Colosso, uma estátua antiga gigante? | Rodes | Creta | Sicília | Malta
        ja: 古代の巨大な像「巨像」が立っていた島は？ | ロドス島 | クレタ島 | シチリア島 | マルタ島
        ko: 고대의 거대한 조각상 '거상'이 서 있던 섬은? | 로도스섬 | 크레타섬 | 시칠리아섬 | 몰타섬
        zh: 古代巨像矗立在哪个岛上？ | 罗得岛 | 克里特岛 | 西西里岛 | 马耳他岛
        ar: على أي جزيرة وقف التمثال العملاق القديم (العملاق)؟ | رودس | كريت | صقلية | مالطا

        # med.gondolas mediterranean 1
        en: In which city are gondolas a famous sight? | Venice | Naples | Barcelona | Marseille
        fr: Dans quelle ville les gondoles sont-elles célèbres ? | Venise | Naples | Barcelone | Marseille
        es: ¿En qué ciudad son famosas las góndolas? | Venecia | Nápoles | Barcelona | Marsella
        de: In welcher Stadt sind Gondeln berühmt? | Venedig | Neapel | Barcelona | Marseille
        it: In quale città sono famose le gondole? | Venezia | Napoli | Barcellona | Marsiglia
        pt: Em que cidade as gôndolas são famosas? | Veneza | Nápoles | Barcelona | Marselha
        ja: ゴンドラで有名な都市は？ | ベネチア | ナポリ | バルセロナ | マルセイユ
        ko: 곤돌라로 유명한 도시는? | 베네치아 | 나폴리 | 바르셀로나 | 마르세유
        zh: 哪座城市以贡多拉小船闻名？ | 威尼斯 | 那不勒斯 | 巴塞罗那 | 马赛
        ar: في أي مدينة تشتهر قوارب الجندول؟ | البندقية | نابولي | برشلونة | مرسيليا

        # med.marseille mediterranean 3
        en: Which is France's oldest city, founded by Greeks around 600 BC? | Marseille | Nice | Paris | Lyon
        fr: Quelle est la plus vieille ville de France, fondée par des Grecs vers 600 av. J.-C. ? | Marseille | Nice | Paris | Lyon
        es: ¿Cuál es la ciudad más antigua de Francia, fundada por griegos hacia el 600 a. C.? | Marsella | Niza | París | Lyon
        de: Welche ist die älteste Stadt Frankreichs, um 600 v. Chr. von Griechen gegründet? | Marseille | Nizza | Paris | Lyon
        it: Qual è la città più antica della Francia, fondata dai Greci intorno al 600 a.C.? | Marsiglia | Nizza | Parigi | Lione
        pt: Qual é a cidade mais antiga da França, fundada por gregos por volta de 600 a.C.? | Marselha | Nice | Paris | Lyon
        ja: 紀元前600年ごろにギリシャ人が築いた、フランス最古の都市は？ | マルセイユ | ニース | パリ | リヨン
        ko: 기원전 600년경 그리스인이 세운 프랑스에서 가장 오래된 도시는? | 마르세유 | 니스 | 파리 | 리옹
        zh: 约公元前600年由希腊人建立、法国最古老的城市是哪座？ | 马赛 | 尼斯 | 巴黎 | 里昂
        ar: ما أقدم مدينة في فرنسا، أسّسها الإغريق نحو 600 قبل الميلاد؟ | مرسيليا | نيس | باريس | ليون

        # med.morocco-capital mediterranean 2
        en: What is the capital of Morocco? | Rabat | Casablanca | Marrakesh | Fez
        fr: Quelle est la capitale du Maroc ? | Rabat | Casablanca | Marrakech | Fès
        es: ¿Cuál es la capital de Marruecos? | Rabat | Casablanca | Marrakech | Fez
        de: Was ist die Hauptstadt Marokkos? | Rabat | Casablanca | Marrakesch | Fès
        it: Qual è la capitale del Marocco? | Rabat | Casablanca | Marrakech | Fès
        pt: Qual é a capital do Marrocos? | Rabat | Casablanca | Marrakech | Fez
        ja: モロッコの首都は？ | ラバト | カサブランカ | マラケシュ | フェズ
        ko: 모로코의 수도는? | 라바트 | 카사블랑카 | 마라케시 | 페스
        zh: 摩洛哥的首都是哪里？ | 拉巴特 | 卡萨布兰卡 | 马拉喀什 | 非斯
        ar: ما عاصمة المغرب؟ | الرباط | الدار البيضاء | مراكش | فاس

        # med.algeria-capital mediterranean 1
        en: What is the capital of Algeria? | Algiers | Oran | Constantine | Annaba
        fr: Quelle est la capitale de l'Algérie ? | Alger | Oran | Constantine | Annaba
        es: ¿Cuál es la capital de Argelia? | Argel | Orán | Constantina | Annaba
        de: Was ist die Hauptstadt Algeriens? | Algier | Oran | Constantine | Annaba
        it: Qual è la capitale dell'Algeria? | Algeri | Orano | Costantina | Annaba
        pt: Qual é a capital da Argélia? | Argel | Orã | Constantina | Annaba
        ja: アルジェリアの首都は？ | アルジェ | オラン | コンスタンティーヌ | アンナバ
        ko: 알제리의 수도는? | 알제 | 오랑 | 콩스탕틴 | 안나바
        zh: 阿尔及利亚的首都是哪里？ | 阿尔及尔 | 奥兰 | 君士坦丁 | 安纳巴
        ar: ما عاصمة الجزائر؟ | الجزائر العاصمة | وهران | قسنطينة | عنابة

        # med.libya-capital mediterranean 2
        en: What is the capital of Libya? | Tripoli | Benghazi | Misrata | Tobruk
        fr: Quelle est la capitale de la Libye ? | Tripoli | Benghazi | Misrata | Tobrouk
        es: ¿Cuál es la capital de Libia? | Trípoli | Bengasi | Misrata | Tobruk
        de: Was ist die Hauptstadt Libyens? | Tripolis | Bengasi | Misrata | Tobruk
        it: Qual è la capitale della Libia? | Tripoli | Bengasi | Misurata | Tobruch
        pt: Qual é a capital da Líbia? | Trípoli | Benghazi | Misrata | Tobruk
        ja: リビアの首都は？ | トリポリ | ベンガジ | ミスラタ | トブルク
        ko: 리비아의 수도는? | 트리폴리 | 벵가지 | 미스라타 | 투브루크
        zh: 利比亚的首都是哪里？ | 的黎波里 | 班加西 | 米苏拉塔 | 图卜鲁格
        ar: ما عاصمة ليبيا؟ | طرابلس | بنغازي | مصراتة | طبرق

        # med.cedar mediterranean 2
        en: Which tree is on the flag of Lebanon? | The cedar | The olive tree | The palm tree | The oak
        fr: Quel arbre figure sur le drapeau du Liban ? | Le cèdre | L'olivier | Le palmier | Le chêne
        es: ¿Qué árbol aparece en la bandera del Líbano? | El cedro | El olivo | La palmera | El roble
        de: Welcher Baum ist auf der Flagge des Libanon? | Die Zeder | Der Olivenbaum | Die Palme | Die Eiche
        it: Quale albero c'è sulla bandiera del Libano? | Il cedro | L'olivo | La palma | La quercia
        pt: Que árvore aparece na bandeira do Líbano? | O cedro | A oliveira | A palmeira | O carvalho
        ja: レバノンの国旗に描かれている木は？ | レバノンスギ | オリーブ | ヤシ | オーク
        ko: 레바논 국기에 그려진 나무는? | 백향목(레바논삼나무) | 올리브나무 | 야자나무 | 참나무
        zh: 黎巴嫩国旗上画的是哪种树？ | 雪松 | 橄榄树 | 棕榈树 | 橡树
        ar: أي شجرة تظهر على علم لبنان؟ | الأرز | الزيتون | النخيل | البلوط

        # med.olive-branch mediterranean 1
        en: An olive branch is a symbol of what? | Peace | War | Wealth | Speed
        fr: Un rameau d'olivier est le symbole de quoi ? | La paix | La guerre | La richesse | La vitesse
        es: ¿De qué es símbolo una rama de olivo? | La paz | La guerra | La riqueza | La velocidad
        de: Wofür ist ein Olivenzweig ein Symbol? | Frieden | Krieg | Reichtum | Schnelligkeit
        it: Di che cosa è simbolo un ramoscello d'ulivo? | La pace | La guerra | La ricchezza | La velocità
        pt: Um ramo de oliveira é símbolo de quê? | Paz | Guerra | Riqueza | Velocidade
        ja: オリーブの枝は何の象徴？ | 平和 | 戦争 | 富 | 速さ
        ko: 올리브 가지는 무엇의 상징일까요? | 평화 | 전쟁 | 부 | 속도
        zh: 橄榄枝象征什么？ | 和平 | 战争 | 财富 | 速度
        ar: غصن الزيتون رمزٌ لماذا؟ | السلام | الحرب | الثروة | السرعة

        # med.alphabet-word mediterranean 2
        en: The word "alphabet" comes from the first two letters of which alphabet? | Greek | Latin | Arabic | Cyrillic
        fr: Le mot « alphabet » vient des deux premières lettres de quel alphabet ? | Grec | Latin | Arabe | Cyrillique
        es: ¿De las dos primeras letras de qué alfabeto viene la palabra «alfabeto»? | Griego | Latino | Árabe | Cirílico
        de: Das Wort „Alphabet“ kommt von den ersten beiden Buchstaben welches Alphabets? | Griechisch | Lateinisch | Arabisch | Kyrillisch
        it: La parola «alfabeto» viene dalle prime due lettere di quale alfabeto? | Greco | Latino | Arabo | Cirillico
        pt: A palavra "alfabeto" vem das duas primeiras letras de qual alfabeto? | Grego | Latino | Árabe | Cirílico
        ja: 「アルファベット」という言葉は、どの文字の最初の2文字から来た？ | ギリシャ文字 | ラテン文字 | アラビア文字 | キリル文字
        ko: '알파벳'이라는 말은 어느 문자의 첫 두 글자에서 왔을까요? | 그리스 문자 | 라틴 문자 | 아랍 문자 | 키릴 문자
        zh: “字母表（alphabet）”一词来自哪种字母的前两个字母？ | 希腊字母 | 拉丁字母 | 阿拉伯字母 | 西里尔字母
        ar: من أول حرفين في أي أبجدية جاءت كلمة «ألفبائية» (alphabet)؟ | اليونانية | اللاتينية | العربية | السيريلية

        # med.carthage-founders mediterranean 3
        en: Carthage was founded by settlers from which people? | The Phoenicians | The Greeks | The Romans | The Egyptians
        fr: Carthage a été fondée par des colons de quel peuple ? | Les Phéniciens | Les Grecs | Les Romains | Les Égyptiens
        es: ¿Qué pueblo fundó Cartago? | Los fenicios | Los griegos | Los romanos | Los egipcios
        de: Von welchem Volk wurde Karthago gegründet? | Den Phöniziern | Den Griechen | Den Römern | Den Ägyptern
        it: Quale popolo fondò Cartagine? | I Fenici | I Greci | I Romani | Gli Egizi
        pt: Que povo fundou Cartago? | Os fenícios | Os gregos | Os romanos | Os egípcios
        ja: カルタゴを建てたのはどの民族？ | フェニキア人 | ギリシャ人 | ローマ人 | エジプト人
        ko: 카르타고를 세운 사람들은? | 페니키아인 | 그리스인 | 로마인 | 이집트인
        zh: 迦太基是哪个民族的移民建立的？ | 腓尼基人 | 希腊人 | 罗马人 | 埃及人
        ar: أي شعب أسّس قرطاج؟ | الفينيقيون | الإغريق | الرومان | المصريون

        # med.mare-nostrum mediterranean 3
        en: The Romans called the Mediterranean "Mare Nostrum". What does it mean? | Our sea | Middle sea | Blue sea | Great sea
        fr: Les Romains appelaient la Méditerranée « Mare Nostrum ». Qu'est-ce que cela veut dire ? | Notre mer | La mer du milieu | La mer bleue | La grande mer
        es: Los romanos llamaban al Mediterráneo «Mare Nostrum». ¿Qué significa? | Nuestro mar | Mar del medio | Mar azul | Gran mar
        de: Die Römer nannten das Mittelmeer „Mare Nostrum“. Was bedeutet das? | Unser Meer | Mittleres Meer | Blaues Meer | Großes Meer
        it: I Romani chiamavano il Mediterraneo «Mare Nostrum». Che cosa significa? | Il nostro mare | Il mare di mezzo | Il mare blu | Il grande mare
        pt: Os romanos chamavam o Mediterrâneo de "Mare Nostrum". O que isso significa? | Nosso mar | Mar do meio | Mar azul | Grande mar
        ja: ローマ人は地中海を「マーレ・ノストルム」と呼びました。意味は？ | われらの海 | 真ん中の海 | 青い海 | 大きな海
        ko: 로마인은 지중해를 '마레 노스트룸'이라고 불렀어요. 무슨 뜻일까요? | 우리의 바다 | 가운데 바다 | 푸른 바다 | 큰 바다
        zh: 罗马人称地中海为“Mare Nostrum”，意思是什么？ | 我们的海 | 中间的海 | 蓝色的海 | 大海
        ar: سمّى الرومان البحر المتوسط «ماري نوستروم». ماذا يعني ذلك؟ | بحرنا | البحر الأوسط | البحر الأزرق | البحر العظيم

        # med.mediterranean-name mediterranean 2
        en: The name "Mediterranean" comes from Latin words meaning what? | In the middle of the land | Warm water | Blue sea | Sea of the gods
        fr: Le nom « Méditerranée » vient de mots latins qui veulent dire quoi ? | Au milieu des terres | Eau chaude | Mer bleue | Mer des dieux
        es: El nombre «Mediterráneo» viene de palabras latinas que significan… | En medio de la tierra | Agua cálida | Mar azul | Mar de los dioses
        de: Der Name „Mittelmeer“ (Mediterraneum) kommt aus dem Lateinischen. Was bedeutet er? | Inmitten des Landes | Warmes Wasser | Blaues Meer | Meer der Götter
        it: Il nome «Mediterraneo» viene da parole latine che significano… | In mezzo alle terre | Acqua calda | Mare blu | Mare degli dèi
        pt: O nome "Mediterrâneo" vem de palavras latinas que significam o quê? | No meio das terras | Água quente | Mar azul | Mar dos deuses
        ja: 「地中海（Mediterranean）」の語源となったラテン語の意味は？ | 陸地の真ん中 | 温かい水 | 青い海 | 神々の海
        ko: '지중해(Mediterranean)'라는 이름은 어떤 뜻의 라틴어에서 왔을까요? | 육지의 한가운데 | 따뜻한 물 | 푸른 바다 | 신들의 바다
        zh: “地中海（Mediterranean）”一名源自拉丁语，意思是什么？ | 陆地中间 | 温暖的水 | 蓝色的海 | 众神之海
        ar: اسم «المتوسط» (Mediterranean) مأخوذ من كلمات لاتينية تعني ماذا؟ | في وسط اليابسة | الماء الدافئ | البحر الأزرق | بحر الآلهة

        # med.tunisia-flag mediterranean 2
        en: The flag of Tunisia is mostly which colour? | Red | Green | Blue | Black
        fr: Le drapeau de la Tunisie est surtout de quelle couleur ? | Rouge | Vert | Bleu | Noir
        es: ¿De qué color es sobre todo la bandera de Túnez? | Rojo | Verde | Azul | Negro
        de: Welche Farbe hat die Flagge Tunesiens überwiegend? | Rot | Grün | Blau | Schwarz
        it: Di che colore è soprattutto la bandiera della Tunisia? | Rosso | Verde | Blu | Nero
        pt: A bandeira da Tunísia é principalmente de que cor? | Vermelho | Verde | Azul | Preto
        ja: チュニジアの国旗はおもに何色？ | 赤 | 緑 | 青 | 黒
        ko: 튀니지 국기는 주로 무슨 색일까요? | 빨간색 | 초록색 | 파란색 | 검은색
        zh: 突尼斯国旗主要是什么颜色？ | 红色 | 绿色 | 蓝色 | 黑色
        ar: ما اللون الغالب على علم تونس؟ | الأحمر | الأخضر | الأزرق | الأسود

        # med.ibn-khaldun mediterranean 3
        en: In which city was the great historian Ibn Khaldun born? | Tunis | Cairo | Fez | Seville
        fr: Dans quelle ville est né le grand historien Ibn Khaldoun ? | Tunis | Le Caire | Fès | Séville
        es: ¿En qué ciudad nació el gran historiador Ibn Jaldún? | Túnez | El Cairo | Fez | Sevilla
        de: In welcher Stadt wurde der große Historiker Ibn Chaldun geboren? | Tunis | Kairo | Fès | Sevilla
        it: In quale città nacque il grande storico Ibn Khaldun? | Tunisi | Il Cairo | Fès | Siviglia
        pt: Em que cidade nasceu o grande historiador Ibn Khaldun? | Túnis | Cairo | Fez | Sevilha
        ja: 偉大な歴史家イブン・ハルドゥーンが生まれた都市は？ | チュニス | カイロ | フェズ | セビリア
        ko: 위대한 역사가 이븐 할둔이 태어난 도시는? | 튀니스 | 카이로 | 페스 | 세비야
        zh: 伟大的历史学家伊本·赫勒敦出生在哪座城市？ | 突尼斯市 | 开罗 | 非斯 | 塞维利亚
        ar: في أي مدينة وُلد المؤرخ الكبير ابن خلدون؟ | تونس | القاهرة | فاس | إشبيلية

        # med.bardo mediterranean 3
        en: The Bardo National Museum in Tunis is famous for what? | Roman mosaics | Egyptian mummies | Impressionist paintings | Dinosaur bones
        fr: Le musée national du Bardo, à Tunis, est célèbre pour quoi ? | Ses mosaïques romaines | Ses momies égyptiennes | Ses tableaux impressionnistes | Ses os de dinosaures
        es: ¿Por qué es famoso el Museo Nacional del Bardo, en Túnez? | Por sus mosaicos romanos | Por sus momias egipcias | Por sus cuadros impresionistas | Por sus huesos de dinosaurio
        de: Wofür ist das Nationalmuseum Bardo in Tunis berühmt? | Für römische Mosaike | Für ägyptische Mumien | Für impressionistische Gemälde | Für Dinosaurierknochen
        it: Per che cosa è famoso il Museo nazionale del Bardo, a Tunisi? | Per i mosaici romani | Per le mummie egizie | Per i quadri impressionisti | Per le ossa di dinosauro
        pt: O Museu Nacional do Bardo, em Túnis, é famoso por quê? | Por mosaicos romanos | Por múmias egípcias | Por quadros impressionistas | Por ossos de dinossauro
        ja: チュニスのバルド国立博物館が有名なのは？ | ローマ時代のモザイク | エジプトのミイラ | 印象派の絵画 | 恐竜の骨
        ko: 튀니스의 바르도 국립 박물관은 무엇으로 유명할까요? | 로마 시대 모자이크 | 이집트 미라 | 인상파 그림 | 공룡 뼈
        zh: 突尼斯市的巴尔杜国家博物馆以什么闻名？ | 古罗马马赛克 | 埃及木乃伊 | 印象派绘画 | 恐龙骨骼
        ar: بماذا يشتهر المتحف الوطني بباردو في تونس؟ | الفسيفساء الرومانية | المومياوات المصرية | اللوحات الانطباعية | عظام الديناصورات

        # med.chebbi mediterranean 3
        en: Aboul-Qacem Echebbi, whose verses are in Tunisia's national anthem, was a what? | Poet | Painter | Footballer | Architect
        fr: Aboul-Qacem Chebbi, dont des vers figurent dans l'hymne tunisien, était un… | Poète | Peintre | Footballeur | Architecte
        es: Abulqasim al-Shabbi, cuyos versos están en el himno de Túnez, era… | Poeta | Pintor | Futbolista | Arquitecto
        de: Abu al-Qasim asch-Schabbi, dessen Verse in Tunesiens Hymne stehen, war ein… | Dichter | Maler | Fußballer | Architekt
        it: Abu al-Qasim al-Shabbi, i cui versi sono nell'inno tunisino, era un… | Poeta | Pittore | Calciatore | Architetto
        pt: Abu al-Qasim al-Shabbi, cujos versos estão no hino da Tunísia, era… | Poeta | Pintor | Jogador de futebol | Arquiteto
        ja: チュニジア国歌に詩が使われているアブル＝カーシム・シャービーの職業は？ | 詩人 | 画家 | サッカー選手 | 建築家
        ko: 튀니지 국가에 시구가 들어간 아불카심 샤비는 무엇을 한 사람일까요? | 시인 | 화가 | 축구 선수 | 건축가
        zh: 突尼斯国歌中采用了其诗句的沙比是做什么的？ | 诗人 | 画家 | 足球运动员 | 建筑师
        ar: أبو القاسم الشابي، الذي تتضمّن أبياته النشيد الوطني التونسي، كان…؟ | شاعرًا | رسامًا | لاعب كرة قدم | مهندسًا معماريًا

        # med.tunisia-neighbours mediterranean 2
        en: Which two countries share a land border with Tunisia? | Algeria and Libya | Morocco and Egypt | Libya and Egypt | Algeria and Morocco
        fr: Quels deux pays ont une frontière terrestre avec la Tunisie ? | L'Algérie et la Libye | Le Maroc et l'Égypte | La Libye et l'Égypte | L'Algérie et le Maroc
        es: ¿Qué dos países tienen frontera terrestre con Túnez? | Argelia y Libia | Marruecos y Egipto | Libia y Egipto | Argelia y Marruecos
        de: Welche zwei Länder grenzen an Tunesien? | Algerien und Libyen | Marokko und Ägypten | Libyen und Ägypten | Algerien und Marokko
        it: Quali due Paesi confinano via terra con la Tunisia? | Algeria e Libia | Marocco ed Egitto | Libia ed Egitto | Algeria e Marocco
        pt: Quais dois países fazem fronteira terrestre com a Tunísia? | Argélia e Líbia | Marrocos e Egito | Líbia e Egito | Argélia e Marrocos
        ja: チュニジアと陸の国境を接する2か国は？ | アルジェリアとリビア | モロッコとエジプト | リビアとエジプト | アルジェリアとモロッコ
        ko: 튀니지와 육지 국경을 맞댄 두 나라는? | 알제리와 리비아 | 모로코와 이집트 | 리비아와 이집트 | 알제리와 모로코
        zh: 哪两个国家与突尼斯陆地接壤？ | 阿尔及利亚和利比亚 | 摩洛哥和埃及 | 利比亚和埃及 | 阿尔及利亚和摩洛哥
        ar: أي دولتين تشتركان مع تونس في حدود برية؟ | الجزائر وليبيا | المغرب ومصر | ليبيا ومصر | الجزائر والمغرب
        """
}
