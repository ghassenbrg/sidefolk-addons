extension Games.QuizBank {
    // Science: the right answer first; the round shuffles the options.
    static let science = """
        # sci.plants-gas science 1
        en: What gas do plants take from the air to make their food? | Carbon dioxide | Oxygen | Nitrogen | Helium
        fr: Quel gaz les plantes prennent-elles dans l'air pour fabriquer leur nourriture ? | Le dioxyde de carbone | L'oxygène | L'azote | L'hélium
        es: ¿Qué gas toman las plantas del aire para fabricar su alimento? | Dióxido de carbono | Oxígeno | Nitrógeno | Helio
        de: Welches Gas nehmen Pflanzen aus der Luft, um ihre Nahrung herzustellen? | Kohlendioxid | Sauerstoff | Stickstoff | Helium
        it: Quale gas prendono le piante dall'aria per produrre il loro cibo? | Anidride carbonica | Ossigeno | Azoto | Elio
        pt: Que gás as plantas tiram do ar para produzir seu alimento? | Gás carbônico | Oxigênio | Nitrogênio | Hélio
        ja: 植物が栄養をつくるために空気から取り入れる気体は？ | 二酸化炭素 | 酸素 | 窒素 | ヘリウム
        ko: 식물이 양분을 만들기 위해 공기에서 받아들이는 기체는? | 이산화탄소 | 산소 | 질소 | 헬륨
        zh: 植物从空气中吸收哪种气体来制造养分？ | 二氧化碳 | 氧气 | 氮气 | 氦气
        ar: ما الغاز الذي تأخذه النباتات من الهواء لتصنع غذاءها؟ | ثاني أكسيد الكربون | الأكسجين | النيتروجين | الهيليوم

        # sci.gold-symbol science 1
        *: Au | Ag | Gd | Go
        en: What is the chemical symbol for gold?
        fr: Quel est le symbole chimique de l'or ?
        es: ¿Cuál es el símbolo químico del oro?
        de: Was ist das chemische Symbol für Gold?
        it: Qual è il simbolo chimico dell'oro?
        pt: Qual é o símbolo químico do ouro?
        ja: 金の元素記号は？
        ko: 금의 원소 기호는?
        zh: 金的化学符号是什么？
        ar: ما الرمز الكيميائي للذهب؟

        # sci.adult-bones science 2
        *: 206 | 186 | 226 | 256
        en: How many bones does an adult human have?
        fr: Combien d'os compte le squelette d'un adulte ?
        es: ¿Cuántos huesos tiene una persona adulta?
        de: Wie viele Knochen hat ein erwachsener Mensch?
        it: Quante ossa ha un essere umano adulto?
        pt: Quantos ossos tem um ser humano adulto?
        ja: 大人の人間の骨はいくつ？
        ko: 성인의 뼈는 모두 몇 개일까요?
        zh: 成年人有多少块骨头？
        ar: كم عظمة في جسم الإنسان البالغ؟

        # sci.hardest-material science 1
        en: What is the hardest natural material? | Diamond | Quartz | Granite | Iron
        fr: Quel est le matériau naturel le plus dur ? | Le diamant | Le quartz | Le granit | Le fer
        es: ¿Cuál es el material natural más duro? | El diamante | El cuarzo | El granito | El hierro
        de: Was ist das härteste natürliche Material? | Diamant | Quarz | Granit | Eisen
        it: Qual è il materiale naturale più duro? | Il diamante | Il quarzo | Il granito | Il ferro
        pt: Qual é o material natural mais duro? | Diamante | Quartzo | Granito | Ferro
        ja: 天然でいちばん硬い物質は？ | ダイヤモンド | 石英 | 花こう岩 | 鉄
        ko: 자연에서 가장 단단한 물질은? | 다이아몬드 | 석영 | 화강암 | 철
        zh: 最坚硬的天然物质是什么？ | 钻石 | 石英 | 花岗岩 | 铁
        ar: ما أصلب مادة طبيعية؟ | الألماس | الكوارتز | الجرانيت | الحديد

        # sci.water-boils science 1
        *: 100 °C | 90 °C | 110 °C | 120 °C
        en: At sea level, at what temperature does water boil?
        fr: Au niveau de la mer, à quelle température l'eau bout-elle ?
        es: Al nivel del mar, ¿a qué temperatura hierve el agua?
        de: Bei welcher Temperatur kocht Wasser auf Meereshöhe?
        it: Al livello del mare, a che temperatura bolle l'acqua?
        pt: Ao nível do mar, a que temperatura a água ferve?
        ja: 海面の高さで、水は何度で沸騰する？
        ko: 해수면에서 물은 몇 도에서 끓을까요?
        zh: 在海平面，水在多少度沸腾？
        ar: عند مستوى سطح البحر، عند أي درجة حرارة يغلي الماء؟

        # sci.atomic-number-1 science 2
        en: Which element has the atomic number 1? | Hydrogen | Helium | Oxygen | Carbon
        fr: Quel élément a le numéro atomique 1 ? | L'hydrogène | L'hélium | L'oxygène | Le carbone
        es: ¿Qué elemento tiene el número atómico 1? | Hidrógeno | Helio | Oxígeno | Carbono
        de: Welches Element hat die Ordnungszahl 1? | Wasserstoff | Helium | Sauerstoff | Kohlenstoff
        it: Quale elemento ha numero atomico 1? | Idrogeno | Elio | Ossigeno | Carbonio
        pt: Qual elemento tem número atômico 1? | Hidrogênio | Hélio | Oxigênio | Carbono
        ja: 原子番号1の元素は？ | 水素 | ヘリウム | 酸素 | 炭素
        ko: 원자 번호 1번인 원소는? | 수소 | 헬륨 | 산소 | 탄소
        zh: 原子序数为1的元素是什么？ | 氢 | 氦 | 氧 | 碳
        ar: ما العنصر الذي عدده الذري 1؟ | الهيدروجين | الهيليوم | الأكسجين | الكربون

        # sci.cell-dna science 2
        en: Which part of a cell holds most of its DNA? | The nucleus | The ribosomes | The vacuole | The cell wall
        fr: Quelle partie d'une cellule contient l'essentiel de son ADN ? | Le noyau | Les ribosomes | La vacuole | La paroi cellulaire
        es: ¿Qué parte de la célula guarda la mayor parte de su ADN? | El núcleo | Los ribosomas | La vacuola | La pared celular
        de: Welcher Teil einer Zelle enthält den Großteil ihrer DNA? | Der Zellkern | Die Ribosomen | Die Vakuole | Die Zellwand
        it: Quale parte della cellula contiene la maggior parte del suo DNA? | Il nucleo | I ribosomi | Il vacuolo | La parete cellulare
        pt: Que parte da célula guarda a maior parte do seu DNA? | O núcleo | Os ribossomos | O vacúolo | A parede celular
        ja: 細胞の中でDNAの大部分があるのはどこ？ | 核 | リボソーム | 液胞 | 細胞壁
        ko: 세포에서 DNA 대부분이 들어 있는 곳은? | 핵 | 리보솜 | 액포 | 세포벽
        zh: 细胞的大部分DNA在哪里？ | 细胞核 | 核糖体 | 液泡 | 细胞壁
        ar: أي جزء من الخلية يحتوي معظم حمضها النووي؟ | النواة | الريبوسومات | الفجوة | الجدار الخلوي

        # sci.water-formula science 1
        *: H₂O | CO₂ | O₂ | NaCl
        en: What is the chemical formula of water?
        fr: Quelle est la formule chimique de l'eau ?
        es: ¿Cuál es la fórmula química del agua?
        de: Wie lautet die chemische Formel von Wasser?
        it: Qual è la formula chimica dell'acqua?
        pt: Qual é a fórmula química da água?
        ja: 水の化学式は？
        ko: 물의 화학식은?
        zh: 水的化学式是什么？
        ar: ما الصيغة الكيميائية للماء؟

        # sci.water-freezes science 1
        *: 0 °C | −10 °C | 4 °C | 10 °C
        en: At what temperature does pure water freeze at sea level?
        fr: À quelle température l'eau pure gèle-t-elle au niveau de la mer ?
        es: ¿A qué temperatura se congela el agua pura al nivel del mar?
        de: Bei welcher Temperatur gefriert reines Wasser auf Meereshöhe?
        it: A che temperatura gela l'acqua pura al livello del mare?
        pt: A que temperatura a água pura congela ao nível do mar?
        ja: 海面の高さで、純粋な水は何度で凍る？
        ko: 해수면에서 순수한 물은 몇 도에서 얼까요?
        zh: 在海平面，纯水在多少度结冰？
        ar: عند أي درجة حرارة يتجمد الماء النقي عند مستوى سطح البحر؟

        # sci.oxygen-cells science 2
        en: Which blood cells carry oxygen around the body? | Red blood cells | White blood cells | Platelets | Nerve cells
        fr: Quelles cellules du sang transportent l'oxygène ? | Les globules rouges | Les globules blancs | Les plaquettes | Les neurones
        es: ¿Qué células de la sangre llevan el oxígeno por el cuerpo? | Los glóbulos rojos | Los glóbulos blancos | Las plaquetas | Las neuronas
        de: Welche Blutzellen transportieren Sauerstoff durch den Körper? | Rote Blutkörperchen | Weiße Blutkörperchen | Blutplättchen | Nervenzellen
        it: Quali cellule del sangue trasportano l'ossigeno nel corpo? | I globuli rossi | I globuli bianchi | Le piastrine | I neuroni
        pt: Quais células do sangue levam oxigênio pelo corpo? | Glóbulos vermelhos | Glóbulos brancos | Plaquetas | Neurônios
        ja: 体じゅうに酸素を運ぶ血液の細胞は？ | 赤血球 | 白血球 | 血小板 | 神経細胞
        ko: 몸 곳곳에 산소를 나르는 혈액 세포는? | 적혈구 | 백혈구 | 혈소판 | 신경 세포
        zh: 哪种血细胞负责把氧气运送到全身？ | 红细胞 | 白细胞 | 血小板 | 神经细胞
        ar: ما خلايا الدم التي تنقل الأكسجين في الجسم؟ | كريات الدم الحمراء | كريات الدم البيضاء | الصفائح الدموية | الخلايا العصبية

        # sci.heart-chambers science 2
        *: 4 | 2 | 3 | 6
        en: How many chambers does the human heart have?
        fr: Combien de cavités le cœur humain possède-t-il ?
        es: ¿Cuántas cavidades tiene el corazón humano?
        de: Wie viele Kammern und Vorhöfe hat das menschliche Herz zusammen?
        it: Quante cavità ha il cuore umano?
        pt: Quantas cavidades tem o coração humano?
        ja: 人間の心臓には部屋がいくつある？
        ko: 사람의 심장은 몇 개의 방으로 나뉘어 있을까요?
        zh: 人的心脏有几个腔？
        ar: كم حجرة في قلب الإنسان؟

        # sci.largest-organ science 2
        en: What is the largest organ of the human body? | The skin | The liver | The brain | The lungs
        fr: Quel est le plus grand organe du corps humain ? | La peau | Le foie | Le cerveau | Les poumons
        es: ¿Cuál es el órgano más grande del cuerpo humano? | La piel | El hígado | El cerebro | Los pulmones
        de: Was ist das größte Organ des menschlichen Körpers? | Die Haut | Die Leber | Das Gehirn | Die Lunge
        it: Qual è l'organo più grande del corpo umano? | La pelle | Il fegato | Il cervello | I polmoni
        pt: Qual é o maior órgão do corpo humano? | A pele | O fígado | O cérebro | Os pulmões
        ja: 人間の体でいちばん大きな器官は？ | 皮膚 | 肝臓 | 脳 | 肺
        ko: 사람 몸에서 가장 큰 기관은? | 피부 | 간 | 뇌 | 폐
        zh: 人体最大的器官是什么？ | 皮肤 | 肝脏 | 大脑 | 肺
        ar: ما أكبر عضو في جسم الإنسان؟ | الجلد | الكبد | الدماغ | الرئتان

        # sci.fastest science 1
        en: Which of these travels fastest? | Light | Sound | A bullet | A jet plane
        fr: Lequel va le plus vite ? | La lumière | Le son | Une balle de fusil | Un avion à réaction
        es: ¿Cuál de estos viaja más rápido? | La luz | El sonido | Una bala | Un avión a reacción
        de: Was davon ist am schnellsten? | Licht | Schall | Eine Gewehrkugel | Ein Düsenflugzeug
        it: Quale di questi viaggia più veloce? | La luce | Il suono | Un proiettile | Un aereo a reazione
        pt: Qual destes viaja mais rápido? | A luz | O som | Uma bala | Um avião a jato
        ja: この中でいちばん速く進むのは？ | 光 | 音 | 弾丸 | ジェット機
        ko: 이 중 가장 빠르게 이동하는 것은? | 빛 | 소리 | 총알 | 제트기
        zh: 下面哪个传播得最快？ | 光 | 声音 | 子弹 | 喷气式飞机
        ar: أيّ هذه ينتقل أسرع؟ | الضوء | الصوت | الرصاصة | الطائرة النفاثة

        # sci.table-salt science 2
        en: Table salt is mostly which compound? | Sodium chloride | Calcium carbonate | Potassium nitrate | Baking soda
        fr: Le sel de table est surtout composé de… | Chlorure de sodium | Carbonate de calcium | Nitrate de potassium | Bicarbonate de soude
        es: La sal de mesa es sobre todo… | Cloruro de sodio | Carbonato de calcio | Nitrato de potasio | Bicarbonato de sodio
        de: Speisesalz besteht vor allem aus… | Natriumchlorid | Calciumcarbonat | Kaliumnitrat | Natron
        it: Il sale da cucina è soprattutto… | Cloruro di sodio | Carbonato di calcio | Nitrato di potassio | Bicarbonato di sodio
        pt: O sal de cozinha é principalmente… | Cloreto de sódio | Carbonato de cálcio | Nitrato de potássio | Bicarbonato de sódio
        ja: 食塩のおもな成分は？ | 塩化ナトリウム | 炭酸カルシウム | 硝酸カリウム | 重曹
        ko: 식탁용 소금의 주성분은? | 염화나트륨 | 탄산칼슘 | 질산칼륨 | 베이킹소다
        zh: 食盐的主要成分是什么？ | 氯化钠 | 碳酸钙 | 硝酸钾 | 小苏打
        ar: ملح الطعام مكوّن أساسًا من… | كلوريد الصوديوم | كربونات الكالسيوم | نترات البوتاسيوم | بيكربونات الصوديوم

        # sci.iron-symbol science 2
        *: Fe | Ir | In | I
        en: What is the chemical symbol for iron?
        fr: Quel est le symbole chimique du fer ?
        es: ¿Cuál es el símbolo químico del hierro?
        de: Was ist das chemische Symbol für Eisen?
        it: Qual è il simbolo chimico del ferro?
        pt: Qual é o símbolo químico do ferro?
        ja: 鉄の元素記号は？
        ko: 철의 원소 기호는?
        zh: 铁的化学符号是什么？
        ar: ما الرمز الكيميائي للحديد؟

        # sci.newton science 1
        en: Who described the laws of motion and universal gravitation in 1687? | Isaac Newton | Albert Einstein | Galileo Galilei | Charles Darwin
        fr: Qui a décrit les lois du mouvement et la gravitation universelle en 1687 ? | Isaac Newton | Albert Einstein | Galilée | Charles Darwin
        es: ¿Quién describió las leyes del movimiento y la gravitación universal en 1687? | Isaac Newton | Albert Einstein | Galileo Galilei | Charles Darwin
        de: Wer beschrieb 1687 die Bewegungsgesetze und die allgemeine Gravitation? | Isaac Newton | Albert Einstein | Galileo Galilei | Charles Darwin
        it: Chi descrisse nel 1687 le leggi del moto e la gravitazione universale? | Isaac Newton | Albert Einstein | Galileo Galilei | Charles Darwin
        pt: Quem descreveu as leis do movimento e a gravitação universal em 1687? | Isaac Newton | Albert Einstein | Galileu Galilei | Charles Darwin
        ja: 1687年に運動の法則と万有引力を発表したのは？ | アイザック・ニュートン | アルベルト・アインシュタイン | ガリレオ・ガリレイ | チャールズ・ダーウィン
        ko: 1687년에 운동 법칙과 만유인력을 발표한 사람은? | 아이작 뉴턴 | 알베르트 아인슈타인 | 갈릴레오 갈릴레이 | 찰스 다윈
        zh: 1687年提出运动定律和万有引力的是谁？ | 艾萨克·牛顿 | 阿尔伯特·爱因斯坦 | 伽利略 | 查尔斯·达尔文
        ar: من وصف قوانين الحركة والجاذبية العامة عام 1687؟ | إسحاق نيوتن | ألبرت أينشتاين | غاليليو غاليلي | تشارلز داروين

        # sci.origin-of-species science 1
        en: Who wrote "On the Origin of Species" (1859)? | Charles Darwin | Gregor Mendel | Louis Pasteur | Isaac Newton
        fr: Qui a écrit « L'Origine des espèces » (1859) ? | Charles Darwin | Gregor Mendel | Louis Pasteur | Isaac Newton
        es: ¿Quién escribió «El origen de las especies» (1859)? | Charles Darwin | Gregor Mendel | Louis Pasteur | Isaac Newton
        de: Wer schrieb „Über die Entstehung der Arten“ (1859)? | Charles Darwin | Gregor Mendel | Louis Pasteur | Isaac Newton
        it: Chi scrisse «L'origine delle specie» (1859)? | Charles Darwin | Gregor Mendel | Louis Pasteur | Isaac Newton
        pt: Quem escreveu "A Origem das Espécies" (1859)? | Charles Darwin | Gregor Mendel | Louis Pasteur | Isaac Newton
        ja: 『種の起源』（1859年）を書いたのは？ | チャールズ・ダーウィン | グレゴール・メンデル | ルイ・パスツール | アイザック・ニュートン
        ko: 『종의 기원』(1859)을 쓴 사람은? | 찰스 다윈 | 그레고어 멘델 | 루이 파스퇴르 | 아이작 뉴턴
        zh: 《物种起源》（1859年）的作者是谁？ | 查尔斯·达尔文 | 格雷戈尔·孟德尔 | 路易·巴斯德 | 艾萨克·牛顿
        ar: من كتب «أصل الأنواع» (1859)؟ | تشارلز داروين | غريغور مندل | لويس باستور | إسحاق نيوتن

        # sci.penicillin science 2
        en: Who discovered penicillin in 1928? | Alexander Fleming | Louis Pasteur | Marie Curie | Robert Koch
        fr: Qui a découvert la pénicilline en 1928 ? | Alexander Fleming | Louis Pasteur | Marie Curie | Robert Koch
        es: ¿Quién descubrió la penicilina en 1928? | Alexander Fleming | Louis Pasteur | Marie Curie | Robert Koch
        de: Wer entdeckte 1928 das Penicillin? | Alexander Fleming | Louis Pasteur | Marie Curie | Robert Koch
        it: Chi scoprì la penicillina nel 1928? | Alexander Fleming | Louis Pasteur | Marie Curie | Robert Koch
        pt: Quem descobriu a penicilina em 1928? | Alexander Fleming | Louis Pasteur | Marie Curie | Robert Koch
        ja: 1928年にペニシリンを発見したのは？ | アレクサンダー・フレミング | ルイ・パスツール | マリ・キュリー | ロベルト・コッホ
        ko: 1928년에 페니실린을 발견한 사람은? | 알렉산더 플레밍 | 루이 파스퇴르 | 마리 퀴리 | 로베르트 코흐
        zh: 1928年发现青霉素的是谁？ | 亚历山大·弗莱明 | 路易·巴斯德 | 玛丽·居里 | 罗伯特·科赫
        ar: من اكتشف البنسلين عام 1928؟ | ألكسندر فليمنغ | لويس باستور | ماري كوري | روبرت كوخ

        # sci.curie-nobel science 2
        en: Marie Curie won Nobel Prizes in physics and in which other field? | Chemistry | Medicine | Literature | Peace
        fr: Marie Curie a reçu un prix Nobel de physique et un autre en… | Chimie | Médecine | Littérature | Paix
        es: Marie Curie ganó el Nobel de Física y también el de… | Química | Medicina | Literatura | la Paz
        de: Marie Curie erhielt den Nobelpreis für Physik und den für… | Chemie | Medizin | Literatur | Frieden
        it: Marie Curie vinse il Nobel per la fisica e quello per… | La chimica | La medicina | La letteratura | La pace
        pt: Marie Curie ganhou o Nobel de Física e também o de… | Química | Medicina | Literatura | Paz
        ja: マリ・キュリーがノーベル物理学賞のほかに受賞したのは？ | 化学賞 | 医学生理学賞 | 文学賞 | 平和賞
        ko: 마리 퀴리가 노벨 물리학상 말고 받은 상은? | 화학상 | 생리의학상 | 문학상 | 평화상
        zh: 居里夫人除了诺贝尔物理学奖，还获得了哪个奖？ | 化学奖 | 生理学或医学奖 | 文学奖 | 和平奖
        ar: نالت ماري كوري جائزة نوبل في الفيزياء وفي أي مجال آخر؟ | الكيمياء | الطب | الأدب | السلام

        # sci.air-oxygen science 3
        en: Roughly what share of the air we breathe is oxygen? | About 21% | About 50% | About 78% | About 5%
        fr: Quelle part environ de l'air que nous respirons est de l'oxygène ? | Environ 21 % | Environ 50 % | Environ 78 % | Environ 5 %
        es: ¿Qué parte aproximada del aire que respiramos es oxígeno? | Un 21 % | Un 50 % | Un 78 % | Un 5 %
        de: Welcher Anteil der Atemluft ist ungefähr Sauerstoff? | Etwa 21 % | Etwa 50 % | Etwa 78 % | Etwa 5 %
        it: Più o meno quanta parte dell'aria che respiriamo è ossigeno? | Circa il 21% | Circa il 50% | Circa il 78% | Circa il 5%
        pt: Mais ou menos quanto do ar que respiramos é oxigênio? | Cerca de 21% | Cerca de 50% | Cerca de 78% | Cerca de 5%
        ja: 私たちが吸う空気のうち、酸素はおよそ何％？ | 約21％ | 約50％ | 約78％ | 約5％
        ko: 우리가 숨 쉬는 공기 중 산소는 대략 몇 %일까요? | 약 21% | 약 50% | 약 78% | 약 5%
        zh: 我们呼吸的空气中，氧气大约占多少？ | 约21% | 约50% | 约78% | 约5%
        ar: ما النسبة التقريبية للأكسجين في الهواء الذي نتنفسه؟ | نحو 21٪ | نحو 50٪ | نحو 78٪ | نحو 5٪

        # sci.air-nitrogen science 2
        en: Which gas makes up most of Earth's atmosphere? | Nitrogen | Oxygen | Carbon dioxide | Argon
        fr: Quel gaz compose la plus grande partie de l'atmosphère terrestre ? | L'azote | L'oxygène | Le dioxyde de carbone | L'argon
        es: ¿Qué gas forma la mayor parte de la atmósfera terrestre? | Nitrógeno | Oxígeno | Dióxido de carbono | Argón
        de: Welches Gas macht den größten Teil der Erdatmosphäre aus? | Stickstoff | Sauerstoff | Kohlendioxid | Argon
        it: Quale gas forma la maggior parte dell'atmosfera terrestre? | Azoto | Ossigeno | Anidride carbonica | Argon
        pt: Que gás forma a maior parte da atmosfera da Terra? | Nitrogênio | Oxigênio | Gás carbônico | Argônio
        ja: 地球の大気でいちばん多い気体は？ | 窒素 | 酸素 | 二酸化炭素 | アルゴン
        ko: 지구 대기에서 가장 많은 기체는? | 질소 | 산소 | 이산화탄소 | 아르곤
        zh: 地球大气中含量最多的气体是什么？ | 氮气 | 氧气 | 二氧化碳 | 氩气
        ar: ما الغاز الذي يشكّل معظم الغلاف الجوي للأرض؟ | النيتروجين | الأكسجين | ثاني أكسيد الكربون | الأرغون

        # sci.neutral-ph science 3
        *: 7 | 0 | 1 | 14
        en: What is the pH of pure water at 25 °C?
        fr: Quel est le pH de l'eau pure à 25 °C ?
        es: ¿Cuál es el pH del agua pura a 25 °C?
        de: Welchen pH-Wert hat reines Wasser bei 25 °C?
        it: Qual è il pH dell'acqua pura a 25 °C?
        pt: Qual é o pH da água pura a 25 °C?
        ja: 25 °Cの純粋な水のpHは？
        ko: 25 °C에서 순수한 물의 pH는?
        zh: 25 °C时纯水的pH值是多少？
        ar: ما الرقم الهيدروجيني (pH) للماء النقي عند 25 °C؟

        # sci.liquid-metal science 2
        en: Which metal is liquid at room temperature? | Mercury | Iron | Aluminium | Lead
        fr: Quel métal est liquide à température ambiante ? | Le mercure | Le fer | L'aluminium | Le plomb
        es: ¿Qué metal es líquido a temperatura ambiente? | El mercurio | El hierro | El aluminio | El plomo
        de: Welches Metall ist bei Zimmertemperatur flüssig? | Quecksilber | Eisen | Aluminium | Blei
        it: Quale metallo è liquido a temperatura ambiente? | Il mercurio | Il ferro | L'alluminio | Il piombo
        pt: Que metal é líquido em temperatura ambiente? | Mercúrio | Ferro | Alumínio | Chumbo
        ja: 常温で液体の金属は？ | 水銀 | 鉄 | アルミニウム | 鉛
        ko: 상온에서 액체인 금속은? | 수은 | 철 | 알루미늄 | 납
        zh: 哪种金属在室温下是液体？ | 汞（水银） | 铁 | 铝 | 铅
        ar: ما المعدن السائل في درجة حرارة الغرفة؟ | الزئبق | الحديد | الألومنيوم | الرصاص

        # sci.insulin science 3
        en: Which organ makes insulin? | The pancreas | The liver | The kidneys | The stomach
        fr: Quel organe produit l'insuline ? | Le pancréas | Le foie | Les reins | L'estomac
        es: ¿Qué órgano produce la insulina? | El páncreas | El hígado | Los riñones | El estómago
        de: Welches Organ bildet Insulin? | Die Bauchspeicheldrüse | Die Leber | Die Nieren | Der Magen
        it: Quale organo produce l'insulina? | Il pancreas | Il fegato | I reni | Lo stomaco
        pt: Que órgão produz a insulina? | O pâncreas | O fígado | Os rins | O estômago
        ja: インスリンをつくる臓器は？ | すい臓 | 肝臓 | 腎臓 | 胃
        ko: 인슐린을 만드는 기관은? | 이자(췌장) | 간 | 콩팥 | 위
        zh: 哪个器官分泌胰岛素？ | 胰腺 | 肝脏 | 肾脏 | 胃
        ar: ما العضو الذي يفرز الإنسولين؟ | البنكرياس | الكبد | الكليتان | المعدة

        # sci.adult-teeth science 2
        *: 32 | 28 | 24 | 36
        en: How many teeth does an adult have, counting the wisdom teeth?
        fr: Combien de dents a un adulte, dents de sagesse comprises ?
        es: ¿Cuántos dientes tiene un adulto, contando las muelas del juicio?
        de: Wie viele Zähne hat ein Erwachsener, die Weisheitszähne mitgezählt?
        it: Quanti denti ha un adulto, contando i denti del giudizio?
        pt: Quantos dentes tem um adulto, contando os sisos?
        ja: 親知らずを含めて、大人の歯は何本？
        ko: 사랑니를 포함해 성인의 이는 몇 개일까요?
        zh: 算上智齿，成年人有多少颗牙？
        ar: كم سنًّا لدى الشخص البالغ، مع ضروس العقل؟

        # sci.chloroplast science 3
        en: In which part of a plant cell does photosynthesis happen? | The chloroplast | The mitochondrion | The nucleus | The cell wall
        fr: Dans quelle partie de la cellule végétale se fait la photosynthèse ? | Le chloroplaste | La mitochondrie | Le noyau | La paroi
        es: ¿En qué parte de la célula vegetal ocurre la fotosíntesis? | El cloroplasto | La mitocondria | El núcleo | La pared celular
        de: In welchem Teil der Pflanzenzelle findet die Fotosynthese statt? | Im Chloroplasten | In den Mitochondrien | Im Zellkern | In der Zellwand
        it: In quale parte della cellula vegetale avviene la fotosintesi? | Il cloroplasto | Il mitocondrio | Il nucleo | La parete cellulare
        pt: Em que parte da célula vegetal acontece a fotossíntese? | No cloroplasto | Na mitocôndria | No núcleo | Na parede celular
        ja: 植物の細胞で光合成が行われる場所は？ | 葉緑体 | ミトコンドリア | 核 | 細胞壁
        ko: 식물 세포에서 광합성이 일어나는 곳은? | 엽록체 | 미토콘드리아 | 핵 | 세포벽
        zh: 植物细胞的光合作用在哪里进行？ | 叶绿体 | 线粒体 | 细胞核 | 细胞壁
        ar: في أي جزء من الخلية النباتية يحدث البناء الضوئي؟ | البلاستيدات الخضراء | الميتوكوندريا | النواة | الجدار الخلوي

        # sci.powerhouse science 2
        en: Which part of a cell is often called its powerhouse? | The mitochondrion | The nucleus | The ribosome | The vacuole
        fr: Quelle partie de la cellule appelle-t-on souvent sa centrale énergétique ? | La mitochondrie | Le noyau | Le ribosome | La vacuole
        es: ¿Qué parte de la célula se suele llamar su central de energía? | La mitocondria | El núcleo | El ribosoma | La vacuola
        de: Welcher Zellteil wird oft das Kraftwerk der Zelle genannt? | Das Mitochondrium | Der Zellkern | Das Ribosom | Die Vakuole
        it: Quale parte della cellula è spesso chiamata la sua centrale energetica? | Il mitocondrio | Il nucleo | Il ribosoma | Il vacuolo
        pt: Que parte da célula costuma ser chamada de usina de energia? | A mitocôndria | O núcleo | O ribossomo | O vacúolo
        ja: 「細胞の発電所」とよく呼ばれるのは？ | ミトコンドリア | 核 | リボソーム | 液胞
        ko: 흔히 '세포의 발전소'라고 부르는 것은? | 미토콘드리아 | 핵 | 리보솜 | 액포
        zh: 常被称为细胞“发电站”的是什么？ | 线粒体 | 细胞核 | 核糖体 | 液泡
        ar: أي جزء من الخلية يُسمّى غالبًا محطة طاقتها؟ | الميتوكوندريا | النواة | الريبوسوم | الفجوة

        # sci.sun-vitamin science 2
        en: Which vitamin does your skin make in sunlight? | Vitamin D | Vitamin C | Vitamin A | Vitamin B12
        fr: Quelle vitamine la peau fabrique-t-elle au soleil ? | La vitamine D | La vitamine C | La vitamine A | La vitamine B12
        es: ¿Qué vitamina fabrica la piel con la luz del sol? | Vitamina D | Vitamina C | Vitamina A | Vitamina B12
        de: Welches Vitamin bildet die Haut im Sonnenlicht? | Vitamin D | Vitamin C | Vitamin A | Vitamin B12
        it: Quale vitamina produce la pelle alla luce del sole? | Vitamina D | Vitamina C | Vitamina A | Vitamina B12
        pt: Que vitamina a pele produz com a luz do sol? | Vitamina D | Vitamina C | Vitamina A | Vitamina B12
        ja: 日光を浴びると皮膚でつくられるビタミンは？ | ビタミンD | ビタミンC | ビタミンA | ビタミンB12
        ko: 햇빛을 받으면 피부에서 만들어지는 비타민은? | 비타민 D | 비타민 C | 비타민 A | 비타민 B12
        zh: 皮肤在阳光下会合成哪种维生素？ | 维生素D | 维生素C | 维生素A | 维生素B12
        ar: ما الفيتامين الذي يصنعه الجلد في ضوء الشمس؟ | فيتامين د | فيتامين ج | فيتامين أ | فيتامين ب12

        # sci.absolute-zero science 3
        en: Absolute zero is 0 on which temperature scale? | Kelvin | Celsius | Fahrenheit | Réaumur
        fr: Le zéro absolu vaut 0 sur quelle échelle de température ? | Kelvin | Celsius | Fahrenheit | Réaumur
        es: ¿En qué escala de temperatura vale 0 el cero absoluto? | Kelvin | Celsius | Fahrenheit | Réaumur
        de: Der absolute Nullpunkt ist 0 auf welcher Temperaturskala? | Kelvin | Celsius | Fahrenheit | Réaumur
        it: Lo zero assoluto vale 0 su quale scala di temperatura? | Kelvin | Celsius | Fahrenheit | Réaumur
        pt: O zero absoluto é 0 em qual escala de temperatura? | Kelvin | Celsius | Fahrenheit | Réaumur
        ja: 絶対零度が0になる温度の単位は？ | ケルビン | セルシウス度 | ファーレンハイト度 | レオミュール度
        ko: 절대 영도가 0인 온도 단위는? | 켈빈 | 섭씨 | 화씨 | 열씨
        zh: 绝对零度在哪种温标上是0？ | 开尔文 | 摄氏 | 华氏 | 列氏
        ar: الصفر المطلق يساوي 0 على أي مقياس حرارة؟ | كلفن | سلسيوس | فهرنهايت | ريومور

        # sci.richter science 2
        en: What does the Richter scale measure? | Earthquakes | Wind speed | Temperature | Rainfall
        fr: Que mesure l'échelle de Richter ? | Les séismes | La vitesse du vent | La température | La pluie
        es: ¿Qué mide la escala de Richter? | Los terremotos | La velocidad del viento | La temperatura | La lluvia
        de: Was misst die Richterskala? | Erdbeben | Windgeschwindigkeit | Temperatur | Niederschlag
        it: Che cosa misura la scala Richter? | I terremoti | La velocità del vento | La temperatura | La pioggia
        pt: O que a escala Richter mede? | Terremotos | Velocidade do vento | Temperatura | Chuva
        ja: リヒター・スケールが表すのは？ | 地震の規模 | 風の速さ | 気温 | 雨の量
        ko: 리히터 규모는 무엇을 나타낼까요? | 지진 | 바람의 세기 | 기온 | 강수량
        zh: 里氏震级衡量的是什么？ | 地震 | 风速 | 气温 | 降雨量
        ar: ماذا يقيس مقياس ريختر؟ | الزلازل | سرعة الرياح | الحرارة | الأمطار

        # sci.periodic-table science 2
        en: Who published a famous periodic table of the elements in 1869? | Dmitri Mendeleev | Antoine Lavoisier | John Dalton | Niels Bohr
        fr: Qui a publié en 1869 un célèbre tableau périodique des éléments ? | Dmitri Mendeleïev | Antoine Lavoisier | John Dalton | Niels Bohr
        es: ¿Quién publicó en 1869 una famosa tabla periódica de los elementos? | Dmitri Mendeléiev | Antoine Lavoisier | John Dalton | Niels Bohr
        de: Wer veröffentlichte 1869 ein berühmtes Periodensystem der Elemente? | Dmitri Mendelejew | Antoine Lavoisier | John Dalton | Niels Bohr
        it: Chi pubblicò nel 1869 una celebre tavola periodica degli elementi? | Dmitrij Mendeleev | Antoine Lavoisier | John Dalton | Niels Bohr
        pt: Quem publicou em 1869 uma famosa tabela periódica dos elementos? | Dmitri Mendeleiev | Antoine Lavoisier | John Dalton | Niels Bohr
        ja: 1869年に有名な元素の周期表を発表したのは？ | ドミトリ・メンデレーエフ | アントワーヌ・ラヴォアジエ | ジョン・ドルトン | ニールス・ボーア
        ko: 1869년에 유명한 원소 주기율표를 발표한 사람은? | 드미트리 멘델레예프 | 앙투안 라부아지에 | 존 돌턴 | 닐스 보어
        zh: 1869年发表著名元素周期表的是谁？ | 门捷列夫 | 拉瓦锡 | 道尔顿 | 玻尔
        ar: من نشر عام 1869 جدولًا دوريًا شهيرًا للعناصر؟ | ديمتري مندلييف | أنطوان لافوازييه | جون دالتون | نيلز بور

        # sci.emc2 science 1
        en: Which scientist is known for the equation E = mc²? | Albert Einstein | Isaac Newton | Nikola Tesla | Stephen Hawking
        fr: Quel scientifique est connu pour l'équation E = mc² ? | Albert Einstein | Isaac Newton | Nikola Tesla | Stephen Hawking
        es: ¿Qué científico es conocido por la ecuación E = mc²? | Albert Einstein | Isaac Newton | Nikola Tesla | Stephen Hawking
        de: Welcher Wissenschaftler ist für die Formel E = mc² bekannt? | Albert Einstein | Isaac Newton | Nikola Tesla | Stephen Hawking
        it: Quale scienziato è noto per l'equazione E = mc²? | Albert Einstein | Isaac Newton | Nikola Tesla | Stephen Hawking
        pt: Que cientista é conhecido pela equação E = mc²? | Albert Einstein | Isaac Newton | Nikola Tesla | Stephen Hawking
        ja: E = mc² の式で知られる科学者は？ | アルベルト・アインシュタイン | アイザック・ニュートン | ニコラ・テスラ | スティーヴン・ホーキング
        ko: E = mc² 공식으로 유명한 과학자는? | 알베르트 아인슈타인 | 아이작 뉴턴 | 니콜라 테슬라 | 스티븐 호킹
        zh: 哪位科学家以公式 E = mc² 闻名？ | 爱因斯坦 | 牛顿 | 特斯拉 | 霍金
        ar: أي عالم اشتهر بالمعادلة E = mc²؟ | ألبرت أينشتاين | إسحاق نيوتن | نيكولا تسلا | ستيفن هوكينغ

        # sci.dry-ice science 3
        en: Dry ice is the solid form of what? | Carbon dioxide | Water | Nitrogen | Oxygen
        fr: La glace carbonique est la forme solide de quoi ? | Du dioxyde de carbone | De l'eau | De l'azote | De l'oxygène
        es: El hielo seco es la forma sólida de… | Dióxido de carbono | Agua | Nitrógeno | Oxígeno
        de: Trockeneis ist die feste Form von… | Kohlendioxid | Wasser | Stickstoff | Sauerstoff
        it: Il ghiaccio secco è la forma solida di… | Anidride carbonica | Acqua | Azoto | Ossigeno
        pt: O gelo-seco é a forma sólida de… | Gás carbônico | Água | Nitrogênio | Oxigênio
        ja: ドライアイスは何が固体になったもの？ | 二酸化炭素 | 水 | 窒素 | 酸素
        ko: 드라이아이스는 무엇이 고체가 된 것일까요? | 이산화탄소 | 물 | 질소 | 산소
        zh: 干冰是什么物质的固态？ | 二氧化碳 | 水 | 氮气 | 氧气
        ar: الثلج الجاف هو الشكل الصلب لأي مادة؟ | ثاني أكسيد الكربون | الماء | النيتروجين | الأكسجين

        # sci.carbon-forms science 3
        en: Diamond and graphite are both made of which element? | Carbon | Silicon | Sulfur | Calcium
        fr: Le diamant et le graphite sont faits de quel élément ? | Le carbone | Le silicium | Le soufre | Le calcium
        es: ¿De qué elemento están hechos el diamante y el grafito? | Carbono | Silicio | Azufre | Calcio
        de: Aus welchem Element bestehen Diamant und Graphit? | Kohlenstoff | Silicium | Schwefel | Calcium
        it: Diamante e grafite sono fatti di quale elemento? | Carbonio | Silicio | Zolfo | Calcio
        pt: Diamante e grafite são feitos de qual elemento? | Carbono | Silício | Enxofre | Cálcio
        ja: ダイヤモンドと黒鉛は、どちらも何の元素でできている？ | 炭素 | ケイ素 | 硫黄 | カルシウム
        ko: 다이아몬드와 흑연은 모두 어떤 원소로 이루어져 있을까요? | 탄소 | 규소 | 황 | 칼슘
        zh: 钻石和石墨都由哪种元素构成？ | 碳 | 硅 | 硫 | 钙
        ar: الألماس والغرافيت كلاهما مكوّن من أي عنصر؟ | الكربون | السيليكون | الكبريت | الكالسيوم

        # sci.magnets science 1
        en: What do the opposite poles of two magnets do? | Attract each other | Repel each other | Nothing at all | Heat up
        fr: Que font les pôles opposés de deux aimants ? | Ils s'attirent | Ils se repoussent | Rien du tout | Ils chauffent
        es: ¿Qué hacen los polos opuestos de dos imanes? | Se atraen | Se repelen | Nada | Se calientan
        de: Was tun die entgegengesetzten Pole zweier Magnete? | Sie ziehen sich an | Sie stoßen sich ab | Gar nichts | Sie werden heiß
        it: Che cosa fanno i poli opposti di due magneti? | Si attraggono | Si respingono | Niente | Si scaldano
        pt: O que fazem os polos opostos de dois ímãs? | Se atraem | Se repelem | Nada | Esquentam
        ja: 2つの磁石の異なる極どうしはどうなる？ | 引き合う | 反発し合う | 何も起きない | 熱くなる
        ko: 두 자석의 서로 다른 극은 어떻게 될까요? | 서로 끌어당긴다 | 서로 밀어낸다 | 아무 일도 없다 | 뜨거워진다
        zh: 两块磁铁的异极靠近时会怎样？ | 相互吸引 | 相互排斥 | 什么都不发生 | 变热
        ar: ماذا يحدث بين القطبين المختلفين لمغناطيسين؟ | يتجاذبان | يتنافران | لا شيء | يسخنان

        # sci.chromosomes science 3
        *: 46 | 23 | 44 | 48
        en: How many chromosomes are in most human cells?
        fr: Combien de chromosomes y a-t-il dans la plupart des cellules humaines ?
        es: ¿Cuántos cromosomas hay en la mayoría de las células humanas?
        de: Wie viele Chromosomen enthalten die meisten menschlichen Zellen?
        it: Quanti cromosomi ci sono nella maggior parte delle cellule umane?
        pt: Quantos cromossomos há na maioria das células humanas?
        ja: ヒトのほとんどの細胞にある染色体の数は？
        ko: 사람 세포 대부분에 들어 있는 염색체 수는?
        zh: 人体大多数细胞有多少条染色体？
        ar: كم عدد الصبغيات (الكروموسومات) في معظم خلايا الإنسان؟

        # sci.breathe science 1
        en: Which gas do our bodies need from the air to live? | Oxygen | Carbon dioxide | Helium | Hydrogen
        fr: De quel gaz de l'air notre corps a-t-il besoin pour vivre ? | L'oxygène | Le dioxyde de carbone | L'hélium | L'hydrogène
        es: ¿Qué gas del aire necesita nuestro cuerpo para vivir? | Oxígeno | Dióxido de carbono | Helio | Hidrógeno
        de: Welches Gas aus der Luft braucht unser Körper zum Leben? | Sauerstoff | Kohlendioxid | Helium | Wasserstoff
        it: Di quale gas dell'aria ha bisogno il nostro corpo per vivere? | Ossigeno | Anidride carbonica | Elio | Idrogeno
        pt: De que gás do ar nosso corpo precisa para viver? | Oxigênio | Gás carbônico | Hélio | Hidrogênio
        ja: 私たちの体が生きるために空気から必要とする気体は？ | 酸素 | 二酸化炭素 | ヘリウム | 水素
        ko: 우리 몸이 살기 위해 공기에서 얻어야 하는 기체는? | 산소 | 이산화탄소 | 헬륨 | 수소
        zh: 我们的身体需要从空气中吸入哪种气体才能生存？ | 氧气 | 二氧化碳 | 氦气 | 氢气
        ar: ما الغاز الذي يحتاجه جسمنا من الهواء ليعيش؟ | الأكسجين | ثاني أكسيد الكربون | الهيليوم | الهيدروجين

        # sci.thermometer science 1
        en: What does a thermometer measure? | Temperature | Weight | Air pressure | Speed
        fr: Que mesure un thermomètre ? | La température | Le poids | La pression de l'air | La vitesse
        es: ¿Qué mide un termómetro? | La temperatura | El peso | La presión del aire | La velocidad
        de: Was misst ein Thermometer? | Die Temperatur | Das Gewicht | Den Luftdruck | Die Geschwindigkeit
        it: Che cosa misura un termometro? | La temperatura | Il peso | La pressione dell'aria | La velocità
        pt: O que um termômetro mede? | A temperatura | O peso | A pressão do ar | A velocidade
        ja: 温度計で測るものは？ | 温度 | 重さ | 気圧 | 速さ
        ko: 온도계로 재는 것은? | 온도 | 무게 | 기압 | 속도
        zh: 温度计测量的是什么？ | 温度 | 重量 | 气压 | 速度
        ar: ماذا يقيس الترمومتر (ميزان الحرارة)؟ | درجة الحرارة | الوزن | ضغط الهواء | السرعة

        # sci.barometer science 2
        en: What does a barometer measure? | Air pressure | Humidity | Wind speed | Temperature
        fr: Que mesure un baromètre ? | La pression de l'air | L'humidité | La vitesse du vent | La température
        es: ¿Qué mide un barómetro? | La presión del aire | La humedad | La velocidad del viento | La temperatura
        de: Was misst ein Barometer? | Den Luftdruck | Die Luftfeuchtigkeit | Die Windgeschwindigkeit | Die Temperatur
        it: Che cosa misura un barometro? | La pressione dell'aria | L'umidità | La velocità del vento | La temperatura
        pt: O que um barômetro mede? | A pressão do ar | A umidade | A velocidade do vento | A temperatura
        ja: 気圧計（バロメーター）で測るものは？ | 気圧 | 湿度 | 風速 | 気温
        ko: 기압계로 재는 것은? | 기압 | 습도 | 풍속 | 기온
        zh: 气压计测量的是什么？ | 气压 | 湿度 | 风速 | 温度
        ar: ماذا يقيس البارومتر؟ | ضغط الهواء | الرطوبة | سرعة الرياح | درجة الحرارة

        # sci.atom-center science 2
        en: What is at the centre of an atom? | The nucleus | An electron | A photon | A molecule
        fr: Qu'y a-t-il au centre d'un atome ? | Le noyau | Un électron | Un photon | Une molécule
        es: ¿Qué hay en el centro de un átomo? | El núcleo | Un electrón | Un fotón | Una molécula
        de: Was befindet sich im Zentrum eines Atoms? | Der Atomkern | Ein Elektron | Ein Photon | Ein Molekül
        it: Che cosa c'è al centro di un atomo? | Il nucleo | Un elettrone | Un fotone | Una molecola
        pt: O que fica no centro de um átomo? | O núcleo | Um elétron | Um fóton | Uma molécula
        ja: 原子の中心にあるのは？ | 原子核 | 電子 | 光子 | 分子
        ko: 원자의 중심에 있는 것은? | 원자핵 | 전자 | 광자 | 분자
        zh: 原子的中心是什么？ | 原子核 | 电子 | 光子 | 分子
        ar: ماذا يوجد في مركز الذرة؟ | النواة | إلكترون | فوتون | جزيء
        """
}
