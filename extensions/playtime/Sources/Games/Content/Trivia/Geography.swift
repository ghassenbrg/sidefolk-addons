extension Games.QuizBank {
    // Geography: only facts that don't move (no populations, no capitals that changed or are changing).
    static let geography = """
        # geo.australia-capital geography 2
        en: What is the capital of Australia? | Canberra | Sydney | Melbourne | Perth
        fr: Quelle est la capitale de l'Australie ? | Canberra | Sydney | Melbourne | Perth
        es: ¿Cuál es la capital de Australia? | Canberra | Sídney | Melbourne | Perth
        de: Was ist die Hauptstadt Australiens? | Canberra | Sydney | Melbourne | Perth
        it: Qual è la capitale dell'Australia? | Canberra | Sydney | Melbourne | Perth
        pt: Qual é a capital da Austrália? | Camberra | Sydney | Melbourne | Perth
        ja: オーストラリアの首都は？ | キャンベラ | シドニー | メルボルン | パース
        ko: 오스트레일리아의 수도는? | 캔버라 | 시드니 | 멜버른 | 퍼스
        zh: 澳大利亚的首都是哪里？ | 堪培拉 | 悉尼 | 墨尔本 | 珀斯
        ar: ما عاصمة أستراليا؟ | كانبرا | سيدني | ملبورن | بيرث

        # geo.canada-capital geography 2
        en: What is the capital of Canada? | Ottawa | Toronto | Vancouver | Montreal
        fr: Quelle est la capitale du Canada ? | Ottawa | Toronto | Vancouver | Montréal
        es: ¿Cuál es la capital de Canadá? | Ottawa | Toronto | Vancouver | Montreal
        de: Was ist die Hauptstadt Kanadas? | Ottawa | Toronto | Vancouver | Montreal
        it: Qual è la capitale del Canada? | Ottawa | Toronto | Vancouver | Montréal
        pt: Qual é a capital do Canadá? | Ottawa | Toronto | Vancouver | Montreal
        ja: カナダの首都は？ | オタワ | トロント | バンクーバー | モントリオール
        ko: 캐나다의 수도는? | 오타와 | 토론토 | 밴쿠버 | 몬트리올
        zh: 加拿大的首都是哪里？ | 渥太华 | 多伦多 | 温哥华 | 蒙特利尔
        ar: ما عاصمة كندا؟ | أوتاوا | تورونتو | فانكوفر | مونتريال

        # geo.largest-ocean geography 1
        en: What is the largest ocean? | The Pacific | The Atlantic | The Indian Ocean | The Arctic
        fr: Quel est le plus grand océan ? | Le Pacifique | L'Atlantique | L'océan Indien | L'Arctique
        es: ¿Cuál es el océano más grande? | El Pacífico | El Atlántico | El Índico | El Ártico
        de: Welcher ist der größte Ozean? | Der Pazifik | Der Atlantik | Der Indische Ozean | Das Nordpolarmeer
        it: Qual è l'oceano più grande? | Il Pacifico | L'Atlantico | L'oceano Indiano | Il mar Glaciale Artico
        pt: Qual é o maior oceano? | O Pacífico | O Atlântico | O Índico | O Ártico
        ja: いちばん大きな海洋は？ | 太平洋 | 大西洋 | インド洋 | 北極海
        ko: 가장 큰 대양은? | 태평양 | 대서양 | 인도양 | 북극해
        zh: 最大的大洋是哪个？ | 太平洋 | 大西洋 | 印度洋 | 北冰洋
        ar: ما أكبر المحيطات؟ | المحيط الهادئ | المحيط الأطلسي | المحيط الهندي | المحيط المتجمد الشمالي

        # geo.smallest-country geography 1
        en: What is the smallest country in the world? | Vatican City | Monaco | San Marino | Malta
        fr: Quel est le plus petit pays du monde ? | Le Vatican | Monaco | Saint-Marin | Malte
        es: ¿Cuál es el país más pequeño del mundo? | El Vaticano | Mónaco | San Marino | Malta
        de: Was ist das kleinste Land der Welt? | Die Vatikanstadt | Monaco | San Marino | Malta
        it: Qual è lo Stato più piccolo del mondo? | La Città del Vaticano | Monaco | San Marino | Malta
        pt: Qual é o menor país do mundo? | O Vaticano | Mônaco | San Marino | Malta
        ja: 世界でいちばん小さな国は？ | バチカン市国 | モナコ | サンマリノ | マルタ
        ko: 세계에서 가장 작은 나라는? | 바티칸 시국 | 모나코 | 산마리노 | 몰타
        zh: 世界上最小的国家是哪个？ | 梵蒂冈 | 摩纳哥 | 圣马力诺 | 马耳他
        ar: ما أصغر دولة في العالم؟ | الفاتيكان | موناكو | سان مارينو | مالطا

        # geo.two-continents geography 2
        en: Which city lies on two continents? | Istanbul | Cairo | Athens | Rome
        fr: Quelle ville s'étend sur deux continents ? | Istanbul | Le Caire | Athènes | Rome
        es: ¿Qué ciudad está en dos continentes? | Estambul | El Cairo | Atenas | Roma
        de: Welche Stadt liegt auf zwei Kontinenten? | Istanbul | Kairo | Athen | Rom
        it: Quale città si trova su due continenti? | Istanbul | Il Cairo | Atene | Roma
        pt: Que cidade fica em dois continentes? | Istambul | Cairo | Atenas | Roma
        ja: 2つの大陸にまたがる都市は？ | イスタンブール | カイロ | アテネ | ローマ
        ko: 두 대륙에 걸쳐 있는 도시는? | 이스탄불 | 카이로 | 아테네 | 로마
        zh: 哪座城市横跨两个大洲？ | 伊斯坦布尔 | 开罗 | 雅典 | 罗马
        ar: أي مدينة تمتد على قارتين؟ | إسطنبول | القاهرة | أثينا | روما

        # geo.hot-desert geography 1
        en: What is the largest hot desert in the world? | The Sahara | The Gobi | The Kalahari | The Atacama
        fr: Quel est le plus grand désert chaud du monde ? | Le Sahara | Le désert de Gobi | Le Kalahari | L'Atacama
        es: ¿Cuál es el desierto cálido más grande del mundo? | El Sahara | El Gobi | El Kalahari | El Atacama
        de: Was ist die größte heiße Wüste der Welt? | Die Sahara | Die Gobi | Die Kalahari | Die Atacama
        it: Qual è il deserto caldo più grande del mondo? | Il Sahara | Il Gobi | Il Kalahari | L'Atacama
        pt: Qual é o maior deserto quente do mundo? | O Saara | O Gobi | O Kalahari | O Atacama
        ja: 世界最大の暑い砂漠は？ | サハラ砂漠 | ゴビ砂漠 | カラハリ砂漠 | アタカマ砂漠
        ko: 세계에서 가장 큰 더운 사막은? | 사하라 사막 | 고비 사막 | 칼라하리 사막 | 아타카마 사막
        zh: 世界上最大的热带沙漠是哪个？ | 撒哈拉沙漠 | 戈壁沙漠 | 卡拉哈里沙漠 | 阿塔卡马沙漠
        ar: ما أكبر صحراء حارة في العالم؟ | الصحراء الكبرى | صحراء غوبي | صحراء كالاهاري | صحراء أتاكاما

        # geo.everest-border geography 2
        en: Mount Everest stands on the border of Nepal and which country? | China | India | Bhutan | Pakistan
        fr: L'Everest se trouve à la frontière du Népal et de quel pays ? | La Chine | L'Inde | Le Bhoutan | Le Pakistan
        es: ¿Con qué país comparte Nepal la frontera donde está el Everest? | China | India | Bután | Pakistán
        de: Der Mount Everest liegt an der Grenze von Nepal und welchem Land? | China | Indien | Bhutan | Pakistan
        it: L'Everest si trova al confine tra il Nepal e quale Paese? | Cina | India | Bhutan | Pakistan
        pt: O Everest fica na fronteira do Nepal com qual país? | China | Índia | Butão | Paquistão
        ja: エベレストはネパールとどの国の国境にある？ | 中国 | インド | ブータン | パキスタン
        ko: 에베레스트산은 네팔과 어느 나라의 국경에 있을까요? | 중국 | 인도 | 부탄 | 파키스탄
        zh: 珠穆朗玛峰位于尼泊尔和哪个国家的边境上？ | 中国 | 印度 | 不丹 | 巴基斯坦
        ar: يقع جبل إيفرست على الحدود بين نيبال وأي دولة؟ | الصين | الهند | بوتان | باكستان

        # geo.south-america-river geography 1
        en: What is the longest river in South America? | The Amazon | The Orinoco | The Paraná | The Magdalena
        fr: Quel est le plus long fleuve d'Amérique du Sud ? | L'Amazone | L'Orénoque | Le Paraná | Le Magdalena
        es: ¿Cuál es el río más largo de América del Sur? | El Amazonas | El Orinoco | El Paraná | El Magdalena
        de: Welcher ist der längste Fluss Südamerikas? | Der Amazonas | Der Orinoco | Der Paraná | Der Magdalena
        it: Qual è il fiume più lungo del Sud America? | Il Rio delle Amazzoni | L'Orinoco | Il Paraná | Il Magdalena
        pt: Qual é o rio mais longo da América do Sul? | O Amazonas | O Orinoco | O Paraná | O Magdalena
        ja: 南アメリカでいちばん長い川は？ | アマゾン川 | オリノコ川 | パラナ川 | マグダレナ川
        ko: 남아메리카에서 가장 긴 강은? | 아마존강 | 오리노코강 | 파라나강 | 막달레나강
        zh: 南美洲最长的河流是哪条？ | 亚马孙河 | 奥里诺科河 | 巴拉那河 | 马格达莱纳河
        ar: ما أطول نهر في أمريكا الجنوبية؟ | الأمازون | أورينوكو | بارانا | ماغدالينا

        # geo.japan-capital geography 1
        en: What is the capital of Japan? | Tokyo | Kyoto | Osaka | Yokohama
        fr: Quelle est la capitale du Japon ? | Tokyo | Kyoto | Osaka | Yokohama
        es: ¿Cuál es la capital de Japón? | Tokio | Kioto | Osaka | Yokohama
        de: Was ist die Hauptstadt Japans? | Tokio | Kyoto | Osaka | Yokohama
        it: Qual è la capitale del Giappone? | Tokyo | Kyoto | Osaka | Yokohama
        pt: Qual é a capital do Japão? | Tóquio | Quioto | Osaka | Yokohama
        ja: 日本の首都は？ | 東京 | 京都 | 大阪 | 横浜
        ko: 일본의 수도는? | 도쿄 | 교토 | 오사카 | 요코하마
        zh: 日本的首都是哪里？ | 东京 | 京都 | 大阪 | 横滨
        ar: ما عاصمة اليابان؟ | طوكيو | كيوتو | أوساكا | يوكوهاما

        # geo.brazil-capital geography 2
        en: What is the capital of Brazil? | Brasília | Rio de Janeiro | São Paulo | Salvador
        fr: Quelle est la capitale du Brésil ? | Brasília | Rio de Janeiro | São Paulo | Salvador
        es: ¿Cuál es la capital de Brasil? | Brasilia | Río de Janeiro | São Paulo | Salvador
        de: Was ist die Hauptstadt Brasiliens? | Brasília | Rio de Janeiro | São Paulo | Salvador
        it: Qual è la capitale del Brasile? | Brasília | Rio de Janeiro | San Paolo | Salvador
        pt: Qual é a capital do Brasil? | Brasília | Rio de Janeiro | São Paulo | Salvador
        ja: ブラジルの首都は？ | ブラジリア | リオデジャネイロ | サンパウロ | サルバドール
        ko: 브라질의 수도는? | 브라질리아 | 리우데자네이루 | 상파울루 | 사우바도르
        zh: 巴西的首都是哪里？ | 巴西利亚 | 里约热内卢 | 圣保罗 | 萨尔瓦多
        ar: ما عاصمة البرازيل؟ | برازيليا | ريو دي جانيرو | ساو باولو | سلفادور

        # geo.largest-country geography 1
        en: Which is the largest country by area? | Russia | Canada | China | The United States
        fr: Quel est le plus grand pays par sa superficie ? | La Russie | Le Canada | La Chine | Les États-Unis
        es: ¿Cuál es el país más grande por superficie? | Rusia | Canadá | China | Estados Unidos
        de: Welches Land hat die größte Fläche? | Russland | Kanada | China | Die USA
        it: Qual è il Paese più grande per superficie? | La Russia | Il Canada | La Cina | Gli Stati Uniti
        pt: Qual é o maior país em área? | Rússia | Canadá | China | Estados Unidos
        ja: 面積がいちばん大きな国は？ | ロシア | カナダ | 中国 | アメリカ合衆国
        ko: 면적이 가장 넓은 나라는? | 러시아 | 캐나다 | 중국 | 미국
        zh: 面积最大的国家是哪个？ | 俄罗斯 | 加拿大 | 中国 | 美国
        ar: ما أكبر دولة من حيث المساحة؟ | روسيا | كندا | الصين | الولايات المتحدة

        # geo.nile-continent geography 1
        en: The Nile flows through which continent? | Africa | Asia | Europe | South America
        fr: Sur quel continent coule le Nil ? | L'Afrique | L'Asie | L'Europe | L'Amérique du Sud
        es: ¿Por qué continente fluye el Nilo? | África | Asia | Europa | América del Sur
        de: Durch welchen Kontinent fließt der Nil? | Afrika | Asien | Europa | Südamerika
        it: In quale continente scorre il Nilo? | Africa | Asia | Europa | Sud America
        pt: Por qual continente corre o Nilo? | África | Ásia | Europa | América do Sul
        ja: ナイル川が流れる大陸は？ | アフリカ | アジア | ヨーロッパ | 南アメリカ
        ko: 나일강이 흐르는 대륙은? | 아프리카 | 아시아 | 유럽 | 남아메리카
        zh: 尼罗河流经哪个大洲？ | 非洲 | 亚洲 | 欧洲 | 南美洲
        ar: في أي قارة يجري نهر النيل؟ | أفريقيا | آسيا | أوروبا | أمريكا الجنوبية

        # geo.kilimanjaro geography 2
        en: Mount Kilimanjaro is in which country? | Tanzania | Kenya | Uganda | Ethiopia
        fr: Dans quel pays se trouve le Kilimandjaro ? | La Tanzanie | Le Kenya | L'Ouganda | L'Éthiopie
        es: ¿En qué país está el Kilimanjaro? | Tanzania | Kenia | Uganda | Etiopía
        de: In welchem Land liegt der Kilimandscharo? | Tansania | Kenia | Uganda | Äthiopien
        it: In quale Paese si trova il Kilimangiaro? | Tanzania | Kenya | Uganda | Etiopia
        pt: Em que país fica o Kilimanjaro? | Tanzânia | Quênia | Uganda | Etiópia
        ja: キリマンジャロがある国は？ | タンザニア | ケニア | ウガンダ | エチオピア
        ko: 킬리만자로산이 있는 나라는? | 탄자니아 | 케냐 | 우간다 | 에티오피아
        zh: 乞力马扎罗山在哪个国家？ | 坦桑尼亚 | 肯尼亚 | 乌干达 | 埃塞俄比亚
        ar: في أي دولة يقع جبل كليمنجارو؟ | تنزانيا | كينيا | أوغندا | إثيوبيا

        # geo.barrier-reef geography 1
        en: The Great Barrier Reef lies off the coast of which country? | Australia | Brazil | Mexico | Indonesia
        fr: La Grande Barrière de corail longe la côte de quel pays ? | L'Australie | Le Brésil | Le Mexique | L'Indonésie
        es: ¿Frente a la costa de qué país está la Gran Barrera de Coral? | Australia | Brasil | México | Indonesia
        de: Vor der Küste welches Landes liegt das Great Barrier Reef? | Australien | Brasilien | Mexiko | Indonesien
        it: La Grande barriera corallina si trova al largo di quale Paese? | Australia | Brasile | Messico | Indonesia
        pt: A Grande Barreira de Corais fica na costa de qual país? | Austrália | Brasil | México | Indonésia
        ja: グレート・バリア・リーフがあるのはどの国の沖？ | オーストラリア | ブラジル | メキシコ | インドネシア
        ko: 그레이트배리어리프는 어느 나라 해안에 있을까요? | 오스트레일리아 | 브라질 | 멕시코 | 인도네시아
        zh: 大堡礁位于哪个国家的海岸外？ | 澳大利亚 | 巴西 | 墨西哥 | 印度尼西亚
        ar: قبالة ساحل أي دولة يقع الحاجز المرجاني العظيم؟ | أستراليا | البرازيل | المكسيك | إندونيسيا

        # geo.panama-canal geography 2
        en: The Panama Canal links which two oceans? | Atlantic and Pacific | Atlantic and Indian | Pacific and Arctic | Indian and Pacific
        fr: Le canal de Panama relie quels océans ? | Atlantique et Pacifique | Atlantique et Indien | Pacifique et Arctique | Indien et Pacifique
        es: ¿Qué océanos une el canal de Panamá? | Atlántico y Pacífico | Atlántico e Índico | Pacífico y Ártico | Índico y Pacífico
        de: Welche Ozeane verbindet der Panamakanal? | Atlantik und Pazifik | Atlantik und Indik | Pazifik und Nordpolarmeer | Indik und Pazifik
        it: Quali oceani collega il canale di Panama? | Atlantico e Pacifico | Atlantico e Indiano | Pacifico e Artico | Indiano e Pacifico
        pt: Quais oceanos o canal do Panamá liga? | Atlântico e Pacífico | Atlântico e Índico | Pacífico e Ártico | Índico e Pacífico
        ja: パナマ運河が結ぶ2つの海洋は？ | 大西洋と太平洋 | 大西洋とインド洋 | 太平洋と北極海 | インド洋と太平洋
        ko: 파나마 운하가 잇는 두 대양은? | 대서양과 태평양 | 대서양과 인도양 | 태평양과 북극해 | 인도양과 태평양
        zh: 巴拿马运河连接哪两个大洋？ | 大西洋和太平洋 | 大西洋和印度洋 | 太平洋和北冰洋 | 印度洋和太平洋
        ar: أي محيطين تربط قناة بنما؟ | الأطلسي والهادئ | الأطلسي والهندي | الهادئ والمتجمد الشمالي | الهندي والهادئ

        # geo.boot-shape geography 1
        en: Which country is shaped like a boot? | Italy | Greece | Portugal | Chile
        fr: Quel pays a la forme d'une botte ? | L'Italie | La Grèce | Le Portugal | Le Chili
        es: ¿Qué país tiene forma de bota? | Italia | Grecia | Portugal | Chile
        de: Welches Land hat die Form eines Stiefels? | Italien | Griechenland | Portugal | Chile
        it: Quale Paese ha la forma di uno stivale? | L'Italia | La Grecia | Il Portogallo | Il Cile
        pt: Que país tem forma de bota? | Itália | Grécia | Portugal | Chile
        ja: ブーツのような形をした国は？ | イタリア | ギリシャ | ポルトガル | チリ
        ko: 장화 모양으로 생긴 나라는? | 이탈리아 | 그리스 | 포르투갈 | 칠레
        zh: 哪个国家的形状像一只靴子？ | 意大利 | 希腊 | 葡萄牙 | 智利
        ar: أي دولة شكلها مثل الحذاء الطويل؟ | إيطاليا | اليونان | البرتغال | تشيلي

        # geo.egypt-capital geography 1
        en: What is the capital of Egypt? | Cairo | Alexandria | Luxor | Giza
        fr: Quelle est la capitale de l'Égypte ? | Le Caire | Alexandrie | Louxor | Gizeh
        es: ¿Cuál es la capital de Egipto? | El Cairo | Alejandría | Luxor | Guiza
        de: Was ist die Hauptstadt Ägyptens? | Kairo | Alexandria | Luxor | Gizeh
        it: Qual è la capitale dell'Egitto? | Il Cairo | Alessandria | Luxor | Giza
        pt: Qual é a capital do Egito? | Cairo | Alexandria | Luxor | Gizé
        ja: エジプトの首都は？ | カイロ | アレクサンドリア | ルクソール | ギザ
        ko: 이집트의 수도는? | 카이로 | 알렉산드리아 | 룩소르 | 기자
        zh: 埃及的首都是哪里？ | 开罗 | 亚历山大 | 卢克索 | 吉萨
        ar: ما عاصمة مصر؟ | القاهرة | الإسكندرية | الأقصر | الجيزة

        # geo.korea-capital geography 1
        en: What is the capital of South Korea? | Seoul | Busan | Incheon | Daegu
        fr: Quelle est la capitale de la Corée du Sud ? | Séoul | Busan | Incheon | Daegu
        es: ¿Cuál es la capital de Corea del Sur? | Seúl | Busan | Incheon | Daegu
        de: Was ist die Hauptstadt Südkoreas? | Seoul | Busan | Incheon | Daegu
        it: Qual è la capitale della Corea del Sud? | Seul | Busan | Incheon | Daegu
        pt: Qual é a capital da Coreia do Sul? | Seul | Busan | Incheon | Daegu
        ja: 韓国の首都は？ | ソウル | 釜山 | 仁川 | 大邱
        ko: 대한민국의 수도는? | 서울 | 부산 | 인천 | 대구
        zh: 韩国的首都是哪里？ | 首尔 | 釜山 | 仁川 | 大邱
        ar: ما عاصمة كوريا الجنوبية؟ | سيول | بوسان | إنتشون | دايغو

        # geo.china-capital geography 1
        en: What is the capital of China? | Beijing | Shanghai | Guangzhou | Shenzhen
        fr: Quelle est la capitale de la Chine ? | Pékin | Shanghai | Canton | Shenzhen
        es: ¿Cuál es la capital de China? | Pekín | Shanghái | Cantón | Shenzhen
        de: Was ist die Hauptstadt Chinas? | Peking | Shanghai | Guangzhou | Shenzhen
        it: Qual è la capitale della Cina? | Pechino | Shanghai | Canton | Shenzhen
        pt: Qual é a capital da China? | Pequim | Xangai | Cantão | Shenzhen
        ja: 中国の首都は？ | 北京 | 上海 | 広州 | 深圳
        ko: 중국의 수도는? | 베이징 | 상하이 | 광저우 | 선전
        zh: 中国的首都是哪里？ | 北京 | 上海 | 广州 | 深圳
        ar: ما عاصمة الصين؟ | بكين | شانغهاي | قوانغتشو | شنجن

        # geo.argentina-capital geography 2
        en: What is the capital of Argentina? | Buenos Aires | Santiago | Montevideo | Lima
        fr: Quelle est la capitale de l'Argentine ? | Buenos Aires | Santiago | Montevideo | Lima
        es: ¿Cuál es la capital de Argentina? | Buenos Aires | Santiago | Montevideo | Lima
        de: Was ist die Hauptstadt Argentiniens? | Buenos Aires | Santiago | Montevideo | Lima
        it: Qual è la capitale dell'Argentina? | Buenos Aires | Santiago | Montevideo | Lima
        pt: Qual é a capital da Argentina? | Buenos Aires | Santiago | Montevidéu | Lima
        ja: アルゼンチンの首都は？ | ブエノスアイレス | サンティアゴ | モンテビデオ | リマ
        ko: 아르헨티나의 수도는? | 부에노스아이레스 | 산티아고 | 몬테비데오 | 리마
        zh: 阿根廷的首都是哪里？ | 布宜诺斯艾利斯 | 圣地亚哥 | 蒙得维的亚 | 利马
        ar: ما عاصمة الأرجنتين؟ | بوينس آيرس | سانتياغو | مونتيفيديو | ليما

        # geo.mexico-capital geography 1
        en: What is the capital of Mexico? | Mexico City | Guadalajara | Cancún | Monterrey
        fr: Quelle est la capitale du Mexique ? | Mexico | Guadalajara | Cancún | Monterrey
        es: ¿Cuál es la capital de México? | Ciudad de México | Guadalajara | Cancún | Monterrey
        de: Was ist die Hauptstadt Mexikos? | Mexiko-Stadt | Guadalajara | Cancún | Monterrey
        it: Qual è la capitale del Messico? | Città del Messico | Guadalajara | Cancún | Monterrey
        pt: Qual é a capital do México? | Cidade do México | Guadalajara | Cancún | Monterrey
        ja: メキシコの首都は？ | メキシコシティ | グアダラハラ | カンクン | モンテレイ
        ko: 멕시코의 수도는? | 멕시코시티 | 과달라하라 | 칸쿤 | 몬테레이
        zh: 墨西哥的首都是哪里？ | 墨西哥城 | 瓜达拉哈拉 | 坎昆 | 蒙特雷
        ar: ما عاصمة المكسيك؟ | مكسيكو سيتي | غوادالاخارا | كانكون | مونتيري

        # geo.india-capital geography 2
        en: What is the capital of India? | New Delhi | Mumbai | Kolkata | Bengaluru
        fr: Quelle est la capitale de l'Inde ? | New Delhi | Bombay | Calcutta | Bangalore
        es: ¿Cuál es la capital de la India? | Nueva Delhi | Bombay | Calcuta | Bangalore
        de: Was ist die Hauptstadt Indiens? | Neu-Delhi | Mumbai | Kolkata | Bengaluru
        it: Qual è la capitale dell'India? | Nuova Delhi | Mumbai | Calcutta | Bangalore
        pt: Qual é a capital da Índia? | Nova Délhi | Mumbai | Calcutá | Bangalore
        ja: インドの首都は？ | ニューデリー | ムンバイ | コルカタ | ベンガルール
        ko: 인도의 수도는? | 뉴델리 | 뭄바이 | 콜카타 | 벵갈루루
        zh: 印度的首都是哪里？ | 新德里 | 孟买 | 加尔各答 | 班加罗尔
        ar: ما عاصمة الهند؟ | نيودلهي | مومباي | كولكاتا | بنغالور

        # geo.dead-sea geography 3
        en: The lowest dry land on Earth is on the shore of which sea? | The Dead Sea | The Caspian Sea | The Red Sea | The Aral Sea
        fr: Le point le plus bas des terres émergées est au bord de quelle mer ? | La mer Morte | La mer Caspienne | La mer Rouge | La mer d'Aral
        es: ¿A orillas de qué mar está el punto más bajo de tierra firme? | El mar Muerto | El mar Caspio | El mar Rojo | El mar de Aral
        de: Am Ufer welches Meeres liegt die tiefste Landstelle der Erde? | Totes Meer | Kaspisches Meer | Rotes Meer | Aralsee
        it: Il punto più basso delle terre emerse è sulla riva di quale mare? | Il mar Morto | Il mar Caspio | Il mar Rosso | Il lago d'Aral
        pt: O ponto mais baixo em terra firme fica às margens de qual mar? | O mar Morto | O mar Cáspio | O mar Vermelho | O mar de Aral
        ja: 陸地でいちばん低い場所はどの海（湖）のほとり？ | 死海 | カスピ海 | 紅海 | アラル海
        ko: 육지에서 가장 낮은 곳은 어느 바다의 기슭에 있을까요? | 사해 | 카스피해 | 홍해 | 아랄해
        zh: 地球陆地的最低点在哪个海的岸边？ | 死海 | 里海 | 红海 | 咸海
        ar: على شاطئ أي بحر تقع أخفض بقعة يابسة على الأرض؟ | البحر الميت | بحر قزوين | البحر الأحمر | بحر آرال

        # geo.highest-mountain geography 1
        en: What is the highest mountain above sea level? | Mount Everest | K2 | Kilimanjaro | Mont Blanc
        fr: Quelle est la plus haute montagne au-dessus du niveau de la mer ? | L'Everest | Le K2 | Le Kilimandjaro | Le mont Blanc
        es: ¿Cuál es la montaña más alta sobre el nivel del mar? | El Everest | El K2 | El Kilimanjaro | El Mont Blanc
        de: Welcher ist der höchste Berg über dem Meeresspiegel? | Mount Everest | K2 | Kilimandscharo | Mont Blanc
        it: Qual è la montagna più alta sul livello del mare? | L'Everest | Il K2 | Il Kilimangiaro | Il Monte Bianco
        pt: Qual é a montanha mais alta acima do nível do mar? | O Everest | O K2 | O Kilimanjaro | O Monte Branco
        ja: 海抜でいちばん高い山は？ | エベレスト | K2 | キリマンジャロ | モンブラン
        ko: 해발 고도가 가장 높은 산은? | 에베레스트산 | K2 | 킬리만자로산 | 몽블랑
        zh: 海拔最高的山是哪座？ | 珠穆朗玛峰 | 乔戈里峰（K2） | 乞力马扎罗山 | 勃朗峰
        ar: ما أعلى جبل فوق مستوى سطح البحر؟ | إيفرست | كي 2 | كليمنجارو | مون بلان

        # geo.largest-island geography 2
        en: What is the largest island in the world (not counting Australia)? | Greenland | New Guinea | Borneo | Madagascar
        fr: Quelle est la plus grande île du monde (sans compter l'Australie) ? | Le Groenland | La Nouvelle-Guinée | Bornéo | Madagascar
        es: ¿Cuál es la isla más grande del mundo (sin contar Australia)? | Groenlandia | Nueva Guinea | Borneo | Madagascar
        de: Was ist die größte Insel der Welt (Australien nicht mitgezählt)? | Grönland | Neuguinea | Borneo | Madagaskar
        it: Qual è l'isola più grande del mondo (senza contare l'Australia)? | La Groenlandia | La Nuova Guinea | Il Borneo | Il Madagascar
        pt: Qual é a maior ilha do mundo (sem contar a Austrália)? | Groenlândia | Nova Guiné | Bornéu | Madagascar
        ja: オーストラリアを除いて、世界でいちばん大きな島は？ | グリーンランド | ニューギニア島 | ボルネオ島 | マダガスカル島
        ko: 오스트레일리아를 빼면 세계에서 가장 큰 섬은? | 그린란드 | 뉴기니섬 | 보르네오섬 | 마다가스카르섬
        zh: 不算澳大利亚，世界上最大的岛是哪个？ | 格陵兰岛 | 新几内亚岛 | 婆罗洲 | 马达加斯加岛
        ar: ما أكبر جزيرة في العالم (من دون أستراليا)؟ | غرينلاند | غينيا الجديدة | بورنيو | مدغشقر

        # geo.amazon-country geography 2
        en: Most of the Amazon rainforest is in which country? | Brazil | Peru | Colombia | Venezuela
        fr: La plus grande partie de la forêt amazonienne se trouve dans quel pays ? | Le Brésil | Le Pérou | La Colombie | Le Venezuela
        es: ¿En qué país está la mayor parte de la selva amazónica? | Brasil | Perú | Colombia | Venezuela
        de: In welchem Land liegt der größte Teil des Amazonas-Regenwalds? | Brasilien | Peru | Kolumbien | Venezuela
        it: In quale Paese si trova la maggior parte della foresta amazzonica? | Brasile | Perù | Colombia | Venezuela
        pt: Em que país fica a maior parte da Floresta Amazônica? | Brasil | Peru | Colômbia | Venezuela
        ja: アマゾンの熱帯雨林の大部分がある国は？ | ブラジル | ペルー | コロンビア | ベネズエラ
        ko: 아마존 열대 우림의 대부분은 어느 나라에 있을까요? | 브라질 | 페루 | 콜롬비아 | 베네수엘라
        zh: 亚马孙雨林的大部分在哪个国家？ | 巴西 | 秘鲁 | 哥伦比亚 | 委内瑞拉
        ar: في أي دولة يقع معظم غابات الأمازون المطيرة؟ | البرازيل | بيرو | كولومبيا | فنزويلا

        # geo.niagara geography 1
        en: Niagara Falls lies on the border between Canada and which country? | The United States | Mexico | Cuba | Brazil
        fr: Les chutes du Niagara sont à la frontière entre le Canada et quel pays ? | Les États-Unis | Le Mexique | Cuba | Le Brésil
        es: ¿Entre Canadá y qué país están las cataratas del Niágara? | Estados Unidos | México | Cuba | Brasil
        de: Die Niagarafälle liegen an der Grenze zwischen Kanada und welchem Land? | Den USA | Mexiko | Kuba | Brasilien
        it: Le cascate del Niagara si trovano al confine tra il Canada e quale Paese? | Gli Stati Uniti | Il Messico | Cuba | Il Brasile
        pt: As cataratas do Niágara ficam na fronteira entre o Canadá e qual país? | Estados Unidos | México | Cuba | Brasil
        ja: ナイアガラの滝はカナダとどの国の国境にある？ | アメリカ合衆国 | メキシコ | キューバ | ブラジル
        ko: 나이아가라 폭포는 캐나다와 어느 나라의 국경에 있을까요? | 미국 | 멕시코 | 쿠바 | 브라질
        zh: 尼亚加拉瀑布位于加拿大和哪个国家的边境？ | 美国 | 墨西哥 | 古巴 | 巴西
        ar: تقع شلالات نياغرا على الحدود بين كندا وأي دولة؟ | الولايات المتحدة | المكسيك | كوبا | البرازيل

        # geo.kenya-capital geography 2
        en: What is the capital of Kenya? | Nairobi | Mombasa | Kampala | Addis Ababa
        fr: Quelle est la capitale du Kenya ? | Nairobi | Mombasa | Kampala | Addis-Abeba
        es: ¿Cuál es la capital de Kenia? | Nairobi | Mombasa | Kampala | Adís Abeba
        de: Was ist die Hauptstadt Kenias? | Nairobi | Mombasa | Kampala | Addis Abeba
        it: Qual è la capitale del Kenya? | Nairobi | Mombasa | Kampala | Addis Abeba
        pt: Qual é a capital do Quênia? | Nairóbi | Mombaça | Kampala | Adis Abeba
        ja: ケニアの首都は？ | ナイロビ | モンバサ | カンパラ | アディスアベバ
        ko: 케냐의 수도는? | 나이로비 | 몸바사 | 캄팔라 | 아디스아바바
        zh: 肯尼亚的首都是哪里？ | 内罗毕 | 蒙巴萨 | 坎帕拉 | 亚的斯亚贝巴
        ar: ما عاصمة كينيا؟ | نيروبي | مومباسا | كمبالا | أديس أبابا

        # geo.nigeria-capital geography 3
        en: What is the capital of Nigeria? | Abuja | Lagos | Accra | Kano
        fr: Quelle est la capitale du Nigeria ? | Abuja | Lagos | Accra | Kano
        es: ¿Cuál es la capital de Nigeria? | Abuya | Lagos | Acra | Kano
        de: Was ist die Hauptstadt Nigerias? | Abuja | Lagos | Accra | Kano
        it: Qual è la capitale della Nigeria? | Abuja | Lagos | Accra | Kano
        pt: Qual é a capital da Nigéria? | Abuja | Lagos | Acra | Kano
        ja: ナイジェリアの首都は？ | アブジャ | ラゴス | アクラ | カノ
        ko: 나이지리아의 수도는? | 아부자 | 라고스 | 아크라 | 카노
        zh: 尼日利亚的首都是哪里？ | 阿布贾 | 拉各斯 | 阿克拉 | 卡诺
        ar: ما عاصمة نيجيريا؟ | أبوجا | لاغوس | أكرا | كانو

        # geo.new-zealand-capital geography 3
        en: What is the capital of New Zealand? | Wellington | Auckland | Christchurch | Queenstown
        fr: Quelle est la capitale de la Nouvelle-Zélande ? | Wellington | Auckland | Christchurch | Queenstown
        es: ¿Cuál es la capital de Nueva Zelanda? | Wellington | Auckland | Christchurch | Queenstown
        de: Was ist die Hauptstadt Neuseelands? | Wellington | Auckland | Christchurch | Queenstown
        it: Qual è la capitale della Nuova Zelanda? | Wellington | Auckland | Christchurch | Queenstown
        pt: Qual é a capital da Nova Zelândia? | Wellington | Auckland | Christchurch | Queenstown
        ja: ニュージーランドの首都は？ | ウェリントン | オークランド | クライストチャーチ | クイーンズタウン
        ko: 뉴질랜드의 수도는? | 웰링턴 | 오클랜드 | 크라이스트처치 | 퀸스타운
        zh: 新西兰的首都是哪里？ | 惠灵顿 | 奥克兰 | 基督城 | 皇后镇
        ar: ما عاصمة نيوزيلندا؟ | ويلينغتون | أوكلاند | كرايستشيرش | كوينزتاون

        # geo.vietnam-capital geography 3
        en: What is the capital of Vietnam? | Hanoi | Ho Chi Minh City | Da Nang | Hue
        fr: Quelle est la capitale du Viêt Nam ? | Hanoï | Hô Chi Minh-Ville | Da Nang | Hué
        es: ¿Cuál es la capital de Vietnam? | Hanói | Ciudad Ho Chi Minh | Da Nang | Hue
        de: Was ist die Hauptstadt Vietnams? | Hanoi | Ho-Chi-Minh-Stadt | Da Nang | Huế
        it: Qual è la capitale del Vietnam? | Hanoi | Città di Ho Chi Minh | Da Nang | Huế
        pt: Qual é a capital do Vietnã? | Hanói | Cidade de Ho Chi Minh | Da Nang | Hue
        ja: ベトナムの首都は？ | ハノイ | ホーチミン | ダナン | フエ
        ko: 베트남의 수도는? | 하노이 | 호찌민 | 다낭 | 후에
        zh: 越南的首都是哪里？ | 河内 | 胡志明市 | 岘港 | 顺化
        ar: ما عاصمة فيتنام؟ | هانوي | مدينة هو تشي منه | دا نانغ | هوي

        # geo.machu-picchu geography 2
        en: Machu Picchu is in which country? | Peru | Mexico | Bolivia | Chile
        fr: Dans quel pays se trouve le Machu Picchu ? | Le Pérou | Le Mexique | La Bolivie | Le Chili
        es: ¿En qué país está Machu Picchu? | Perú | México | Bolivia | Chile
        de: In welchem Land liegt Machu Picchu? | Peru | Mexiko | Bolivien | Chile
        it: In quale Paese si trova Machu Picchu? | Perù | Messico | Bolivia | Cile
        pt: Em que país fica Machu Picchu? | Peru | México | Bolívia | Chile
        ja: マチュ・ピチュがある国は？ | ペルー | メキシコ | ボリビア | チリ
        ko: 마추픽추가 있는 나라는? | 페루 | 멕시코 | 볼리비아 | 칠레
        zh: 马丘比丘在哪个国家？ | 秘鲁 | 墨西哥 | 玻利维亚 | 智利
        ar: في أي دولة تقع ماتشو بيتشو؟ | بيرو | المكسيك | بوليفيا | تشيلي

        # geo.thailand-capital geography 2
        en: What is the capital of Thailand? | Bangkok | Phuket | Chiang Mai | Pattaya
        fr: Quelle est la capitale de la Thaïlande ? | Bangkok | Phuket | Chiang Mai | Pattaya
        es: ¿Cuál es la capital de Tailandia? | Bangkok | Phuket | Chiang Mai | Pattaya
        de: Was ist die Hauptstadt Thailands? | Bangkok | Phuket | Chiang Mai | Pattaya
        it: Qual è la capitale della Thailandia? | Bangkok | Phuket | Chiang Mai | Pattaya
        pt: Qual é a capital da Tailândia? | Bangkok | Phuket | Chiang Mai | Pattaya
        ja: タイの首都は？ | バンコク | プーケット | チェンマイ | パタヤ
        ko: 태국의 수도는? | 방콕 | 푸껫 | 치앙마이 | 파타야
        zh: 泰国的首都是哪里？ | 曼谷 | 普吉 | 清迈 | 芭堤雅
        ar: ما عاصمة تايلاند؟ | بانكوك | بوكيت | تشيانغ ماي | باتايا

        # geo.ecuador geography 2
        en: Which country takes its name from the equator? | Ecuador | Colombia | Kenya | Gabon
        fr: Quel pays doit son nom à l'équateur ? | L'Équateur | La Colombie | Le Kenya | Le Gabon
        es: ¿Qué país toma su nombre de la línea del ecuador? | Ecuador | Colombia | Kenia | Gabón
        de: Welches Land ist nach dem Äquator benannt? | Ecuador | Kolumbien | Kenia | Gabun
        it: Quale Paese prende il nome dall'equatore? | L'Ecuador | La Colombia | Il Kenya | Il Gabon
        pt: Que país tem o nome da linha do equador? | Equador | Colômbia | Quênia | Gabão
        ja: 国名がスペイン語の「赤道」に由来する国は？ | エクアドル | コロンビア | ケニア | ガボン
        ko: 나라 이름이 스페인어로 '적도'라는 뜻인 나라는? | 에콰도르 | 콜롬비아 | 케냐 | 가봉
        zh: 哪个国家的名字来自“赤道”一词？ | 厄瓜多尔 | 哥伦比亚 | 肯尼亚 | 加蓬
        ar: أي دولة سُمّيت باسم خط الاستواء؟ | الإكوادور | كولومبيا | كينيا | الغابون

        # geo.reykjavik geography 2
        en: Reykjavík is the capital of which country? | Iceland | Norway | Finland | Ireland
        fr: Reykjavik est la capitale de quel pays ? | L'Islande | La Norvège | La Finlande | L'Irlande
        es: ¿De qué país es capital Reikiavik? | Islandia | Noruega | Finlandia | Irlanda
        de: Reykjavík ist die Hauptstadt welches Landes? | Island | Norwegen | Finnland | Irland
        it: Reykjavík è la capitale di quale Paese? | Islanda | Norvegia | Finlandia | Irlanda
        pt: Reykjavík é a capital de qual país? | Islândia | Noruega | Finlândia | Irlanda
        ja: レイキャビクはどの国の首都？ | アイスランド | ノルウェー | フィンランド | アイルランド
        ko: 레이캬비크는 어느 나라의 수도일까요? | 아이슬란드 | 노르웨이 | 핀란드 | 아일랜드
        zh: 雷克雅未克是哪个国家的首都？ | 冰岛 | 挪威 | 芬兰 | 爱尔兰
        ar: ريكيافيك عاصمة أي دولة؟ | آيسلندا | النرويج | فنلندا | أيرلندا

        # geo.coldest-continent geography 1
        en: Which continent is the coldest? | Antarctica | Asia | Europe | North America
        fr: Quel est le continent le plus froid ? | L'Antarctique | L'Asie | L'Europe | L'Amérique du Nord
        es: ¿Cuál es el continente más frío? | La Antártida | Asia | Europa | América del Norte
        de: Welcher Kontinent ist der kälteste? | Die Antarktis | Asien | Europa | Nordamerika
        it: Qual è il continente più freddo? | L'Antartide | L'Asia | L'Europa | Il Nord America
        pt: Qual é o continente mais frio? | A Antártida | A Ásia | A Europa | A América do Norte
        ja: いちばん寒い大陸は？ | 南極大陸 | アジア | ヨーロッパ | 北アメリカ
        ko: 가장 추운 대륙은? | 남극 대륙 | 아시아 | 유럽 | 북아메리카
        zh: 最冷的大洲是哪个？ | 南极洲 | 亚洲 | 欧洲 | 北美洲
        ar: ما أبرد قارة؟ | القارة القطبية الجنوبية | آسيا | أوروبا | أمريكا الشمالية

        # geo.caspian geography 3
        en: What is the largest inland body of water by area? | The Caspian Sea | Lake Superior | Lake Victoria | Lake Baikal
        fr: Quelle est la plus grande étendue d'eau intérieure par sa superficie ? | La mer Caspienne | Le lac Supérieur | Le lac Victoria | Le lac Baïkal
        es: ¿Cuál es la masa de agua interior más grande por superficie? | El mar Caspio | El lago Superior | El lago Victoria | El lago Baikal
        de: Welches Binnengewässer hat die größte Fläche? | Das Kaspische Meer | Der Obere See | Der Victoriasee | Der Baikalsee
        it: Qual è la più grande distesa d'acqua interna per superficie? | Il mar Caspio | Il lago Superiore | Il lago Vittoria | Il lago Bajkal
        pt: Qual é a maior massa de água interior em área? | O mar Cáspio | O lago Superior | O lago Vitória | O lago Baikal
        ja: 面積がいちばん大きな内陸の水域は？ | カスピ海 | スペリオル湖 | ビクトリア湖 | バイカル湖
        ko: 면적이 가장 넓은 내륙 수역은? | 카스피해 | 슈피리어호 | 빅토리아호 | 바이칼호
        zh: 面积最大的内陆水域是哪个？ | 里海 | 苏必利尔湖 | 维多利亚湖 | 贝加尔湖
        ar: ما أكبر مسطّح مائي داخلي من حيث المساحة؟ | بحر قزوين | بحيرة سوبيريور | بحيرة فيكتوريا | بحيرة بايكال

        # geo.deepest-lake geography 3
        en: What is the deepest lake in the world? | Lake Baikal | Lake Tanganyika | Lake Superior | Lake Titicaca
        fr: Quel est le lac le plus profond du monde ? | Le lac Baïkal | Le lac Tanganyika | Le lac Supérieur | Le lac Titicaca
        es: ¿Cuál es el lago más profundo del mundo? | El lago Baikal | El lago Tanganica | El lago Superior | El lago Titicaca
        de: Welcher ist der tiefste See der Welt? | Der Baikalsee | Der Tanganjikasee | Der Obere See | Der Titicacasee
        it: Qual è il lago più profondo del mondo? | Il lago Bajkal | Il lago Tanganica | Il lago Superiore | Il lago Titicaca
        pt: Qual é o lago mais profundo do mundo? | O lago Baikal | O lago Tanganica | O lago Superior | O lago Titicaca
        ja: 世界でいちばん深い湖は？ | バイカル湖 | タンガニーカ湖 | スペリオル湖 | チチカカ湖
        ko: 세계에서 가장 깊은 호수는? | 바이칼호 | 탕가니카호 | 슈피리어호 | 티티카카호
        zh: 世界上最深的湖是哪个？ | 贝加尔湖 | 坦噶尼喀湖 | 苏必利尔湖 | 的的喀喀湖
        ar: ما أعمق بحيرة في العالم؟ | بحيرة بايكال | بحيرة تنجانيقا | بحيرة سوبيريور | بحيرة تيتيكاكا

        # geo.longest-range geography 2
        en: What is the longest mountain range on land? | The Andes | The Himalayas | The Rocky Mountains | The Alps
        fr: Quelle est la plus longue chaîne de montagnes terrestre ? | Les Andes | L'Himalaya | Les Rocheuses | Les Alpes
        es: ¿Cuál es la cordillera terrestre más larga? | Los Andes | El Himalaya | Las Montañas Rocosas | Los Alpes
        de: Welches ist das längste Gebirge an Land? | Die Anden | Der Himalaya | Die Rocky Mountains | Die Alpen
        it: Qual è la catena montuosa terrestre più lunga? | Le Ande | L'Himalaya | Le Montagne Rocciose | Le Alpi
        pt: Qual é a cordilheira terrestre mais longa? | Os Andes | O Himalaia | As Montanhas Rochosas | Os Alpes
        ja: 陸上でいちばん長い山脈は？ | アンデス山脈 | ヒマラヤ山脈 | ロッキー山脈 | アルプス山脈
        ko: 육지에서 가장 긴 산맥은? | 안데스산맥 | 히말라야산맥 | 로키산맥 | 알프스산맥
        zh: 陆地上最长的山脉是哪条？ | 安第斯山脉 | 喜马拉雅山脉 | 落基山脉 | 阿尔卑斯山脉
        ar: ما أطول سلسلة جبال على اليابسة؟ | جبال الأنديز | جبال الهيمالايا | جبال روكي | جبال الألب

        # geo.honshu geography 2
        en: Honshu and Hokkaido are islands of which country? | Japan | The Philippines | Indonesia | South Korea
        fr: Honshu et Hokkaido sont des îles de quel pays ? | Le Japon | Les Philippines | L'Indonésie | La Corée du Sud
        es: ¿De qué país son las islas Honshu y Hokkaido? | Japón | Filipinas | Indonesia | Corea del Sur
        de: Honshu und Hokkaido sind Inseln welches Landes? | Japan | Philippinen | Indonesien | Südkorea
        it: Honshu e Hokkaido sono isole di quale Paese? | Giappone | Filippine | Indonesia | Corea del Sud
        pt: Honshu e Hokkaido são ilhas de qual país? | Japão | Filipinas | Indonésia | Coreia do Sul
        ja: 本州と北海道はどの国の島？ | 日本 | フィリピン | インドネシア | 韓国
        ko: 혼슈와 홋카이도는 어느 나라의 섬일까요? | 일본 | 필리핀 | 인도네시아 | 한국
        zh: 本州和北海道是哪个国家的岛屿？ | 日本 | 菲律宾 | 印度尼西亚 | 韩国
        ar: هونشو وهوكايدو جزيرتان في أي دولة؟ | اليابان | الفلبين | إندونيسيا | كوريا الجنوبية
        """
}
