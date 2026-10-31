extension Games.AnimalBank {
    // 62 animals and the 61 questions that tell them apart, written for the answers most people would give
    // ("Does it spend its whole life in water?" is no for a frog or a seal). Where someone could fairly answer either
    // way, "Not sure" lets the companion try both sides.
    static let source = """
        # animal dolphin 🐬
        en: dolphin
        fr: dauphin
        es: delfín
        de: Delfin
        it: delfino
        pt: golfinho
        ja: イルカ
        ko: 돌고래
        zh: 海豚
        ar: دلفين
        # animal whale 🐋
        en: whale
        fr: baleine
        es: ballena
        de: Wal
        it: balena
        pt: baleia
        ja: クジラ
        ko: 고래
        zh: 鲸鱼
        ar: حوت
        # animal octopus 🐙
        en: octopus
        fr: pieuvre
        es: pulpo
        de: Krake
        it: polpo
        pt: polvo
        ja: タコ
        ko: 문어
        zh: 章鱼
        ar: أخطبوط
        # animal crab 🦀
        en: crab
        fr: crabe
        es: cangrejo
        de: Krabbe
        it: granchio
        pt: caranguejo
        ja: カニ
        ko: 게
        zh: 螃蟹
        ar: سلطعون
        # animal shark 🦈
        en: shark
        fr: requin
        es: tiburón
        de: Hai
        it: squalo
        pt: tubarão
        ja: サメ
        ko: 상어
        zh: 鲨鱼
        ar: قرش
        # animal clownfish 🐠
        en: clownfish
        fr: poisson-clown
        es: pez payaso
        de: Clownfisch
        it: pesce pagliaccio
        pt: peixe-palhaço
        ja: クマノミ
        ko: 흰동가리
        zh: 小丑鱼
        ar: سمكة المهرج
        # animal penguin 🐧
        en: penguin
        fr: manchot
        es: pingüino
        de: Pinguin
        it: pinguino
        pt: pinguim
        ja: ペンギン
        ko: 펭귄
        zh: 企鹅
        ar: بطريق
        # animal swan 🦢
        en: swan
        fr: cygne
        es: cisne
        de: Schwan
        it: cigno
        pt: cisne
        ja: ハクチョウ
        ko: 백조
        zh: 天鹅
        ar: بجعة
        # animal duck 🦆
        en: duck
        fr: canard
        es: pato
        de: Ente
        it: anatra
        pt: pato
        ja: アヒル
        ko: 오리
        zh: 鸭子
        ar: بطة
        # animal owl 🦉
        en: owl
        fr: chouette
        es: búho
        de: Eule
        it: gufo
        pt: coruja
        ja: フクロウ
        ko: 올빼미
        zh: 猫头鹰
        ar: بومة
        # animal eagle 🦅
        en: eagle
        fr: aigle
        es: águila
        de: Adler
        it: aquila
        pt: águia
        ja: ワシ
        ko: 독수리
        zh: 鹰
        ar: نسر
        # animal chicken 🐔
        en: hen
        fr: poule
        es: gallina
        de: Huhn
        it: gallina
        pt: galinha
        ja: ニワトリ
        ko: 닭
        zh: 鸡
        ar: دجاجة
        # animal parrot 🦜
        en: parrot
        fr: perroquet
        es: loro
        de: Papagei
        it: pappagallo
        pt: papagaio
        ja: オウム
        ko: 앵무새
        zh: 鹦鹉
        ar: ببغاء
        # animal flamingo 🦩
        en: flamingo
        fr: flamant rose
        es: flamenco
        de: Flamingo
        it: fenicottero
        pt: flamingo
        ja: フラミンゴ
        ko: 플라밍고
        zh: 火烈鸟
        ar: فلامنغو
        # animal peacock 🦚
        en: peacock
        fr: paon
        es: pavo real
        de: Pfau
        it: pavone
        pt: pavão
        ja: クジャク
        ko: 공작
        zh: 孔雀
        ar: طاووس
        # animal spider 🕷️
        en: spider
        fr: araignée
        es: araña
        de: Spinne
        it: ragno
        pt: aranha
        ja: クモ
        ko: 거미
        zh: 蜘蛛
        ar: عنكبوت
        # animal ant 🐜
        en: ant
        fr: fourmi
        es: hormiga
        de: Ameise
        it: formica
        pt: formiga
        ja: アリ
        ko: 개미
        zh: 蚂蚁
        ar: نملة
        # animal bee 🐝
        en: bee
        fr: abeille
        es: abeja
        de: Biene
        it: ape
        pt: abelha
        ja: ミツバチ
        ko: 꿀벌
        zh: 蜜蜂
        ar: نحلة
        # animal butterfly 🦋
        en: butterfly
        fr: papillon
        es: mariposa
        de: Schmetterling
        it: farfalla
        pt: borboleta
        ja: チョウ
        ko: 나비
        zh: 蝴蝶
        ar: فراشة
        # animal ladybird 🐞
        en: ladybird
        fr: coccinelle
        es: mariquita
        de: Marienkäfer
        it: coccinella
        pt: joaninha
        ja: テントウムシ
        ko: 무당벌레
        zh: 瓢虫
        ar: دعسوقة
        # animal turtle 🐢
        en: turtle
        fr: tortue
        es: tortuga
        de: Schildkröte
        it: tartaruga
        pt: tartaruga
        ja: カメ
        ko: 거북
        zh: 乌龟
        ar: سلحفاة
        # animal crocodile 🐊
        en: crocodile
        fr: crocodile
        es: cocodrilo
        de: Krokodil
        it: coccodrillo
        pt: crocodilo
        ja: ワニ
        ko: 악어
        zh: 鳄鱼
        ar: تمساح
        # animal lizard 🦎
        en: lizard
        fr: lézard
        es: lagarto
        de: Eidechse
        it: lucertola
        pt: lagarto
        ja: トカゲ
        ko: 도마뱀
        zh: 蜥蜴
        ar: سحلية
        # animal snail 🐌
        en: snail
        fr: escargot
        es: caracol
        de: Schnecke
        it: lumaca
        pt: caracol
        ja: カタツムリ
        ko: 달팽이
        zh: 蜗牛
        ar: حلزون
        # animal snake 🐍
        en: snake
        fr: serpent
        es: serpiente
        de: Schlange
        it: serpente
        pt: cobra
        ja: ヘビ
        ko: 뱀
        zh: 蛇
        ar: ثعبان
        # animal frog 🐸
        en: frog
        fr: grenouille
        es: rana
        de: Frosch
        it: rana
        pt: sapo
        ja: カエル
        ko: 개구리
        zh: 青蛙
        ar: ضفدع
        # animal worm 🪱
        en: earthworm
        fr: ver de terre
        es: lombriz
        de: Regenwurm
        it: lombrico
        pt: minhoca
        ja: ミミズ
        ko: 지렁이
        zh: 蚯蚓
        ar: دودة الأرض
        # animal bat 🦇
        en: bat
        fr: chauve-souris
        es: murciélago
        de: Fledermaus
        it: pipistrello
        pt: morcego
        ja: コウモリ
        ko: 박쥐
        zh: 蝙蝠
        ar: خفاش
        # animal horse 🐴
        en: horse
        fr: cheval
        es: caballo
        de: Pferd
        it: cavallo
        pt: cavalo
        ja: ウマ
        ko: 말
        zh: 马
        ar: حصان
        # animal sheep 🐑
        en: sheep
        fr: mouton
        es: oveja
        de: Schaf
        it: pecora
        pt: ovelha
        ja: ヒツジ
        ko: 양
        zh: 绵羊
        ar: خروف
        # animal pig 🐷
        en: pig
        fr: cochon
        es: cerdo
        de: Schwein
        it: maiale
        pt: porco
        ja: ブタ
        ko: 돼지
        zh: 猪
        ar: خنزير
        # animal goat 🐐
        en: goat
        fr: chèvre
        es: cabra
        de: Ziege
        it: capra
        pt: cabra
        ja: ヤギ
        ko: 염소
        zh: 山羊
        ar: ماعز
        # animal cow 🐮
        en: cow
        fr: vache
        es: vaca
        de: Kuh
        it: mucca
        pt: vaca
        ja: ウシ
        ko: 소
        zh: 牛
        ar: بقرة
        # animal dog 🐶
        en: dog
        fr: chien
        es: perro
        de: Hund
        it: cane
        pt: cachorro
        ja: イヌ
        ko: 개
        zh: 狗
        ar: كلب
        # animal cat 🐱
        en: cat
        fr: chat
        es: gato
        de: Katze
        it: gatto
        pt: gato
        ja: ネコ
        ko: 고양이
        zh: 猫
        ar: قطة
        # animal rabbit 🐰
        en: rabbit
        fr: lapin
        es: conejo
        de: Kaninchen
        it: coniglio
        pt: coelho
        ja: ウサギ
        ko: 토끼
        zh: 兔子
        ar: أرنب
        # animal hamster 🐹
        en: hamster
        fr: hamster
        es: hámster
        de: Hamster
        it: criceto
        pt: hamster
        ja: ハムスター
        ko: 햄스터
        zh: 仓鼠
        ar: هامستر
        # animal hedgehog 🦔
        en: hedgehog
        fr: hérisson
        es: erizo
        de: Igel
        it: riccio
        pt: ouriço-cacheiro
        ja: ハリネズミ
        ko: 고슴도치
        zh: 刺猬
        ar: قنفذ
        # animal squirrel 🐿️
        en: squirrel
        fr: écureuil
        es: ardilla
        de: Eichhörnchen
        it: scoiattolo
        pt: esquilo
        ja: リス
        ko: 다람쥐
        zh: 松鼠
        ar: سنجاب
        # animal mouse 🐭
        en: mouse
        fr: souris
        es: ratón
        de: Maus
        it: topo
        pt: camundongo
        ja: ネズミ
        ko: 생쥐
        zh: 老鼠
        ar: فأر
        # animal tiger 🐯
        en: tiger
        fr: tigre
        es: tigre
        de: Tiger
        it: tigre
        pt: tigre
        ja: トラ
        ko: 호랑이
        zh: 老虎
        ar: نمر
        # animal lion 🦁
        en: lion
        fr: lion
        es: león
        de: Löwe
        it: leone
        pt: leão
        ja: ライオン
        ko: 사자
        zh: 狮子
        ar: أسد
        # animal polar-bear 🐻‍❄️
        en: polar bear
        fr: ours polaire
        es: oso polar
        de: Eisbär
        it: orso polare
        pt: urso-polar
        ja: ホッキョクグマ
        ko: 북극곰
        zh: 北极熊
        ar: دب قطبي
        # animal bear 🐻
        en: bear
        fr: ours
        es: oso
        de: Bär
        it: orso
        pt: urso
        ja: クマ
        ko: 곰
        zh: 熊
        ar: دب
        # animal seal 🦭
        en: seal
        fr: phoque
        es: foca
        de: Robbe
        it: foca
        pt: foca
        ja: アザラシ
        ko: 물범
        zh: 海豹
        ar: فقمة
        # animal wolf 🐺
        en: wolf
        fr: loup
        es: lobo
        de: Wolf
        it: lupo
        pt: lobo
        ja: オオカミ
        ko: 늑대
        zh: 狼
        ar: ذئب
        # animal fox 🦊
        en: fox
        fr: renard
        es: zorro
        de: Fuchs
        it: volpe
        pt: raposa
        ja: キツネ
        ko: 여우
        zh: 狐狸
        ar: ثعلب
        # animal raccoon 🦝
        en: raccoon
        fr: raton laveur
        es: mapache
        de: Waschbär
        it: procione
        pt: guaxinim
        ja: アライグマ
        ko: 라쿤
        zh: 浣熊
        ar: راكون
        # animal otter 🦦
        en: otter
        fr: loutre
        es: nutria
        de: Otter
        it: lontra
        pt: lontra
        ja: カワウソ
        ko: 수달
        zh: 水獭
        ar: قضاعة
        # animal sloth 🦥
        en: sloth
        fr: paresseux
        es: perezoso
        de: Faultier
        it: bradipo
        pt: preguiça
        ja: ナマケモノ
        ko: 나무늘보
        zh: 树懒
        ar: كسلان
        # animal koala 🐨
        en: koala
        fr: koala
        es: koala
        de: Koala
        it: koala
        pt: coala
        ja: コアラ
        ko: 코알라
        zh: 考拉
        ar: كوالا
        # animal monkey 🐒
        en: monkey
        fr: singe
        es: mono
        de: Affe
        it: scimmia
        pt: macaco
        ja: サル
        ko: 원숭이
        zh: 猴子
        ar: قرد
        # animal elephant 🐘
        en: elephant
        fr: éléphant
        es: elefante
        de: Elefant
        it: elefante
        pt: elefante
        ja: ゾウ
        ko: 코끼리
        zh: 大象
        ar: فيل
        # animal zebra 🦓
        en: zebra
        fr: zèbre
        es: cebra
        de: Zebra
        it: zebra
        pt: zebra
        ja: シマウマ
        ko: 얼룩말
        zh: 斑马
        ar: حمار وحشي
        # animal panda 🐼
        en: giant panda
        fr: panda géant
        es: panda gigante
        de: Großer Panda
        it: panda gigante
        pt: panda-gigante
        ja: ジャイアントパンダ
        ko: 대왕판다
        zh: 大熊猫
        ar: باندا عملاق
        # animal kangaroo 🦘
        en: kangaroo
        fr: kangourou
        es: canguro
        de: Känguru
        it: canguro
        pt: canguru
        ja: カンガルー
        ko: 캥거루
        zh: 袋鼠
        ar: كنغر
        # animal giraffe 🦒
        en: giraffe
        fr: girafe
        es: jirafa
        de: Giraffe
        it: giraffa
        pt: girafa
        ja: キリン
        ko: 기린
        zh: 长颈鹿
        ar: زرافة
        # animal camel 🐫
        en: camel
        fr: chameau
        es: camello
        de: Kamel
        it: cammello
        pt: camelo
        ja: ラクダ
        ko: 낙타
        zh: 骆驼
        ar: جمل
        # animal deer 🦌
        en: deer
        fr: cerf
        es: ciervo
        de: Hirsch
        it: cervo
        pt: cervo
        ja: シカ
        ko: 사슴
        zh: 鹿
        ar: أيّل
        # animal rhino 🦏
        en: rhinoceros
        fr: rhinocéros
        es: rinoceronte
        de: Nashorn
        it: rinoceronte
        pt: rinoceronte
        ja: サイ
        ko: 코뿔소
        zh: 犀牛
        ar: وحيد القرن
        # animal hippo 🦛
        en: hippopotamus
        fr: hippopotame
        es: hipopótamo
        de: Nilpferd
        it: ippopotamo
        pt: hipopótamo
        ja: カバ
        ko: 하마
        zh: 河马
        ar: فرس النهر
        # animal gorilla 🦍
        en: gorilla
        fr: gorille
        es: gorila
        de: Gorilla
        it: gorilla
        pt: gorila
        ja: ゴリラ
        ko: 고릴라
        zh: 大猩猩
        ar: غوريلا

        // The tree, in pre-order: each question, then its yes side, then its no side.
        # ask
        en: Does it spend its whole life in water?
        fr: Passe-t-il toute sa vie dans l'eau ?
        es: ¿Pasa toda su vida en el agua?
        de: Verbringt es sein ganzes Leben im Wasser?
        it: Passa tutta la vita in acqua?
        pt: Ele passa a vida inteira na água?
        ja: 一生を水の中で過ごす？
        ko: 평생을 물속에서 사나요?
        zh: 它一辈子都生活在水里吗？
        ar: هل يقضي حياته كلها في الماء؟
        # ask
        en: Is it a mammal, feeding its babies milk?
        fr: Est-ce un mammifère, qui nourrit ses petits de lait ?
        es: ¿Es un mamífero, que alimenta a sus crías con leche?
        de: Ist es ein Säugetier, das seine Jungen mit Milch füttert?
        it: È un mammifero, che nutre i piccoli con il latte?
        pt: É um mamífero, que alimenta os filhotes com leite?
        ja: 赤ちゃんをお乳で育てる哺乳類？
        ko: 새끼에게 젖을 먹이는 포유류인가요?
        zh: 它是用奶喂养幼崽的哺乳动物吗？
        ar: هل هو من الثدييات التي ترضع صغارها؟
        # ask
        en: Is it bigger than a bus?
        fr: Est-il plus grand qu'un autobus ?
        es: ¿Es más grande que un autobús?
        de: Ist es größer als ein Bus?
        it: È più grande di un autobus?
        pt: É maior que um ônibus?
        ja: バスより大きい？
        ko: 버스보다 큰가요?
        zh: 它比公共汽车还大吗？
        ar: هل هو أكبر من الحافلة؟
        # is whale
        # is dolphin
        # ask
        en: Does it have eight arms?
        fr: A-t-il huit bras ?
        es: ¿Tiene ocho brazos?
        de: Hat es acht Arme?
        it: Ha otto braccia?
        pt: Ele tem oito braços?
        ja: 腕が8本ある？
        ko: 팔이 여덟 개인가요?
        zh: 它有八条腕吗？
        ar: هل له ثمانية أذرع؟
        # is octopus
        # ask
        en: Does it have claws?
        fr: A-t-il des pinces ?
        es: ¿Tiene pinzas?
        de: Hat es Scheren?
        it: Ha le chele?
        pt: Ele tem pinças?
        ja: はさみがある？
        ko: 집게발이 있나요?
        zh: 它有大钳子吗？
        ar: هل له كلّابات (مخالب كالملقط)؟
        # is crab
        # ask
        en: Does it have sharp teeth and hunt big prey?
        fr: A-t-il des dents pointues pour chasser de grosses proies ?
        es: ¿Tiene dientes afilados y caza presas grandes?
        de: Hat es scharfe Zähne und jagt große Beute?
        it: Ha denti aguzzi e caccia prede grandi?
        pt: Ele tem dentes afiados e caça presas grandes?
        ja: 鋭い歯で大きな獲物を狩る？
        ko: 날카로운 이빨로 큰 먹이를 사냥하나요?
        zh: 它有锋利的牙齿、会捕猎大型猎物吗？
        ar: هل له أسنان حادة ويصطاد فرائس كبيرة؟
        # is shark
        # is clownfish
        # ask
        en: Does it have feathers?
        fr: A-t-il des plumes ?
        es: ¿Tiene plumas?
        de: Hat es Federn?
        it: Ha le piume?
        pt: Ele tem penas?
        ja: 羽毛がある？
        ko: 깃털이 있나요?
        zh: 它有羽毛吗？
        ar: هل له ريش؟
        # ask
        en: Does it swim well?
        fr: Nage-t-il bien ?
        es: ¿Nada bien?
        de: Kann es gut schwimmen?
        it: Nuota bene?
        pt: Ele nada bem?
        ja: 泳ぐのが得意？
        ko: 헤엄을 잘 치나요?
        zh: 它很会游泳吗？
        ar: هل يجيد السباحة؟
        # ask
        en: Can it fly?
        fr: Sait-il voler ?
        es: ¿Puede volar?
        de: Kann es fliegen?
        it: Sa volare?
        pt: Ele consegue voar?
        ja: 空を飛べる？
        ko: 날 수 있나요?
        zh: 它会飞吗？
        ar: هل يستطيع الطيران؟
        # ask
        en: Is it white, with a long neck?
        fr: Est-il blanc, avec un long cou ?
        es: ¿Es blanco, con el cuello largo?
        de: Ist es weiß und hat einen langen Hals?
        it: È bianco, con il collo lungo?
        pt: Ele é branco, com pescoço comprido?
        ja: 白くて首が長い？
        ko: 하얗고 목이 긴가요?
        zh: 它是白色的、脖子很长吗？
        ar: هل هو أبيض وله عنق طويل؟
        # is swan
        # is duck
        # is penguin
        # ask
        en: Does it hunt other animals?
        fr: Chasse-t-il d'autres animaux ?
        es: ¿Caza a otros animales?
        de: Jagt es andere Tiere?
        it: Caccia altri animali?
        pt: Ele caça outros animais?
        ja: ほかの動物を狩る？
        ko: 다른 동물을 사냥하나요?
        zh: 它会捕猎其他动物吗？
        ar: هل يصطاد حيوانات أخرى؟
        # ask
        en: Is it awake mostly at night?
        fr: Est-il surtout actif la nuit ?
        es: ¿Está despierto sobre todo de noche?
        de: Ist es vor allem nachts wach?
        it: È sveglio soprattutto di notte?
        pt: Ele fica acordado principalmente à noite?
        ja: おもに夜に起きている？
        ko: 주로 밤에 깨어 있나요?
        zh: 它主要在夜里活动吗？
        ar: هل ينشط في الليل غالبًا؟
        # is owl
        # is eagle
        # ask
        en: Do people keep it on farms for its eggs?
        fr: L'élève-t-on dans les fermes pour ses œufs ?
        es: ¿Se cría en granjas por sus huevos?
        de: Hält man es auf Bauernhöfen wegen seiner Eier?
        it: Si alleva nelle fattorie per le sue uova?
        pt: As pessoas o criam em fazendas por causa dos ovos?
        ja: 卵をとるために農場で飼われている？
        ko: 알을 얻으려고 농장에서 기르나요?
        zh: 人们在农场养它来下蛋吗？
        ar: هل يربّيه الناس في المزارع من أجل بيضه؟
        # is chicken
        # ask
        en: Can it copy words people say?
        fr: Peut-il répéter des mots que disent les gens ?
        es: ¿Puede imitar palabras que dice la gente?
        de: Kann es Wörter nachsprechen, die Menschen sagen?
        it: Sa ripetere le parole che dicono le persone?
        pt: Ele consegue imitar palavras que as pessoas dizem?
        ja: 人の言葉をまねできる？
        ko: 사람의 말을 따라 할 수 있나요?
        zh: 它能模仿人说话吗？
        ar: هل يستطيع تقليد كلام الناس؟
        # is parrot
        # ask
        en: Is it pink?
        fr: Est-il rose ?
        es: ¿Es rosa?
        de: Ist es rosa?
        it: È rosa?
        pt: Ele é cor-de-rosa?
        ja: ピンク色？
        ko: 분홍색인가요?
        zh: 它是粉红色的吗？
        ar: هل لونه وردي؟
        # is flamingo
        # is peacock
        # ask
        en: Does it have six or eight legs?
        fr: A-t-il six ou huit pattes ?
        es: ¿Tiene seis u ocho patas?
        de: Hat es sechs oder acht Beine?
        it: Ha sei o otto zampe?
        pt: Ele tem seis ou oito patas?
        ja: 脚が6本か8本ある？
        ko: 다리가 여섯 개나 여덟 개인가요?
        zh: 它有六条或八条腿吗？
        ar: هل له ست أو ثماني أرجل؟
        # ask
        en: Does it have eight legs?
        fr: A-t-il huit pattes ?
        es: ¿Tiene ocho patas?
        de: Hat es acht Beine?
        it: Ha otto zampe?
        pt: Ele tem oito patas?
        ja: 脚が8本ある？
        ko: 다리가 여덟 개인가요?
        zh: 它有八条腿吗？
        ar: هل له ثماني أرجل؟
        # is spider
        # ask
        en: Can it fly?
        fr: Sait-il voler ?
        es: ¿Puede volar?
        de: Kann es fliegen?
        it: Sa volare?
        pt: Ele consegue voar?
        ja: 空を飛べる？
        ko: 날 수 있나요?
        zh: 它会飞吗？
        ar: هل يستطيع الطيران؟
        # ask
        en: Does it make honey?
        fr: Fabrique-t-il du miel ?
        es: ¿Hace miel?
        de: Macht es Honig?
        it: Produce il miele?
        pt: Ele faz mel?
        ja: はちみつをつくる？
        ko: 꿀을 만드나요?
        zh: 它会酿蜜吗？
        ar: هل يصنع العسل؟
        # is bee
        # ask
        en: Does it have big, colourful wings?
        fr: A-t-il de grandes ailes colorées ?
        es: ¿Tiene alas grandes y de colores?
        de: Hat es große, bunte Flügel?
        it: Ha ali grandi e colorate?
        pt: Ele tem asas grandes e coloridas?
        ja: 大きくてカラフルな羽がある？
        ko: 크고 알록달록한 날개가 있나요?
        zh: 它有又大又鲜艳的翅膀吗？
        ar: هل له أجنحة كبيرة ملونة؟
        # is butterfly
        # is ladybird
        # is ant
        # ask
        en: Does it have scales or a shell?
        fr: A-t-il des écailles ou une carapace ?
        es: ¿Tiene escamas o caparazón?
        de: Hat es Schuppen oder einen Panzer?
        it: Ha squame o un guscio?
        pt: Ele tem escamas ou casco?
        ja: うろこや殻がある？
        ko: 비늘이나 껍데기가 있나요?
        zh: 它有鳞片或硬壳吗？
        ar: هل له حراشف أو صَدَفة؟
        # ask
        en: Does it have legs?
        fr: A-t-il des pattes ?
        es: ¿Tiene patas?
        de: Hat es Beine?
        it: Ha le zampe?
        pt: Ele tem patas?
        ja: 脚がある？
        ko: 다리가 있나요?
        zh: 它有腿吗？
        ar: هل له أرجل؟
        # ask
        en: Does it carry a shell on its back?
        fr: Porte-t-il une carapace sur le dos ?
        es: ¿Lleva un caparazón a la espalda?
        de: Trägt es einen Panzer auf dem Rücken?
        it: Porta un guscio sulla schiena?
        pt: Ele carrega um casco nas costas?
        ja: 背中に甲羅や殻をしょっている？
        ko: 등에 등딱지나 껍데기를 지고 다니나요?
        zh: 它背上背着壳吗？
        ar: هل يحمل صدفة على ظهره؟
        # is turtle
        # ask
        en: Is it longer than a grown-up person?
        fr: Est-il plus long qu'un adulte ?
        es: ¿Es más largo que una persona adulta?
        de: Ist es länger als ein Erwachsener?
        it: È più lungo di una persona adulta?
        pt: Ele é mais comprido que um adulto?
        ja: 大人の人間より長い？
        ko: 어른 키보다 긴가요?
        zh: 它比成年人还长吗？
        ar: هل هو أطول من إنسان بالغ؟
        # is crocodile
        # is lizard
        # ask
        en: Does it carry a shell on its back?
        fr: Porte-t-il une coquille sur le dos ?
        es: ¿Lleva una concha a la espalda?
        de: Trägt es ein Haus auf dem Rücken?
        it: Porta un guscio sulla schiena?
        pt: Ele carrega uma concha nas costas?
        ja: 背中に殻をしょっている？
        ko: 등에 껍데기를 지고 다니나요?
        zh: 它背上背着壳吗？
        ar: هل يحمل صدفة على ظهره؟
        # is snail
        # is snake
        # ask
        en: Does it feed its babies milk?
        fr: Nourrit-il ses petits de lait ?
        es: ¿Alimenta a sus crías con leche?
        de: Füttert es seine Jungen mit Milch?
        it: Nutre i piccoli con il latte?
        pt: Ele alimenta os filhotes com leite?
        ja: 赤ちゃんをお乳で育てる？
        ko: 새끼에게 젖을 먹이나요?
        zh: 它用奶喂养幼崽吗？
        ar: هل يرضع صغاره؟
        # ask
        en: Can it fly?
        fr: Sait-il voler ?
        es: ¿Puede volar?
        de: Kann es fliegen?
        it: Sa volare?
        pt: Ele consegue voar?
        ja: 空を飛べる？
        ko: 날 수 있나요?
        zh: 它会飞吗？
        ar: هل يستطيع الطيران؟
        # is bat
        # ask
        en: Do people often keep it at home or on a farm?
        fr: Le garde-t-on souvent à la maison ou à la ferme ?
        es: ¿Se suele tener en casa o en una granja?
        de: Hält man es oft zu Hause oder auf dem Bauernhof?
        it: Si tiene spesso in casa o in fattoria?
        pt: As pessoas costumam tê-lo em casa ou na fazenda?
        ja: 家や農場でよく飼われている？
        ko: 사람들이 집이나 농장에서 흔히 기르나요?
        zh: 人们常在家里或农场养它吗？
        ar: هل يربّيه الناس عادةً في البيت أو المزرعة؟
        # ask
        en: Do people ride it?
        fr: Monte-t-on dessus ?
        es: ¿La gente lo monta?
        de: Reitet man darauf?
        it: Lo si cavalca?
        pt: As pessoas montam nele?
        ja: 人が乗って走る？
        ko: 사람이 타고 다니나요?
        zh: 人们会骑它吗？
        ar: هل يركبه الناس؟
        # is horse
        # ask
        en: Does it have hooves?
        fr: A-t-il des sabots ?
        es: ¿Tiene pezuñas?
        de: Hat es Hufe?
        it: Ha gli zoccoli?
        pt: Ele tem cascos?
        ja: ひづめがある？
        ko: 발굽이 있나요?
        zh: 它有蹄子吗？
        ar: هل له حوافر؟
        # ask
        en: Is it covered in thick wool?
        fr: Est-il couvert d'une épaisse laine ?
        es: ¿Está cubierto de lana gruesa?
        de: Hat es dicke Wolle?
        it: È coperto di lana folta?
        pt: Ele é coberto de lã grossa?
        ja: 厚い羊毛におおわれている？
        ko: 두꺼운 털(양모)로 덮여 있나요?
        zh: 它身上长着厚厚的羊毛吗？
        ar: هل يغطيه صوف كثيف؟
        # is sheep
        # ask
        en: Does it go "oink" and roll in mud?
        fr: Fait-il « groin groin » et se roule-t-il dans la boue ?
        es: ¿Hace «oinc» y se revuelca en el barro?
        de: Grunzt es und suhlt sich im Schlamm?
        it: Fa «oink» e si rotola nel fango?
        pt: Ele faz "oinc" e rola na lama?
        ja: 「ブーブー」と鳴いて泥あそびをする？
        ko: '꿀꿀' 울고 진흙에서 뒹구나요?
        zh: 它会“哼哼”叫、在泥里打滚吗？
        ar: هل يصدر صوت «أوينك» ويتمرّغ في الوحل؟
        # is pig
        # ask
        en: Does it have a little beard under its chin?
        fr: A-t-il une petite barbiche sous le menton ?
        es: ¿Tiene una barbita bajo la barbilla?
        de: Hat es einen kleinen Bart am Kinn?
        it: Ha una barbetta sotto il mento?
        pt: Ele tem um cavanhaque debaixo do queixo?
        ja: あごの下に小さなひげがある？
        ko: 턱 밑에 작은 수염이 있나요?
        zh: 它下巴下面有一小撮胡子吗？
        ar: هل له لحية صغيرة تحت ذقنه؟
        # is goat
        # is cow
        # ask
        en: Does it bark?
        fr: Aboie-t-il ?
        es: ¿Ladra?
        de: Bellt es?
        it: Abbaia?
        pt: Ele late?
        ja: ワンワンほえる？
        ko: 멍멍 짖나요?
        zh: 它会汪汪叫吗？
        ar: هل ينبح؟
        # is dog
        # ask
        en: Does it purr?
        fr: Ronronne-t-il ?
        es: ¿Ronronea?
        de: Schnurrt es?
        it: Fa le fusa?
        pt: Ele ronrona?
        ja: のどをゴロゴロ鳴らす？
        ko: 가르랑거리나요?
        zh: 它会打呼噜（呼噜呼噜）吗？
        ar: هل يُخرخر؟
        # is cat
        # ask
        en: Does it have long ears and hop?
        fr: A-t-il de longues oreilles et sautille-t-il ?
        es: ¿Tiene orejas largas y da saltitos?
        de: Hat es lange Ohren und hoppelt?
        it: Ha le orecchie lunghe e saltella?
        pt: Ele tem orelhas compridas e dá pulinhos?
        ja: 耳が長くてぴょんぴょん跳ねる？
        ko: 귀가 길고 깡충깡충 뛰나요?
        zh: 它耳朵长、蹦蹦跳跳吗？
        ar: هل له أذنان طويلتان ويقفز؟
        # is rabbit
        # is hamster
        # ask
        en: Is it smaller than a cat?
        fr: Est-il plus petit qu'un chat ?
        es: ¿Es más pequeño que un gato?
        de: Ist es kleiner als eine Katze?
        it: È più piccolo di un gatto?
        pt: Ele é menor que um gato?
        ja: ネコより小さい？
        ko: 고양이보다 작은가요?
        zh: 它比猫小吗？
        ar: هل هو أصغر من القطة؟
        # ask
        en: Is it covered in prickly spines?
        fr: Est-il couvert de piquants ?
        es: ¿Está cubierto de púas?
        de: Hat es Stacheln?
        it: È coperto di aculei?
        pt: Ele é coberto de espinhos?
        ja: とげとげの針におおわれている？
        ko: 뾰족한 가시로 덮여 있나요?
        zh: 它身上长满了刺吗？
        ar: هل يغطيه شوك؟
        # is hedgehog
        # ask
        en: Does it have a big bushy tail?
        fr: A-t-il une grande queue touffue ?
        es: ¿Tiene una cola grande y peluda?
        de: Hat es einen großen buschigen Schwanz?
        it: Ha una grande coda folta?
        pt: Ele tem um rabo grande e peludo?
        ja: ふさふさの大きなしっぽがある？
        ko: 크고 복슬복슬한 꼬리가 있나요?
        zh: 它有一条又大又蓬松的尾巴吗？
        ar: هل له ذيل كبير كثيف الشعر؟
        # is squirrel
        # is mouse
        # ask
        en: Does it eat other animals?
        fr: Mange-t-il d'autres animaux ?
        es: ¿Come otros animales?
        de: Frisst es andere Tiere?
        it: Mangia altri animali?
        pt: Ele come outros animais?
        ja: ほかの動物を食べる？
        ko: 다른 동물을 잡아먹나요?
        zh: 它吃其他动物吗？
        ar: هل يأكل حيوانات أخرى؟
        # ask
        en: Is it a big cat?
        fr: Est-ce un grand félin ?
        es: ¿Es un gran felino?
        de: Ist es eine Großkatze?
        it: È un grande felino?
        pt: É um grande felino?
        ja: 大型のネコのなかま？
        ko: 몸집이 큰 고양잇과 동물인가요?
        zh: 它是大型猫科动物吗？
        ar: هل هو من السنّوريات الكبيرة؟
        # ask
        en: Does it have stripes?
        fr: A-t-il des rayures ?
        es: ¿Tiene rayas?
        de: Hat es Streifen?
        it: Ha le strisce?
        pt: Ele tem listras?
        ja: しま模様がある？
        ko: 줄무늬가 있나요?
        zh: 它身上有条纹吗？
        ar: هل له خطوط؟
        # is tiger
        # is lion
        # ask
        en: Is it a bear?
        fr: Est-ce un ours ?
        es: ¿Es un oso?
        de: Ist es ein Bär?
        it: È un orso?
        pt: É um urso?
        ja: クマのなかま？
        ko: 곰인가요?
        zh: 它是熊吗？
        ar: هل هو دب؟
        # ask
        en: Is it white, living in the Arctic?
        fr: Est-il blanc et vit-il en Arctique ?
        es: ¿Es blanco y vive en el Ártico?
        de: Ist es weiß und lebt in der Arktis?
        it: È bianco e vive nell'Artico?
        pt: Ele é branco e vive no Ártico?
        ja: 白くて北極にすんでいる？
        ko: 하얗고 북극에 사나요?
        zh: 它是白色的、生活在北极吗？
        ar: هل هو أبيض ويعيش في القطب الشمالي؟
        # is polar-bear
        # is bear
        # ask
        en: Does it have flippers?
        fr: A-t-il des nageoires ?
        es: ¿Tiene aletas?
        de: Hat es Flossen?
        it: Ha le pinne?
        pt: Ele tem nadadeiras?
        ja: ひれのような足がある？
        ko: 지느러미발이 있나요?
        zh: 它有鳍状肢吗？
        ar: هل له زعانف؟
        # is seal
        # ask
        en: Does it look like a dog?
        fr: Ressemble-t-il à un chien ?
        es: ¿Se parece a un perro?
        de: Sieht es aus wie ein Hund?
        it: Somiglia a un cane?
        pt: Ele parece um cachorro?
        ja: イヌに似ている？
        ko: 개처럼 생겼나요?
        zh: 它长得像狗吗？
        ar: هل يشبه الكلب؟
        # ask
        en: Does it hunt in packs and howl?
        fr: Chasse-t-il en meute et hurle-t-il ?
        es: ¿Caza en manada y aúlla?
        de: Jagt es im Rudel und heult?
        it: Caccia in branco e ulula?
        pt: Ele caça em bando e uiva?
        ja: 群れで狩りをして遠ぼえする？
        ko: 무리 지어 사냥하고 울부짖나요?
        zh: 它成群捕猎、会嚎叫吗？
        ar: هل يصطاد في قطيع ويعوي؟
        # is wolf
        # is fox
        # ask
        en: Does it have a mask on its face and a ringed tail?
        fr: A-t-il un masque sur le visage et une queue à anneaux ?
        es: ¿Tiene un antifaz en la cara y la cola a anillos?
        de: Hat es eine Maske im Gesicht und einen geringelten Schwanz?
        it: Ha una mascherina sul muso e la coda ad anelli?
        pt: Ele tem uma máscara no rosto e o rabo listrado em anéis?
        ja: 顔に仮面のような模様、しっぽにしまがある？
        ko: 얼굴에 가면 같은 무늬가 있고 꼬리에 고리 무늬가 있나요?
        zh: 它脸上有“面罩”、尾巴上有环纹吗？
        ar: هل على وجهه قناع وذيله مخطط بحلقات؟
        # is raccoon
        # is otter
        # ask
        en: Does it live mostly up in trees?
        fr: Vit-il surtout dans les arbres ?
        es: ¿Vive sobre todo en los árboles?
        de: Lebt es meistens oben in Bäumen?
        it: Vive soprattutto sugli alberi?
        pt: Ele vive principalmente nas árvores?
        ja: おもに木の上で暮らしている？
        ko: 주로 나무 위에서 사나요?
        zh: 它主要生活在树上吗？
        ar: هل يعيش غالبًا فوق الأشجار؟
        # ask
        en: Does it hang upside down and move very slowly?
        fr: Se suspend-il la tête en bas en bougeant très lentement ?
        es: ¿Cuelga boca abajo y se mueve muy despacio?
        de: Hängt es kopfüber und bewegt sich sehr langsam?
        it: Sta appeso a testa in giù e si muove lentissimo?
        pt: Ele fica pendurado de cabeça para baixo e se move bem devagar?
        ja: さかさまにぶら下がって、とてもゆっくり動く？
        ko: 거꾸로 매달려 아주 느리게 움직이나요?
        zh: 它倒挂着、动作非常慢吗？
        ar: هل يتدلّى مقلوبًا ويتحرك ببطء شديد؟
        # is sloth
        # ask
        en: Does the mother carry her baby in a pouch?
        fr: La maman porte-t-elle son petit dans une poche ?
        es: ¿La madre lleva a su cría en una bolsa?
        de: Trägt die Mutter ihr Junges in einem Beutel?
        it: La mamma porta il piccolo in un marsupio?
        pt: A mãe carrega o filhote numa bolsa?
        ja: お母さんがおなかの袋で赤ちゃんを育てる？
        ko: 어미가 새끼를 주머니에 넣고 다니나요?
        zh: 它的妈妈用育儿袋带着宝宝吗？
        ar: هل تحمل الأم صغيرها في جراب؟
        # is koala
        # is monkey
        # ask
        en: Does it have a long trunk?
        fr: A-t-il une longue trompe ?
        es: ¿Tiene una trompa larga?
        de: Hat es einen langen Rüssel?
        it: Ha una lunga proboscide?
        pt: Ele tem uma tromba comprida?
        ja: 長い鼻がある？
        ko: 긴 코가 있나요?
        zh: 它有长长的鼻子吗？
        ar: هل له خرطوم طويل؟
        # is elephant
        # ask
        en: Is it black and white?
        fr: Est-il noir et blanc ?
        es: ¿Es blanco y negro?
        de: Ist es schwarz-weiß?
        it: È bianco e nero?
        pt: Ele é preto e branco?
        ja: 白と黒の動物？
        ko: 흰색과 검은색인가요?
        zh: 它是黑白相间的吗？
        ar: هل لونه أبيض وأسود؟
        # ask
        en: Does it have stripes?
        fr: A-t-il des rayures ?
        es: ¿Tiene rayas?
        de: Hat es Streifen?
        it: Ha le strisce?
        pt: Ele tem listras?
        ja: しま模様がある？
        ko: 줄무늬가 있나요?
        zh: 它身上有条纹吗？
        ar: هل له خطوط؟
        # is zebra
        # is panda
        # ask
        en: Does it hop on big back feet?
        fr: Bondit-il sur de grandes pattes arrière ?
        es: ¿Salta sobre grandes patas traseras?
        de: Springt es auf großen Hinterbeinen?
        it: Salta sulle grandi zampe posteriori?
        pt: Ele pula com as grandes patas de trás?
        ja: 大きな後ろ足でぴょんぴょん跳ぶ？
        ko: 큰 뒷다리로 껑충껑충 뛰나요?
        zh: 它用大大的后腿跳着走吗？
        ar: هل يقفز على قدمين خلفيتين كبيرتين؟
        # is kangaroo
        # ask
        en: Does it have a very long neck?
        fr: A-t-il un très long cou ?
        es: ¿Tiene el cuello muy largo?
        de: Hat es einen sehr langen Hals?
        it: Ha il collo lunghissimo?
        pt: Ele tem o pescoço muito comprido?
        ja: とても首が長い？
        ko: 목이 아주 긴가요?
        zh: 它的脖子特别长吗？
        ar: هل له عنق طويل جدًا؟
        # is giraffe
        # ask
        en: Does it have a hump on its back?
        fr: A-t-il une bosse sur le dos ?
        es: ¿Tiene joroba?
        de: Hat es einen Höcker auf dem Rücken?
        it: Ha una gobba sulla schiena?
        pt: Ele tem corcova nas costas?
        ja: 背中にこぶがある？
        ko: 등에 혹이 있나요?
        zh: 它背上有驼峰吗？
        ar: هل له سنام على ظهره؟
        # is camel
        # ask
        en: Does it have antlers?
        fr: A-t-il des bois sur la tête ?
        es: ¿Tiene cuernos ramificados (astas)?
        de: Hat es ein Geweih?
        it: Ha le corna ramificate?
        pt: Ele tem chifres ramificados (galhada)?
        ja: 枝分かれした角がある？
        ko: 나뭇가지 모양의 뿔이 있나요?
        zh: 它头上有分叉的角吗？
        ar: هل له قرون متفرعة؟
        # is deer
        # ask
        en: Does it have a horn on its nose?
        fr: A-t-il une corne sur le nez ?
        es: ¿Tiene un cuerno en la nariz?
        de: Hat es ein Horn auf der Nase?
        it: Ha un corno sul naso?
        pt: Ele tem um chifre no nariz?
        ja: 鼻の上に角がある？
        ko: 코 위에 뿔이 있나요?
        zh: 它鼻子上长着角吗？
        ar: هل له قرن على أنفه؟
        # is rhino
        # ask
        en: Does it spend its days in rivers and lakes?
        fr: Passe-t-il ses journées dans les rivières et les lacs ?
        es: ¿Pasa el día en ríos y lagos?
        de: Verbringt es seine Tage in Flüssen und Seen?
        it: Passa le giornate nei fiumi e nei laghi?
        pt: Ele passa os dias em rios e lagos?
        ja: 昼間は川や湖の中で過ごす？
        ko: 낮에는 강이나 호수에서 지내나요?
        zh: 它白天待在河流和湖泊里吗？
        ar: هل يقضي نهاره في الأنهار والبحيرات؟
        # is hippo
        # is gorilla
        # ask
        en: Does it have legs?
        fr: A-t-il des pattes ?
        es: ¿Tiene patas?
        de: Hat es Beine?
        it: Ha le zampe?
        pt: Ele tem patas?
        ja: 脚がある？
        ko: 다리가 있나요?
        zh: 它有腿吗？
        ar: هل له أرجل؟
        # is frog
        # is worm
        """
}
