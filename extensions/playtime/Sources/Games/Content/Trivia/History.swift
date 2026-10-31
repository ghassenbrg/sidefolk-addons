extension Games.QuizBank {
    // History from every part of the world, settled facts only.
    static let history = """
        # hist.moon-landing history 1
        *: 1969 | 1965 | 1972 | 1975
        en: In which year did people first walk on the Moon?
        fr: En quelle année l'homme a-t-il marché sur la Lune pour la première fois ?
        es: ¿En qué año caminaron por primera vez personas sobre la Luna?
        de: In welchem Jahr betraten zum ersten Mal Menschen den Mond?
        it: In che anno l'uomo camminò per la prima volta sulla Luna?
        pt: Em que ano pessoas andaram na Lua pela primeira vez?
        ja: 人類が初めて月面を歩いたのは何年？
        ko: 사람이 처음 달 위를 걸은 해는?
        zh: 人类第一次在月球上行走是哪一年？
        ar: في أي عام مشى البشر على القمر أول مرة؟

        # hist.wall-1989 history 2
        en: Which wall came down in 1989? | The Berlin Wall | Hadrian's Wall | The Great Wall of China | The walls of Troy
        fr: Quel mur est tombé en 1989 ? | Le mur de Berlin | Le mur d'Hadrien | La Grande Muraille de Chine | Les murailles de Troie
        es: ¿Qué muro cayó en 1989? | El muro de Berlín | El muro de Adriano | La Gran Muralla china | Las murallas de Troya
        de: Welche Mauer fiel 1989? | Die Berliner Mauer | Der Hadrianswall | Die Chinesische Mauer | Die Mauern von Troja
        it: Quale muro cadde nel 1989? | Il muro di Berlino | Il vallo di Adriano | La Grande Muraglia cinese | Le mura di Troia
        pt: Que muro caiu em 1989? | O Muro de Berlim | A Muralha de Adriano | A Grande Muralha da China | As muralhas de Troia
        ja: 1989年に崩壊した壁は？ | ベルリンの壁 | ハドリアヌスの長城 | 万里の長城 | トロイアの城壁
        ko: 1989년에 무너진 장벽은? | 베를린 장벽 | 하드리아누스 방벽 | 만리장성 | 트로이 성벽
        zh: 1989年倒塌的是哪堵墙？ | 柏林墙 | 哈德良长城 | 中国长城 | 特洛伊城墙
        ar: أي جدار سقط عام 1989؟ | جدار برلين | سور هادريان | سور الصين العظيم | أسوار طروادة

        # hist.lindbergh history 3
        en: Who first flew alone and nonstop across the Atlantic, in 1927? | Charles Lindbergh | Amelia Earhart | Orville Wright | Louis Blériot
        fr: Qui a le premier traversé l'Atlantique seul et sans escale en avion, en 1927 ? | Charles Lindbergh | Amelia Earhart | Orville Wright | Louis Blériot
        es: ¿Quién cruzó primero el Atlántico en avión, solo y sin escalas, en 1927? | Charles Lindbergh | Amelia Earhart | Orville Wright | Louis Blériot
        de: Wer überflog 1927 als Erster allein und ohne Zwischenstopp den Atlantik? | Charles Lindbergh | Amelia Earhart | Orville Wright | Louis Blériot
        it: Chi attraversò per primo l'Atlantico in volo da solo e senza scalo, nel 1927? | Charles Lindbergh | Amelia Earhart | Orville Wright | Louis Blériot
        pt: Quem cruzou primeiro o Atlântico voando sozinho e sem escalas, em 1927? | Charles Lindbergh | Amelia Earhart | Orville Wright | Louis Blériot
        ja: 1927年、大西洋単独無着陸横断飛行に初めて成功したのは？ | チャールズ・リンドバーグ | アメリア・イアハート | オーヴィル・ライト | ルイ・ブレリオ
        ko: 1927년 처음으로 대서양 단독 무착륙 비행에 성공한 사람은? | 찰스 린드버그 | 어밀리아 에어하트 | 오빌 라이트 | 루이 블레리오
        zh: 1927年首次单人不着陆飞越大西洋的是谁？ | 查尔斯·林德伯格 | 阿梅莉亚·埃尔哈特 | 奥维尔·莱特 | 路易·布莱里奥
        ar: من أول من عبر المحيط الأطلسي بالطائرة منفردًا ومن دون توقف عام 1927؟ | تشارلز ليندبرغ | أميليا إيرهارت | أورفيل رايت | لويس بليريو

        # hist.gutenberg history 2
        en: Who built Europe's first printing press with movable type, around 1440? | Johannes Gutenberg | Galileo Galilei | Isaac Newton | William Caxton
        fr: Qui a mis au point vers 1440 la première presse à caractères mobiles d'Europe ? | Johannes Gutenberg | Galilée | Isaac Newton | William Caxton
        es: ¿Quién creó hacia 1440 la primera imprenta de tipos móviles de Europa? | Johannes Gutenberg | Galileo Galilei | Isaac Newton | William Caxton
        de: Wer baute um 1440 Europas erste Druckerpresse mit beweglichen Lettern? | Johannes Gutenberg | Galileo Galilei | Isaac Newton | William Caxton
        it: Chi costruì intorno al 1440 la prima stampa a caratteri mobili d'Europa? | Johannes Gutenberg | Galileo Galilei | Isaac Newton | William Caxton
        pt: Quem criou por volta de 1440 a primeira prensa de tipos móveis da Europa? | Johannes Gutenberg | Galileu Galilei | Isaac Newton | William Caxton
        ja: 1440年ごろ、ヨーロッパで初めて活版印刷機をつくったのは？ | ヨハネス・グーテンベルク | ガリレオ・ガリレイ | アイザック・ニュートン | ウィリアム・キャクストン
        ko: 1440년경 유럽 최초의 활판 인쇄기를 만든 사람은? | 요하네스 구텐베르크 | 갈릴레오 갈릴레이 | 아이작 뉴턴 | 윌리엄 캑스턴
        zh: 约1440年在欧洲造出第一台活字印刷机的是谁？ | 约翰内斯·古腾堡 | 伽利略 | 牛顿 | 威廉·卡克斯顿
        ar: من صنع نحو عام 1440 أول مطبعة بحروف متحركة في أوروبا؟ | يوهانس غوتنبرغ | غاليليو غاليلي | إسحاق نيوتن | ويليام كاكستون

        # hist.giza-builders history 1
        en: Which ancient civilisation built the Great Pyramid of Giza? | The Egyptians | The Romans | The Greeks | The Maya
        fr: Quelle civilisation antique a construit la grande pyramide de Gizeh ? | Les Égyptiens | Les Romains | Les Grecs | Les Mayas
        es: ¿Qué civilización antigua construyó la Gran Pirámide de Guiza? | Los egipcios | Los romanos | Los griegos | Los mayas
        de: Welche antike Kultur baute die Cheops-Pyramide von Gizeh? | Die Ägypter | Die Römer | Die Griechen | Die Maya
        it: Quale antica civiltà costruì la Grande Piramide di Giza? | Gli Egizi | I Romani | I Greci | I Maya
        pt: Que civilização antiga construiu a Grande Pirâmide de Gizé? | Os egípcios | Os romanos | Os gregos | Os maias
        ja: ギザの大ピラミッドを建てた古代文明は？ | 古代エジプト | 古代ローマ | 古代ギリシャ | マヤ
        ko: 기자의 대피라미드를 지은 고대 문명은? | 고대 이집트 | 고대 로마 | 고대 그리스 | 마야
        zh: 吉萨大金字塔是哪个古代文明建造的？ | 古埃及 | 古罗马 | 古希腊 | 玛雅
        ar: أي حضارة قديمة بنت هرم الجيزة الأكبر؟ | المصريون القدماء | الرومان | الإغريق | المايا

        # hist.columbus history 2
        en: In 1492, which ocean did Christopher Columbus cross? | The Atlantic | The Pacific | The Indian Ocean | The Arctic
        fr: En 1492, quel océan Christophe Colomb a-t-il traversé ? | L'Atlantique | Le Pacifique | L'océan Indien | L'Arctique
        es: En 1492, ¿qué océano cruzó Cristóbal Colón? | El Atlántico | El Pacífico | El Índico | El Ártico
        de: Welchen Ozean überquerte Christoph Kolumbus 1492? | Den Atlantik | Den Pazifik | Den Indischen Ozean | Das Nordpolarmeer
        it: Nel 1492, quale oceano attraversò Cristoforo Colombo? | L'Atlantico | Il Pacifico | L'oceano Indiano | Il mar Glaciale Artico
        pt: Em 1492, que oceano Cristóvão Colombo atravessou? | O Atlântico | O Pacífico | O Índico | O Ártico
        ja: 1492年にコロンブスが横断した海洋は？ | 大西洋 | 太平洋 | インド洋 | 北極海
        ko: 1492년 콜럼버스가 건넌 바다는? | 대서양 | 태평양 | 인도양 | 북극해
        zh: 1492年哥伦布横渡的是哪个大洋？ | 大西洋 | 太平洋 | 印度洋 | 北冰洋
        ar: أي محيط عبره كريستوفر كولومبوس عام 1492؟ | الأطلسي | الهادئ | الهندي | المتجمد الشمالي

        # hist.great-wall history 1
        en: Which country is famous for the Great Wall? | China | Japan | India | Egypt
        fr: Quel pays est célèbre pour sa Grande Muraille ? | La Chine | Le Japon | L'Inde | L'Égypte
        es: ¿Qué país es famoso por su Gran Muralla? | China | Japón | India | Egipto
        de: Welches Land ist für seine Große Mauer berühmt? | China | Japan | Indien | Ägypten
        it: Quale Paese è famoso per la sua Grande Muraglia? | Cina | Giappone | India | Egitto
        pt: Que país é famoso pela Grande Muralha? | China | Japão | Índia | Egito
        ja: 万里の長城で有名な国は？ | 中国 | 日本 | インド | エジプト
        ko: 만리장성으로 유명한 나라는? | 중국 | 일본 | 인도 | 이집트
        zh: 长城是哪个国家的著名建筑？ | 中国 | 日本 | 印度 | 埃及
        ar: أي دولة تشتهر بالسور العظيم؟ | الصين | اليابان | الهند | مصر

        # hist.montgolfier history 2
        en: In 1783 the first people ever to fly rode in what, built by the Montgolfier brothers? | A hot-air balloon | An airplane | A glider | A helicopter
        fr: En 1783, les premiers humains à voler montèrent dans quoi, construit par les frères Montgolfier ? | Un ballon à air chaud | Un avion | Un planeur | Un hélicoptère
        es: En 1783, ¿en qué volaron las primeras personas, una obra de los hermanos Montgolfier? | Un globo de aire caliente | Un avión | Un planeador | Un helicóptero
        de: Worin flogen 1783 die ersten Menschen, gebaut von den Brüdern Montgolfier? | In einem Heißluftballon | In einem Flugzeug | In einem Segelflugzeug | In einem Hubschrauber
        it: Nel 1783 i primi uomini a volare salirono su che cosa, costruito dai fratelli Montgolfier? | Una mongolfiera | Un aereo | Un aliante | Un elicottero
        pt: Em 1783, as primeiras pessoas a voar subiram em quê, construído pelos irmãos Montgolfier? | Um balão de ar quente | Um avião | Um planador | Um helicóptero
        ja: 1783年、人類が初めて空を飛んだときの乗り物は？（モンゴルフィエ兄弟が製作） | 熱気球 | 飛行機 | グライダー | ヘリコプター
        ko: 1783년 인류가 처음 하늘을 날 때 탄 것은? (몽골피에 형제가 만듦) | 열기구 | 비행기 | 글라이더 | 헬리콥터
        zh: 1783年，人类第一次飞上天空乘坐的是什么？（由蒙戈尔菲耶兄弟制造） | 热气球 | 飞机 | 滑翔机 | 直升机
        ar: عام 1783، في أي شيء طار البشر أول مرة، من صنع الأخوين مونغولفييه؟ | منطاد هواء ساخن | طائرة | طائرة شراعية | مروحية

        # hist.ww2-end history 2
        *: 1945 | 1939 | 1918 | 1950
        en: In which year did the Second World War end?
        fr: En quelle année la Seconde Guerre mondiale a-t-elle pris fin ?
        es: ¿En qué año terminó la Segunda Guerra Mundial?
        de: In welchem Jahr endete der Zweite Weltkrieg?
        it: In che anno finì la seconda guerra mondiale?
        pt: Em que ano terminou a Segunda Guerra Mundial?
        ja: 第二次世界大戦が終わったのは何年？
        ko: 제2차 세계 대전이 끝난 해는?
        zh: 第二次世界大战在哪一年结束？
        ar: في أي عام انتهت الحرب العالمية الثانية؟

        # hist.ww1-start history 2
        *: 1914 | 1918 | 1905 | 1939
        en: In which year did the First World War begin?
        fr: En quelle année la Première Guerre mondiale a-t-elle commencé ?
        es: ¿En qué año empezó la Primera Guerra Mundial?
        de: In welchem Jahr begann der Erste Weltkrieg?
        it: In che anno iniziò la prima guerra mondiale?
        pt: Em que ano começou a Primeira Guerra Mundial?
        ja: 第一次世界大戦が始まったのは何年？
        ko: 제1차 세계 대전이 시작된 해는?
        zh: 第一次世界大战在哪一年爆发？
        ar: في أي عام بدأت الحرب العالمية الأولى؟

        # hist.latin history 2
        en: What was the main language of ancient Rome? | Latin | Greek | Italian | Etruscan
        fr: Quelle était la langue principale de la Rome antique ? | Le latin | Le grec | L'italien | L'étrusque
        es: ¿Cuál era la lengua principal de la antigua Roma? | El latín | El griego | El italiano | El etrusco
        de: Was war die Hauptsprache im antiken Rom? | Latein | Griechisch | Italienisch | Etruskisch
        it: Qual era la lingua principale dell'antica Roma? | Il latino | Il greco | L'italiano | L'etrusco
        pt: Qual era a língua principal da Roma antiga? | Latim | Grego | Italiano | Etrusco
        ja: 古代ローマのおもな言語は？ | ラテン語 | ギリシャ語 | イタリア語 | エトルリア語
        ko: 고대 로마의 주된 언어는? | 라틴어 | 그리스어 | 이탈리아어 | 에트루리아어
        zh: 古罗马的主要语言是什么？ | 拉丁语 | 希腊语 | 意大利语 | 伊特鲁里亚语
        ar: ما اللغة الرئيسية في روما القديمة؟ | اللاتينية | اليونانية | الإيطالية | الإتروسكية

        # hist.titanic history 1
        en: In 1912, what did the Titanic hit before it sank? | An iceberg | A whale | Another ship | A coral reef
        fr: En 1912, qu'a heurté le Titanic avant de couler ? | Un iceberg | Une baleine | Un autre navire | Un récif de corail
        es: En 1912, ¿con qué chocó el Titanic antes de hundirse? | Un iceberg | Una ballena | Otro barco | Un arrecife de coral
        de: Womit stieß die Titanic 1912 zusammen, bevor sie sank? | Mit einem Eisberg | Mit einem Wal | Mit einem anderen Schiff | Mit einem Korallenriff
        it: Nel 1912, che cosa urtò il Titanic prima di affondare? | Un iceberg | Una balena | Un'altra nave | Una barriera corallina
        pt: Em 1912, em que o Titanic bateu antes de afundar? | Um iceberg | Uma baleia | Outro navio | Um recife de coral
        ja: 1912年、タイタニック号が沈む前にぶつかったのは？ | 氷山 | クジラ | 別の船 | サンゴ礁
        ko: 1912년 타이태닉호가 가라앉기 전에 부딪힌 것은? | 빙산 | 고래 | 다른 배 | 산호초
        zh: 1912年泰坦尼克号沉没前撞上了什么？ | 冰山 | 鲸鱼 | 另一艘船 | 珊瑚礁
        ar: بماذا اصطدمت سفينة تيتانيك قبل أن تغرق عام 1912؟ | جبل جليدي | حوت | سفينة أخرى | شعاب مرجانية

        # hist.cleopatra history 2
        en: Cleopatra was the queen of which ancient land? | Egypt | Greece | Persia | Carthage
        fr: Cléopâtre était la reine de quel pays antique ? | L'Égypte | La Grèce | La Perse | Carthage
        es: ¿De qué tierra antigua fue reina Cleopatra? | Egipto | Grecia | Persia | Cartago
        de: Kleopatra war Königin welches antiken Landes? | Ägypten | Griechenland | Persien | Karthago
        it: Cleopatra fu regina di quale antica terra? | Egitto | Grecia | Persia | Cartagine
        pt: Cleópatra foi rainha de qual terra antiga? | Egito | Grécia | Pérsia | Cartago
        ja: クレオパトラはどこの女王だった？ | エジプト | ギリシャ | ペルシア | カルタゴ
        ko: 클레오파트라는 어느 나라의 여왕이었을까요? | 이집트 | 그리스 | 페르시아 | 카르타고
        zh: 克利奥帕特拉是哪个古国的女王？ | 埃及 | 希腊 | 波斯 | 迦太基
        ar: كليوباترا كانت ملكة أي أرض قديمة؟ | مصر | اليونان | فارس | قرطاج

        # hist.genghis history 2
        en: Genghis Khan founded which empire? | The Mongol Empire | The Ottoman Empire | The Roman Empire | The Persian Empire
        fr: Quel empire Gengis Khan a-t-il fondé ? | L'Empire mongol | L'Empire ottoman | L'Empire romain | L'Empire perse
        es: ¿Qué imperio fundó Gengis Kan? | El Imperio mongol | El Imperio otomano | El Imperio romano | El Imperio persa
        de: Welches Reich gründete Dschingis Khan? | Das Mongolische Reich | Das Osmanische Reich | Das Römische Reich | Das Perserreich
        it: Quale impero fondò Gengis Khan? | L'Impero mongolo | L'Impero ottomano | L'Impero romano | L'Impero persiano
        pt: Que império Gengis Khan fundou? | O Império Mongol | O Império Otomano | O Império Romano | O Império Persa
        ja: チンギス・ハンが建国した帝国は？ | モンゴル帝国 | オスマン帝国 | ローマ帝国 | ペルシア帝国
        ko: 칭기즈 칸이 세운 제국은? | 몽골 제국 | 오스만 제국 | 로마 제국 | 페르시아 제국
        zh: 成吉思汗建立了哪个帝国？ | 蒙古帝国 | 奥斯曼帝国 | 罗马帝国 | 波斯帝国
        ar: أي إمبراطورية أسّسها جنكيز خان؟ | الإمبراطورية المغولية | الدولة العثمانية | الإمبراطورية الرومانية | الإمبراطورية الفارسية

        # hist.first-circumnavigation history 3
        en: Whose expedition first sailed around the world, from 1519 to 1522? | Magellan and Elcano's | Vasco da Gama's | Christopher Columbus's | James Cook's
        fr: Quelle expédition a la première fait le tour du monde, de 1519 à 1522 ? | Celle de Magellan et Elcano | Celle de Vasco de Gama | Celle de Christophe Colomb | Celle de James Cook
        es: ¿Qué expedición dio por primera vez la vuelta al mundo, de 1519 a 1522? | La de Magallanes y Elcano | La de Vasco da Gama | La de Cristóbal Colón | La de James Cook
        de: Wessen Expedition umsegelte von 1519 bis 1522 als erste die Welt? | Die von Magellan und Elcano | Die von Vasco da Gama | Die von Christoph Kolumbus | Die von James Cook
        it: Quale spedizione fece per prima il giro del mondo, dal 1519 al 1522? | Quella di Magellano ed Elcano | Quella di Vasco da Gama | Quella di Cristoforo Colombo | Quella di James Cook
        pt: Qual expedição deu a primeira volta ao mundo, de 1519 a 1522? | A de Fernão de Magalhães e Elcano | A de Vasco da Gama | A de Cristóvão Colombo | A de James Cook
        ja: 1519年から1522年に初めて世界一周を果たした航海は？ | マゼランとエルカーノの航海 | ヴァスコ・ダ・ガマの航海 | コロンブスの航海 | クックの航海
        ko: 1519년부터 1522년까지 처음으로 세계 일주를 한 원정대는? | 마젤란과 엘카노의 원정대 | 바스쿠 다 가마의 원정대 | 콜럼버스의 원정대 | 제임스 쿡의 원정대
        zh: 1519年至1522年首次完成环球航行的是谁的船队？ | 麦哲伦和埃尔卡诺 | 达·伽马 | 哥伦布 | 库克船长
        ar: أي بعثة أبحرت حول العالم أول مرة بين 1519 و1522؟ | بعثة ماجلان وإلكانو | بعثة فاسكو دا غاما | بعثة كولومبوس | بعثة جيمس كوك

        # hist.mandela history 1
        en: Who became South Africa's first democratically elected president, in 1994? | Nelson Mandela | Desmond Tutu | F. W. de Klerk | Thabo Mbeki
        fr: Qui est devenu en 1994 le premier président démocratiquement élu d'Afrique du Sud ? | Nelson Mandela | Desmond Tutu | Frederik de Klerk | Thabo Mbeki
        es: ¿Quién fue en 1994 el primer presidente elegido democráticamente de Sudáfrica? | Nelson Mandela | Desmond Tutu | Frederik de Klerk | Thabo Mbeki
        de: Wer wurde 1994 der erste demokratisch gewählte Präsident Südafrikas? | Nelson Mandela | Desmond Tutu | Frederik de Klerk | Thabo Mbeki
        it: Chi divenne nel 1994 il primo presidente democraticamente eletto del Sudafrica? | Nelson Mandela | Desmond Tutu | Frederik de Klerk | Thabo Mbeki
        pt: Quem se tornou em 1994 o primeiro presidente eleito democraticamente da África do Sul? | Nelson Mandela | Desmond Tutu | Frederik de Klerk | Thabo Mbeki
        ja: 1994年に南アフリカ初の民主的に選ばれた大統領になったのは？ | ネルソン・マンデラ | デズモンド・ツツ | デクラーク | タボ・ムベキ
        ko: 1994년 남아프리카 공화국 최초의 민주적 선거로 뽑힌 대통령은? | 넬슨 만델라 | 데즈먼드 투투 | 데클레르크 | 타보 음베키
        zh: 1994年成为南非首位民选总统的是谁？ | 纳尔逊·曼德拉 | 德斯蒙德·图图 | 德克勒克 | 姆贝基
        ar: من أصبح عام 1994 أول رئيس منتخب ديمقراطيًا لجنوب أفريقيا؟ | نيلسون مانديلا | ديزموند توتو | فريدريك دي كليرك | ثابو مبيكي

        # hist.salt-march history 2
        en: Who led the Salt March of 1930 in India? | Mahatma Gandhi | Jawaharlal Nehru | Indira Gandhi | Rabindranath Tagore
        fr: Qui a mené la marche du sel en Inde, en 1930 ? | Mahatma Gandhi | Jawaharlal Nehru | Indira Gandhi | Rabindranath Tagore
        es: ¿Quién encabezó la Marcha de la Sal en la India, en 1930? | Mahatma Gandhi | Jawaharlal Nehru | Indira Gandhi | Rabindranath Tagore
        de: Wer führte 1930 in Indien den Salzmarsch an? | Mahatma Gandhi | Jawaharlal Nehru | Indira Gandhi | Rabindranath Tagore
        it: Chi guidò la marcia del sale in India, nel 1930? | Mahatma Gandhi | Jawaharlal Nehru | Indira Gandhi | Rabindranath Tagore
        pt: Quem liderou a Marcha do Sal na Índia, em 1930? | Mahatma Gandhi | Jawaharlal Nehru | Indira Gandhi | Rabindranath Tagore
        ja: 1930年にインドで「塩の行進」を率いたのは？ | マハトマ・ガンディー | ジャワハルラール・ネルー | インディラ・ガンディー | ラビンドラナート・タゴール
        ko: 1930년 인도에서 '소금 행진'을 이끈 사람은? | 마하트마 간디 | 자와할랄 네루 | 인디라 간디 | 라빈드라나트 타고르
        zh: 1930年在印度领导“食盐进军”的是谁？ | 圣雄甘地 | 尼赫鲁 | 英迪拉·甘地 | 泰戈尔
        ar: من قاد مسيرة الملح في الهند عام 1930؟ | المهاتما غاندي | جواهر لال نهرو | إنديرا غاندي | رابندرانات طاغور

        # hist.french-revolution history 2
        *: 1789 | 1689 | 1815 | 1848
        en: In which year did the French Revolution begin?
        fr: En quelle année la Révolution française a-t-elle commencé ?
        es: ¿En qué año comenzó la Revolución francesa?
        de: In welchem Jahr begann die Französische Revolution?
        it: In che anno iniziò la Rivoluzione francese?
        pt: Em que ano começou a Revolução Francesa?
        ja: フランス革命が始まったのは何年？
        ko: 프랑스 혁명이 시작된 해는?
        zh: 法国大革命在哪一年开始？
        ar: في أي عام بدأت الثورة الفرنسية؟

        # hist.us-independence history 2
        *: 1776 | 1789 | 1812 | 1865
        en: In which year did the United States declare independence?
        fr: En quelle année les États-Unis ont-ils déclaré leur indépendance ?
        es: ¿En qué año declararon su independencia los Estados Unidos?
        de: In welchem Jahr erklärten die Vereinigten Staaten ihre Unabhängigkeit?
        it: In che anno gli Stati Uniti dichiararono l'indipendenza?
        pt: Em que ano os Estados Unidos declararam a independência?
        ja: アメリカ合衆国が独立を宣言したのは何年？
        ko: 미국이 독립을 선언한 해는?
        zh: 美国在哪一年宣布独立？
        ar: في أي عام أعلنت الولايات المتحدة استقلالها؟

        # hist.inca history 2
        en: Which people built Machu Picchu? | The Incas | The Aztecs | The Maya | The Olmecs
        fr: Quel peuple a construit le Machu Picchu ? | Les Incas | Les Aztèques | Les Mayas | Les Olmèques
        es: ¿Qué pueblo construyó Machu Picchu? | Los incas | Los aztecas | Los mayas | Los olmecas
        de: Welches Volk baute Machu Picchu? | Die Inka | Die Azteken | Die Maya | Die Olmeken
        it: Quale popolo costruì Machu Picchu? | Gli Inca | Gli Aztechi | I Maya | Gli Olmechi
        pt: Que povo construiu Machu Picchu? | Os incas | Os astecas | Os maias | Os olmecas
        ja: マチュ・ピチュを築いたのは？ | インカ | アステカ | マヤ | オルメカ
        ko: 마추픽추를 지은 사람들은? | 잉카인 | 아스테카인 | 마야인 | 올멕인
        zh: 马丘比丘是谁建造的？ | 印加人 | 阿兹特克人 | 玛雅人 | 奥尔梅克人
        ar: أي شعب بنى ماتشو بيتشو؟ | الإنكا | الأزتيك | المايا | الأولمك

        # hist.tenochtitlan history 3
        en: The Aztec capital Tenochtitlan stood where which city is today? | Mexico City | Lima | Bogotá | Havana
        fr: La capitale aztèque Tenochtitlan se trouvait à l'emplacement de quelle ville actuelle ? | Mexico | Lima | Bogota | La Havane
        es: ¿Qué ciudad actual ocupa el lugar de Tenochtitlan, la capital azteca? | Ciudad de México | Lima | Bogotá | La Habana
        de: Welche heutige Stadt steht dort, wo die Aztekenhauptstadt Tenochtitlan lag? | Mexiko-Stadt | Lima | Bogotá | Havanna
        it: Quale città di oggi sorge dove c'era Tenochtitlan, la capitale azteca? | Città del Messico | Lima | Bogotá | L'Avana
        pt: Que cidade de hoje fica onde ficava Tenochtitlan, a capital asteca? | Cidade do México | Lima | Bogotá | Havana
        ja: アステカの都テノチティトランがあった場所にある今の都市は？ | メキシコシティ | リマ | ボゴタ | ハバナ
        ko: 아스테카의 수도 테노치티틀란이 있던 곳에 오늘날 있는 도시는? | 멕시코시티 | 리마 | 보고타 | 아바나
        zh: 阿兹特克首都特诺奇蒂特兰位于今天哪座城市？ | 墨西哥城 | 利马 | 波哥大 | 哈瓦那
        ar: أي مدينة حالية تقوم مكان تينوتشتيتلان، عاصمة الأزتيك؟ | مكسيكو سيتي | ليما | بوغوتا | هافانا

        # hist.colosseum history 1
        en: In which city is the Colosseum? | Rome | Athens | Istanbul | Cairo
        fr: Dans quelle ville se trouve le Colisée ? | Rome | Athènes | Istanbul | Le Caire
        es: ¿En qué ciudad está el Coliseo? | Roma | Atenas | Estambul | El Cairo
        de: In welcher Stadt steht das Kolosseum? | Rom | Athen | Istanbul | Kairo
        it: In quale città si trova il Colosseo? | Roma | Atene | Istanbul | Il Cairo
        pt: Em que cidade fica o Coliseu? | Roma | Atenas | Istambul | Cairo
        ja: コロッセオがある都市は？ | ローマ | アテネ | イスタンブール | カイロ
        ko: 콜로세움이 있는 도시는? | 로마 | 아테네 | 이스탄불 | 카이로
        zh: 罗马斗兽场在哪座城市？ | 罗马 | 雅典 | 伊斯坦布尔 | 开罗
        ar: في أي مدينة يقع الكولوسيوم؟ | روما | أثينا | إسطنبول | القاهرة

        # hist.terracotta history 2
        en: The Terracotta Army was made for which Chinese emperor? | Qin Shi Huang | Kublai Khan | Emperor Wu of Han | Puyi
        fr: Pour quel empereur chinois l'armée de terre cuite a-t-elle été faite ? | Qin Shi Huang | Kubilai Khan | L'empereur Wu des Han | Puyi
        es: ¿Para qué emperador chino se hizo el Ejército de terracota? | Qin Shi Huang | Kublai Kan | El emperador Wu de Han | Puyi
        de: Für welchen chinesischen Kaiser wurde die Terrakotta-Armee geschaffen? | Qin Shi Huang | Kublai Khan | Kaiser Wu der Han | Puyi
        it: Per quale imperatore cinese fu creato l'Esercito di terracotta? | Qin Shi Huang | Kublai Khan | L'imperatore Wu degli Han | Puyi
        pt: Para qual imperador chinês foi feito o Exército de Terracota? | Qin Shi Huang | Kublai Khan | O imperador Wu de Han | Puyi
        ja: 兵馬俑はどの皇帝のためにつくられた？ | 始皇帝 | クビライ | 漢の武帝 | 溥儀
        ko: 병마용은 어느 황제를 위해 만들어졌을까요? | 진시황 | 쿠빌라이 칸 | 한 무제 | 푸이
        zh: 兵马俑是为哪位皇帝制作的？ | 秦始皇 | 忽必烈 | 汉武帝 | 溥仪
        ar: لأي إمبراطور صيني صُنع جيش الطين (التيراكوتا)؟ | تشين شي هوانغ | قوبلاي خان | الإمبراطور وو من سلالة هان | بو يي

        # hist.silk-road history 2
        en: The Silk Road linked China with which region? | The Mediterranean | The Americas | Australia | Antarctica
        fr: La route de la soie reliait la Chine à quelle région ? | La Méditerranée | Les Amériques | L'Australie | L'Antarctique
        es: ¿Con qué región unía a China la Ruta de la Seda? | El Mediterráneo | América | Australia | La Antártida
        de: Mit welcher Region verband die Seidenstraße China? | Dem Mittelmeerraum | Amerika | Australien | Der Antarktis
        it: Con quale regione collegava la Cina la Via della seta? | Il Mediterraneo | Le Americhe | L'Australia | L'Antartide
        pt: A Rota da Seda ligava a China a qual região? | Ao Mediterrâneo | Às Américas | À Austrália | À Antártida
        ja: シルクロードが中国と結んでいた地域は？ | 地中海世界 | 南北アメリカ | オーストラリア | 南極
        ko: 실크로드는 중국과 어느 지역을 이었을까요? | 지중해 세계 | 아메리카 | 오스트레일리아 | 남극
        zh: 丝绸之路把中国和哪个地区连接起来？ | 地中海地区 | 美洲 | 澳大利亚 | 南极洲
        ar: ربط طريق الحرير الصين بأي منطقة؟ | البحر المتوسط | الأمريكتين | أستراليا | القارة القطبية الجنوبية

        # hist.ancient-olympics history 2
        en: In which country did the ancient Olympic Games begin? | Greece | Italy | Egypt | Persia
        fr: Dans quel pays les Jeux olympiques antiques sont-ils nés ? | La Grèce | L'Italie | L'Égypte | La Perse
        es: ¿En qué país nacieron los Juegos Olímpicos antiguos? | Grecia | Italia | Egipto | Persia
        de: In welchem Land entstanden die antiken Olympischen Spiele? | Griechenland | Italien | Ägypten | Persien
        it: In quale Paese nacquero gli antichi Giochi olimpici? | Grecia | Italia | Egitto | Persia
        pt: Em que país nasceram os Jogos Olímpicos da Antiguidade? | Grécia | Itália | Egito | Pérsia
        ja: 古代オリンピックが始まった国は？ | ギリシャ | イタリア | エジプト | ペルシア
        ko: 고대 올림픽이 시작된 나라는? | 그리스 | 이탈리아 | 이집트 | 페르시아
        zh: 古代奥运会起源于哪个国家？ | 希腊 | 意大利 | 埃及 | 波斯
        ar: في أي بلد بدأت الألعاب الأولمبية القديمة؟ | اليونان | إيطاليا | مصر | فارس

        # hist.napoleon history 2
        en: Napoleon Bonaparte was emperor of which country? | France | Spain | Austria | Russia
        fr: De quel pays Napoléon Bonaparte fut-il l'empereur ? | La France | L'Espagne | L'Autriche | La Russie
        es: ¿De qué país fue emperador Napoleón Bonaparte? | Francia | España | Austria | Rusia
        de: Von welchem Land war Napoleon Bonaparte Kaiser? | Frankreich | Spanien | Österreich | Russland
        it: Di quale Paese fu imperatore Napoleone Bonaparte? | Francia | Spagna | Austria | Russia
        pt: De que país Napoleão Bonaparte foi imperador? | França | Espanha | Áustria | Rússia
        ja: ナポレオン・ボナパルトが皇帝となった国は？ | フランス | スペイン | オーストリア | ロシア
        ko: 나폴레옹 보나파르트가 황제였던 나라는? | 프랑스 | 스페인 | 오스트리아 | 러시아
        zh: 拿破仑·波拿巴是哪个国家的皇帝？ | 法国 | 西班牙 | 奥地利 | 俄国
        ar: نابليون بونابرت كان إمبراطورًا لأي دولة؟ | فرنسا | إسبانيا | النمسا | روسيا

        # hist.waterloo history 3
        en: Napoleon's final defeat, in 1815, was at which battle? | Waterloo | Austerlitz | Trafalgar | Leipzig
        fr: Quelle bataille marque la défaite finale de Napoléon, en 1815 ? | Waterloo | Austerlitz | Trafalgar | Leipzig
        es: ¿En qué batalla sufrió Napoleón su derrota final, en 1815? | Waterloo | Austerlitz | Trafalgar | Leipzig
        de: In welcher Schlacht wurde Napoleon 1815 endgültig besiegt? | Waterloo | Austerlitz | Trafalgar | Leipzig
        it: In quale battaglia Napoleone fu sconfitto definitivamente, nel 1815? | Waterloo | Austerlitz | Trafalgar | Lipsia
        pt: Em que batalha Napoleão sofreu a derrota final, em 1815? | Waterloo | Austerlitz | Trafalgar | Leipzig
        ja: 1815年、ナポレオンが最後に敗れた戦いは？ | ワーテルローの戦い | アウステルリッツの戦い | トラファルガーの海戦 | ライプツィヒの戦い
        ko: 1815년 나폴레옹이 마지막으로 패한 전투는? | 워털루 전투 | 아우스터리츠 전투 | 트라팔가르 해전 | 라이프치히 전투
        zh: 1815年拿破仑最终战败于哪场战役？ | 滑铁卢战役 | 奥斯特里茨战役 | 特拉法尔加海战 | 莱比锡战役
        ar: في أي معركة هُزم نابليون هزيمته الأخيرة عام 1815؟ | واترلو | أوسترليتز | الطرف الأغر | لايبزيغ

        # hist.edo history 3
        en: What was Tokyo called before 1868? | Edo | Kyoto | Nara | Osaka
        fr: Comment s'appelait Tokyo avant 1868 ? | Edo | Kyoto | Nara | Osaka
        es: ¿Cómo se llamaba Tokio antes de 1868? | Edo | Kioto | Nara | Osaka
        de: Wie hieß Tokio vor 1868? | Edo | Kyoto | Nara | Osaka
        it: Come si chiamava Tokyo prima del 1868? | Edo | Kyoto | Nara | Osaka
        pt: Como Tóquio se chamava antes de 1868? | Edo | Quioto | Nara | Osaka
        ja: 1868年より前、東京は何と呼ばれていた？ | 江戸 | 京都 | 奈良 | 大坂
        ko: 1868년 이전에 도쿄는 무엇이라고 불렸을까요? | 에도 | 교토 | 나라 | 오사카
        zh: 1868年以前东京叫什么？ | 江户 | 京都 | 奈良 | 大阪
        ar: ما اسم طوكيو قبل عام 1868؟ | إيدو | كيوتو | نارا | أوساكا

        # hist.hangul history 3
        en: Which king created the Korean alphabet, Hangul? | Sejong the Great | Taejo | Gwanggaeto the Great | Jeongjo
        fr: Quel roi a créé l'alphabet coréen, le hangeul ? | Sejong le Grand | Taejo | Gwanggaeto le Grand | Jeongjo
        es: ¿Qué rey creó el alfabeto coreano, el hangul? | Sejong el Grande | Taejo | Gwanggaeto el Grande | Jeongjo
        de: Welcher König schuf das koreanische Alphabet Hangeul? | Sejong der Große | Taejo | Gwanggaeto der Große | Jeongjo
        it: Quale re creò l'alfabeto coreano, l'hangul? | Sejong il Grande | Taejo | Gwanggaeto il Grande | Jeongjo
        pt: Que rei criou o alfabeto coreano, o hangul? | Sejong, o Grande | Taejo | Gwanggaeto, o Grande | Jeongjo
        ja: 韓国の文字ハングルをつくった王は？ | 世宗大王 | 太祖 | 広開土王 | 正祖
        ko: 한글을 만든 왕은? | 세종대왕 | 태조 | 광개토대왕 | 정조
        zh: 哪位国王创制了韩文（谚文）？ | 世宗大王 | 太祖 | 广开土王 | 正祖
        ar: أي ملك ابتكر الأبجدية الكورية (الهانغول)؟ | سيجونغ العظيم | تايجو | غوانغيتو العظيم | جونغجو

        # hist.paper history 2
        en: Which country invented paper, about 2,000 years ago? | China | Greece | Rome | India
        fr: Quel pays a inventé le papier, il y a environ 2 000 ans ? | La Chine | La Grèce | Rome | L'Inde
        es: ¿Qué país inventó el papel hace unos 2000 años? | China | Grecia | Roma | India
        de: Welches Land erfand vor etwa 2000 Jahren das Papier? | China | Griechenland | Rom | Indien
        it: Quale Paese inventò la carta, circa 2000 anni fa? | Cina | Grecia | Roma | India
        pt: Que país inventou o papel, há cerca de 2 mil anos? | China | Grécia | Roma | Índia
        ja: 約2000年前に紙を発明した国は？ | 中国 | ギリシャ | ローマ | インド
        ko: 약 2000년 전에 종이를 발명한 나라는? | 중국 | 그리스 | 로마 | 인도
        zh: 大约两千年前，哪个国家发明了纸？ | 中国 | 希腊 | 罗马 | 印度
        ar: أي بلد اخترع الورق قبل نحو ألفي عام؟ | الصين | اليونان | روما | الهند

        # hist.ibn-battuta history 3
        en: In which city was the great 14th-century traveller Ibn Battuta born? | Tangier | Cairo | Baghdad | Tunis
        fr: Dans quelle ville est né Ibn Battuta, le grand voyageur du XIVe siècle ? | Tanger | Le Caire | Bagdad | Tunis
        es: ¿En qué ciudad nació Ibn Battuta, el gran viajero del siglo XIV? | Tánger | El Cairo | Bagdad | Túnez
        de: In welcher Stadt wurde Ibn Battuta geboren, der große Reisende des 14. Jahrhunderts? | Tanger | Kairo | Bagdad | Tunis
        it: In quale città nacque Ibn Battuta, il grande viaggiatore del Trecento? | Tangeri | Il Cairo | Baghdad | Tunisi
        pt: Em que cidade nasceu Ibn Battuta, o grande viajante do século XIV? | Tânger | Cairo | Bagdá | Túnis
        ja: 14世紀の大旅行家イブン・バットゥータが生まれた都市は？ | タンジール | カイロ | バグダード | チュニス
        ko: 14세기의 위대한 여행가 이븐 바투타가 태어난 도시는? | 탕헤르 | 카이로 | 바그다드 | 튀니스
        zh: 14世纪大旅行家伊本·白图泰出生在哪座城市？ | 丹吉尔 | 开罗 | 巴格达 | 突尼斯
        ar: في أي مدينة وُلد الرحالة الكبير ابن بطوطة في القرن الرابع عشر؟ | طنجة | القاهرة | بغداد | تونس

        # hist.house-of-wisdom history 3
        en: The House of Wisdom, a great centre of learning, was in which city? | Baghdad | Damascus | Córdoba | Cairo
        fr: La Maison de la sagesse, grand centre du savoir, se trouvait dans quelle ville ? | Bagdad | Damas | Cordoue | Le Caire
        es: ¿En qué ciudad estaba la Casa de la Sabiduría, gran centro del saber? | Bagdad | Damasco | Córdoba | El Cairo
        de: In welcher Stadt stand das Haus der Weisheit, ein großes Zentrum der Gelehrsamkeit? | Bagdad | Damaskus | Córdoba | Kairo
        it: In quale città si trovava la Casa della saggezza, grande centro del sapere? | Baghdad | Damasco | Cordova | Il Cairo
        pt: Em que cidade ficava a Casa da Sabedoria, grande centro do saber? | Bagdá | Damasco | Córdoba | Cairo
        ja: 学問の中心「知恵の館」があった都市は？ | バグダード | ダマスカス | コルドバ | カイロ
        ko: 학문의 중심지였던 '지혜의 집'이 있던 도시는? | 바그다드 | 다마스쿠스 | 코르도바 | 카이로
        zh: 学术中心“智慧宫”位于哪座城市？ | 巴格达 | 大马士革 | 科尔多瓦 | 开罗
        ar: في أي مدينة كان بيت الحكمة، مركز العلم الكبير؟ | بغداد | دمشق | قرطبة | القاهرة

        # hist.mansa-musa history 3
        en: Mansa Musa, famed for his wealth, ruled which empire? | The Mali Empire | The Ottoman Empire | The Mughal Empire | The Inca Empire
        fr: Mansa Moussa, célèbre pour sa richesse, régnait sur quel empire ? | L'Empire du Mali | L'Empire ottoman | L'Empire moghol | L'Empire inca
        es: ¿Qué imperio gobernó Mansa Musa, famoso por su riqueza? | El Imperio de Malí | El Imperio otomano | El Imperio mogol | El Imperio inca
        de: Welches Reich regierte Mansa Musa, berühmt für seinen Reichtum? | Das Malireich | Das Osmanische Reich | Das Mogulreich | Das Inkareich
        it: Quale impero governò Mansa Musa, famoso per la sua ricchezza? | L'Impero del Mali | L'Impero ottomano | L'Impero moghul | L'Impero inca
        pt: Que império Mansa Musa, famoso por sua riqueza, governou? | O Império do Mali | O Império Otomano | O Império Mogol | O Império Inca
        ja: 莫大な富で知られるマンサ・ムーサが治めた帝国は？ | マリ帝国 | オスマン帝国 | ムガル帝国 | インカ帝国
        ko: 엄청난 부로 유명한 만사 무사가 다스린 제국은? | 말리 제국 | 오스만 제국 | 무굴 제국 | 잉카 제국
        zh: 以富有闻名的曼萨·穆萨统治的是哪个帝国？ | 马里帝国 | 奥斯曼帝国 | 莫卧儿帝国 | 印加帝国
        ar: أي إمبراطورية حكمها مانسا موسى المشهور بثرائه؟ | إمبراطورية مالي | الدولة العثمانية | الإمبراطورية المغولية الهندية | إمبراطورية الإنكا

        # hist.taj-mahal history 2
        en: Which emperor built the Taj Mahal? | Shah Jahan | Akbar | Babur | Aurangzeb
        fr: Quel empereur a fait construire le Taj Mahal ? | Shah Jahan | Akbar | Babur | Aurangzeb
        es: ¿Qué emperador mandó construir el Taj Mahal? | Sha Jahan | Akbar | Babur | Aurangzeb
        de: Welcher Kaiser ließ das Taj Mahal bauen? | Shah Jahan | Akbar | Babur | Aurangzeb
        it: Quale imperatore fece costruire il Taj Mahal? | Shah Jahan | Akbar | Babur | Aurangzeb
        pt: Que imperador mandou construir o Taj Mahal? | Shah Jahan | Akbar | Babur | Aurangzeb
        ja: タージ・マハルを建てた皇帝は？ | シャー・ジャハーン | アクバル | バーブル | アウラングゼーブ
        ko: 타지마할을 지은 황제는? | 샤자한 | 악바르 | 바부르 | 아우랑제브
        zh: 泰姬陵是哪位皇帝修建的？ | 沙贾汗 | 阿克巴 | 巴布尔 | 奥朗则布
        ar: أي إمبراطور بنى تاج محل؟ | شاه جهان | أكبر | بابر | أورنكزيب

        # hist.constantinople history 3
        *: 1453 | 1492 | 1204 | 1571
        en: In which year did the Ottomans take Constantinople?
        fr: En quelle année les Ottomans ont-ils pris Constantinople ?
        es: ¿En qué año tomaron los otomanos Constantinopla?
        de: In welchem Jahr eroberten die Osmanen Konstantinopel?
        it: In che anno gli Ottomani conquistarono Costantinopoli?
        pt: Em que ano os otomanos tomaram Constantinopla?
        ja: オスマン帝国がコンスタンティノープルを征服したのは何年？
        ko: 오스만 제국이 콘스탄티노폴리스를 점령한 해는?
        zh: 奥斯曼人在哪一年攻占君士坦丁堡？
        ar: في أي عام فتح العثمانيون القسطنطينية؟

        # hist.cuneiform history 3
        en: Cuneiform, one of the first writing systems, came from which region? | Mesopotamia | China | Mesoamerica | Greece
        fr: L'écriture cunéiforme, l'une des premières écritures, vient de quelle région ? | La Mésopotamie | La Chine | La Mésoamérique | La Grèce
        es: ¿De qué región procede la escritura cuneiforme, una de las primeras? | Mesopotamia | China | Mesoamérica | Grecia
        de: Aus welcher Region stammt die Keilschrift, eine der ersten Schriften? | Mesopotamien | China | Mesoamerika | Griechenland
        it: Da quale regione viene il cuneiforme, una delle prime scritture? | Mesopotamia | Cina | Mesoamerica | Grecia
        pt: De que região veio a escrita cuneiforme, uma das primeiras? | Mesopotâmia | China | Mesoamérica | Grécia
        ja: 最古の文字のひとつ、くさび形文字が生まれた地域は？ | メソポタミア | 中国 | メソアメリカ | ギリシャ
        ko: 가장 오래된 문자 중 하나인 쐐기 문자가 생겨난 지역은? | 메소포타미아 | 중국 | 메소아메리카 | 그리스
        zh: 最早的文字之一楔形文字起源于哪个地区？ | 美索不达米亚 | 中国 | 中美洲 | 希腊
        ar: من أي منطقة جاءت الكتابة المسمارية، من أقدم أنظمة الكتابة؟ | بلاد الرافدين | الصين | أمريكا الوسطى | اليونان

        # hist.vikings history 2
        en: Where did the Vikings come from? | Scandinavia | The Mediterranean | North Africa | Central Asia
        fr: D'où venaient les Vikings ? | De Scandinavie | De Méditerranée | D'Afrique du Nord | D'Asie centrale
        es: ¿De dónde venían los vikingos? | De Escandinavia | Del Mediterráneo | Del norte de África | De Asia Central
        de: Woher kamen die Wikinger? | Aus Skandinavien | Aus dem Mittelmeerraum | Aus Nordafrika | Aus Zentralasien
        it: Da dove venivano i Vichinghi? | Dalla Scandinavia | Dal Mediterraneo | Dal Nordafrica | Dall'Asia centrale
        pt: De onde vinham os vikings? | Da Escandinávia | Do Mediterrâneo | Do norte da África | Da Ásia Central
        ja: ヴァイキングはどこから来た？ | スカンディナヴィア | 地中海 | 北アフリカ | 中央アジア
        ko: 바이킹은 어디에서 왔을까요? | 스칸디나비아 | 지중해 | 북아프리카 | 중앙아시아
        zh: 维京人来自哪里？ | 斯堪的纳维亚 | 地中海 | 北非 | 中亚
        ar: من أين جاء الفايكنغ؟ | إسكندنافيا | البحر المتوسط | شمال أفريقيا | آسيا الوسطى

        # hist.rosetta history 3
        en: The Rosetta Stone helped scholars read what? | Egyptian hieroglyphs | Maya glyphs | Cuneiform | Chinese oracle bones
        fr: La pierre de Rosette a aidé les savants à lire quoi ? | Les hiéroglyphes égyptiens | Les glyphes mayas | Le cunéiforme | Les os oraculaires chinois
        es: ¿Qué ayudó a leer la piedra de Rosetta? | Los jeroglíficos egipcios | Los glifos mayas | La escritura cuneiforme | Los huesos oraculares chinos
        de: Was half der Stein von Rosette den Gelehrten zu lesen? | Ägyptische Hieroglyphen | Maya-Glyphen | Keilschrift | Chinesische Orakelknochen
        it: Che cosa aiutò a leggere la stele di Rosetta? | I geroglifici egizi | I glifi maya | Il cuneiforme | Le ossa oracolari cinesi
        pt: A Pedra de Roseta ajudou os estudiosos a ler o quê? | Hieróglifos egípcios | Glifos maias | Escrita cuneiforme | Ossos oraculares chineses
        ja: ロゼッタ・ストーンのおかげで読めるようになったのは？ | エジプトの象形文字 | マヤ文字 | くさび形文字 | 甲骨文字
        ko: 로제타석 덕분에 읽을 수 있게 된 문자는? | 이집트 상형 문자 | 마야 문자 | 쐐기 문자 | 갑골 문자
        zh: 罗塞塔石碑帮助学者读懂了什么？ | 埃及象形文字 | 玛雅文字 | 楔形文字 | 甲骨文
        ar: ماذا ساعد حجر رشيد العلماء على قراءته؟ | الهيروغليفية المصرية | كتابة المايا | الكتابة المسمارية | عظام العرافة الصينية

        # hist.un-founded history 2
        *: 1945 | 1919 | 1955 | 1965
        en: In which year was the United Nations founded?
        fr: En quelle année l'Organisation des Nations unies a-t-elle été fondée ?
        es: ¿En qué año se fundó la Organización de las Naciones Unidas?
        de: In welchem Jahr wurden die Vereinten Nationen gegründet?
        it: In che anno furono fondate le Nazioni Unite?
        pt: Em que ano foi fundada a Organização das Nações Unidas?
        ja: 国際連合が設立されたのは何年？
        ko: 국제 연합(UN)이 세워진 해는?
        zh: 联合国在哪一年成立？
        ar: في أي عام تأسست الأمم المتحدة؟

        # hist.washington history 2
        en: Who was the first President of the United States? | George Washington | Abraham Lincoln | Thomas Jefferson | John Adams
        fr: Qui fut le premier président des États-Unis ? | George Washington | Abraham Lincoln | Thomas Jefferson | John Adams
        es: ¿Quién fue el primer presidente de los Estados Unidos? | George Washington | Abraham Lincoln | Thomas Jefferson | John Adams
        de: Wer war der erste Präsident der Vereinigten Staaten? | George Washington | Abraham Lincoln | Thomas Jefferson | John Adams
        it: Chi fu il primo presidente degli Stati Uniti? | George Washington | Abraham Lincoln | Thomas Jefferson | John Adams
        pt: Quem foi o primeiro presidente dos Estados Unidos? | George Washington | Abraham Lincoln | Thomas Jefferson | John Adams
        ja: アメリカ合衆国の初代大統領は？ | ジョージ・ワシントン | エイブラハム・リンカーン | トマス・ジェファーソン | ジョン・アダムズ
        ko: 미국의 초대 대통령은? | 조지 워싱턴 | 에이브러햄 링컨 | 토머스 제퍼슨 | 존 애덤스
        zh: 美国第一任总统是谁？ | 乔治·华盛顿 | 亚伯拉罕·林肯 | 托马斯·杰斐逊 | 约翰·亚当斯
        ar: من أول رئيس للولايات المتحدة؟ | جورج واشنطن | أبراهام لينكولن | توماس جيفرسون | جون آدامز
        """
}
