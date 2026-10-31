extension Games.QuizBank {
    // Food from many kitchens; no alcohol, so the round suits everyone.
    static let food = """
        # food.guacamole food 1
        en: Guacamole is made mainly from which fruit? | Avocado | Pea | Cucumber | Green apple
        fr: Le guacamole est fait surtout de quel fruit ? | L'avocat | Le petit pois | Le concombre | La pomme verte
        es: ¿De qué fruto se hace sobre todo el guacamole? | Aguacate | Guisante | Pepino | Manzana verde
        de: Woraus wird Guacamole hauptsächlich gemacht? | Avocado | Erbsen | Gurke | Grüner Apfel
        it: Con quale frutto si prepara soprattutto il guacamole? | Avocado | Piselli | Cetriolo | Mela verde
        pt: Guacamole é feito principalmente de qual fruta? | Abacate | Ervilha | Pepino | Maçã verde
        ja: ワカモレのおもな材料は？ | アボカド | グリーンピース | キュウリ | 青リンゴ
        ko: 과카몰리의 주재료는? | 아보카도 | 완두콩 | 오이 | 풋사과
        zh: 牛油果酱（鳄梨酱）主要用什么做？ | 牛油果 | 豌豆 | 黄瓜 | 青苹果
        ar: من أي ثمرة يُصنع الغواكامولي أساسًا؟ | الأفوكادو | البازلاء | الخيار | التفاح الأخضر

        # food.sushi food 1
        en: Sushi is a traditional dish of which country? | Japan | Thailand | India | Peru
        fr: Les sushis sont un plat traditionnel de quel pays ? | Le Japon | La Thaïlande | L'Inde | Le Pérou
        es: ¿De qué país es plato tradicional el sushi? | Japón | Tailandia | India | Perú
        de: Sushi ist ein traditionelles Gericht welches Landes? | Japan | Thailand | Indien | Peru
        it: Il sushi è un piatto tradizionale di quale Paese? | Giappone | Thailandia | India | Perù
        pt: Sushi é um prato tradicional de qual país? | Japão | Tailândia | Índia | Peru
        ja: すしはどの国の伝統料理？ | 日本 | タイ | インド | ペルー
        ko: 스시는 어느 나라의 전통 요리일까요? | 일본 | 태국 | 인도 | 페루
        zh: 寿司是哪个国家的传统美食？ | 日本 | 泰国 | 印度 | 秘鲁
        ar: السوشي طبق تقليدي من أي بلد؟ | اليابان | تايلاند | الهند | بيرو

        # food.kimchi food 1
        en: Kimchi is a traditional dish of which country? | Korea | Japan | Vietnam | Thailand
        fr: Le kimchi est un plat traditionnel de quel pays ? | La Corée | Le Japon | Le Viêt Nam | La Thaïlande
        es: ¿De qué país es plato tradicional el kimchi? | Corea | Japón | Vietnam | Tailandia
        de: Kimchi ist ein traditionelles Gericht welches Landes? | Korea | Japan | Vietnam | Thailand
        it: Il kimchi è un piatto tradizionale di quale Paese? | Corea | Giappone | Vietnam | Thailandia
        pt: Kimchi é um prato tradicional de qual país? | Coreia | Japão | Vietnã | Tailândia
        ja: キムチはどの国の伝統料理？ | 韓国・朝鮮 | 日本 | ベトナム | タイ
        ko: 김치는 어느 나라의 전통 음식일까요? | 한국 | 일본 | 베트남 | 태국
        zh: 泡菜（辛奇）是哪个国家的传统美食？ | 韩国 | 日本 | 越南 | 泰国
        ar: الكيمتشي طبق تقليدي من أي بلد؟ | كوريا | اليابان | فيتنام | تايلاند

        # food.paella food 1
        en: Paella comes from which country? | Spain | Italy | Mexico | Greece
        fr: De quel pays vient la paella ? | L'Espagne | L'Italie | Le Mexique | La Grèce
        es: ¿De qué país es la paella? | España | Italia | México | Grecia
        de: Aus welchem Land stammt die Paella? | Spanien | Italien | Mexiko | Griechenland
        it: Da quale Paese viene la paella? | Spagna | Italia | Messico | Grecia
        pt: De que país vem a paella? | Espanha | Itália | México | Grécia
        ja: パエリアはどの国の料理？ | スペイン | イタリア | メキシコ | ギリシャ
        ko: 파에야는 어느 나라 음식일까요? | 스페인 | 이탈리아 | 멕시코 | 그리스
        zh: 西班牙海鲜饭（帕埃利亚）来自哪个国家？ | 西班牙 | 意大利 | 墨西哥 | 希腊
        ar: من أي بلد تأتي الباييلا؟ | إسبانيا | إيطاليا | المكسيك | اليونان

        # food.margherita food 2
        en: The pizza Margherita is linked to which Italian city? | Naples | Rome | Milan | Venice
        fr: La pizza Margherita est associée à quelle ville italienne ? | Naples | Rome | Milan | Venise
        es: ¿Con qué ciudad italiana se asocia la pizza Margarita? | Nápoles | Roma | Milán | Venecia
        de: Mit welcher italienischen Stadt ist die Pizza Margherita verbunden? | Neapel | Rom | Mailand | Venedig
        it: A quale città italiana è legata la pizza Margherita? | Napoli | Roma | Milano | Venezia
        pt: A pizza Margherita está ligada a qual cidade italiana? | Nápoles | Roma | Milão | Veneza
        ja: ピッツァ・マルゲリータと縁が深いイタリアの都市は？ | ナポリ | ローマ | ミラノ | ベネチア
        ko: 마르게리타 피자와 관련 깊은 이탈리아 도시는? | 나폴리 | 로마 | 밀라노 | 베네치아
        zh: 玛格丽特披萨与意大利哪座城市有关？ | 那不勒斯 | 罗马 | 米兰 | 威尼斯
        ar: بأي مدينة إيطالية ترتبط بيتزا مارغريتا؟ | نابولي | روما | ميلانو | البندقية

        # food.croissant food 1
        en: What shape is a croissant named after? | A crescent | A star | A shell | A heart
        fr: D'après quelle forme le croissant est-il nommé ? | Le croissant de lune | L'étoile | Le coquillage | Le cœur
        es: ¿A qué forma debe su nombre el cruasán? | La luna creciente | Una estrella | Una concha | Un corazón
        de: Nach welcher Form ist das Croissant benannt? | Nach der Mondsichel | Nach einem Stern | Nach einer Muschel | Nach einem Herz
        it: Da quale forma prende il nome il croissant? | La falce di luna | Una stella | Una conchiglia | Un cuore
        pt: O croissant recebeu o nome de qual forma? | A lua crescente | Uma estrela | Uma concha | Um coração
        ja: クロワッサンという名前の由来になった形は？ | 三日月 | 星 | 貝がら | ハート
        ko: 크루아상의 이름은 어떤 모양에서 왔을까요? | 초승달 | 별 | 조개껍데기 | 하트
        zh: 可颂（牛角包）的名字来自哪种形状？ | 新月 | 星星 | 贝壳 | 心形
        ar: تُسمّى الكرواسون نسبةً إلى أي شكل؟ | الهلال | النجمة | الصدفة | القلب

        # food.tofu food 2
        en: Tofu is made from which beans? | Soybeans | Kidney beans | Chickpeas | Lentils
        fr: Le tofu est fabriqué à partir de quelles graines ? | Le soja | Les haricots rouges | Les pois chiches | Les lentilles
        es: ¿De qué legumbre se hace el tofu? | Soja | Alubias rojas | Garbanzos | Lentejas
        de: Woraus wird Tofu gemacht? | Aus Sojabohnen | Aus Kidneybohnen | Aus Kichererbsen | Aus Linsen
        it: Con quale legume si fa il tofu? | Soia | Fagioli rossi | Ceci | Lenticchie
        pt: O tofu é feito de qual grão? | Soja | Feijão-vermelho | Grão-de-bico | Lentilha
        ja: 豆腐は何からつくられる？ | 大豆 | インゲン豆 | ひよこ豆 | レンズ豆
        ko: 두부는 무엇으로 만들까요? | 콩(대두) | 강낭콩 | 병아리콩 | 렌틸콩
        zh: 豆腐是用什么做的？ | 黄豆 | 红芸豆 | 鹰嘴豆 | 小扁豆
        ar: من أي حبوب يُصنع التوفو؟ | فول الصويا | الفاصوليا الحمراء | الحمّص | العدس

        # food.cacao food 1
        en: Chocolate is made from the beans of which plant? | Cacao | Coffee | Vanilla | Carob
        fr: Le chocolat est fait avec les fèves de quelle plante ? | Le cacaoyer | Le caféier | La vanille | Le caroubier
        es: ¿Con las semillas de qué planta se hace el chocolate? | Cacao | Café | Vainilla | Algarrobo
        de: Aus den Bohnen welcher Pflanze wird Schokolade gemacht? | Kakao | Kaffee | Vanille | Johannisbrot
        it: Con i semi di quale pianta si fa il cioccolato? | Cacao | Caffè | Vaniglia | Carrubo
        pt: O chocolate é feito com as sementes de qual planta? | Cacau | Café | Baunilha | Alfarroba
        ja: チョコレートは何の植物の豆からつくられる？ | カカオ | コーヒー | バニラ | イナゴマメ
        ko: 초콜릿은 어떤 식물의 열매 씨로 만들까요? | 카카오 | 커피 | 바닐라 | 캐럽
        zh: 巧克力是用哪种植物的豆子做的？ | 可可 | 咖啡 | 香草 | 角豆
        ar: من بذور أي نبات تُصنع الشوكولاتة؟ | الكاكاو | البن | الفانيليا | الخرّوب

        # food.vanilla food 3
        en: Vanilla comes from the pod of which kind of plant? | An orchid | A palm | A cactus | A rose
        fr: La vanille vient de la gousse de quel type de plante ? | Une orchidée | Un palmier | Un cactus | Un rosier
        es: ¿De la vaina de qué tipo de planta sale la vainilla? | Una orquídea | Una palmera | Un cactus | Un rosal
        de: Aus der Schote welcher Pflanzenart stammt Vanille? | Einer Orchidee | Einer Palme | Einem Kaktus | Einer Rose
        it: Da quale tipo di pianta viene il baccello della vaniglia? | Un'orchidea | Una palma | Un cactus | Una rosa
        pt: A baunilha vem da vagem de que tipo de planta? | Uma orquídea | Uma palmeira | Um cacto | Uma roseira
        ja: バニラのさやは、どんな植物からとれる？ | ラン | ヤシ | サボテン | バラ
        ko: 바닐라 꼬투리는 어떤 식물에서 얻을까요? | 난초 | 야자나무 | 선인장 | 장미
        zh: 香草荚来自哪类植物？ | 兰花 | 棕榈 | 仙人掌 | 玫瑰
        ar: من قرون أي نوع من النباتات تأتي الفانيليا؟ | سحلبية (أوركيد) | نخلة | صبّار | وردة

        # food.saffron food 3
        en: Saffron is made from which part of a flower? | The stigmas | The petals | The roots | The seeds
        fr: Le safran est fait avec quelle partie d'une fleur ? | Les stigmates | Les pétales | Les racines | Les graines
        es: ¿Con qué parte de una flor se hace el azafrán? | Los estigmas | Los pétalos | Las raíces | Las semillas
        de: Aus welchem Teil einer Blüte wird Safran gewonnen? | Aus den Narben | Aus den Blütenblättern | Aus den Wurzeln | Aus den Samen
        it: Con quale parte del fiore si fa lo zafferano? | Gli stimmi | I petali | Le radici | I semi
        pt: O açafrão é feito de que parte da flor? | Os estigmas | As pétalas | As raízes | As sementes
        ja: サフランは花のどの部分からつくられる？ | めしべ（柱頭） | 花びら | 根 | 種
        ko: 사프란은 꽃의 어느 부분으로 만들까요? | 암술머리 | 꽃잎 | 뿌리 | 씨앗
        zh: 藏红花香料取自花的哪个部分？ | 柱头 | 花瓣 | 根 | 种子
        ar: من أي جزء من الزهرة يُصنع الزعفران؟ | المياسم | البتلات | الجذور | البذور

        # food.paddy food 2
        en: Rice is often grown in flooded fields called what? | Paddies | Orchards | Vineyards | Greenhouses
        fr: Le riz pousse souvent dans des champs inondés appelés… | Rizières | Vergers | Vignobles | Serres
        es: El arroz suele cultivarse en campos inundados llamados… | Arrozales | Huertos frutales | Viñedos | Invernaderos
        de: Reis wächst oft auf überfluteten Feldern. Wie heißen sie? | Reisfelder | Obstgärten | Weinberge | Gewächshäuser
        it: Il riso cresce spesso in campi allagati chiamati… | Risaie | Frutteti | Vigneti | Serre
        pt: O arroz costuma ser plantado em campos alagados chamados… | Arrozais | Pomares | Vinhedos | Estufas
        ja: 米がよく育てられる、水を張った畑を何という？ | 水田 | 果樹園 | ぶどう畑 | 温室
        ko: 쌀을 기르는, 물을 댄 밭을 무엇이라고 할까요? | 논 | 과수원 | 포도밭 | 온실
        zh: 种水稻的灌水田地叫什么？ | 稻田 | 果园 | 葡萄园 | 温室
        ar: يُزرع الأرز غالبًا في حقول مغمورة بالماء تُسمّى… | حقول الأرز | البساتين | الكروم | البيوت الزجاجية

        # food.sauerkraut food 2
        en: Sauerkraut is made by fermenting which vegetable? | Cabbage | Potato | Cucumber | Carrot
        fr: La choucroute est faite en fermentant quel légume ? | Le chou | La pomme de terre | Le concombre | La carotte
        es: ¿Qué verdura se fermenta para hacer el chucrut? | Col | Patata | Pepino | Zanahoria
        de: Sauerkraut entsteht durch Gärung welches Gemüses? | Weißkohl | Kartoffel | Gurke | Karotte
        it: I crauti si fanno facendo fermentare quale verdura? | Cavolo | Patata | Cetriolo | Carota
        pt: O chucrute é feito fermentando qual legume? | Repolho | Batata | Pepino | Cenoura
        ja: ザワークラウトは何の野菜を発酵させたもの？ | キャベツ | ジャガイモ | キュウリ | ニンジン
        ko: 사워크라우트는 어떤 채소를 발효시킨 것일까요? | 양배추 | 감자 | 오이 | 당근
        zh: 德国酸菜是用哪种蔬菜发酵做成的？ | 卷心菜 | 土豆 | 黄瓜 | 胡萝卜
        ar: يُصنع الملفوف المخلل الألماني (زاوركراوت) بتخمير أي خضار؟ | الملفوف | البطاطا | الخيار | الجزر

        # food.hummus food 1
        en: Hummus is made mainly from which legume? | Chickpeas | Lentils | Peas | Soybeans
        fr: Le houmous est fait surtout avec quelle légumineuse ? | Les pois chiches | Les lentilles | Les petits pois | Le soja
        es: ¿De qué legumbre se hace sobre todo el hummus? | Garbanzos | Lentejas | Guisantes | Soja
        de: Aus welcher Hülsenfrucht wird Hummus hauptsächlich gemacht? | Kichererbsen | Linsen | Erbsen | Sojabohnen
        it: Con quale legume si fa soprattutto l'hummus? | Ceci | Lenticchie | Piselli | Soia
        pt: O homus é feito principalmente de qual leguminosa? | Grão-de-bico | Lentilha | Ervilha | Soja
        ja: フムスのおもな材料の豆は？ | ひよこ豆 | レンズ豆 | エンドウ豆 | 大豆
        ko: 후무스의 주재료인 콩은? | 병아리콩 | 렌틸콩 | 완두콩 | 대두
        zh: 鹰嘴豆泥（胡姆斯）主要用哪种豆子做？ | 鹰嘴豆 | 小扁豆 | 豌豆 | 黄豆
        ar: من أي بقول يُصنع الحمّص بالطحينة أساسًا؟ | الحمّص | العدس | البازلاء | فول الصويا

        # food.wasabi food 2
        en: What is wasabi known for? | A sharp, hot bite | Being very sweet | Being sour | Tasting of nothing
        fr: Pour quoi le wasabi est-il connu ? | Son piquant qui monte au nez | Sa grande douceur | Son acidité | Son absence de goût
        es: ¿Por qué es conocido el wasabi? | Por su picor intenso | Por ser muy dulce | Por ser ácido | Por no saber a nada
        de: Wofür ist Wasabi bekannt? | Für seine beißende Schärfe | Für seine Süße | Für seine Säure | Für seinen fehlenden Geschmack
        it: Per che cosa è noto il wasabi? | Per il suo piccante pungente | Per essere molto dolce | Per essere acido | Per non sapere di niente
        pt: O wasabi é conhecido por quê? | Pela ardência forte | Por ser muito doce | Por ser azedo | Por não ter gosto
        ja: わさびといえばどんな味？ | ツンと辛い | とても甘い | すっぱい | 味がない
        ko: 고추냉이(와사비)는 어떤 맛으로 유명할까요? | 코를 찌르는 매운맛 | 아주 단맛 | 신맛 | 아무 맛도 없음
        zh: 芥末（山葵）以什么味道著称？ | 冲鼻的辣味 | 非常甜 | 很酸 | 没有味道
        ar: بماذا يشتهر الوسابي؟ | بحرارته اللاذعة | بحلاوته الشديدة | بحموضته | بأنه بلا طعم

        # food.matcha food 2
        en: Matcha is a powder made from what? | Green tea leaves | Coffee beans | Cocoa | Seaweed
        fr: Le matcha est une poudre faite à partir de quoi ? | De feuilles de thé vert | De grains de café | De cacao | D'algues
        es: ¿De qué se hace el polvo de matcha? | De hojas de té verde | De granos de café | De cacao | De algas
        de: Woraus wird Matcha-Pulver gemacht? | Aus grünen Teeblättern | Aus Kaffeebohnen | Aus Kakao | Aus Algen
        it: Di che cosa è fatta la polvere di matcha? | Foglie di tè verde | Chicchi di caffè | Cacao | Alghe
        pt: O matcha é um pó feito de quê? | Folhas de chá-verde | Grãos de café | Cacau | Algas
        ja: 抹茶は何を粉にしたもの？ | 緑茶の葉 | コーヒー豆 | カカオ | 海藻
        ko: 말차는 무엇을 가루로 만든 것일까요? | 녹차 잎 | 커피콩 | 카카오 | 해조류
        zh: 抹茶是用什么磨成的粉？ | 绿茶叶 | 咖啡豆 | 可可 | 海藻
        ar: الماتشا مسحوق مصنوع من ماذا؟ | أوراق الشاي الأخضر | حبوب البن | الكاكاو | الطحالب

        # food.taco food 1
        en: Tacos come from which country? | Mexico | Spain | Peru | Argentina
        fr: De quel pays viennent les tacos ? | Le Mexique | L'Espagne | Le Pérou | L'Argentine
        es: ¿De qué país son los tacos? | México | España | Perú | Argentina
        de: Aus welchem Land stammen Tacos? | Mexiko | Spanien | Peru | Argentinien
        it: Da quale Paese vengono i tacos? | Messico | Spagna | Perù | Argentina
        pt: De que país vêm os tacos? | México | Espanha | Peru | Argentina
        ja: タコスはどの国の料理？ | メキシコ | スペイン | ペルー | アルゼンチン
        ko: 타코는 어느 나라 음식일까요? | 멕시코 | 스페인 | 페루 | 아르헨티나
        zh: 塔可来自哪个国家？ | 墨西哥 | 西班牙 | 秘鲁 | 阿根廷
        ar: من أي بلد تأتي التاكو؟ | المكسيك | إسبانيا | بيرو | الأرجنتين

        # food.feijoada food 2
        en: Feijoada, a black-bean stew, is a famous dish of which country? | Brazil | Mexico | Spain | Cuba
        fr: La feijoada, un ragoût de haricots noirs, est un plat célèbre de quel pays ? | Le Brésil | Le Mexique | L'Espagne | Cuba
        es: ¿De qué país es plato típico la feijoada, un guiso de frijoles negros? | Brasil | México | España | Cuba
        de: Feijoada, ein Eintopf aus schwarzen Bohnen, ist ein berühmtes Gericht welches Landes? | Brasilien | Mexiko | Spanien | Kuba
        it: La feijoada, uno stufato di fagioli neri, è un piatto famoso di quale Paese? | Brasile | Messico | Spagna | Cuba
        pt: A feijoada, ensopado de feijão-preto, é um prato famoso de qual país? | Brasil | México | Espanha | Cuba
        ja: 黒豆の煮込み料理フェイジョアーダが有名な国は？ | ブラジル | メキシコ | スペイン | キューバ
        ko: 검은콩 스튜인 페이조아다로 유명한 나라는? | 브라질 | 멕시코 | 스페인 | 쿠바
        zh: 黑豆炖肉（费若阿达）是哪个国家的名菜？ | 巴西 | 墨西哥 | 西班牙 | 古巴
        ar: الفيجوادا، يخنة الفاصوليا السوداء، طبق شهير في أي بلد؟ | البرازيل | المكسيك | إسبانيا | كوبا

        # food.pho food 2
        en: Phở is a noodle soup from which country? | Vietnam | Thailand | Japan | Korea
        fr: Le phở est une soupe de nouilles de quel pays ? | Le Viêt Nam | La Thaïlande | Le Japon | La Corée
        es: ¿De qué país es el phở, una sopa de fideos? | Vietnam | Tailandia | Japón | Corea
        de: Phở ist eine Nudelsuppe aus welchem Land? | Vietnam | Thailand | Japan | Korea
        it: Il phở è una zuppa di noodle di quale Paese? | Vietnam | Thailandia | Giappone | Corea
        pt: O phở é uma sopa de macarrão de qual país? | Vietnã | Tailândia | Japão | Coreia
        ja: 麺料理のフォーはどの国の料理？ | ベトナム | タイ | 日本 | 韓国
        ko: 쌀국수 '퍼(포)'는 어느 나라 음식일까요? | 베트남 | 태국 | 일본 | 한국
        zh: 越南河粉（Phở）来自哪个国家？ | 越南 | 泰国 | 日本 | 韩国
        ar: الفو حساء نودلز من أي بلد؟ | فيتنام | تايلاند | اليابان | كوريا

        # food.baguette food 1
        en: The baguette, a long thin bread, is a symbol of which country? | France | Germany | Russia | Japan
        fr: La baguette, ce pain long et fin, est un symbole de quel pays ? | La France | L'Allemagne | La Russie | Le Japon
        es: ¿De qué país es símbolo la baguette, un pan largo y fino? | Francia | Alemania | Rusia | Japón
        de: Das Baguette, ein langes dünnes Brot, ist ein Symbol welches Landes? | Frankreich | Deutschland | Russland | Japan
        it: La baguette, un pane lungo e sottile, è un simbolo di quale Paese? | Francia | Germania | Russia | Giappone
        pt: A baguete, um pão longo e fino, é símbolo de qual país? | França | Alemanha | Rússia | Japão
        ja: 細長いパン、バゲットがシンボルになっている国は？ | フランス | ドイツ | ロシア | 日本
        ko: 길고 가는 빵 바게트는 어느 나라의 상징일까요? | 프랑스 | 독일 | 러시아 | 일본
        zh: 长棍面包是哪个国家的象征？ | 法国 | 德国 | 俄罗斯 | 日本
        ar: الباغيت، الخبز الطويل الرفيع، رمزٌ لأي بلد؟ | فرنسا | ألمانيا | روسيا | اليابان

        # food.dim-sum food 3
        en: Dim sum is most closely linked to which Chinese cuisine? | Cantonese | Sichuan | Hunan | Shandong
        fr: Les dim sum sont surtout liés à quelle cuisine chinoise ? | Cantonaise | Du Sichuan | Du Hunan | Du Shandong
        es: ¿Con qué cocina china se asocia sobre todo el dim sum? | Cantonesa | De Sichuan | De Hunan | De Shandong
        de: Mit welcher chinesischen Küche ist Dim Sum am engsten verbunden? | Kantonesisch | Sichuan | Hunan | Shandong
        it: A quale cucina cinese sono legati soprattutto i dim sum? | Cantonese | Del Sichuan | Dello Hunan | Dello Shandong
        pt: O dim sum está mais ligado a qual cozinha chinesa? | Cantonesa | De Sichuan | De Hunan | De Shandong
        ja: 点心（飲茶）といえば、どの中国料理？ | 広東料理 | 四川料理 | 湖南料理 | 山東料理
        ko: 딤섬과 가장 관련 깊은 중국 요리는? | 광둥 요리 | 쓰촨 요리 | 후난 요리 | 산둥 요리
        zh: 点心（早茶）与哪个菜系关系最密切？ | 粤菜 | 川菜 | 湘菜 | 鲁菜
        ar: بأي مطبخ صيني ترتبط أطباق الديم سم أكثر من غيره؟ | الكانتوني | السيشواني | الهونانّي | الشاندونغي

        # food.turmeric food 2
        en: Which spice gives many curries their yellow colour? | Turmeric | Cinnamon | Black pepper | Cumin
        fr: Quelle épice donne à beaucoup de currys leur couleur jaune ? | Le curcuma | La cannelle | Le poivre noir | Le cumin
        es: ¿Qué especia da a muchos currys su color amarillo? | La cúrcuma | La canela | La pimienta negra | El comino
        de: Welches Gewürz gibt vielen Currys ihre gelbe Farbe? | Kurkuma | Zimt | Schwarzer Pfeffer | Kreuzkümmel
        it: Quale spezia dà a molti curry il loro colore giallo? | La curcuma | La cannella | Il pepe nero | Il cumino
        pt: Que especiaria dá a muitos curries a cor amarela? | Cúrcuma | Canela | Pimenta-do-reino | Cominho
        ja: 多くのカレーを黄色くしているスパイスは？ | ターメリック | シナモン | 黒こしょう | クミン
        ko: 많은 카레를 노랗게 만드는 향신료는? | 강황 | 계피 | 후추 | 쿠민
        zh: 哪种香料让许多咖喱呈黄色？ | 姜黄 | 肉桂 | 黑胡椒 | 孜然
        ar: أي بهار يعطي كثيرًا من أطباق الكاري لونها الأصفر؟ | الكركم | القرفة | الفلفل الأسود | الكمّون

        # food.potato-origin food 3
        en: Where were potatoes first grown? | The Andes of South America | Ireland | China | Egypt
        fr: Où les pommes de terre ont-elles été cultivées en premier ? | Dans les Andes d'Amérique du Sud | En Irlande | En Chine | En Égypte
        es: ¿Dónde se cultivaron las papas por primera vez? | En los Andes de América del Sur | En Irlanda | En China | En Egipto
        de: Wo wurden Kartoffeln zuerst angebaut? | In den Anden Südamerikas | In Irland | In China | In Ägypten
        it: Dove furono coltivate per la prima volta le patate? | Sulle Ande del Sud America | In Irlanda | In Cina | In Egitto
        pt: Onde a batata foi cultivada pela primeira vez? | Nos Andes da América do Sul | Na Irlanda | Na China | No Egito
        ja: ジャガイモが最初に栽培されたのはどこ？ | 南アメリカのアンデス | アイルランド | 中国 | エジプト
        ko: 감자를 처음 재배한 곳은? | 남아메리카 안데스 지역 | 아일랜드 | 중국 | 이집트
        zh: 土豆最早在哪里种植？ | 南美洲安第斯山区 | 爱尔兰 | 中国 | 埃及
        ar: أين زُرعت البطاطا أول مرة؟ | في جبال الأنديز بأمريكا الجنوبية | في أيرلندا | في الصين | في مصر

        # food.tomato-fruit food 2
        en: To a botanist, a tomato is which part of the plant? | The fruit | The root | The leaf | The stem
        fr: Pour un botaniste, la tomate est quelle partie de la plante ? | Le fruit | La racine | La feuille | La tige
        es: Para un botánico, ¿qué parte de la planta es el tomate? | El fruto | La raíz | La hoja | El tallo
        de: Was ist eine Tomate für Botaniker? | Eine Frucht | Eine Wurzel | Ein Blatt | Ein Stängel
        it: Per un botanico, che parte della pianta è il pomodoro? | Il frutto | La radice | La foglia | Il fusto
        pt: Para um botânico, o tomate é que parte da planta? | O fruto | A raiz | A folha | O caule
        ja: 植物学では、トマトは植物のどの部分？ | 果実 | 根 | 葉 | 茎
        ko: 식물학적으로 토마토는 식물의 어느 부분일까요? | 열매 | 뿌리 | 잎 | 줄기
        zh: 从植物学上说，番茄是植物的哪个部分？ | 果实 | 根 | 叶 | 茎
        ar: بالنسبة لعالم النبات، الطماطم أي جزء من النبتة؟ | الثمرة | الجذر | الورقة | الساق

        # food.cheese food 1
        en: Cheese is made from what? | Milk | Eggs | Flour | Oil
        fr: Le fromage est fait à partir de quoi ? | De lait | D'œufs | De farine | D'huile
        es: ¿De qué se hace el queso? | De leche | De huevos | De harina | De aceite
        de: Woraus wird Käse gemacht? | Aus Milch | Aus Eiern | Aus Mehl | Aus Öl
        it: Con che cosa si fa il formaggio? | Con il latte | Con le uova | Con la farina | Con l'olio
        pt: O queijo é feito de quê? | Leite | Ovos | Farinha | Óleo
        ja: チーズは何からつくられる？ | 牛乳など動物の乳 | 卵 | 小麦粉 | 油
        ko: 치즈는 무엇으로 만들까요? | 우유(동물의 젖) | 달걀 | 밀가루 | 기름
        zh: 奶酪是用什么做的？ | 奶 | 鸡蛋 | 面粉 | 油
        ar: مِمّ يُصنع الجبن؟ | الحليب | البيض | الطحين | الزيت

        # food.yeast food 2
        en: What makes bread dough rise? | Yeast | Salt | Sugar | Oil
        fr: Qu'est-ce qui fait lever la pâte à pain ? | La levure | Le sel | Le sucre | L'huile
        es: ¿Qué hace subir la masa del pan? | La levadura | La sal | El azúcar | El aceite
        de: Was lässt Brotteig aufgehen? | Hefe | Salz | Zucker | Öl
        it: Che cosa fa lievitare l'impasto del pane? | Il lievito | Il sale | Lo zucchero | L'olio
        pt: O que faz a massa do pão crescer? | O fermento (levedura) | O sal | O açúcar | O óleo
        ja: パン生地をふくらませるのは？ | 酵母（イースト） | 塩 | 砂糖 | 油
        ko: 빵 반죽을 부풀게 하는 것은? | 효모(이스트) | 소금 | 설탕 | 기름
        zh: 是什么让面团发起来？ | 酵母 | 盐 | 糖 | 油
        ar: ما الذي يجعل عجينة الخبز تنتفخ؟ | الخميرة | الملح | السكر | الزيت

        # food.popcorn food 1
        en: Popcorn is made from which grain? | Corn (maize) | Rice | Wheat | Oats
        fr: Le pop-corn est fait avec quelle céréale ? | Le maïs | Le riz | Le blé | L'avoine
        es: ¿De qué cereal son las palomitas? | Maíz | Arroz | Trigo | Avena
        de: Aus welchem Getreide wird Popcorn gemacht? | Mais | Reis | Weizen | Hafer
        it: Con quale cereale si fanno i popcorn? | Mais | Riso | Grano | Avena
        pt: A pipoca é feita de qual grão? | Milho | Arroz | Trigo | Aveia
        ja: ポップコーンは何の穀物からつくられる？ | トウモロコシ | 米 | 小麦 | オーツ麦
        ko: 팝콘은 어떤 곡물로 만들까요? | 옥수수 | 쌀 | 밀 | 귀리
        zh: 爆米花是用哪种谷物做的？ | 玉米 | 大米 | 小麦 | 燕麦
        ar: من أي حبوب يُصنع الفشار؟ | الذرة | الأرز | القمح | الشوفان

        # food.coffee-origin food 3
        en: Coffee is thought to have first come from which country? | Ethiopia | Brazil | Colombia | Italy
        fr: De quel pays le café serait-il originaire ? | L'Éthiopie | Le Brésil | La Colombie | L'Italie
        es: ¿De qué país se cree que es originario el café? | Etiopía | Brasil | Colombia | Italia
        de: Aus welchem Land stammt der Kaffee ursprünglich wohl? | Äthiopien | Brasilien | Kolumbien | Italien
        it: Da quale Paese si pensa che provenga in origine il caffè? | Etiopia | Brasile | Colombia | Italia
        pt: De que país se acredita que o café seja originário? | Etiópia | Brasil | Colômbia | Itália
        ja: コーヒーのふるさととされる国は？ | エチオピア | ブラジル | コロンビア | イタリア
        ko: 커피가 처음 시작된 곳으로 여겨지는 나라는? | 에티오피아 | 브라질 | 콜롬비아 | 이탈리아
        zh: 咖啡被认为最早起源于哪个国家？ | 埃塞俄比亚 | 巴西 | 哥伦比亚 | 意大利
        ar: من أي بلد يُعتقد أن البن جاء أول مرة؟ | إثيوبيا | البرازيل | كولومبيا | إيطاليا

        # food.maple-syrup food 2
        en: Maple syrup is most associated with which country? | Canada | Sweden | Russia | Japan
        fr: Le sirop d'érable est surtout associé à quel pays ? | Le Canada | La Suède | La Russie | Le Japon
        es: ¿Con qué país se asocia sobre todo el jarabe de arce? | Canadá | Suecia | Rusia | Japón
        de: Mit welchem Land verbindet man Ahornsirup am meisten? | Kanada | Schweden | Russland | Japan
        it: A quale Paese è associato soprattutto lo sciroppo d'acero? | Canada | Svezia | Russia | Giappone
        pt: O xarope de bordo é mais associado a qual país? | Canadá | Suécia | Rússia | Japão
        ja: メープルシロップといえばどの国？ | カナダ | スウェーデン | ロシア | 日本
        ko: 메이플 시럽으로 가장 유명한 나라는? | 캐나다 | 스웨덴 | 러시아 | 일본
        zh: 枫糖浆最常与哪个国家联系在一起？ | 加拿大 | 瑞典 | 俄罗斯 | 日本
        ar: بأي بلد يرتبط شراب القيقب أكثر من غيره؟ | كندا | السويد | روسيا | اليابان

        # food.mochi food 2
        en: Japanese mochi is made from what? | Sticky rice | Wheat | Potato | Corn
        fr: Le mochi japonais est fait avec quoi ? | Du riz gluant | Du blé | De la pomme de terre | Du maïs
        es: ¿De qué se hace el mochi japonés? | Arroz glutinoso | Trigo | Patata | Maíz
        de: Woraus wird japanisches Mochi gemacht? | Aus Klebreis | Aus Weizen | Aus Kartoffeln | Aus Mais
        it: Con che cosa si fa il mochi giapponese? | Riso glutinoso | Grano | Patate | Mais
        pt: O mochi japonês é feito de quê? | Arroz glutinoso | Trigo | Batata | Milho
        ja: もちは何からつくられる？ | もち米 | 小麦 | ジャガイモ | トウモロコシ
        ko: 일본의 모치(찹쌀떡)는 무엇으로 만들까요? | 찹쌀 | 밀 | 감자 | 옥수수
        zh: 日本麻糬是用什么做的？ | 糯米 | 小麦 | 土豆 | 玉米
        ar: مِمّ تُصنع حلوى الموتشي اليابانية؟ | الأرز الدبق | القمح | البطاطا | الذرة

        # food.citrus-vitamin food 1
        en: Oranges and lemons are rich in which vitamin? | Vitamin C | Vitamin D | Vitamin B12 | Vitamin K
        fr: Les oranges et les citrons sont riches en quelle vitamine ? | Vitamine C | Vitamine D | Vitamine B12 | Vitamine K
        es: ¿En qué vitamina son ricos las naranjas y los limones? | Vitamina C | Vitamina D | Vitamina B12 | Vitamina K
        de: An welchem Vitamin sind Orangen und Zitronen reich? | Vitamin C | Vitamin D | Vitamin B12 | Vitamin K
        it: Di quale vitamina sono ricchi arance e limoni? | Vitamina C | Vitamina D | Vitamina B12 | Vitamina K
        pt: Laranjas e limões são ricos em qual vitamina? | Vitamina C | Vitamina D | Vitamina B12 | Vitamina K
        ja: オレンジやレモンに多く含まれるビタミンは？ | ビタミンC | ビタミンD | ビタミンB12 | ビタミンK
        ko: 오렌지와 레몬에 많은 비타민은? | 비타민 C | 비타민 D | 비타민 B12 | 비타민 K
        zh: 橙子和柠檬富含哪种维生素？ | 维生素C | 维生素D | 维生素B12 | 维生素K
        ar: البرتقال والليمون غنيّان بأي فيتامين؟ | فيتامين ج | فيتامين د | فيتامين ب12 | فيتامين ك

        # food.capsaicin food 3
        en: Which substance makes chili peppers hot? | Capsaicin | Caffeine | Menthol | Gluten
        fr: Quelle substance rend les piments piquants ? | La capsaïcine | La caféine | Le menthol | Le gluten
        es: ¿Qué sustancia hace picantes los chiles? | La capsaicina | La cafeína | El mentol | El gluten
        de: Welcher Stoff macht Chilischoten scharf? | Capsaicin | Koffein | Menthol | Gluten
        it: Quale sostanza rende piccanti i peperoncini? | La capsaicina | La caffeina | Il mentolo | Il glutine
        pt: Que substância faz as pimentas arderem? | Capsaicina | Cafeína | Mentol | Glúten
        ja: 唐辛子を辛くしている成分は？ | カプサイシン | カフェイン | メントール | グルテン
        ko: 고추를 맵게 만드는 성분은? | 캡사이신 | 카페인 | 멘톨 | 글루텐
        zh: 是什么物质让辣椒变辣？ | 辣椒素 | 咖啡因 | 薄荷醇 | 麸质
        ar: ما المادة التي تجعل الفلفل الحار حارًّا؟ | الكابسيسين | الكافيين | المنثول | الغلوتين

        # food.ramen food 1
        en: Ramen is a noodle soup most famous in which country? | Japan | Italy | Mexico | India
        fr: Les ramen sont une soupe de nouilles surtout célèbre dans quel pays ? | Le Japon | L'Italie | Le Mexique | L'Inde
        es: ¿En qué país es más famoso el ramen, una sopa de fideos? | Japón | Italia | México | India
        de: In welchem Land ist die Nudelsuppe Ramen am berühmtesten? | Japan | Italien | Mexiko | Indien
        it: In quale Paese è più famoso il ramen, una zuppa di noodle? | Giappone | Italia | Messico | India
        pt: Em que país o ramen, uma sopa de macarrão, é mais famoso? | Japão | Itália | México | Índia
        ja: ラーメンがとくに有名な国は？ | 日本 | イタリア | メキシコ | インド
        ko: 라멘(일본식 라면)이 특히 유명한 나라는? | 일본 | 이탈리아 | 멕시코 | 인도
        zh: 拉面这种汤面在哪个国家最出名？ | 日本 | 意大利 | 墨西哥 | 印度
        ar: الرامن حساء نودلز يشتهر أكثر في أي بلد؟ | اليابان | إيطاليا | المكسيك | الهند

        # food.biryani food 2
        en: Biryani is a rice dish from which region? | South Asia | Scandinavia | South America | Australia
        fr: Le biryani est un plat de riz de quelle région ? | L'Asie du Sud | La Scandinavie | L'Amérique du Sud | L'Australie
        es: ¿De qué región es el biryani, un plato de arroz? | Asia del Sur | Escandinavia | América del Sur | Australia
        de: Aus welcher Region stammt das Reisgericht Biryani? | Südasien | Skandinavien | Südamerika | Australien
        it: Da quale regione viene il biryani, un piatto di riso? | Asia meridionale | Scandinavia | Sud America | Australia
        pt: O biryani é um prato de arroz de qual região? | Sul da Ásia | Escandinávia | América do Sul | Austrália
        ja: 米料理ビリヤニはどの地域の料理？ | 南アジア | 北欧 | 南アメリカ | オーストラリア
        ko: 쌀 요리 비리야니는 어느 지역 음식일까요? | 남아시아 | 북유럽 | 남아메리카 | 오스트레일리아
        zh: 印度香饭（比尔亚尼）来自哪个地区？ | 南亚 | 北欧 | 南美洲 | 澳大利亚
        ar: البرياني طبق أرز من أي منطقة؟ | جنوب آسيا | إسكندنافيا | أمريكا الجنوبية | أستراليا

        # food.jollof food 3
        en: Jollof rice is a famous dish of which region? | West Africa | East Asia | Northern Europe | Central America
        fr: Le riz jollof est un plat célèbre de quelle région ? | L'Afrique de l'Ouest | L'Asie de l'Est | L'Europe du Nord | L'Amérique centrale
        es: ¿De qué región es famoso el arroz jollof? | África occidental | Asia oriental | Europa del Norte | Centroamérica
        de: Jollof-Reis ist ein berühmtes Gericht welcher Region? | Westafrika | Ostasien | Nordeuropa | Mittelamerika
        it: Il riso jollof è un piatto famoso di quale regione? | Africa occidentale | Asia orientale | Nord Europa | America centrale
        pt: O arroz jollof é um prato famoso de qual região? | África Ocidental | Ásia Oriental | Norte da Europa | América Central
        ja: ジョロフライスが有名なのはどの地域？ | 西アフリカ | 東アジア | 北ヨーロッパ | 中央アメリカ
        ko: 졸로프 라이스로 유명한 지역은? | 서아프리카 | 동아시아 | 북유럽 | 중앙아메리카
        zh: 乔洛夫饭是哪个地区的名菜？ | 西非 | 东亚 | 北欧 | 中美洲
        ar: أرز الجولوف طبق شهير في أي منطقة؟ | غرب أفريقيا | شرق آسيا | شمال أوروبا | أمريكا الوسطى

        # food.fusilli food 2
        en: Which of these is a type of pasta? | Fusilli | Paella | Burrito | Strudel
        fr: Lequel de ces mots désigne des pâtes ? | Fusilli | Paella | Burrito | Strudel
        es: ¿Cuál de estos es un tipo de pasta? | Fusilli | Paella | Burrito | Strudel
        de: Welches davon ist eine Nudelsorte? | Fusilli | Paella | Burrito | Strudel
        it: Quale di questi è un formato di pasta? | Fusilli | Paella | Burrito | Strudel
        pt: Qual destes é um tipo de massa? | Fusilli | Paella | Burrito | Strudel
        ja: この中でパスタの種類はどれ？ | フジッリ | パエリア | ブリトー | シュトゥルーデル
        ko: 다음 중 파스타의 한 종류는? | 푸실리 | 파에야 | 부리토 | 슈트루델
        zh: 下面哪个是意大利面的一种？ | 螺旋面 | 西班牙海鲜饭 | 墨西哥卷饼 | 苹果卷
        ar: أيّ هذه نوع من المعكرونة؟ | الفوسيلي | الباييلا | البوريتو | الشترودل

        # food.peanut food 3
        en: Botanically, what is a peanut? | A legume, like a bean | A tree nut | A root | A grain
        fr: Botaniquement, qu'est-ce qu'une cacahuète ? | Une légumineuse, comme le haricot | Un fruit à coque d'arbre | Une racine | Une céréale
        es: Botánicamente, ¿qué es un cacahuete? | Una legumbre, como la judía | Un fruto seco de árbol | Una raíz | Un cereal
        de: Was ist eine Erdnuss botanisch? | Eine Hülsenfrucht wie die Bohne | Eine Baumnuss | Eine Wurzel | Ein Getreide
        it: Dal punto di vista botanico, che cos'è un'arachide? | Un legume, come il fagiolo | Una noce d'albero | Una radice | Un cereale
        pt: Botanicamente, o que é o amendoim? | Uma leguminosa, como o feijão | Uma noz de árvore | Uma raiz | Um cereal
        ja: 植物学的には、ピーナッツは何のなかま？ | 豆類（マメ科） | 木の実 | 根 | 穀物
        ko: 식물학적으로 땅콩은 무엇일까요? | 콩과 식물의 열매 | 나무 열매(견과) | 뿌리 | 곡물
        zh: 从植物学上说，花生属于什么？ | 豆类 | 树坚果 | 根 | 谷物
        ar: من الناحية النباتية، ما الفول السوداني؟ | من البقوليات مثل الفاصوليا | جوز ينمو على الأشجار | جذر | حبوب

        # food.strawberry food 2
        en: Which fruit wears its seeds on the outside? | The strawberry | The banana | The mango | The grape
        fr: Quel fruit porte ses graines à l'extérieur ? | La fraise | La banane | La mangue | Le raisin
        es: ¿Qué fruta lleva sus semillas por fuera? | La fresa | El plátano | El mango | La uva
        de: Welche Frucht trägt ihre Samen außen? | Die Erdbeere | Die Banane | Die Mango | Die Weintraube
        it: Quale frutto porta i semi all'esterno? | La fragola | La banana | Il mango | L'uva
        pt: Que fruta tem as sementes do lado de fora? | O morango | A banana | A manga | A uva
        ja: 種が外側についている果物は？ | イチゴ | バナナ | マンゴー | ブドウ
        ko: 씨가 겉에 붙어 있는 과일은? | 딸기 | 바나나 | 망고 | 포도
        zh: 哪种水果的“籽”长在外面？ | 草莓 | 香蕉 | 芒果 | 葡萄
        ar: أي فاكهة تحمل بذورها على سطحها الخارجي؟ | الفراولة | الموز | المانجو | العنب

        # food.durian food 3
        en: Which fruit is famous for its very strong smell? | Durian | Lychee | Mango | Papaya
        fr: Quel fruit est célèbre pour son odeur très forte ? | Le durian | Le litchi | La mangue | La papaye
        es: ¿Qué fruta es famosa por su olor muy fuerte? | El durián | El lichi | El mango | La papaya
        de: Welche Frucht ist für ihren sehr starken Geruch bekannt? | Die Durian | Die Litschi | Die Mango | Die Papaya
        it: Quale frutto è famoso per il suo odore fortissimo? | Il durian | Il litchi | Il mango | La papaia
        pt: Que fruta é famosa pelo cheiro muito forte? | Durião | Lichia | Manga | Mamão
        ja: とても強いにおいで有名な果物は？ | ドリアン | ライチ | マンゴー | パパイヤ
        ko: 아주 강한 냄새로 유명한 과일은? | 두리안 | 리치 | 망고 | 파파야
        zh: 哪种水果以气味浓烈闻名？ | 榴莲 | 荔枝 | 芒果 | 木瓜
        ar: أي فاكهة تشتهر برائحتها القوية جدًا؟ | الدوريان | الليتشي | المانجو | البابايا

        # food.coconut food 2
        en: Which of these has water inside it you can drink? | A coconut | A walnut | An almond | A chestnut
        fr: Lequel contient une eau que l'on peut boire ? | La noix de coco | La noix | L'amande | La châtaigne
        es: ¿Cuál de estos tiene dentro agua que se puede beber? | El coco | La nuez | La almendra | La castaña
        de: Was davon enthält Wasser, das man trinken kann? | Die Kokosnuss | Die Walnuss | Die Mandel | Die Esskastanie
        it: Quale di questi contiene acqua che si può bere? | La noce di cocco | La noce | La mandorla | La castagna
        pt: Qual destes tem água dentro que dá para beber? | O coco | A noz | A amêndoa | A castanha
        ja: 中に飲める水が入っているのは？ | ココナッツ | クルミ | アーモンド | クリ
        ko: 안에 마실 수 있는 물이 들어 있는 것은? | 코코넛 | 호두 | 아몬드 | 밤
        zh: 下面哪个里面有可以喝的水？ | 椰子 | 核桃 | 杏仁 | 栗子
        ar: أيّ هذه يحتوي في داخله ماءً يمكن شربه؟ | جوز الهند | الجوز | اللوز | الكستناء

        # food.borscht food 2
        en: Borscht, a soup made red by beetroot, is famous in which region? | Eastern Europe | South Asia | West Africa | The Caribbean
        fr: Le bortsch, une soupe rouge à la betterave, est célèbre dans quelle région ? | L'Europe de l'Est | L'Asie du Sud | L'Afrique de l'Ouest | Les Caraïbes
        es: ¿En qué región es famoso el borsch, una sopa roja de remolacha? | Europa del Este | Asia del Sur | África occidental | El Caribe
        de: In welcher Region ist Borschtsch, eine rote Rote-Bete-Suppe, berühmt? | Osteuropa | Südasien | Westafrika | Karibik
        it: In quale regione è famoso il boršč, una zuppa rossa di barbabietola? | Europa orientale | Asia meridionale | Africa occidentale | Caraibi
        pt: Em que região é famoso o borscht, sopa vermelha de beterraba? | Leste Europeu | Sul da Ásia | África Ocidental | Caribe
        ja: ビーツで赤いスープ、ボルシチが有名な地域は？ | 東ヨーロッパ | 南アジア | 西アフリカ | カリブ海
        ko: 비트로 붉은 수프 보르시가 유명한 지역은? | 동유럽 | 남아시아 | 서아프리카 | 카리브해
        zh: 用甜菜做成的红色汤“罗宋汤”在哪个地区很有名？ | 东欧 | 南亚 | 西非 | 加勒比
        ar: البورش، حساء أحمر بالشمندر، يشتهر في أي منطقة؟ | أوروبا الشرقية | جنوب آسيا | غرب أفريقيا | الكاريبي
        """
}
