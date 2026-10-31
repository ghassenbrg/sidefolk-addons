extension Games.QuizBank {
    // Tech: inventions and computing basics that don't date (no companies' fortunes, no "newest" anything).
    static let tech = """
        # tech.processor tech 1
        en: Which part of a computer carries out a program's instructions? | The processor (CPU) | The memory (RAM) | The hard drive | The screen
        fr: Quelle partie d'un ordinateur exécute les instructions d'un programme ? | Le processeur | La mémoire vive | Le disque dur | L'écran
        es: ¿Qué parte del ordenador ejecuta las instrucciones de un programa? | El procesador | La memoria RAM | El disco duro | La pantalla
        de: Welcher Teil eines Computers führt die Befehle eines Programms aus? | Der Prozessor | Der Arbeitsspeicher | Die Festplatte | Der Bildschirm
        it: Quale parte del computer esegue le istruzioni di un programma? | Il processore | La memoria RAM | Il disco rigido | Lo schermo
        pt: Que parte do computador executa as instruções de um programa? | O processador | A memória RAM | O disco rígido | A tela
        ja: プログラムの命令を実行するコンピューターの部品は？ | CPU（プロセッサー） | メモリー（RAM） | ハードディスク | 画面
        ko: 프로그램의 명령을 실행하는 컴퓨터 부품은? | 중앙 처리 장치(CPU) | 메모리(RAM) | 하드 디스크 | 화면
        zh: 电脑中执行程序指令的部件是什么？ | 处理器（CPU） | 内存（RAM） | 硬盘 | 屏幕
        ar: أي جزء في الحاسوب ينفّذ تعليمات البرنامج؟ | المعالج | الذاكرة العشوائية | القرص الصلب | الشاشة

        # tech.web-inventor tech 2
        en: Who invented the World Wide Web, in 1989? | Tim Berners-Lee | Bill Gates | Steve Jobs | Alan Turing
        fr: Qui a inventé le World Wide Web, en 1989 ? | Tim Berners-Lee | Bill Gates | Steve Jobs | Alan Turing
        es: ¿Quién inventó la World Wide Web, en 1989? | Tim Berners-Lee | Bill Gates | Steve Jobs | Alan Turing
        de: Wer erfand 1989 das World Wide Web? | Tim Berners-Lee | Bill Gates | Steve Jobs | Alan Turing
        it: Chi inventò il World Wide Web, nel 1989? | Tim Berners-Lee | Bill Gates | Steve Jobs | Alan Turing
        pt: Quem inventou a World Wide Web, em 1989? | Tim Berners-Lee | Bill Gates | Steve Jobs | Alan Turing
        ja: 1989年にワールド・ワイド・ウェブを考案したのは？ | ティム・バーナーズ＝リー | ビル・ゲイツ | スティーブ・ジョブズ | アラン・チューリング
        ko: 1989년에 월드 와이드 웹을 발명한 사람은? | 팀 버너스리 | 빌 게이츠 | 스티브 잡스 | 앨런 튜링
        zh: 1989年发明万维网的是谁？ | 蒂姆·伯纳斯-李 | 比尔·盖茨 | 史蒂夫·乔布斯 | 艾伦·图灵
        ar: من اخترع الشبكة العنكبوتية العالمية عام 1989؟ | تيم بيرنرز لي | بيل غيتس | ستيف جوبز | آلان تورينغ

        # tech.telephone-patent tech 2
        en: Who received the first patent for the telephone, in 1876? | Alexander Graham Bell | Thomas Edison | Nikola Tesla | Guglielmo Marconi
        fr: Qui a obtenu le premier brevet du téléphone, en 1876 ? | Alexander Graham Bell | Thomas Edison | Nikola Tesla | Guglielmo Marconi
        es: ¿Quién obtuvo la primera patente del teléfono, en 1876? | Alexander Graham Bell | Thomas Edison | Nikola Tesla | Guglielmo Marconi
        de: Wer erhielt 1876 das erste Patent auf das Telefon? | Alexander Graham Bell | Thomas Edison | Nikola Tesla | Guglielmo Marconi
        it: Chi ottenne il primo brevetto del telefono, nel 1876? | Alexander Graham Bell | Thomas Edison | Nikola Tesla | Guglielmo Marconi
        pt: Quem recebeu a primeira patente do telefone, em 1876? | Alexander Graham Bell | Thomas Edison | Nikola Tesla | Guglielmo Marconi
        ja: 1876年に電話の最初の特許を取ったのは？ | グラハム・ベル | トーマス・エジソン | ニコラ・テスラ | グリエルモ・マルコーニ
        ko: 1876년 전화기 특허를 처음 받은 사람은? | 알렉산더 그레이엄 벨 | 토머스 에디슨 | 니콜라 테슬라 | 굴리엘모 마르코니
        zh: 1876年获得第一项电话专利的是谁？ | 贝尔 | 爱迪生 | 特斯拉 | 马可尼
        ar: من حصل على أول براءة اختراع للهاتف عام 1876؟ | ألكسندر غراهام بيل | توماس إديسون | نيكولا تسلا | غولييلمو ماركوني

        # tech.binary tech 1
        en: Computers store everything using which number system? | Binary (0 and 1) | Decimal | Roman numerals | Base 60
        fr: Les ordinateurs stockent tout avec quel système de numération ? | Le binaire (0 et 1) | Le décimal | Les chiffres romains | La base 60
        es: ¿Con qué sistema de numeración guardan todo los ordenadores? | Binario (0 y 1) | Decimal | Números romanos | Base 60
        de: Mit welchem Zahlensystem speichern Computer alles? | Binär (0 und 1) | Dezimal | Römische Zahlen | Sechzigersystem
        it: Con quale sistema numerico i computer memorizzano tutto? | Binario (0 e 1) | Decimale | Numeri romani | Base 60
        pt: Os computadores guardam tudo usando qual sistema numérico? | Binário (0 e 1) | Decimal | Números romanos | Base 60
        ja: コンピューターはどんな数の表し方ですべてを記録する？ | 2進法（0と1） | 10進法 | ローマ数字 | 60進法
        ko: 컴퓨터는 어떤 수 체계로 모든 것을 저장할까요? | 2진법(0과 1) | 10진법 | 로마 숫자 | 60진법
        zh: 计算机用哪种数制存储一切？ | 二进制（0和1） | 十进制 | 罗马数字 | 六十进制
        ar: بأي نظام عددي تخزّن الحواسيب كل شيء؟ | النظام الثنائي (0 و1) | النظام العشري | الأرقام الرومانية | النظام الستيني

        # tech.byte tech 2
        *: 8 | 4 | 10 | 16
        en: How many bits are in one byte?
        fr: Combien de bits y a-t-il dans un octet ?
        es: ¿Cuántos bits hay en un byte?
        de: Wie viele Bits hat ein Byte?
        it: Quanti bit ci sono in un byte?
        pt: Quantos bits há em um byte?
        ja: 1バイトは何ビット？
        ko: 1바이트는 몇 비트일까요?
        zh: 一个字节有多少位（比特）？
        ar: كم بتًّا في البايت الواحد؟

        # tech.www tech 1
        en: In web addresses, what does "www" stand for? | World Wide Web | Wide Web World | Web With Words | World Web Window
        fr: Dans les adresses web, que signifie « www » ? | World Wide Web | Wide Web World | Web With Words | World Web Window
        es: En las direcciones web, ¿qué significa «www»? | World Wide Web | Wide Web World | Web With Words | World Web Window
        de: Wofür steht „www“ in Webadressen? | World Wide Web | Wide Web World | Web With Words | World Web Window
        it: Negli indirizzi web, che cosa significa «www»? | World Wide Web | Wide Web World | Web With Words | World Web Window
        pt: Nos endereços da web, o que significa "www"? | World Wide Web | Wide Web World | Web With Words | World Web Window
        ja: ウェブアドレスの「www」は何の略？ | World Wide Web | Wide Web World | Web With Words | World Web Window
        ko: 웹 주소의 'www'는 무엇의 줄임말일까요? | World Wide Web | Wide Web World | Web With Words | World Web Window
        zh: 网址里的“www”代表什么？ | World Wide Web | Wide Web World | Web With Words | World Web Window
        ar: ماذا تعني «www» في عناوين الويب؟ | World Wide Web | Wide Web World | Web With Words | World Web Window

        # tech.universal-machine tech 2
        en: Who described a "universal machine" in 1936, an idea behind every computer? | Alan Turing | Charles Babbage | John von Neumann | Ada Lovelace
        fr: Qui a décrit en 1936 une « machine universelle », idée à la base de tout ordinateur ? | Alan Turing | Charles Babbage | John von Neumann | Ada Lovelace
        es: ¿Quién describió en 1936 una «máquina universal», idea en la base de todo ordenador? | Alan Turing | Charles Babbage | John von Neumann | Ada Lovelace
        de: Wer beschrieb 1936 eine „universelle Maschine“, die Idee hinter jedem Computer? | Alan Turing | Charles Babbage | John von Neumann | Ada Lovelace
        it: Chi descrisse nel 1936 una «macchina universale», idea alla base di ogni computer? | Alan Turing | Charles Babbage | John von Neumann | Ada Lovelace
        pt: Quem descreveu em 1936 uma "máquina universal", ideia por trás de todo computador? | Alan Turing | Charles Babbage | John von Neumann | Ada Lovelace
        ja: 1936年、あらゆるコンピューターの基礎となる「万能機械」を考えたのは？ | アラン・チューリング | チャールズ・バベッジ | ジョン・フォン・ノイマン | エイダ・ラブレス
        ko: 1936년 모든 컴퓨터의 바탕이 된 '보편 기계'를 제시한 사람은? | 앨런 튜링 | 찰스 배비지 | 존 폰 노이만 | 에이다 러브레이스
        zh: 1936年提出“通用机器”、为计算机奠定基础的是谁？ | 艾伦·图灵 | 查尔斯·巴贝奇 | 冯·诺依曼 | 埃达·洛夫莱斯
        ar: من وصف عام 1936 «آلة شاملة» هي الفكرة وراء كل حاسوب؟ | آلان تورينغ | تشارلز باباج | جون فون نيومان | آدا لوفلايس

        # tech.lovelace tech 3
        en: Who is often called the first computer programmer? | Ada Lovelace | Grace Hopper | Marie Curie | Hedy Lamarr
        fr: Qui est souvent considérée comme la première programmeuse ? | Ada Lovelace | Grace Hopper | Marie Curie | Hedy Lamarr
        es: ¿A quién se suele considerar la primera programadora? | Ada Lovelace | Grace Hopper | Marie Curie | Hedy Lamarr
        de: Wer gilt oft als erste Programmiererin der Welt? | Ada Lovelace | Grace Hopper | Marie Curie | Hedy Lamarr
        it: Chi è spesso considerata la prima programmatrice? | Ada Lovelace | Grace Hopper | Marie Curie | Hedy Lamarr
        pt: Quem costuma ser chamada de primeira programadora? | Ada Lovelace | Grace Hopper | Marie Curie | Hedy Lamarr
        ja: 世界初のプログラマーとよく呼ばれるのは？ | エイダ・ラブレス | グレース・ホッパー | マリ・キュリー | ヘディ・ラマー
        ko: 흔히 최초의 프로그래머로 불리는 사람은? | 에이다 러브레이스 | 그레이스 호퍼 | 마리 퀴리 | 헤디 라마
        zh: 常被称为第一位程序员的是谁？ | 埃达·洛夫莱斯 | 格蕾丝·霍珀 | 居里夫人 | 海蒂·拉玛
        ar: من تُوصف غالبًا بأنها أول مبرمجة في التاريخ؟ | آدا لوفلايس | غريس هوبر | ماري كوري | هيدي لامار

        # tech.analytical-engine tech 3
        en: Who designed the Analytical Engine, a mechanical computer, in the 1830s? | Charles Babbage | Alan Turing | Blaise Pascal | Gottfried Leibniz
        fr: Qui a conçu dans les années 1830 la machine analytique, un ordinateur mécanique ? | Charles Babbage | Alan Turing | Blaise Pascal | Gottfried Leibniz
        es: ¿Quién diseñó en la década de 1830 la máquina analítica, un ordenador mecánico? | Charles Babbage | Alan Turing | Blaise Pascal | Gottfried Leibniz
        de: Wer entwarf in den 1830er-Jahren die Analytical Engine, einen mechanischen Computer? | Charles Babbage | Alan Turing | Blaise Pascal | Gottfried Leibniz
        it: Chi progettò negli anni 1830 la macchina analitica, un computer meccanico? | Charles Babbage | Alan Turing | Blaise Pascal | Gottfried Leibniz
        pt: Quem projetou nos anos 1830 a máquina analítica, um computador mecânico? | Charles Babbage | Alan Turing | Blaise Pascal | Gottfried Leibniz
        ja: 1830年代に機械式計算機「解析機関」を設計したのは？ | チャールズ・バベッジ | アラン・チューリング | ブレーズ・パスカル | ライプニッツ
        ko: 1830년대에 기계식 컴퓨터 '해석 기관'을 설계한 사람은? | 찰스 배비지 | 앨런 튜링 | 블레즈 파스칼 | 라이프니츠
        zh: 19世纪30年代设计机械计算机“分析机”的是谁？ | 查尔斯·巴贝奇 | 艾伦·图灵 | 帕斯卡 | 莱布尼茨
        ar: من صمّم في ثلاثينيات القرن التاسع عشر «المحرّك التحليلي»، وهو حاسوب ميكانيكي؟ | تشارلز باباج | آلان تورينغ | بليز باسكال | غوتفريد لايبنتس

        # tech.email-at tech 1
        *: @ | # | & | %
        en: Which symbol is in every email address?
        fr: Quel symbole se trouve dans toutes les adresses e-mail ?
        es: ¿Qué símbolo aparece en todas las direcciones de correo electrónico?
        de: Welches Zeichen steht in jeder E-Mail-Adresse?
        it: Quale simbolo c'è in ogni indirizzo email?
        pt: Que símbolo aparece em todo endereço de e-mail?
        ja: すべてのメールアドレスに入っている記号は？
        ko: 모든 이메일 주소에 들어 있는 기호는?
        zh: 每个电子邮件地址里都有哪个符号？
        ar: ما الرمز الموجود في كل عنوان بريد إلكتروني؟

        # tech.gps tech 2
        en: GPS finds your position using signals from what? | Satellites | Radio towers | Undersea cables | Lighthouses
        fr: Le GPS trouve votre position grâce aux signaux de quoi ? | De satellites | D'antennes radio | De câbles sous-marins | De phares
        es: ¿Con señales de qué encuentra el GPS tu posición? | De satélites | De torres de radio | De cables submarinos | De faros
        de: Mit Signalen wovon bestimmt GPS deine Position? | Von Satelliten | Von Funktürmen | Von Seekabeln | Von Leuchttürmen
        it: Con i segnali di che cosa il GPS trova la tua posizione? | Dei satelliti | Delle antenne radio | Dei cavi sottomarini | Dei fari
        pt: O GPS encontra sua posição usando sinais de quê? | Satélites | Torres de rádio | Cabos submarinos | Faróis
        ja: GPSは何からの信号で位置を割り出す？ | 人工衛星 | 電波塔 | 海底ケーブル | 灯台
        ko: GPS는 무엇에서 오는 신호로 위치를 알아낼까요? | 인공위성 | 전파 송신탑 | 해저 케이블 | 등대
        zh: GPS利用来自什么的信号确定位置？ | 卫星 | 广播塔 | 海底电缆 | 灯塔
        ar: يحدّد نظام GPS موقعك بإشارات من ماذا؟ | الأقمار الصناعية | أبراج الراديو | الكابلات البحرية | المنارات

        # tech.solar-panel tech 1
        en: What do solar panels turn sunlight into? | Electricity | Water | Wind | Gas
        fr: En quoi les panneaux solaires transforment-ils la lumière du soleil ? | En électricité | En eau | En vent | En gaz
        es: ¿En qué convierten la luz del sol los paneles solares? | En electricidad | En agua | En viento | En gas
        de: Wozu machen Solarmodule Sonnenlicht? | Zu Strom | Zu Wasser | Zu Wind | Zu Gas
        it: In che cosa trasformano la luce del sole i pannelli solari? | In elettricità | In acqua | In vento | In gas
        pt: Em que os painéis solares transformam a luz do sol? | Em eletricidade | Em água | Em vento | Em gás
        ja: 太陽光パネルは日光を何に変える？ | 電気 | 水 | 風 | ガス
        ko: 태양광 패널은 햇빛을 무엇으로 바꿀까요? | 전기 | 물 | 바람 | 가스
        zh: 太阳能电池板把阳光转化成什么？ | 电 | 水 | 风 | 燃气
        ar: إلى ماذا تحوّل الألواح الشمسية ضوء الشمس؟ | الكهرباء | الماء | الرياح | الغاز

        # tech.wind-turbine tech 1
        en: A wind turbine makes electricity from what? | Moving air | Sunlight | Coal | Sea tides
        fr: Une éolienne produit de l'électricité à partir de quoi ? | Du vent | Du soleil | Du charbon | Des marées
        es: ¿De qué produce electricidad un aerogenerador? | Del viento | De la luz del sol | Del carbón | De las mareas
        de: Woraus erzeugt ein Windrad Strom? | Aus Wind | Aus Sonnenlicht | Aus Kohle | Aus Gezeiten
        it: Da che cosa produce elettricità una pala eolica? | Dal vento | Dalla luce del sole | Dal carbone | Dalle maree
        pt: Uma turbina eólica gera eletricidade a partir de quê? | Do vento | Da luz do sol | Do carvão | Das marés
        ja: 風力発電機は何から電気をつくる？ | 風 | 日光 | 石炭 | 潮の満ち引き
        ko: 풍력 발전기는 무엇으로 전기를 만들까요? | 바람 | 햇빛 | 석탄 | 밀물과 썰물
        zh: 风力发电机用什么发电？ | 风 | 阳光 | 煤 | 潮汐
        ar: من أي شيء تولّد التوربينة الهوائية الكهرباء؟ | الرياح | ضوء الشمس | الفحم | المدّ والجزر

        # tech.steam-engine tech 3
        en: Who greatly improved the steam engine in the 1760s and 1770s? | James Watt | Thomas Edison | Henry Ford | Isaac Newton
        fr: Qui a beaucoup amélioré la machine à vapeur dans les années 1760 et 1770 ? | James Watt | Thomas Edison | Henry Ford | Isaac Newton
        es: ¿Quién mejoró mucho la máquina de vapor en las décadas de 1760 y 1770? | James Watt | Thomas Edison | Henry Ford | Isaac Newton
        de: Wer verbesserte die Dampfmaschine in den 1760er- und 1770er-Jahren entscheidend? | James Watt | Thomas Edison | Henry Ford | Isaac Newton
        it: Chi migliorò molto la macchina a vapore negli anni 1760 e 1770? | James Watt | Thomas Edison | Henry Ford | Isaac Newton
        pt: Quem aperfeiçoou muito a máquina a vapor nas décadas de 1760 e 1770? | James Watt | Thomas Edison | Henry Ford | Isaac Newton
        ja: 1760〜70年代に蒸気機関を大きく改良したのは？ | ジェームズ・ワット | トーマス・エジソン | ヘンリー・フォード | アイザック・ニュートン
        ko: 1760~1770년대에 증기 기관을 크게 개량한 사람은? | 제임스 와트 | 토머스 에디슨 | 헨리 포드 | 아이작 뉴턴
        zh: 18世纪六七十年代大幅改进蒸汽机的是谁？ | 詹姆斯·瓦特 | 爱迪生 | 亨利·福特 | 牛顿
        ar: من حسّن المحرك البخاري كثيرًا في ستينيات وسبعينيات القرن الثامن عشر؟ | جيمس واط | توماس إديسون | هنري فورد | إسحاق نيوتن

        # tech.model-t tech 2
        en: What was Henry Ford's famous car of 1908 called? | The Model T | The Beetle | The Mini | The 2CV
        fr: Comment s'appelait la célèbre voiture de Henry Ford sortie en 1908 ? | La Ford T | La Coccinelle | La Mini | La 2 CV
        es: ¿Cómo se llamaba el famoso coche de Henry Ford de 1908? | El Modelo T | El Escarabajo | El Mini | El 2CV
        de: Wie hieß Henry Fords berühmtes Auto von 1908? | Modell T | Käfer | Mini | 2CV („Ente“)
        it: Come si chiamava la famosa auto di Henry Ford del 1908? | La Model T | Il Maggiolino | La Mini | La 2CV
        pt: Como se chamava o famoso carro de Henry Ford de 1908? | O Modelo T | O Fusca | O Mini | O 2CV
        ja: ヘンリー・フォードが1908年に出した有名な車は？ | T型フォード | ビートル | ミニ | 2CV
        ko: 헨리 포드가 1908년에 내놓은 유명한 자동차는? | 모델 T | 비틀 | 미니 | 2CV
        zh: 亨利·福特1908年推出的著名汽车叫什么？ | T型车 | 甲壳虫 | 迷你 | 2CV
        ar: ما اسم سيارة هنري فورد الشهيرة عام 1908؟ | موديل T | الخنفساء (بيتل) | ميني | 2CV

        # tech.pixel tech 2
        en: What are the tiny dots that make up a picture on a screen called? | Pixels | Bytes | Atoms | Chips
        fr: Comment s'appellent les petits points qui forment l'image d'un écran ? | Les pixels | Les octets | Les atomes | Les puces
        es: ¿Cómo se llaman los puntitos que forman la imagen de una pantalla? | Píxeles | Bytes | Átomos | Chips
        de: Wie heißen die winzigen Punkte, aus denen ein Bildschirmbild besteht? | Pixel | Bytes | Atome | Chips
        it: Come si chiamano i puntini che formano l'immagine di uno schermo? | Pixel | Byte | Atomi | Chip
        pt: Como se chamam os pontinhos que formam a imagem de uma tela? | Pixels | Bytes | Átomos | Chips
        ja: 画面の画像をつくっている小さな点を何という？ | ピクセル（画素） | バイト | 原子 | チップ
        ko: 화면의 그림을 이루는 아주 작은 점을 무엇이라고 할까요? | 픽셀(화소) | 바이트 | 원자 | 칩
        zh: 构成屏幕图像的小点叫什么？ | 像素 | 字节 | 原子 | 芯片
        ar: ماذا تُسمّى النقاط الصغيرة التي تكوّن صورة الشاشة؟ | البكسلات | البايتات | الذرات | الرقائق

        # tech.html tech 3
        en: What is HTML mainly used for? | Building web pages | Storing passwords | Shrinking photos | Playing music
        fr: À quoi sert principalement le HTML ? | À construire des pages web | À stocker des mots de passe | À compresser des photos | À jouer de la musique
        es: ¿Para qué se usa sobre todo el HTML? | Para crear páginas web | Para guardar contraseñas | Para comprimir fotos | Para reproducir música
        de: Wofür wird HTML hauptsächlich verwendet? | Zum Aufbau von Webseiten | Zum Speichern von Passwörtern | Zum Verkleinern von Fotos | Zum Abspielen von Musik
        it: A che cosa serve soprattutto l'HTML? | A creare pagine web | A conservare password | A comprimere foto | A riprodurre musica
        pt: Para que serve principalmente o HTML? | Para montar páginas da web | Para guardar senhas | Para comprimir fotos | Para tocar música
        ja: HTMLはおもに何に使われる？ | ウェブページをつくる | パスワードを保存する | 写真を圧縮する | 音楽を再生する
        ko: HTML은 주로 무엇에 쓰일까요? | 웹 페이지 만들기 | 비밀번호 저장 | 사진 압축 | 음악 재생
        zh: HTML主要用来做什么？ | 构建网页 | 保存密码 | 压缩照片 | 播放音乐
        ar: فيمَ تُستخدم لغة HTML أساسًا؟ | بناء صفحات الويب | حفظ كلمات المرور | ضغط الصور | تشغيل الموسيقى

        # tech.bluetooth tech 3
        en: Bluetooth is named after a king of which country? | Denmark | England | France | Spain
        fr: Le Bluetooth doit son nom à un roi de quel pays ? | Le Danemark | L'Angleterre | La France | L'Espagne
        es: El Bluetooth debe su nombre a un rey de… | Dinamarca | Inglaterra | Francia | España
        de: Bluetooth ist nach einem König welches Landes benannt? | Dänemark | England | Frankreich | Spanien
        it: Il Bluetooth prende il nome da un re di quale Paese? | Danimarca | Inghilterra | Francia | Spagna
        pt: O Bluetooth tem o nome de um rei de qual país? | Dinamarca | Inglaterra | França | Espanha
        ja: ブルートゥースの名前の由来になったのはどの国の王？ | デンマーク | イングランド | フランス | スペイン
        ko: 블루투스라는 이름은 어느 나라 왕에게서 왔을까요? | 덴마크 | 잉글랜드 | 프랑스 | 스페인
        zh: 蓝牙的名字来自哪个国家的一位国王？ | 丹麦 | 英格兰 | 法国 | 西班牙
        ar: سُمّيت تقنية البلوتوث باسم ملك من أي بلد؟ | الدنمارك | إنجلترا | فرنسا | إسبانيا

        # tech.morse tech 2
        en: What does Morse code use to spell letters? | Dots and dashes | Colours | Pictures | Musical notes
        fr: Avec quoi le code Morse écrit-il les lettres ? | Des points et des traits | Des couleurs | Des images | Des notes de musique
        es: ¿Qué usa el código morse para formar letras? | Puntos y rayas | Colores | Dibujos | Notas musicales
        de: Womit bildet der Morsecode Buchstaben? | Mit Punkten und Strichen | Mit Farben | Mit Bildern | Mit Noten
        it: Che cosa usa il codice Morse per formare le lettere? | Punti e linee | Colori | Immagini | Note musicali
        pt: O que o código Morse usa para formar letras? | Pontos e traços | Cores | Desenhos | Notas musicais
        ja: モールス信号は何で文字を表す？ | 点と線（トンとツー） | 色 | 絵 | 音符
        ko: 모스 부호는 무엇으로 글자를 나타낼까요? | 점과 선 | 색깔 | 그림 | 음표
        zh: 摩尔斯电码用什么表示字母？ | 点和划 | 颜色 | 图画 | 音符
        ar: بماذا تكتب شيفرة مورس الحروف؟ | النقاط والشرطات | الألوان | الصور | النوتات الموسيقية

        # tech.galileo-telescope tech 2
        en: Who used a telescope in 1610 to discover moons of Jupiter? | Galileo Galilei | Nicolaus Copernicus | Johannes Kepler | Isaac Newton
        fr: Qui a découvert des lunes de Jupiter avec une lunette en 1610 ? | Galilée | Nicolas Copernic | Johannes Kepler | Isaac Newton
        es: ¿Quién descubrió lunas de Júpiter con un telescopio en 1610? | Galileo Galilei | Nicolás Copérnico | Johannes Kepler | Isaac Newton
        de: Wer entdeckte 1610 mit einem Fernrohr Monde des Jupiter? | Galileo Galilei | Nikolaus Kopernikus | Johannes Kepler | Isaac Newton
        it: Chi scoprì nel 1610 delle lune di Giove con un cannocchiale? | Galileo Galilei | Niccolò Copernico | Giovanni Keplero | Isaac Newton
        pt: Quem descobriu luas de Júpiter com um telescópio em 1610? | Galileu Galilei | Nicolau Copérnico | Johannes Kepler | Isaac Newton
        ja: 1610年に望遠鏡で木星の衛星を発見したのは？ | ガリレオ・ガリレイ | コペルニクス | ケプラー | ニュートン
        ko: 1610년 망원경으로 목성의 위성을 발견한 사람은? | 갈릴레오 갈릴레이 | 코페르니쿠스 | 케플러 | 뉴턴
        zh: 1610年用望远镜发现木星卫星的是谁？ | 伽利略 | 哥白尼 | 开普勒 | 牛顿
        ar: من اكتشف أقمار المشتري بالتلسكوب عام 1610؟ | غاليليو غاليلي | نيكولاس كوبرنيكوس | يوهانس كبلر | إسحاق نيوتن

        # tech.microscope tech 1
        en: Which tool makes tiny things look much bigger? | A microscope | A telescope | A stethoscope | A periscope
        fr: Quel instrument fait paraître beaucoup plus grandes les choses minuscules ? | Le microscope | Le télescope | Le stéthoscope | Le périscope
        es: ¿Qué instrumento hace que las cosas diminutas se vean mucho más grandes? | El microscopio | El telescopio | El estetoscopio | El periscopio
        de: Welches Gerät lässt winzige Dinge viel größer aussehen? | Das Mikroskop | Das Teleskop | Das Stethoskop | Das Periskop
        it: Quale strumento fa sembrare molto più grandi le cose minuscole? | Il microscopio | Il telescopio | Lo stetoscopio | Il periscopio
        pt: Que instrumento faz coisas minúsculas parecerem muito maiores? | O microscópio | O telescópio | O estetoscópio | O periscópio
        ja: とても小さなものを大きく見せる道具は？ | 顕微鏡 | 望遠鏡 | 聴診器 | 潜望鏡
        ko: 아주 작은 것을 크게 보여 주는 도구는? | 현미경 | 망원경 | 청진기 | 잠망경
        zh: 哪种工具能让微小的东西看起来大得多？ | 显微镜 | 望远镜 | 听诊器 | 潜望镜
        ar: أي أداة تجعل الأشياء الدقيقة تبدو أكبر بكثير؟ | المجهر | التلسكوب | السمّاعة الطبية | المنظار (البيريسكوب)

        # tech.compass tech 2
        en: Which way does a compass needle point? | Towards magnetic north | Towards the Sun | Towards the equator | Towards the Moon
        fr: Vers où pointe l'aiguille d'une boussole ? | Vers le nord magnétique | Vers le Soleil | Vers l'équateur | Vers la Lune
        es: ¿Hacia dónde apunta la aguja de una brújula? | Hacia el norte magnético | Hacia el Sol | Hacia el ecuador | Hacia la Luna
        de: Wohin zeigt die Nadel eines Kompasses? | Nach magnetisch Nord | Zur Sonne | Zum Äquator | Zum Mond
        it: Verso dove punta l'ago di una bussola? | Verso il nord magnetico | Verso il Sole | Verso l'equatore | Verso la Luna
        pt: Para onde aponta a agulha de uma bússola? | Para o norte magnético | Para o Sol | Para o equador | Para a Lua
        ja: 方位磁針の針はどちらを指す？ | 磁北 | 太陽 | 赤道 | 月
        ko: 나침반 바늘은 어느 쪽을 가리킬까요? | 자북 | 태양 | 적도 | 달
        zh: 指南针的磁针（N极）指向哪里？ | 磁北 | 太阳 | 赤道 | 月亮
        ar: إلى أين تشير إبرة البوصلة؟ | إلى الشمال المغناطيسي | إلى الشمس | إلى خط الاستواء | إلى القمر

        # tech.x-rays tech 2
        en: Who discovered X-rays, in 1895? | Wilhelm Röntgen | Marie Curie | Thomas Edison | Max Planck
        fr: Qui a découvert les rayons X, en 1895 ? | Wilhelm Röntgen | Marie Curie | Thomas Edison | Max Planck
        es: ¿Quién descubrió los rayos X, en 1895? | Wilhelm Röntgen | Marie Curie | Thomas Edison | Max Planck
        de: Wer entdeckte 1895 die Röntgenstrahlen? | Wilhelm Conrad Röntgen | Marie Curie | Thomas Edison | Max Planck
        it: Chi scoprì i raggi X, nel 1895? | Wilhelm Röntgen | Marie Curie | Thomas Edison | Max Planck
        pt: Quem descobriu os raios X, em 1895? | Wilhelm Röntgen | Marie Curie | Thomas Edison | Max Planck
        ja: 1895年にX線を発見したのは？ | ヴィルヘルム・レントゲン | マリ・キュリー | トーマス・エジソン | マックス・プランク
        ko: 1895년에 X선을 발견한 사람은? | 빌헬름 뢴트겐 | 마리 퀴리 | 토머스 에디슨 | 막스 플랑크
        zh: 1895年发现X射线的是谁？ | 伦琴 | 居里夫人 | 爱迪生 | 普朗克
        ar: من اكتشف الأشعة السينية عام 1895؟ | فيلهلم رونتغن | ماري كوري | توماس إديسون | ماكس بلانك

        # tech.volta tech 3
        en: Who invented the first electric battery, around 1800? | Alessandro Volta | Benjamin Franklin | Michael Faraday | André-Marie Ampère
        fr: Qui a inventé la première pile électrique, vers 1800 ? | Alessandro Volta | Benjamin Franklin | Michael Faraday | André-Marie Ampère
        es: ¿Quién inventó la primera pila eléctrica, hacia 1800? | Alessandro Volta | Benjamin Franklin | Michael Faraday | André-Marie Ampère
        de: Wer erfand um 1800 die erste elektrische Batterie? | Alessandro Volta | Benjamin Franklin | Michael Faraday | André-Marie Ampère
        it: Chi inventò la prima pila elettrica, intorno al 1800? | Alessandro Volta | Benjamin Franklin | Michael Faraday | André-Marie Ampère
        pt: Quem inventou a primeira pilha elétrica, por volta de 1800? | Alessandro Volta | Benjamin Franklin | Michael Faraday | André-Marie Ampère
        ja: 1800年ごろ最初の電池を発明したのは？ | アレッサンドロ・ボルタ | ベンジャミン・フランクリン | マイケル・ファラデー | アンペール
        ko: 1800년 무렵 최초의 전지를 발명한 사람은? | 알레산드로 볼타 | 벤저민 프랭클린 | 마이클 패러데이 | 앙드레마리 앙페르
        zh: 约1800年发明第一个电池的是谁？ | 伏打 | 富兰克林 | 法拉第 | 安培
        ar: من اخترع أول بطارية كهربائية نحو عام 1800؟ | أليساندرو فولتا | بنجامين فرانكلين | مايكل فاراداي | أندريه ماري أمبير

        # tech.watts tech 2
        en: Electric power is measured in which unit? | Watts | Litres | Metres | Grams
        fr: En quelle unité mesure-t-on la puissance électrique ? | En watts | En litres | En mètres | En grammes
        es: ¿En qué unidad se mide la potencia eléctrica? | Vatios | Litros | Metros | Gramos
        de: In welcher Einheit misst man elektrische Leistung? | Watt | Liter | Meter | Gramm
        it: In quale unità si misura la potenza elettrica? | Watt | Litri | Metri | Grammi
        pt: Em que unidade se mede a potência elétrica? | Watts | Litros | Metros | Gramas
        ja: 電力の単位は？ | ワット | リットル | メートル | グラム
        ko: 전력의 단위는? | 와트 | 리터 | 미터 | 그램
        zh: 电功率的单位是什么？ | 瓦特 | 升 | 米 | 克
        ar: بأي وحدة تُقاس القدرة الكهربائية؟ | الواط | اللتر | المتر | الغرام

        # tech.shinkansen tech 2
        en: The Shinkansen is the high-speed train of which country? | Japan | China | France | Germany
        fr: Le Shinkansen est le train à grande vitesse de quel pays ? | Le Japon | La Chine | La France | L'Allemagne
        es: ¿De qué país es el tren de alta velocidad Shinkansen? | Japón | China | Francia | Alemania
        de: Der Shinkansen ist der Hochgeschwindigkeitszug welches Landes? | Japan | China | Frankreich | Deutschland
        it: Lo Shinkansen è il treno ad alta velocità di quale Paese? | Giappone | Cina | Francia | Germania
        pt: O Shinkansen é o trem de alta velocidade de qual país? | Japão | China | França | Alemanha
        ja: 新幹線はどの国の高速鉄道？ | 日本 | 中国 | フランス | ドイツ
        ko: 신칸센은 어느 나라의 고속 열차일까요? | 일본 | 중국 | 프랑스 | 독일
        zh: 新干线是哪个国家的高速列车？ | 日本 | 中国 | 法国 | 德国
        ar: الشينكانسن قطار فائق السرعة في أي بلد؟ | اليابان | الصين | فرنسا | ألمانيا

        # tech.robot-word tech 3
        en: The word "robot" first appeared in a play written in which language? | Czech | Russian | German | Japanese
        fr: Le mot « robot » est apparu dans une pièce écrite en quelle langue ? | Le tchèque | Le russe | L'allemand | Le japonais
        es: ¿En qué idioma se escribió la obra de teatro donde apareció la palabra «robot»? | Checo | Ruso | Alemán | Japonés
        de: In welcher Sprache wurde das Theaterstück geschrieben, in dem das Wort „Roboter“ zuerst vorkam? | Tschechisch | Russisch | Deutsch | Japanisch
        it: In quale lingua fu scritta l'opera teatrale in cui comparve la parola «robot»? | Ceco | Russo | Tedesco | Giapponese
        pt: Em que língua foi escrita a peça em que surgiu a palavra "robô"? | Tcheco | Russo | Alemão | Japonês
        ja: 「ロボット」という言葉が初めて登場した戯曲は何語で書かれた？ | チェコ語 | ロシア語 | ドイツ語 | 日本語
        ko: '로봇'이라는 말이 처음 나온 희곡은 어느 언어로 쓰였을까요? | 체코어 | 러시아어 | 독일어 | 일본어
        zh: “机器人（robot）”一词最早出现在用哪种语言写的剧本里？ | 捷克语 | 俄语 | 德语 | 日语
        ar: بأي لغة كُتبت المسرحية التي ظهرت فيها كلمة «روبوت» أول مرة؟ | التشيكية | الروسية | الألمانية | اليابانية

        # tech.qr-code tech 3
        en: In which country was the QR code invented? | Japan | South Korea | The United States | Germany
        fr: Dans quel pays le QR code a-t-il été inventé ? | Le Japon | La Corée du Sud | Les États-Unis | L'Allemagne
        es: ¿En qué país se inventó el código QR? | Japón | Corea del Sur | Estados Unidos | Alemania
        de: In welchem Land wurde der QR-Code erfunden? | Japan | Südkorea | USA | Deutschland
        it: In quale Paese fu inventato il codice QR? | Giappone | Corea del Sud | Stati Uniti | Germania
        pt: Em que país o QR code foi inventado? | Japão | Coreia do Sul | Estados Unidos | Alemanha
        ja: QRコードが発明された国は？ | 日本 | 韓国 | アメリカ合衆国 | ドイツ
        ko: QR 코드가 발명된 나라는? | 일본 | 한국 | 미국 | 독일
        zh: 二维码（QR码）是在哪个国家发明的？ | 日本 | 韩国 | 美国 | 德国
        ar: في أي بلد اختُرع رمز QR؟ | اليابان | كوريا الجنوبية | الولايات المتحدة | ألمانيا

        # tech.emoji-word tech 3
        en: The word "emoji" comes from which language? | Japanese | English | Korean | Chinese
        fr: De quelle langue vient le mot « emoji » ? | Du japonais | De l'anglais | Du coréen | Du chinois
        es: ¿De qué idioma viene la palabra «emoji»? | Del japonés | Del inglés | Del coreano | Del chino
        de: Aus welcher Sprache stammt das Wort „Emoji“? | Aus dem Japanischen | Aus dem Englischen | Aus dem Koreanischen | Aus dem Chinesischen
        it: Da quale lingua viene la parola «emoji»? | Dal giapponese | Dall'inglese | Dal coreano | Dal cinese
        pt: De que língua vem a palavra "emoji"? | Do japonês | Do inglês | Do coreano | Do chinês
        ja: 「絵文字（emoji）」はもともと何語？ | 日本語 | 英語 | 韓国語 | 中国語
        ko: '이모지(emoji)'라는 말은 어느 언어에서 왔을까요? | 일본어 | 영어 | 한국어 | 중국어
        zh: “emoji”这个词来自哪种语言？ | 日语 | 英语 | 韩语 | 汉语
        ar: من أي لغة جاءت كلمة «إيموجي»؟ | اليابانية | الإنجليزية | الكورية | الصينية

        # tech.lightning-rod tech 3
        en: Who invented the lightning rod? | Benjamin Franklin | Thomas Edison | Nikola Tesla | James Watt
        fr: Qui a inventé le paratonnerre ? | Benjamin Franklin | Thomas Edison | Nikola Tesla | James Watt
        es: ¿Quién inventó el pararrayos? | Benjamin Franklin | Thomas Edison | Nikola Tesla | James Watt
        de: Wer erfand den Blitzableiter? | Benjamin Franklin | Thomas Edison | Nikola Tesla | James Watt
        it: Chi inventò il parafulmine? | Benjamin Franklin | Thomas Edison | Nikola Tesla | James Watt
        pt: Quem inventou o para-raios? | Benjamin Franklin | Thomas Edison | Nikola Tesla | James Watt
        ja: 避雷針を発明したのは？ | ベンジャミン・フランクリン | トーマス・エジソン | ニコラ・テスラ | ジェームズ・ワット
        ko: 피뢰침을 발명한 사람은? | 벤저민 프랭클린 | 토머스 에디슨 | 니콜라 테슬라 | 제임스 와트
        zh: 避雷针是谁发明的？ | 富兰克林 | 爱迪生 | 特斯拉 | 瓦特
        ar: من اخترع مانعة الصواعق؟ | بنجامين فرانكلين | توماس إديسون | نيكولا تسلا | جيمس واط

        # tech.ram tech 2
        en: Which memory is wiped when a computer is switched off? | RAM | The hard drive | The SSD | A USB stick
        fr: Quelle mémoire s'efface quand on éteint l'ordinateur ? | La mémoire vive (RAM) | Le disque dur | Le SSD | La clé USB
        es: ¿Qué memoria se borra al apagar el ordenador? | La memoria RAM | El disco duro | El SSD | El pendrive USB
        de: Welcher Speicher wird gelöscht, wenn man den Computer ausschaltet? | Der Arbeitsspeicher (RAM) | Die Festplatte | Die SSD | Der USB-Stick
        it: Quale memoria si cancella quando si spegne il computer? | La RAM | Il disco rigido | L'SSD | La chiavetta USB
        pt: Que memória se apaga quando o computador é desligado? | A memória RAM | O disco rígido | O SSD | O pen drive
        ja: コンピューターの電源を切ると消えるメモリーは？ | RAM（メインメモリー） | ハードディスク | SSD | USBメモリー
        ko: 컴퓨터 전원을 끄면 지워지는 메모리는? | 램(RAM) | 하드 디스크 | SSD | USB 메모리
        zh: 电脑关机后哪种存储里的数据会消失？ | 内存（RAM） | 硬盘 | 固态硬盘 | U盘
        ar: أي ذاكرة تُمحى عند إطفاء الحاسوب؟ | الذاكرة العشوائية (RAM) | القرص الصلب | قرص SSD | ذاكرة USB

        # tech.operating-systems tech 2
        en: macOS, Windows and Linux are all what? | Operating systems | Web browsers | Programming languages | Antivirus programs
        fr: macOS, Windows et Linux sont tous des… | Systèmes d'exploitation | Navigateurs web | Langages de programmation | Antivirus
        es: macOS, Windows y Linux son todos… | Sistemas operativos | Navegadores web | Lenguajes de programación | Antivirus
        de: macOS, Windows und Linux sind alle… | Betriebssysteme | Webbrowser | Programmiersprachen | Virenscanner
        it: macOS, Windows e Linux sono tutti… | Sistemi operativi | Browser web | Linguaggi di programmazione | Antivirus
        pt: macOS, Windows e Linux são todos… | Sistemas operacionais | Navegadores | Linguagens de programação | Antivírus
        ja: macOS、Windows、Linuxはどれも何？ | OS（オペレーティングシステム） | ウェブブラウザー | プログラミング言語 | ウイルス対策ソフト
        ko: macOS, Windows, Linux는 모두 무엇일까요? | 운영 체제 | 웹 브라우저 | 프로그래밍 언어 | 백신 프로그램
        zh: macOS、Windows和Linux都是什么？ | 操作系统 | 网页浏览器 | 编程语言 | 杀毒软件
        ar: ماك أو إس وويندوز ولينكس كلها…؟ | أنظمة تشغيل | متصفحات ويب | لغات برمجة | برامج مكافحة فيروسات

        # tech.browser tech 1
        en: Which of these is a web browser? | Safari | Excel | Photoshop | Python
        fr: Lequel de ces logiciels est un navigateur web ? | Safari | Excel | Photoshop | Python
        es: ¿Cuál de estos es un navegador web? | Safari | Excel | Photoshop | Python
        de: Welches davon ist ein Webbrowser? | Safari | Excel | Photoshop | Python
        it: Quale di questi è un browser web? | Safari | Excel | Photoshop | Python
        pt: Qual destes é um navegador da web? | Safari | Excel | Photoshop | Python
        ja: この中でウェブブラウザーはどれ？ | Safari | Excel | Photoshop | Python
        ko: 다음 중 웹 브라우저는? | Safari | Excel | Photoshop | Python
        zh: 下面哪个是网页浏览器？ | Safari | Excel | Photoshop | Python
        ar: أيّ هذه متصفح ويب؟ | Safari | Excel | Photoshop | Python

        # tech.python tech 2
        en: What is Python, in computing? | A programming language | A web browser | A computer brand | A video format
        fr: En informatique, qu'est-ce que Python ? | Un langage de programmation | Un navigateur web | Une marque d'ordinateurs | Un format vidéo
        es: En informática, ¿qué es Python? | Un lenguaje de programación | Un navegador web | Una marca de ordenadores | Un formato de vídeo
        de: Was ist Python in der Informatik? | Eine Programmiersprache | Ein Webbrowser | Eine Computermarke | Ein Videoformat
        it: In informatica, che cos'è Python? | Un linguaggio di programmazione | Un browser web | Una marca di computer | Un formato video
        pt: Em informática, o que é Python? | Uma linguagem de programação | Um navegador | Uma marca de computador | Um formato de vídeo
        ja: コンピューターの世界でPythonとは？ | プログラミング言語 | ウェブブラウザー | パソコンのメーカー | 動画の形式
        ko: 컴퓨터 분야에서 파이썬(Python)은 무엇일까요? | 프로그래밍 언어 | 웹 브라우저 | 컴퓨터 브랜드 | 동영상 형식
        zh: 在计算机领域，Python是什么？ | 一种编程语言 | 一种浏览器 | 一个电脑品牌 | 一种视频格式
        ar: في الحوسبة، ما بايثون (Python)؟ | لغة برمجة | متصفح ويب | علامة حواسيب | صيغة فيديو

        # tech.velcro tech 3
        en: What gave the inventor of Velcro his idea? | Burrs sticking to his dog's fur | Gecko feet | Spider webs | Fish scales
        fr: Qu'est-ce qui a donné l'idée du Velcro à son inventeur ? | Des bardanes collées au poil de son chien | Les pattes du gecko | Les toiles d'araignée | Les écailles de poisson
        es: ¿Qué le dio la idea del velcro a su inventor? | Unos abrojos pegados al pelo de su perro | Las patas del geco | Las telarañas | Las escamas de pez
        de: Was brachte den Erfinder des Klettverschlusses auf die Idee? | Kletten im Fell seines Hundes | Geckofüße | Spinnennetze | Fischschuppen
        it: Che cosa diede l'idea del velcro al suo inventore? | Le bardane attaccate al pelo del suo cane | Le zampe del geco | Le ragnatele | Le squame dei pesci
        pt: O que deu a ideia do velcro ao seu inventor? | Carrapichos grudados no pelo do cão | Patas de lagartixa | Teias de aranha | Escamas de peixe
        ja: マジックテープ（面ファスナー）のヒントになったのは？ | 犬の毛についたゴボウの実 | ヤモリの足 | クモの巣 | 魚のうろこ
        ko: 벨크로(찍찍이)를 발명하게 된 계기는? | 개의 털에 붙은 우엉 열매 | 도마뱀붙이의 발 | 거미줄 | 물고기 비늘
        zh: 魔术贴的发明灵感来自什么？ | 粘在狗毛上的牛蒡果 | 壁虎的脚 | 蜘蛛网 | 鱼鳞
        ar: ما الذي ألهم مخترع شريط الفيلكرو فكرته؟ | ثمار الأرقطيون العالقة بفرو كلبه | أقدام الوزغ | خيوط العنكبوت | قشور السمك

        # tech.fibre-optics tech 3
        en: Fibre-optic cables carry data as what? | Light | Water | Sound | Heat
        fr: Sous quelle forme les fibres optiques transportent-elles les données ? | De la lumière | De l'eau | Du son | De la chaleur
        es: ¿En forma de qué transporta datos la fibra óptica? | Luz | Agua | Sonido | Calor
        de: In welcher Form übertragen Glasfaserkabel Daten? | Als Licht | Als Wasser | Als Schall | Als Wärme
        it: Sotto quale forma la fibra ottica trasporta i dati? | Luce | Acqua | Suono | Calore
        pt: Os cabos de fibra óptica transportam dados na forma de quê? | Luz | Água | Som | Calor
        ja: 光ファイバーはデータを何として運ぶ？ | 光 | 水 | 音 | 熱
        ko: 광섬유 케이블은 데이터를 무엇으로 전달할까요? | 빛 | 물 | 소리 | 열
        zh: 光纤以什么形式传输数据？ | 光 | 水 | 声音 | 热
        ar: بأي شكل تنقل كابلات الألياف الضوئية البيانات؟ | الضوء | الماء | الصوت | الحرارة

        # tech.otis tech 3
        en: Elisha Otis is known for a safety brake for what? | Elevators | Cars | Trains | Bicycles
        fr: Elisha Otis est connu pour un frein de sécurité pour quoi ? | Les ascenseurs | Les voitures | Les trains | Les vélos
        es: Elisha Otis es conocido por un freno de seguridad para… | Ascensores | Coches | Trenes | Bicicletas
        de: Elisha Otis ist für eine Sicherheitsbremse für was bekannt? | Aufzüge | Autos | Züge | Fahrräder
        it: Elisha Otis è noto per un freno di sicurezza per… | Ascensori | Automobili | Treni | Biciclette
        pt: Elisha Otis é conhecido por um freio de segurança para quê? | Elevadores | Carros | Trens | Bicicletas
        ja: エリシャ・オーチスが発明した安全ブレーキは何のためのもの？ | エレベーター | 自動車 | 列車 | 自転車
        ko: 엘리샤 오티스가 만든 안전 브레이크는 무엇을 위한 것일까요? | 엘리베이터 | 자동차 | 기차 | 자전거
        zh: 伊莱沙·奥的斯以发明哪种东西的安全制动装置闻名？ | 电梯 | 汽车 | 火车 | 自行车
        ar: يُعرف إليشا أوتيس بمكابح أمان لماذا؟ | المصاعد | السيارات | القطارات | الدراجات

        # tech.hertz tech 3
        en: What do hertz (Hz) measure? | Frequency | Weight | Distance | Temperature
        fr: Que mesurent les hertz (Hz) ? | La fréquence | Le poids | La distance | La température
        es: ¿Qué miden los hercios (Hz)? | La frecuencia | El peso | La distancia | La temperatura
        de: Was misst man in Hertz (Hz)? | Frequenz | Gewicht | Entfernung | Temperatur
        it: Che cosa misurano gli hertz (Hz)? | La frequenza | Il peso | La distanza | La temperatura
        pt: O que os hertz (Hz) medem? | Frequência | Peso | Distância | Temperatura
        ja: ヘルツ（Hz）が表すのは？ | 周波数 | 重さ | 距離 | 温度
        ko: 헤르츠(Hz)는 무엇의 단위일까요? | 진동수(주파수) | 무게 | 거리 | 온도
        zh: 赫兹（Hz）是什么的单位？ | 频率 | 重量 | 距离 | 温度
        ar: ماذا تقيس وحدة الهرتز (Hz)؟ | التردد | الوزن | المسافة | درجة الحرارة

        # tech.abacus tech 2
        en: What is an abacus used for? | Doing sums | Telling the time | Writing letters | Weighing food
        fr: À quoi sert un boulier ? | À calculer | À lire l'heure | À écrire des lettres | À peser les aliments
        es: ¿Para qué sirve un ábaco? | Para hacer cuentas | Para ver la hora | Para escribir cartas | Para pesar comida
        de: Wofür benutzt man einen Abakus? | Zum Rechnen | Zum Ablesen der Uhrzeit | Zum Briefeschreiben | Zum Wiegen von Essen
        it: A che cosa serve un abaco? | A fare i conti | A leggere l'ora | A scrivere lettere | A pesare il cibo
        pt: Para que serve um ábaco? | Para fazer contas | Para ver as horas | Para escrever cartas | Para pesar comida
        ja: そろばんは何に使う道具？ | 計算 | 時間を知る | 手紙を書く | 食べ物をはかる
        ko: 주판은 무엇에 쓰는 도구일까요? | 셈하기 | 시간 보기 | 편지 쓰기 | 음식 무게 재기
        zh: 算盘是用来做什么的？ | 计算 | 看时间 | 写信 | 称食物
        ar: فيمَ يُستخدم العدّاد (المعداد)؟ | إجراء الحسابات | معرفة الوقت | كتابة الرسائل | وزن الطعام

        # tech.3d-printer tech 2
        en: How do most 3D printers build an object? | Layer by layer | All at once in a mould | By carving a block | By inflating it
        fr: Comment la plupart des imprimantes 3D fabriquent-elles un objet ? | Couche par couche | D'un coup dans un moule | En taillant un bloc | En le gonflant
        es: ¿Cómo fabrican un objeto la mayoría de las impresoras 3D? | Capa a capa | De golpe en un molde | Tallando un bloque | Inflándolo
        de: Wie bauen die meisten 3D-Drucker einen Gegenstand? | Schicht für Schicht | Auf einmal in einer Form | Durch Schnitzen eines Blocks | Durch Aufblasen
        it: Come costruisce un oggetto la maggior parte delle stampanti 3D? | Strato dopo strato | Tutto insieme in uno stampo | Scolpendo un blocco | Gonfiandolo
        pt: Como a maioria das impressoras 3D fabrica um objeto? | Camada por camada | De uma vez num molde | Esculpindo um bloco | Inflando-o
        ja: ほとんどの3Dプリンターはどうやって物をつくる？ | 1層ずつ積み重ねる | 型で一度に固める | ブロックを削る | ふくらませる
        ko: 대부분의 3D 프린터는 물건을 어떻게 만들까요? | 한 층씩 쌓아서 | 틀에 한 번에 부어서 | 덩어리를 깎아서 | 부풀려서
        zh: 大多数3D打印机怎样制造物体？ | 一层一层堆叠 | 一次性用模具成型 | 雕刻一整块材料 | 把它吹起来
        ar: كيف تصنع معظم الطابعات ثلاثية الأبعاد الأجسام؟ | طبقة فوق طبقة | دفعة واحدة في قالب | بنحت كتلة | بنفخها
        """
}
