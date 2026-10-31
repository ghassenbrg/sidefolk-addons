extension Games.QuizBank {
    static let nature = """
        # nat.largest-animal nature 1
        en: What is the largest animal alive today? | The blue whale | The African elephant | The whale shark | The giraffe
        fr: Quel est le plus grand animal vivant aujourd'hui ? | La baleine bleue | L'éléphant d'Afrique | Le requin-baleine | La girafe
        es: ¿Cuál es el animal vivo más grande? | La ballena azul | El elefante africano | El tiburón ballena | La jirafa
        de: Welches ist das größte heute lebende Tier? | Der Blauwal | Der Afrikanische Elefant | Der Walhai | Die Giraffe
        it: Qual è il più grande animale vivente? | La balenottera azzurra | L'elefante africano | Lo squalo balena | La giraffa
        pt: Qual é o maior animal vivo hoje? | A baleia-azul | O elefante-africano | O tubarão-baleia | A girafa
        ja: 今生きている動物でいちばん大きいのは？ | シロナガスクジラ | アフリカゾウ | ジンベエザメ | キリン
        ko: 오늘날 살아 있는 가장 큰 동물은? | 대왕고래 | 아프리카코끼리 | 고래상어 | 기린
        zh: 现存最大的动物是什么？ | 蓝鲸 | 非洲象 | 鲸鲨 | 长颈鹿
        ar: ما أكبر حيوان يعيش اليوم؟ | الحوت الأزرق | الفيل الأفريقي | القرش الحوتي | الزرافة

        # nat.octopus-hearts nature 2
        *: 3 | 1 | 2 | 8
        en: How many hearts does an octopus have?
        fr: Combien de cœurs une pieuvre a-t-elle ?
        es: ¿Cuántos corazones tiene un pulpo?
        de: Wie viele Herzen hat ein Oktopus?
        it: Quanti cuori ha un polpo?
        pt: Quantos corações tem um polvo?
        ja: タコの心臓はいくつ？
        ko: 문어의 심장은 몇 개일까요?
        zh: 章鱼有几颗心脏？
        ar: كم قلبًا للأخطبوط؟

        # nat.fastest-land nature 1
        en: What is the fastest land animal? | The cheetah | The lion | The horse | The greyhound
        fr: Quel est l'animal terrestre le plus rapide ? | Le guépard | Le lion | Le cheval | Le lévrier
        es: ¿Cuál es el animal terrestre más rápido? | El guepardo | El león | El caballo | El galgo
        de: Welches ist das schnellste Landtier? | Der Gepard | Der Löwe | Das Pferd | Der Windhund
        it: Qual è l'animale terrestre più veloce? | Il ghepardo | Il leone | Il cavallo | Il levriero
        pt: Qual é o animal terrestre mais rápido? | O guepardo | O leão | O cavalo | O galgo
        ja: 陸上でいちばん速い動物は？ | チーター | ライオン | ウマ | グレイハウンド
        ko: 땅 위에서 가장 빠른 동물은? | 치타 | 사자 | 말 | 그레이하운드
        zh: 陆地上跑得最快的动物是什么？ | 猎豹 | 狮子 | 马 | 灵缇犬
        ar: ما أسرع حيوان بري؟ | الفهد الصياد | الأسد | الحصان | السلوقي

        # nat.tallest-animal nature 1
        en: What is the tallest animal? | The giraffe | The elephant | The camel | The ostrich
        fr: Quel est l'animal le plus grand en hauteur ? | La girafe | L'éléphant | Le chameau | L'autruche
        es: ¿Cuál es el animal más alto? | La jirafa | El elefante | El camello | El avestruz
        de: Welches ist das höchste Tier? | Die Giraffe | Der Elefant | Das Kamel | Der Strauß
        it: Qual è l'animale più alto? | La giraffa | L'elefante | Il cammello | Lo struzzo
        pt: Qual é o animal mais alto? | A girafa | O elefante | O camelo | O avestruz
        ja: いちばん背の高い動物は？ | キリン | ゾウ | ラクダ | ダチョウ
        ko: 키가 가장 큰 동물은? | 기린 | 코끼리 | 낙타 | 타조
        zh: 最高的动物是什么？ | 长颈鹿 | 大象 | 骆驼 | 鸵鸟
        ar: ما أطول حيوان؟ | الزرافة | الفيل | الجمل | النعامة

        # nat.spider-legs nature 1
        *: 8 | 6 | 10 | 12
        en: How many legs does a spider have?
        fr: Combien de pattes une araignée a-t-elle ?
        es: ¿Cuántas patas tiene una araña?
        de: Wie viele Beine hat eine Spinne?
        it: Quante zampe ha un ragno?
        pt: Quantas pernas tem uma aranha?
        ja: クモの脚は何本？
        ko: 거미의 다리는 몇 개일까요?
        zh: 蜘蛛有几条腿？
        ar: كم رجلًا للعنكبوت؟

        # nat.insect-legs nature 1
        *: 6 | 4 | 8 | 10
        en: How many legs does an insect have?
        fr: Combien de pattes un insecte a-t-il ?
        es: ¿Cuántas patas tiene un insecto?
        de: Wie viele Beine hat ein Insekt?
        it: Quante zampe ha un insetto?
        pt: Quantas pernas tem um inseto?
        ja: 昆虫の脚は何本？
        ko: 곤충의 다리는 몇 개일까요?
        zh: 昆虫有几条腿？
        ar: كم رجلًا للحشرة؟

        # nat.bat-mammal nature 2
        en: Which of these animals is a mammal? | The bat | The penguin | The shark | The crocodile
        fr: Lequel de ces animaux est un mammifère ? | La chauve-souris | Le manchot | Le requin | Le crocodile
        es: ¿Cuál de estos animales es un mamífero? | El murciélago | El pingüino | El tiburón | El cocodrilo
        de: Welches dieser Tiere ist ein Säugetier? | Die Fledermaus | Der Pinguin | Der Hai | Das Krokodil
        it: Quale di questi animali è un mammifero? | Il pipistrello | Il pinguino | Lo squalo | Il coccodrillo
        pt: Qual destes animais é um mamífero? | O morcego | O pinguim | O tubarão | O crocodilo
        ja: この中で哺乳類はどれ？ | コウモリ | ペンギン | サメ | ワニ
        ko: 다음 중 포유류는? | 박쥐 | 펭귄 | 상어 | 악어
        zh: 下面哪种动物是哺乳动物？ | 蝙蝠 | 企鹅 | 鲨鱼 | 鳄鱼
        ar: أيّ هذه الحيوانات من الثدييات؟ | الخفاش | البطريق | القرش | التمساح

        # nat.flightless nature 1
        en: Which of these birds cannot fly? | The penguin | The eagle | The swallow | The parrot
        fr: Lequel de ces oiseaux ne sait pas voler ? | Le manchot | L'aigle | L'hirondelle | Le perroquet
        es: ¿Cuál de estas aves no puede volar? | El pingüino | El águila | La golondrina | El loro
        de: Welcher dieser Vögel kann nicht fliegen? | Der Pinguin | Der Adler | Die Schwalbe | Der Papagei
        it: Quale di questi uccelli non sa volare? | Il pinguino | L'aquila | La rondine | Il pappagallo
        pt: Qual destas aves não consegue voar? | O pinguim | A águia | A andorinha | O papagaio
        ja: この中で空を飛べない鳥は？ | ペンギン | ワシ | ツバメ | オウム
        ko: 다음 중 날지 못하는 새는? | 펭귄 | 독수리 | 제비 | 앵무새
        zh: 下面哪种鸟不会飞？ | 企鹅 | 鹰 | 燕子 | 鹦鹉
        ar: أيّ هذه الطيور لا يستطيع الطيران؟ | البطريق | النسر | السنونو | الببغاء

        # nat.tadpole nature 1
        en: What is a young frog called? | A tadpole | A caterpillar | A cub | A foal
        fr: Comment appelle-t-on le petit de la grenouille ? | Un têtard | Une chenille | Un lionceau | Un poulain
        es: ¿Cómo se llama la cría de la rana? | Renacuajo | Oruga | Cachorro | Potro
        de: Wie nennt man einen jungen Frosch? | Kaulquappe | Raupe | Welpe | Fohlen
        it: Come si chiama il piccolo della rana? | Girino | Bruco | Cucciolo | Puledro
        pt: Como se chama o filhote de sapo e de rã? | Girino | Lagarta | Filhote de leão | Potro
        ja: カエルの子どもの名前は？ | オタマジャクシ | イモムシ | 子グマ | 子ウマ
        ko: 개구리의 새끼를 무엇이라고 할까요? | 올챙이 | 애벌레 | 강아지 | 망아지
        zh: 青蛙的幼体叫什么？ | 蝌蚪 | 毛毛虫 | 幼崽 | 小马驹
        ar: ماذا يُسمّى صغير الضفدع؟ | الشرغوف (أبو ذنيبة) | اليرقة | الشبل | المهر

        # nat.caterpillar nature 1
        en: What does a caterpillar turn into? | A butterfly or a moth | A frog | A snail | A spider
        fr: En quoi une chenille se transforme-t-elle ? | En papillon | En grenouille | En escargot | En araignée
        es: ¿En qué se convierte una oruga? | En mariposa o polilla | En rana | En caracol | En araña
        de: Was wird aus einer Raupe? | Ein Schmetterling | Ein Frosch | Eine Schnecke | Eine Spinne
        it: In che cosa si trasforma un bruco? | In una farfalla | In una rana | In una lumaca | In un ragno
        pt: Em que uma lagarta se transforma? | Em borboleta ou mariposa | Em sapo | Em caracol | Em aranha
        ja: イモムシは何になる？ | チョウやガ | カエル | カタツムリ | クモ
        ko: 애벌레는 자라서 무엇이 될까요? | 나비나 나방 | 개구리 | 달팽이 | 거미
        zh: 毛毛虫会变成什么？ | 蝴蝶或蛾 | 青蛙 | 蜗牛 | 蜘蛛
        ar: إلى ماذا تتحوّل اليرقة (الدودة)؟ | فراشة أو عثّة | ضفدع | حلزون | عنكبوت

        # nat.honey nature 1
        en: What do bees make from flower nectar? | Honey | Silk | Milk | Pearls
        fr: Que fabriquent les abeilles avec le nectar des fleurs ? | Du miel | De la soie | Du lait | Des perles
        es: ¿Qué hacen las abejas con el néctar de las flores? | Miel | Seda | Leche | Perlas
        de: Was machen Bienen aus Blütennektar? | Honig | Seide | Milch | Perlen
        it: Che cosa producono le api dal nettare dei fiori? | Miele | Seta | Latte | Perle
        pt: O que as abelhas fazem com o néctar das flores? | Mel | Seda | Leite | Pérolas
        ja: ミツバチが花の蜜からつくるものは？ | はちみつ | 絹 | 牛乳 | 真珠
        ko: 꿀벌이 꽃의 꿀물로 만드는 것은? | 꿀 | 비단 | 우유 | 진주
        zh: 蜜蜂用花蜜酿造什么？ | 蜂蜜 | 丝绸 | 牛奶 | 珍珠
        ar: ماذا يصنع النحل من رحيق الأزهار؟ | العسل | الحرير | الحليب | اللؤلؤ

        # nat.silk nature 2
        en: Most silk fabric comes from which creature? | The silkworm | The spider | The bee | The snail
        fr: La plupart des tissus de soie viennent de quelle créature ? | Le ver à soie | L'araignée | L'abeille | L'escargot
        es: ¿De qué animal viene la mayor parte de la tela de seda? | El gusano de seda | La araña | La abeja | El caracol
        de: Von welchem Tier stammt der meiste Seidenstoff? | Von der Seidenraupe | Von der Spinne | Von der Biene | Von der Schnecke
        it: Da quale animale viene la maggior parte del tessuto di seta? | Il baco da seta | Il ragno | L'ape | La lumaca
        pt: De que animal vem a maior parte do tecido de seda? | Bicho-da-seda | Aranha | Abelha | Caracol
        ja: 絹の布のほとんどは何からとれる？ | カイコ | クモ | ハチ | カタツムリ
        ko: 비단 옷감은 대부분 어떤 생물에서 얻을까요? | 누에 | 거미 | 벌 | 달팽이
        zh: 大部分丝绸来自哪种生物？ | 蚕 | 蜘蛛 | 蜜蜂 | 蜗牛
        ar: من أي كائن يأتي معظم قماش الحرير؟ | دودة القز | العنكبوت | النحلة | الحلزون

        # nat.kangaroos nature 1
        en: Which country is home to most of the world's kangaroos? | Australia | South Africa | Brazil | India
        fr: Quel pays abrite la plupart des kangourous du monde ? | L'Australie | L'Afrique du Sud | Le Brésil | L'Inde
        es: ¿En qué país vive la mayoría de los canguros del mundo? | Australia | Sudáfrica | Brasil | India
        de: In welchem Land leben die meisten Kängurus der Welt? | Australien | Südafrika | Brasilien | Indien
        it: In quale Paese vive la maggior parte dei canguri del mondo? | Australia | Sudafrica | Brasile | India
        pt: Em que país vive a maioria dos cangurus do mundo? | Austrália | África do Sul | Brasil | Índia
        ja: 世界のカンガルーのほとんどがすんでいる国は？ | オーストラリア | 南アフリカ | ブラジル | インド
        ko: 세계 캥거루 대부분이 사는 나라는? | 오스트레일리아 | 남아프리카 공화국 | 브라질 | 인도
        zh: 世界上大多数袋鼠生活在哪个国家？ | 澳大利亚 | 南非 | 巴西 | 印度
        ar: في أي دولة يعيش معظم الكناغر في العالم؟ | أستراليا | جنوب أفريقيا | البرازيل | الهند

        # nat.panda-food nature 1
        en: What do giant pandas mostly eat? | Bamboo | Fish | Honey | Grass
        fr: Que mangent surtout les pandas géants ? | Du bambou | Du poisson | Du miel | De l'herbe
        es: ¿Qué comen sobre todo los pandas gigantes? | Bambú | Pescado | Miel | Hierba
        de: Was fressen Große Pandas hauptsächlich? | Bambus | Fisch | Honig | Gras
        it: Che cosa mangiano soprattutto i panda giganti? | Bambù | Pesce | Miele | Erba
        pt: O que os pandas-gigantes comem principalmente? | Bambu | Peixe | Mel | Capim
        ja: ジャイアントパンダがおもに食べるものは？ | 竹 | 魚 | はちみつ | 草
        ko: 대왕판다가 주로 먹는 것은? | 대나무 | 물고기 | 꿀 | 풀
        zh: 大熊猫主要吃什么？ | 竹子 | 鱼 | 蜂蜜 | 青草
        ar: ماذا تأكل الباندا العملاقة في الغالب؟ | الخيزران | السمك | العسل | العشب

        # nat.chlorophyll nature 2
        en: What gives leaves their green colour? | Chlorophyll | Carotene | Melanin | Haemoglobin
        fr: Qu'est-ce qui donne aux feuilles leur couleur verte ? | La chlorophylle | Le carotène | La mélanine | L'hémoglobine
        es: ¿Qué da a las hojas su color verde? | La clorofila | El caroteno | La melanina | La hemoglobina
        de: Was gibt Blättern ihre grüne Farbe? | Chlorophyll | Carotin | Melanin | Hämoglobin
        it: Che cosa dà alle foglie il loro colore verde? | La clorofilla | Il carotene | La melanina | L'emoglobina
        pt: O que dá às folhas a cor verde? | A clorofila | O caroteno | A melanina | A hemoglobina
        ja: 葉を緑色にしているものは？ | クロロフィル（葉緑素） | カロテン | メラニン | ヘモグロビン
        ko: 잎을 초록색으로 만드는 것은? | 엽록소 | 카로틴 | 멜라닌 | 헤모글로빈
        zh: 是什么让树叶呈现绿色？ | 叶绿素 | 胡萝卜素 | 黑色素 | 血红蛋白
        ar: ما الذي يعطي الأوراق لونها الأخضر؟ | الكلوروفيل (اليخضور) | الكاروتين | الميلانين | الهيموغلوبين

        # nat.largest-bird nature 2
        en: What is the largest living bird? | The ostrich | The emu | The albatross | The condor
        fr: Quel est le plus grand oiseau vivant ? | L'autruche | L'émeu | L'albatros | Le condor
        es: ¿Cuál es el ave viva más grande? | El avestruz | El emú | El albatros | El cóndor
        de: Welches ist der größte lebende Vogel? | Der Strauß | Der Emu | Der Albatros | Der Kondor
        it: Qual è il più grande uccello vivente? | Lo struzzo | L'emù | L'albatro | Il condor
        pt: Qual é a maior ave viva? | O avestruz | A ema-australiana (emu) | O albatroz | O condor
        ja: 今いる鳥でいちばん大きいのは？ | ダチョウ | エミュー | アホウドリ | コンドル
        ko: 현재 살아 있는 가장 큰 새는? | 타조 | 에뮤 | 앨버트로스 | 콘도르
        zh: 现存最大的鸟是什么？ | 鸵鸟 | 鸸鹋 | 信天翁 | 秃鹰
        ar: ما أكبر طائر يعيش اليوم؟ | النعامة | الإيمو | القطرس | الكندور

        # nat.whale-lungs nature 2
        en: Whales breathe air with what? | Lungs | Gills | Their skin | Their fins
        fr: Les baleines respirent l'air avec quoi ? | Des poumons | Des branchies | Leur peau | Leurs nageoires
        es: ¿Con qué respiran aire las ballenas? | Con pulmones | Con branquias | Con la piel | Con las aletas
        de: Womit atmen Wale Luft? | Mit Lungen | Mit Kiemen | Mit der Haut | Mit den Flossen
        it: Con che cosa respirano l'aria le balene? | Con i polmoni | Con le branchie | Con la pelle | Con le pinne
        pt: Com o que as baleias respiram ar? | Pulmões | Brânquias | A pele | As nadadeiras
        ja: クジラは何を使って空気を呼吸する？ | 肺 | えら | 皮膚 | ひれ
        ko: 고래는 무엇으로 공기를 숨 쉴까요? | 폐 | 아가미 | 피부 | 지느러미
        zh: 鲸用什么呼吸空气？ | 肺 | 鳃 | 皮肤 | 鳍
        ar: بماذا تتنفّس الحيتان الهواء؟ | بالرئتين | بالخياشيم | بالجلد | بالزعانف

        # nat.koala-food nature 2
        en: Koalas eat mostly the leaves of which tree? | Eucalyptus | Bamboo | Oak | Pine
        fr: Les koalas mangent surtout les feuilles de quel arbre ? | L'eucalyptus | Le bambou | Le chêne | Le pin
        es: ¿De qué árbol comen sobre todo las hojas los koalas? | Eucalipto | Bambú | Roble | Pino
        de: Die Blätter welches Baumes fressen Koalas hauptsächlich? | Eukalyptus | Bambus | Eiche | Kiefer
        it: Di quale albero mangiano soprattutto le foglie i koala? | Eucalipto | Bambù | Quercia | Pino
        pt: Os coalas comem principalmente as folhas de qual árvore? | Eucalipto | Bambu | Carvalho | Pinheiro
        ja: コアラがおもに食べるのはどの木の葉？ | ユーカリ | 竹 | オーク | マツ
        ko: 코알라가 주로 먹는 것은 어떤 나무의 잎일까요? | 유칼립투스 | 대나무 | 참나무 | 소나무
        zh: 考拉主要吃哪种树的叶子？ | 桉树 | 竹子 | 橡树 | 松树
        ar: أوراق أي شجرة يأكلها الكوالا في الغالب؟ | الكينا (الأوكالبتوس) | الخيزران | البلوط | الصنوبر

        # nat.camel-hump nature 2
        en: What does a camel store in its hump? | Fat | Water | Milk | Air
        fr: Que stocke le chameau dans sa bosse ? | De la graisse | De l'eau | Du lait | De l'air
        es: ¿Qué almacena el camello en su joroba? | Grasa | Agua | Leche | Aire
        de: Was speichert ein Kamel in seinem Höcker? | Fett | Wasser | Milch | Luft
        it: Che cosa immagazzina il cammello nella gobba? | Grasso | Acqua | Latte | Aria
        pt: O que o camelo guarda na corcova? | Gordura | Água | Leite | Ar
        ja: ラクダがこぶにたくわえているものは？ | 脂肪 | 水 | 乳 | 空気
        ko: 낙타가 혹에 저장하는 것은? | 지방 | 물 | 젖 | 공기
        zh: 骆驼的驼峰里储存的是什么？ | 脂肪 | 水 | 奶 | 空气
        ar: ماذا يخزّن الجمل في سنامه؟ | الدهون | الماء | الحليب | الهواء

        # nat.night-hunter nature 1
        en: Which bird is famous for hunting at night? | The owl | The eagle | The swan | The parrot
        fr: Quel oiseau est célèbre pour chasser la nuit ? | La chouette | L'aigle | Le cygne | Le perroquet
        es: ¿Qué ave es famosa por cazar de noche? | El búho | El águila | El cisne | El loro
        de: Welcher Vogel ist dafür bekannt, nachts zu jagen? | Die Eule | Der Adler | Der Schwan | Der Papagei
        it: Quale uccello è famoso per cacciare di notte? | Il gufo | L'aquila | Il cigno | Il pappagallo
        pt: Que ave é famosa por caçar à noite? | A coruja | A águia | O cisne | O papagaio
        ja: 夜に狩りをすることで有名な鳥は？ | フクロウ | ワシ | ハクチョウ | オウム
        ko: 밤에 사냥하는 것으로 유명한 새는? | 올빼미 | 독수리 | 백조 | 앵무새
        zh: 哪种鸟以夜间捕猎闻名？ | 猫头鹰 | 鹰 | 天鹅 | 鹦鹉
        ar: أي طائر يشتهر بالصيد في الليل؟ | البومة | النسر | البجعة | الببغاء

        # nat.chameleon nature 1
        en: Which animal is famous for changing colour? | The chameleon | The giraffe | The zebra | The hippo
        fr: Quel animal est célèbre pour changer de couleur ? | Le caméléon | La girafe | Le zèbre | L'hippopotame
        es: ¿Qué animal es famoso por cambiar de color? | El camaleón | La jirafa | La cebra | El hipopótamo
        de: Welches Tier ist dafür bekannt, seine Farbe zu wechseln? | Das Chamäleon | Die Giraffe | Das Zebra | Das Nilpferd
        it: Quale animale è famoso per cambiare colore? | Il camaleonte | La giraffa | La zebra | L'ippopotamo
        pt: Que animal é famoso por mudar de cor? | O camaleão | A girafa | A zebra | O hipopótamo
        ja: 体の色を変えることで有名な動物は？ | カメレオン | キリン | シマウマ | カバ
        ko: 몸 색깔을 바꾸는 것으로 유명한 동물은? | 카멜레온 | 기린 | 얼룩말 | 하마
        zh: 哪种动物以会变色闻名？ | 变色龙 | 长颈鹿 | 斑马 | 河马
        ar: أي حيوان يشتهر بتغيير لونه؟ | الحرباء | الزرافة | الحمار الوحشي | فرس النهر

        # nat.sloth nature 2
        en: Which tree-dwelling animal is known for moving very slowly? | The sloth | The monkey | The squirrel | The gibbon
        fr: Quel animal des arbres est connu pour sa grande lenteur ? | Le paresseux | Le singe | L'écureuil | Le gibbon
        es: ¿Qué animal de los árboles es conocido por moverse muy despacio? | El perezoso | El mono | La ardilla | El gibón
        de: Welches Baumtier ist für seine große Langsamkeit bekannt? | Das Faultier | Der Affe | Das Eichhörnchen | Der Gibbon
        it: Quale animale degli alberi è noto per la sua lentezza? | Il bradipo | La scimmia | Lo scoiattolo | Il gibbone
        pt: Que animal das árvores é conhecido por se mover bem devagar? | A preguiça | O macaco | O esquilo | O gibão
        ja: 木の上でとてもゆっくり動くことで知られる動物は？ | ナマケモノ | サル | リス | テナガザル
        ko: 나무 위에서 아주 느리게 움직이는 것으로 유명한 동물은? | 나무늘보 | 원숭이 | 다람쥐 | 긴팔원숭이
        zh: 哪种树栖动物以动作极慢闻名？ | 树懒 | 猴子 | 松鼠 | 长臂猿
        ar: أي حيوان يعيش على الأشجار يشتهر بالحركة البطيئة جدًا؟ | الكسلان | القرد | السنجاب | الجبون

        # nat.tree-rings nature 2
        en: Counting the rings in a tree trunk tells you the tree's what? | Age | Height | Weight | Species
        fr: Compter les cernes d'un tronc indique quoi de l'arbre ? | Son âge | Sa hauteur | Son poids | Son espèce
        es: Contar los anillos del tronco de un árbol indica su… | Edad | Altura | Peso | Especie
        de: Was verraten die Jahresringe eines Baumstamms? | Das Alter | Die Höhe | Das Gewicht | Die Art
        it: Contare gli anelli del tronco di un albero rivela il suo… | Età | Altezza | Peso | Specie
        pt: Contar os anéis do tronco de uma árvore revela a sua… | Idade | Altura | Peso | Espécie
        ja: 木の幹の年輪を数えるとわかるのは？ | 年齢 | 高さ | 重さ | 種類
        ko: 나무줄기의 나이테를 세면 알 수 있는 것은? | 나이 | 높이 | 무게 | 종류
        zh: 数树干的年轮可以知道树的什么？ | 年龄 | 高度 | 重量 | 种类
        ar: عدّ الحلقات في جذع الشجرة يخبرك بماذا؟ | عمرها | طولها | وزنها | نوعها

        # nat.cactus nature 1
        en: Which plant stores water in a thick stem and grows in deserts? | The cactus | The fern | Moss | The water lily
        fr: Quelle plante stocke l'eau dans une tige épaisse et pousse dans le désert ? | Le cactus | La fougère | La mousse | Le nénuphar
        es: ¿Qué planta guarda agua en un tallo grueso y crece en el desierto? | El cactus | El helecho | El musgo | El nenúfar
        de: Welche Pflanze speichert Wasser in einem dicken Stamm und wächst in Wüsten? | Der Kaktus | Der Farn | Das Moos | Die Seerose
        it: Quale pianta conserva l'acqua in un fusto spesso e cresce nel deserto? | Il cactus | La felce | Il muschio | La ninfea
        pt: Que planta guarda água num caule grosso e cresce no deserto? | O cacto | A samambaia | O musgo | A vitória-régia
        ja: 太い茎に水をたくわえ、砂漠で育つ植物は？ | サボテン | シダ | コケ | スイレン
        ko: 두꺼운 줄기에 물을 저장하고 사막에서 자라는 식물은? | 선인장 | 고사리 | 이끼 | 수련
        zh: 哪种植物在粗茎里储水并生长在沙漠中？ | 仙人掌 | 蕨类 | 苔藓 | 睡莲
        ar: أي نبات يخزّن الماء في ساق سميكة وينمو في الصحراء؟ | الصبّار | السرخس | الطحلب | زنبق الماء

        # nat.trunk nature 1
        en: An elephant's trunk is actually which body part? | Its nose | A tooth | Its tongue | An ear
        fr: La trompe de l'éléphant est en fait quelle partie du corps ? | Le nez | Une dent | La langue | Une oreille
        es: ¿Qué parte del cuerpo es en realidad la trompa del elefante? | La nariz | Un diente | La lengua | Una oreja
        de: Welcher Körperteil ist der Rüssel eines Elefanten eigentlich? | Die Nase | Ein Zahn | Die Zunge | Ein Ohr
        it: Che parte del corpo è in realtà la proboscide dell'elefante? | Il naso | Un dente | La lingua | Un orecchio
        pt: Que parte do corpo é, na verdade, a tromba do elefante? | O nariz | Um dente | A língua | Uma orelha
        ja: ゾウの長い鼻は、体のどの部分？ | 鼻 | 歯 | 舌 | 耳
        ko: 코끼리의 긴 코는 몸의 어느 부분일까요? | 코 | 이빨 | 혀 | 귀
        zh: 大象的长鼻子其实是身体的哪个部位？ | 鼻子 | 牙齿 | 舌头 | 耳朵
        ar: خرطوم الفيل هو في الحقيقة أي جزء من الجسم؟ | الأنف | سنّ | اللسان | أذن

        # nat.tusks nature 3
        en: What are an elephant's tusks, really? | Teeth | Horns | Bones | Claws
        fr: Que sont en réalité les défenses de l'éléphant ? | Des dents | Des cornes | Des os | Des griffes
        es: ¿Qué son en realidad los colmillos del elefante? | Dientes | Cuernos | Huesos | Garras
        de: Was sind die Stoßzähne eines Elefanten eigentlich? | Zähne | Hörner | Knochen | Krallen
        it: Che cosa sono in realtà le zanne dell'elefante? | Denti | Corna | Ossa | Artigli
        pt: O que são, na verdade, as presas do elefante? | Dentes | Chifres | Ossos | Garras
        ja: ゾウの牙は、じつは何が長くのびたもの？ | 歯 | 角 | 骨 | 爪
        ko: 코끼리의 상아는 사실 무엇이 길게 자란 것일까요? | 이빨 | 뿔 | 뼈 | 발톱
        zh: 象牙其实是什么长长了？ | 牙齿 | 角 | 骨头 | 爪子
        ar: ما أنياب الفيل في الحقيقة؟ | أسنان | قرون | عظام | مخالب

        # nat.starfish-arms nature 2
        *: 5 | 4 | 6 | 8
        en: How many arms do most starfish have?
        fr: Combien de bras ont la plupart des étoiles de mer ?
        es: ¿Cuántos brazos tienen la mayoría de las estrellas de mar?
        de: Wie viele Arme haben die meisten Seesterne?
        it: Quante braccia hanno quasi tutte le stelle marine?
        pt: Quantos braços tem a maioria das estrelas-do-mar?
        ja: ほとんどのヒトデの腕は何本？
        ko: 대부분의 불가사리는 팔이 몇 개일까요?
        zh: 大多数海星有几条腕？
        ar: كم ذراعًا لمعظم نجوم البحر؟

        # nat.shark-skeleton nature 3
        en: What is a shark's skeleton made of? | Cartilage | Bone | Shell | Wood-like fibre
        fr: De quoi est fait le squelette d'un requin ? | De cartilage | D'os | De coquille | De fibres
        es: ¿De qué está hecho el esqueleto de un tiburón? | De cartílago | De hueso | De concha | De fibras
        de: Woraus besteht das Skelett eines Hais? | Aus Knorpel | Aus Knochen | Aus Schale | Aus Fasern
        it: Di che cosa è fatto lo scheletro di uno squalo? | Di cartilagine | Di osso | Di conchiglia | Di fibre
        pt: De que é feito o esqueleto de um tubarão? | De cartilagem | De osso | De concha | De fibras
        ja: サメの骨格は何でできている？ | 軟骨 | 硬い骨 | 殻 | 繊維
        ko: 상어의 뼈대는 무엇으로 이루어져 있을까요? | 연골 | 단단한 뼈 | 껍데기 | 섬유
        zh: 鲨鱼的骨骼是由什么构成的？ | 软骨 | 硬骨 | 甲壳 | 纤维
        ar: مِمّ يتكوّن هيكل القرش العظمي؟ | الغضاريف | العظام | الصدف | الألياف

        # nat.backwards-bird nature 2
        en: Which bird can fly backwards? | The hummingbird | The sparrow | The pigeon | The crow
        fr: Quel oiseau peut voler en arrière ? | Le colibri | Le moineau | Le pigeon | Le corbeau
        es: ¿Qué ave puede volar hacia atrás? | El colibrí | El gorrión | La paloma | El cuervo
        de: Welcher Vogel kann rückwärts fliegen? | Der Kolibri | Der Spatz | Die Taube | Die Krähe
        it: Quale uccello sa volare all'indietro? | Il colibrì | Il passero | Il piccione | Il corvo
        pt: Que ave consegue voar para trás? | O beija-flor | O pardal | O pombo | O corvo
        ja: 後ろ向きに飛べる鳥は？ | ハチドリ | スズメ | ハト | カラス
        ko: 뒤로 날 수 있는 새는? | 벌새 | 참새 | 비둘기 | 까마귀
        zh: 哪种鸟能向后飞？ | 蜂鸟 | 麻雀 | 鸽子 | 乌鸦
        ar: أي طائر يستطيع الطيران إلى الخلف؟ | الطائر الطنّان | العصفور | الحمامة | الغراب

        # nat.polar-bear-skin nature 3
        en: What colour is a polar bear's skin? | Black | White | Pink | Yellow
        fr: De quelle couleur est la peau d'un ours polaire ? | Noire | Blanche | Rose | Jaune
        es: ¿De qué color es la piel de un oso polar? | Negra | Blanca | Rosa | Amarilla
        de: Welche Farbe hat die Haut eines Eisbären? | Schwarz | Weiß | Rosa | Gelb
        it: Di che colore è la pelle di un orso polare? | Nera | Bianca | Rosa | Gialla
        pt: De que cor é a pele de um urso-polar? | Preta | Branca | Rosa | Amarela
        ja: ホッキョクグマの皮膚の色は？ | 黒 | 白 | ピンク | 黄色
        ko: 북극곰의 피부는 무슨 색일까요? | 검은색 | 흰색 | 분홍색 | 노란색
        zh: 北极熊的皮肤是什么颜色？ | 黑色 | 白色 | 粉色 | 黄色
        ar: ما لون جلد الدب القطبي؟ | أسود | أبيض | وردي | أصفر

        # nat.flamingo nature 2
        en: Where do flamingos get their pink colour from? | Their food | The sun | Cold water | Their age
        fr: D'où les flamants roses tiennent-ils leur couleur ? | De leur nourriture | Du soleil | De l'eau froide | De leur âge
        es: ¿De dónde sacan los flamencos su color rosa? | De su comida | Del sol | Del agua fría | De su edad
        de: Woher haben Flamingos ihre rosa Farbe? | Von ihrem Futter | Von der Sonne | Vom kalten Wasser | Vom Alter
        it: Da dove prendono i fenicotteri il loro colore rosa? | Dal cibo | Dal sole | Dall'acqua fredda | Dall'età
        pt: De onde os flamingos tiram a cor rosa? | Da comida | Do sol | Da água fria | Da idade
        ja: フラミンゴがピンク色になるのはなぜ？ | 食べ物のため | 日光のため | 冷たい水のため | 年齢のため
        ko: 플라밍고가 분홍색을 띠는 이유는? | 먹이 때문 | 햇빛 때문 | 차가운 물 때문 | 나이 때문
        zh: 火烈鸟的粉红色来自哪里？ | 食物 | 阳光 | 冷水 | 年龄
        ar: من أين يأتي اللون الوردي للنحام (الفلامنغو)؟ | من طعامه | من الشمس | من الماء البارد | من عمره

        # nat.fungi nature 2
        en: Mushrooms belong to which group of living things? | Fungi | Plants | Animals | Bacteria
        fr: À quel groupe d'êtres vivants appartiennent les champignons ? | Les champignons (fonges) | Les plantes | Les animaux | Les bactéries
        es: ¿A qué grupo de seres vivos pertenecen las setas? | Los hongos | Las plantas | Los animales | Las bacterias
        de: Zu welcher Gruppe von Lebewesen gehören Pilze? | Zu den Pilzen | Zu den Pflanzen | Zu den Tieren | Zu den Bakterien
        it: A quale gruppo di esseri viventi appartengono i funghi? | Ai funghi (regno Fungi) | Alle piante | Agli animali | Ai batteri
        pt: A que grupo de seres vivos os cogumelos pertencem? | Fungos | Plantas | Animais | Bactérias
        ja: キノコはどの生き物のなかま？ | 菌類 | 植物 | 動物 | 細菌
        ko: 버섯은 어떤 생물 무리에 속할까요? | 균류 | 식물 | 동물 | 세균
        zh: 蘑菇属于哪一类生物？ | 真菌 | 植物 | 动物 | 细菌
        ar: إلى أي مجموعة من الكائنات الحية ينتمي الفطر؟ | الفطريات | النباتات | الحيوانات | البكتيريا

        # nat.fast-plant nature 3
        en: Which plant is among the fastest-growing on Earth? | Bamboo | Oak | Cactus | Rose
        fr: Quelle plante compte parmi celles qui poussent le plus vite ? | Le bambou | Le chêne | Le cactus | Le rosier
        es: ¿Qué planta está entre las que crecen más rápido en la Tierra? | El bambú | El roble | El cactus | El rosal
        de: Welche Pflanze gehört zu den am schnellsten wachsenden der Erde? | Bambus | Eiche | Kaktus | Rose
        it: Quale pianta è tra quelle che crescono più in fretta sulla Terra? | Il bambù | La quercia | Il cactus | La rosa
        pt: Que planta está entre as que crescem mais rápido na Terra? | O bambu | O carvalho | O cacto | A roseira
        ja: 地球上で最も成長の速い植物のひとつは？ | 竹 | オーク | サボテン | バラ
        ko: 지구에서 가장 빨리 자라는 식물 중 하나는? | 대나무 | 참나무 | 선인장 | 장미
        zh: 哪种植物是地球上长得最快的植物之一？ | 竹子 | 橡树 | 仙人掌 | 玫瑰
        ar: أي نبات من أسرع النباتات نموًا على الأرض؟ | الخيزران | البلوط | الصبّار | الورد

        # nat.egg-mammal nature 3
        en: Which of these mammals lays eggs? | The platypus | The kangaroo | The koala | The bat
        fr: Lequel de ces mammifères pond des œufs ? | L'ornithorynque | Le kangourou | Le koala | La chauve-souris
        es: ¿Cuál de estos mamíferos pone huevos? | El ornitorrinco | El canguro | El koala | El murciélago
        de: Welches dieser Säugetiere legt Eier? | Das Schnabeltier | Das Känguru | Der Koala | Die Fledermaus
        it: Quale di questi mammiferi depone le uova? | L'ornitorinco | Il canguro | Il koala | Il pipistrello
        pt: Qual destes mamíferos põe ovos? | O ornitorrinco | O canguru | O coala | O morcego
        ja: この中で卵を産む哺乳類は？ | カモノハシ | カンガルー | コアラ | コウモリ
        ko: 다음 중 알을 낳는 포유류는? | 오리너구리 | 캥거루 | 코알라 | 박쥐
        zh: 下面哪种哺乳动物会下蛋？ | 鸭嘴兽 | 袋鼠 | 考拉 | 蝙蝠
        ar: أيّ هذه الثدييات يبيض؟ | خلد الماء (البلاتيبوس) | الكنغر | الكوالا | الخفاش

        # nat.owl-head nature 3
        en: About how far can an owl turn its head? | About 270 degrees | About 90 degrees | About 180 degrees | A full 360 degrees
        fr: Jusqu'où une chouette peut-elle tourner la tête ? | Environ 270 degrés | Environ 90 degrés | Environ 180 degrés | 360 degrés
        es: ¿Cuánto puede girar la cabeza un búho? | Unos 270 grados | Unos 90 grados | Unos 180 grados | 360 grados completos
        de: Wie weit kann eine Eule ihren Kopf ungefähr drehen? | Etwa 270 Grad | Etwa 90 Grad | Etwa 180 Grad | Volle 360 Grad
        it: Più o meno di quanto può ruotare la testa un gufo? | Circa 270 gradi | Circa 90 gradi | Circa 180 gradi | Ben 360 gradi
        pt: Mais ou menos quanto uma coruja consegue girar a cabeça? | Cerca de 270 graus | Cerca de 90 graus | Cerca de 180 graus | 360 graus completos
        ja: フクロウは首をおよそ何度まで回せる？ | 約270度 | 約90度 | 約180度 | 360度
        ko: 올빼미는 고개를 대략 몇 도까지 돌릴 수 있을까요? | 약 270도 | 약 90도 | 약 180도 | 360도
        zh: 猫头鹰的头大约能转多少度？ | 约270度 | 约90度 | 约180度 | 整整360度
        ar: إلى أي حد تقريبًا تستطيع البومة أن تدير رأسها؟ | نحو 270 درجة | نحو 90 درجة | نحو 180 درجة | 360 درجة كاملة

        # nat.largest-fish nature 2
        en: What is the largest fish? | The whale shark | The great white shark | The manta ray | The tuna
        fr: Quel est le plus grand poisson ? | Le requin-baleine | Le grand requin blanc | La raie manta | Le thon
        es: ¿Cuál es el pez más grande? | El tiburón ballena | El tiburón blanco | La manta raya | El atún
        de: Welches ist der größte Fisch? | Der Walhai | Der Weiße Hai | Der Mantarochen | Der Thunfisch
        it: Qual è il pesce più grande? | Lo squalo balena | Lo squalo bianco | La manta | Il tonno
        pt: Qual é o maior peixe? | O tubarão-baleia | O tubarão-branco | A raia-manta | O atum
        ja: いちばん大きな魚は？ | ジンベエザメ | ホホジロザメ | オニイトマキエイ | マグロ
        ko: 가장 큰 물고기는? | 고래상어 | 백상아리 | 쥐가오리 | 참치
        zh: 最大的鱼是什么？ | 鲸鲨 | 大白鲨 | 蝠鲼 | 金枪鱼
        ar: ما أكبر سمكة؟ | القرش الحوتي | القرش الأبيض الكبير | شيطان البحر (المانتا) | التونة

        # nat.cow-stomach nature 3
        *: 4 | 1 | 2 | 6
        en: How many compartments does a cow's stomach have?
        fr: Combien de compartiments l'estomac d'une vache compte-t-il ?
        es: ¿Cuántos compartimentos tiene el estómago de una vaca?
        de: Wie viele Abschnitte hat der Magen einer Kuh?
        it: In quante parti è diviso lo stomaco di una mucca?
        pt: Quantos compartimentos tem o estômago de uma vaca?
        ja: ウシの胃はいくつに分かれている？
        ko: 소의 위는 몇 개의 방으로 나뉘어 있을까요?
        zh: 牛的胃分成几个部分？
        ar: كم حجرة في معدة البقرة؟

        # nat.salmon nature 2
        en: Why do salmon swim up rivers from the sea? | To lay their eggs | To sleep | To find salt | To escape the cold
        fr: Pourquoi les saumons remontent-ils les rivières depuis la mer ? | Pour pondre | Pour dormir | Pour trouver du sel | Pour fuir le froid
        es: ¿Por qué los salmones remontan los ríos desde el mar? | Para desovar | Para dormir | Para buscar sal | Para huir del frío
        de: Warum schwimmen Lachse vom Meer die Flüsse hinauf? | Um zu laichen | Um zu schlafen | Um Salz zu finden | Um der Kälte zu entgehen
        it: Perché i salmoni risalgono i fiumi dal mare? | Per deporre le uova | Per dormire | Per trovare il sale | Per fuggire dal freddo
        pt: Por que os salmões sobem os rios vindos do mar? | Para desovar | Para dormir | Para achar sal | Para fugir do frio
        ja: サケが海から川をさかのぼるのはなぜ？ | 卵を産むため | 眠るため | 塩を探すため | 寒さから逃げるため
        ko: 연어가 바다에서 강을 거슬러 오르는 이유는? | 알을 낳으려고 | 잠을 자려고 | 소금을 찾으려고 | 추위를 피하려고
        zh: 鲑鱼为什么从大海逆流而上？ | 为了产卵 | 为了睡觉 | 为了找盐 | 为了躲避寒冷
        ar: لماذا يسبح السلمون من البحر صعودًا في الأنهار؟ | ليضع بيضه | لينام | ليجد الملح | ليهرب من البرد

        # nat.hibernation nature 1
        en: Many bears sleep through the winter in a den. What is this called? | Hibernation | Migration | Metamorphosis | Pollination
        fr: Beaucoup d'ours dorment tout l'hiver dans une tanière. Comment appelle-t-on cela ? | L'hibernation | La migration | La métamorphose | La pollinisation
        es: Muchos osos duermen todo el invierno en una guarida. ¿Cómo se llama esto? | Hibernación | Migración | Metamorfosis | Polinización
        de: Viele Bären verschlafen den Winter in einer Höhle. Wie heißt das? | Winterruhe | Wanderung | Metamorphose | Bestäubung
        it: Molti orsi dormono tutto l'inverno in una tana. Come si chiama? | Letargo | Migrazione | Metamorfosi | Impollinazione
        pt: Muitos ursos dormem o inverno inteiro numa toca. Como isso se chama? | Hibernação | Migração | Metamorfose | Polinização
        ja: 多くのクマは冬のあいだ巣穴で眠ります。これを何という？ | 冬眠 | 渡り | 変態 | 受粉
        ko: 많은 곰이 겨울 내내 굴에서 잠을 잡니다. 이것을 무엇이라고 할까요? | 겨울잠 | 이동 | 변태 | 꽃가루받이
        zh: 许多熊在洞里睡过整个冬天，这叫什么？ | 冬眠 | 迁徙 | 变态发育 | 授粉
        ar: كثير من الدببة تنام الشتاء كله في وكرها. ماذا يُسمّى ذلك؟ | السبات الشتوي | الهجرة | التحوّل | التلقيح

        # nat.pollination nature 2
        en: Bees carry pollen from flower to flower. What is this called? | Pollination | Photosynthesis | Germination | Evaporation
        fr: Les abeilles portent le pollen de fleur en fleur. Comment appelle-t-on cela ? | La pollinisation | La photosynthèse | La germination | L'évaporation
        es: Las abejas llevan el polen de flor en flor. ¿Cómo se llama esto? | Polinización | Fotosíntesis | Germinación | Evaporación
        de: Bienen tragen Pollen von Blüte zu Blüte. Wie heißt das? | Bestäubung | Fotosynthese | Keimung | Verdunstung
        it: Le api portano il polline di fiore in fiore. Come si chiama? | Impollinazione | Fotosintesi | Germinazione | Evaporazione
        pt: As abelhas levam pólen de flor em flor. Como isso se chama? | Polinização | Fotossíntese | Germinação | Evaporação
        ja: ハチが花から花へ花粉を運ぶことを何という？ | 受粉 | 光合成 | 発芽 | 蒸発
        ko: 벌이 꽃가루를 이 꽃에서 저 꽃으로 옮기는 것을 무엇이라고 할까요? | 꽃가루받이(수분) | 광합성 | 발아 | 증발
        zh: 蜜蜂把花粉从一朵花带到另一朵花，这叫什么？ | 授粉 | 光合作用 | 发芽 | 蒸发
        ar: ينقل النحل حبوب اللقاح من زهرة إلى أخرى. ماذا يُسمّى ذلك؟ | التلقيح | البناء الضوئي | الإنبات | التبخر
        """
}
