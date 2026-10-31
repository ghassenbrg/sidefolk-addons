extension Games.QuizBank {
    // Sports: rules, numbers and origins; never records or champions, which change.
    static let sports = """
        # sp.football-team sports 1
        *: 11 | 9 | 10 | 12
        en: How many players does a football (soccer) team have on the pitch?
        fr: Combien de joueurs une équipe de football a-t-elle sur le terrain ?
        es: ¿Cuántos jugadores tiene un equipo de fútbol en el campo?
        de: Wie viele Spieler hat eine Fußballmannschaft auf dem Platz?
        it: Quanti giocatori ha in campo una squadra di calcio?
        pt: Quantos jogadores um time de futebol tem em campo?
        ja: サッカーの1チームがフィールドに出す選手の数は？
        ko: 축구 한 팀이 경기장에 내보내는 선수는 몇 명일까요?
        zh: 一支足球队场上有几名球员？
        ar: كم لاعبًا لفريق كرة القدم في الملعب؟

        # sp.basketball-team sports 1
        *: 5 | 4 | 6 | 7
        en: How many players does a basketball team have on the court?
        fr: Combien de joueurs une équipe de basket a-t-elle sur le terrain ?
        es: ¿Cuántos jugadores tiene un equipo de baloncesto en la cancha?
        de: Wie viele Spieler hat eine Basketballmannschaft auf dem Feld?
        it: Quanti giocatori ha in campo una squadra di pallacanestro?
        pt: Quantos jogadores um time de basquete tem em quadra?
        ja: バスケットボールの1チームがコートに出す選手の数は？
        ko: 농구 한 팀이 코트에 내보내는 선수는 몇 명일까요?
        zh: 一支篮球队场上有几名球员？
        ar: كم لاعبًا لفريق كرة السلة في الملعب؟

        # sp.marathon-length sports 2
        *: 42 km | 21 km | 30 km | 50 km
        en: About how long is a marathon?
        fr: Quelle est la longueur approximative d'un marathon ?
        es: ¿Cuánto mide aproximadamente un maratón?
        de: Wie lang ist ein Marathon ungefähr?
        it: Quanto è lunga più o meno una maratona?
        pt: Qual é a distância aproximada de uma maratona?
        ja: マラソンの距離はおよそ？
        ko: 마라톤의 거리는 대략?
        zh: 马拉松的距离大约是多少？
        ar: كم يبلغ طول سباق الماراثون تقريبًا؟

        # sp.olympic-rings sports 1
        *: 5 | 4 | 6 | 7
        en: How many rings are in the Olympic symbol?
        fr: Combien d'anneaux compte le symbole olympique ?
        es: ¿Cuántos anillos tiene el símbolo olímpico?
        de: Wie viele Ringe hat das olympische Symbol?
        it: Quanti cerchi ha il simbolo olimpico?
        pt: Quantos anéis tem o símbolo olímpico?
        ja: オリンピックのシンボルの輪はいくつ？
        ko: 올림픽 상징에 있는 고리는 몇 개일까요?
        zh: 奥林匹克标志有几个环？
        ar: كم حلقة في الشعار الأولمبي؟

        # sp.judo sports 2
        en: Judo comes from which country? | Japan | China | Korea | Brazil
        fr: De quel pays vient le judo ? | Le Japon | La Chine | La Corée | Le Brésil
        es: ¿De qué país viene el judo? | Japón | China | Corea | Brasil
        de: Aus welchem Land stammt Judo? | Japan | China | Korea | Brasilien
        it: Da quale Paese viene il judo? | Giappone | Cina | Corea | Brasile
        pt: De que país vem o judô? | Japão | China | Coreia | Brasil
        ja: 柔道が生まれた国は？ | 日本 | 中国 | 韓国 | ブラジル
        ko: 유도는 어느 나라에서 시작되었을까요? | 일본 | 중국 | 한국 | 브라질
        zh: 柔道起源于哪个国家？ | 日本 | 中国 | 韩国 | 巴西
        ar: من أي بلد جاء الجودو؟ | اليابان | الصين | كوريا | البرازيل

        # sp.taekwondo sports 2
        en: Taekwondo comes from which country? | Korea | Japan | China | Thailand
        fr: De quel pays vient le taekwondo ? | La Corée | Le Japon | La Chine | La Thaïlande
        es: ¿De qué país viene el taekwondo? | Corea | Japón | China | Tailandia
        de: Aus welchem Land stammt Taekwondo? | Korea | Japan | China | Thailand
        it: Da quale Paese viene il taekwondo? | Corea | Giappone | Cina | Thailandia
        pt: De que país vem o taekwondo? | Coreia | Japão | China | Tailândia
        ja: テコンドーが生まれた国は？ | 韓国 | 日本 | 中国 | タイ
        ko: 태권도는 어느 나라에서 시작되었을까요? | 한국 | 일본 | 중국 | 태국
        zh: 跆拳道起源于哪个国家？ | 韩国 | 日本 | 中国 | 泰国
        ar: من أي بلد جاء التايكوندو؟ | كوريا | اليابان | الصين | تايلاند

        # sp.cricket-team sports 3
        *: 11 | 9 | 13 | 15
        en: How many players are in a cricket team on the field?
        fr: Combien de joueurs compte une équipe de cricket sur le terrain ?
        es: ¿Cuántos jugadores tiene en el campo un equipo de críquet?
        de: Wie viele Spieler hat eine Cricketmannschaft auf dem Feld?
        it: Quanti giocatori ha in campo una squadra di cricket?
        pt: Quantos jogadores um time de críquete tem em campo?
        ja: クリケットの1チームがフィールドに出す選手の数は？
        ko: 크리켓 한 팀이 경기장에 내보내는 선수는 몇 명일까요?
        zh: 一支板球队场上有几名球员？
        ar: كم لاعبًا لفريق الكريكيت في الملعب؟

        # sp.chess-pieces sports 2
        *: 16 | 12 | 18 | 20
        en: How many pieces does each chess player start with?
        fr: Avec combien de pièces chaque joueur d'échecs commence-t-il ?
        es: ¿Con cuántas piezas empieza cada jugador de ajedrez?
        de: Mit wie vielen Figuren beginnt jeder Schachspieler?
        it: Con quanti pezzi inizia ogni giocatore di scacchi?
        pt: Com quantas peças cada jogador de xadrez começa?
        ja: チェスでそれぞれの人が最初に持つ駒の数は？
        ko: 체스에서 각자 처음에 가지는 말은 몇 개일까요?
        zh: 国际象棋开局时每位棋手有几枚棋子？
        ar: بكم قطعة يبدأ كل لاعب في الشطرنج؟

        # sp.chessboard sports 1
        *: 64 | 49 | 81 | 100
        en: How many squares are on a chessboard?
        fr: Combien de cases compte un échiquier ?
        es: ¿Cuántas casillas tiene un tablero de ajedrez?
        de: Wie viele Felder hat ein Schachbrett?
        it: Quante caselle ha una scacchiera?
        pt: Quantas casas tem um tabuleiro de xadrez?
        ja: チェス盤のマスはいくつ？
        ko: 체스판의 칸은 몇 개일까요?
        zh: 国际象棋棋盘有多少个格子？
        ar: كم مربعًا في رقعة الشطرنج؟

        # sp.golf-holes sports 2
        *: 18 | 9 | 12 | 24
        en: How many holes are in a standard round of golf?
        fr: Combien de trous compte un parcours de golf standard ?
        es: ¿Cuántos hoyos tiene un recorrido estándar de golf?
        de: Wie viele Löcher hat eine normale Golfrunde?
        it: Quante buche ha un normale giro di golf?
        pt: Quantos buracos tem uma volta padrão de golfe?
        ja: ゴルフの標準的な1ラウンドは何ホール？
        ko: 골프 정규 한 라운드는 몇 홀일까요?
        zh: 标准一轮高尔夫有几个洞？
        ar: كم حفرة في جولة الغولف العادية؟

        # sp.volleyball-team sports 2
        *: 6 | 5 | 7 | 8
        en: How many players does a volleyball team have on the court?
        fr: Combien de joueurs une équipe de volley a-t-elle sur le terrain ?
        es: ¿Cuántos jugadores tiene en la cancha un equipo de voleibol?
        de: Wie viele Spieler hat eine Volleyballmannschaft auf dem Feld?
        it: Quanti giocatori ha in campo una squadra di pallavolo?
        pt: Quantos jogadores um time de vôlei tem em quadra?
        ja: バレーボールの1チームがコートに出す選手の数は？
        ko: 배구 한 팀이 코트에 내보내는 선수는 몇 명일까요?
        zh: 一支排球队场上有几名队员？
        ar: كم لاعبًا لفريق الكرة الطائرة في الملعب؟

        # sp.marathon-name sports 3
        en: The marathon is named after a place in which country? | Greece | Italy | Turkey | Egypt
        fr: Le marathon doit son nom à un lieu de quel pays ? | La Grèce | L'Italie | La Turquie | L'Égypte
        es: ¿De qué país es el lugar que dio nombre al maratón? | Grecia | Italia | Turquía | Egipto
        de: Der Marathonlauf ist nach einem Ort in welchem Land benannt? | Griechenland | Italien | Türkei | Ägypten
        it: La maratona prende il nome da un luogo di quale Paese? | Grecia | Italia | Turchia | Egitto
        pt: A maratona tem o nome de um lugar de qual país? | Grécia | Itália | Turquia | Egito
        ja: マラソンという名前は、どの国の地名から来た？ | ギリシャ | イタリア | トルコ | エジプト
        ko: 마라톤이라는 이름은 어느 나라의 지명에서 왔을까요? | 그리스 | 이탈리아 | 튀르키예 | 이집트
        zh: 马拉松的名字来自哪个国家的一个地方？ | 希腊 | 意大利 | 土耳其 | 埃及
        ar: سُمّي الماراثون باسم مكان في أي بلد؟ | اليونان | إيطاليا | تركيا | مصر

        # sp.tour-de-france sports 1
        en: The Tour de France is a race for what? | Bicycles | Cars | Runners | Horses
        fr: Le Tour de France est une course de quoi ? | De vélos | De voitures | De coureurs à pied | De chevaux
        es: ¿De qué es la carrera del Tour de Francia? | De bicicletas | De coches | De corredores a pie | De caballos
        de: Was für ein Rennen ist die Tour de France? | Ein Radrennen | Ein Autorennen | Ein Laufwettbewerb | Ein Pferderennen
        it: Il Tour de France è una corsa di che cosa? | Di biciclette | Di auto | Di podisti | Di cavalli
        pt: O Tour de France é uma corrida de quê? | Bicicletas | Carros | Corredores a pé | Cavalos
        ja: ツール・ド・フランスは何のレース？ | 自転車 | 自動車 | マラソン | 競馬
        ko: 투르 드 프랑스는 무슨 경주일까요? | 자전거 | 자동차 | 달리기 | 경마
        zh: 环法赛是什么比赛？ | 自行车赛 | 汽车赛 | 长跑 | 赛马
        ar: سباق طواف فرنسا سباقٌ لماذا؟ | الدراجات | السيارات | العدّائين | الخيول

        # sp.wimbledon sports 2
        en: Wimbledon is a famous tournament in which sport? | Tennis | Golf | Cricket | Rugby
        fr: Wimbledon est un célèbre tournoi de quel sport ? | Le tennis | Le golf | Le cricket | Le rugby
        es: ¿De qué deporte es el famoso torneo de Wimbledon? | Tenis | Golf | Críquet | Rugby
        de: Wimbledon ist ein berühmtes Turnier in welcher Sportart? | Tennis | Golf | Cricket | Rugby
        it: Wimbledon è un famoso torneo di quale sport? | Tennis | Golf | Cricket | Rugby
        pt: Wimbledon é um torneio famoso de qual esporte? | Tênis | Golfe | Críquete | Rúgbi
        ja: ウィンブルドンは何のスポーツの有名な大会？ | テニス | ゴルフ | クリケット | ラグビー
        ko: 윔블던은 어떤 스포츠의 유명한 대회일까요? | 테니스 | 골프 | 크리켓 | 럭비
        zh: 温布尔登是哪项运动的著名赛事？ | 网球 | 高尔夫 | 板球 | 橄榄球
        ar: ويمبلدون بطولة شهيرة في أي رياضة؟ | التنس | الغولف | الكريكيت | الرغبي

        # sp.sumo sports 1
        en: Sumo wrestling is the traditional sport of which country? | Japan | China | Thailand | India
        fr: Le sumo est le sport traditionnel de quel pays ? | Le Japon | La Chine | La Thaïlande | L'Inde
        es: ¿De qué país es deporte tradicional el sumo? | Japón | China | Tailandia | India
        de: Sumo ist der traditionelle Sport welches Landes? | Japan | China | Thailand | Indien
        it: Il sumo è lo sport tradizionale di quale Paese? | Giappone | Cina | Thailandia | India
        pt: O sumô é o esporte tradicional de qual país? | Japão | China | Tailândia | Índia
        ja: 相撲はどの国の伝統的なスポーツ？ | 日本 | 中国 | タイ | インド
        ko: 스모는 어느 나라의 전통 스포츠일까요? | 일본 | 중국 | 태국 | 인도
        zh: 相扑是哪个国家的传统运动？ | 日本 | 中国 | 泰国 | 印度
        ar: السومو رياضة تقليدية في أي بلد؟ | اليابان | الصين | تايلاند | الهند

        # sp.puck sports 1
        en: What do ice hockey players hit with their sticks? | A puck | A ball | A shuttlecock | A ring
        fr: Que frappent les joueurs de hockey sur glace avec leur crosse ? | Un palet | Une balle | Un volant | Un anneau
        es: ¿Qué golpean con el stick los jugadores de hockey sobre hielo? | Un disco | Una pelota | Un volante | Un aro
        de: Was schlagen Eishockeyspieler mit ihren Schlägern? | Einen Puck | Einen Ball | Einen Federball | Einen Ring
        it: Che cosa colpiscono con il bastone i giocatori di hockey su ghiaccio? | Un disco | Una palla | Un volano | Un anello
        pt: O que os jogadores de hóquei no gelo batem com o taco? | Um disco | Uma bola | Uma peteca | Um anel
        ja: アイスホッケーの選手がスティックで打つものは？ | パック | ボール | シャトル | リング
        ko: 아이스하키 선수가 스틱으로 치는 것은? | 퍽 | 공 | 셔틀콕 | 고리
        zh: 冰球运动员用球杆击打的是什么？ | 冰球（球饼） | 球 | 羽毛球 | 圆环
        ar: ماذا يضرب لاعبو هوكي الجليد بعصيّهم؟ | القرص | الكرة | الريشة | الحلقة

        # sp.badminton sports 2
        en: What is hit over the net in badminton? | A shuttlecock | A puck | A small ball | A frisbee
        fr: Que se renvoie-t-on par-dessus le filet au badminton ? | Un volant | Un palet | Une petite balle | Un frisbee
        es: ¿Qué se pasa por encima de la red en el bádminton? | Un volante | Un disco | Una pelotita | Un frisbi
        de: Was wird beim Badminton über das Netz geschlagen? | Ein Federball | Ein Puck | Ein kleiner Ball | Eine Frisbeescheibe
        it: Che cosa si colpisce sopra la rete nel badminton? | Un volano | Un disco | Una pallina | Un frisbee
        pt: O que é rebatido por cima da rede no badminton? | Uma peteca | Um disco | Uma bolinha | Um frisbee
        ja: バドミントンでネットの上を打ち合うものは？ | シャトル | パック | 小さなボール | フリスビー
        ko: 배드민턴에서 네트 너머로 치는 것은? | 셔틀콕 | 퍽 | 작은 공 | 프리스비
        zh: 羽毛球运动中越网击打的是什么？ | 羽毛球 | 冰球 | 小球 | 飞盘
        ar: ماذا يُضرب فوق الشبكة في الريشة الطائرة؟ | الريشة | القرص | كرة صغيرة | الصحن الطائر

        # sp.olympic-cycle sports 1
        *: 4 | 2 | 3 | 5
        en: The Summer Olympic Games are normally held every how many years?
        fr: Les Jeux olympiques d'été ont lieu normalement tous les combien d'années ?
        es: ¿Cada cuántos años se celebran normalmente los Juegos Olímpicos de verano?
        de: Alle wie viele Jahre finden die Olympischen Sommerspiele normalerweise statt?
        it: Ogni quanti anni si tengono di solito i Giochi olimpici estivi?
        pt: De quantos em quantos anos os Jogos Olímpicos de Verão costumam acontecer?
        ja: 夏季オリンピックはふつう何年に1回開かれる？
        ko: 하계 올림픽은 보통 몇 년마다 열릴까요?
        zh: 夏季奥运会通常每几年举办一次？
        ar: كل كم سنة تُقام الألعاب الأولمبية الصيفية عادةً؟

        # sp.first-modern-games sports 2
        en: Where were the first modern Olympic Games held, in 1896? | Athens | Paris | London | Rome
        fr: Où ont eu lieu les premiers Jeux olympiques modernes, en 1896 ? | À Athènes | À Paris | À Londres | À Rome
        es: ¿Dónde se celebraron los primeros Juegos Olímpicos modernos, en 1896? | Atenas | París | Londres | Roma
        de: Wo fanden 1896 die ersten Olympischen Spiele der Neuzeit statt? | Athen | Paris | London | Rom
        it: Dove si tennero i primi Giochi olimpici moderni, nel 1896? | Atene | Parigi | Londra | Roma
        pt: Onde foram realizados os primeiros Jogos Olímpicos modernos, em 1896? | Atenas | Paris | Londres | Roma
        ja: 1896年に第1回近代オリンピックが開かれた都市は？ | アテネ | パリ | ロンドン | ローマ
        ko: 1896년 제1회 근대 올림픽이 열린 도시는? | 아테네 | 파리 | 런던 | 로마
        zh: 1896年第一届现代奥运会在哪里举办？ | 雅典 | 巴黎 | 伦敦 | 罗马
        ar: أين أُقيمت أول ألعاب أولمبية حديثة عام 1896؟ | أثينا | باريس | لندن | روما

        # sp.first-world-cup sports 3
        en: Which country hosted the first FIFA World Cup, in 1930? | Uruguay | Brazil | Italy | England
        fr: Quel pays a accueilli la première Coupe du monde de la FIFA, en 1930 ? | L'Uruguay | Le Brésil | L'Italie | L'Angleterre
        es: ¿Qué país organizó la primera Copa Mundial de la FIFA, en 1930? | Uruguay | Brasil | Italia | Inglaterra
        de: Welches Land war 1930 Gastgeber der ersten FIFA-Weltmeisterschaft? | Uruguay | Brasilien | Italien | England
        it: Quale Paese ospitò il primo Mondiale FIFA, nel 1930? | Uruguay | Brasile | Italia | Inghilterra
        pt: Que país sediou a primeira Copa do Mundo da FIFA, em 1930? | Uruguai | Brasil | Itália | Inglaterra
        ja: 1930年に第1回FIFAワールドカップを開いた国は？ | ウルグアイ | ブラジル | イタリア | イングランド
        ko: 1930년 제1회 FIFA 월드컵을 연 나라는? | 우루과이 | 브라질 | 이탈리아 | 잉글랜드
        zh: 1930年首届国际足联世界杯在哪个国家举办？ | 乌拉圭 | 巴西 | 意大利 | 英格兰
        ar: أي بلد استضاف أول كأس عالم لكرة القدم عام 1930؟ | الأوروغواي | البرازيل | إيطاليا | إنجلترا

        # sp.naismith sports 3
        en: Who invented basketball, in 1891? | James Naismith | Pierre de Coubertin | Walter Camp | Abner Doubleday
        fr: Qui a inventé le basket-ball, en 1891 ? | James Naismith | Pierre de Coubertin | Walter Camp | Abner Doubleday
        es: ¿Quién inventó el baloncesto, en 1891? | James Naismith | Pierre de Coubertin | Walter Camp | Abner Doubleday
        de: Wer erfand 1891 den Basketball? | James Naismith | Pierre de Coubertin | Walter Camp | Abner Doubleday
        it: Chi inventò la pallacanestro, nel 1891? | James Naismith | Pierre de Coubertin | Walter Camp | Abner Doubleday
        pt: Quem inventou o basquete, em 1891? | James Naismith | Pierre de Coubertin | Walter Camp | Abner Doubleday
        ja: 1891年にバスケットボールを考案したのは？ | ジェームズ・ネイスミス | ピエール・ド・クーベルタン | ウォルター・キャンプ | アブナー・ダブルデイ
        ko: 1891년에 농구를 만든 사람은? | 제임스 네이스미스 | 피에르 드 쿠베르탱 | 월터 캠프 | 애브너 더블데이
        zh: 1891年发明篮球的是谁？ | 詹姆斯·奈史密斯 | 顾拜旦 | 沃尔特·坎普 | 阿布纳·道布尔迪
        ar: من اخترع كرة السلة عام 1891؟ | جيمس نايسميث | بيير دو كوبرتان | والتر كامب | أبنر دبلداي

        # sp.coubertin sports 3
        en: Who founded the modern Olympic Games? | Pierre de Coubertin | James Naismith | Avery Brundage | Jean-Jacques Rousseau
        fr: Qui a fondé les Jeux olympiques modernes ? | Pierre de Coubertin | James Naismith | Avery Brundage | Jean-Jacques Rousseau
        es: ¿Quién fundó los Juegos Olímpicos modernos? | Pierre de Coubertin | James Naismith | Avery Brundage | Jean-Jacques Rousseau
        de: Wer gründete die Olympischen Spiele der Neuzeit? | Pierre de Coubertin | James Naismith | Avery Brundage | Jean-Jacques Rousseau
        it: Chi fondò i Giochi olimpici moderni? | Pierre de Coubertin | James Naismith | Avery Brundage | Jean-Jacques Rousseau
        pt: Quem fundou os Jogos Olímpicos modernos? | Pierre de Coubertin | James Naismith | Avery Brundage | Jean-Jacques Rousseau
        ja: 近代オリンピックを始めたのは？ | ピエール・ド・クーベルタン | ジェームズ・ネイスミス | エイベリー・ブランデージ | ジャン＝ジャック・ルソー
        ko: 근대 올림픽을 창시한 사람은? | 피에르 드 쿠베르탱 | 제임스 네이스미스 | 에이버리 브런디지 | 장자크 루소
        zh: 现代奥运会的创始人是谁？ | 顾拜旦 | 詹姆斯·奈史密斯 | 艾弗里·布伦戴奇 | 卢梭
        ar: من أسّس الألعاب الأولمبية الحديثة؟ | بيير دو كوبرتان | جيمس نايسميث | أفيري برونداج | جان جاك روسو

        # sp.bowling-pins sports 2
        *: 10 | 8 | 9 | 12
        en: How many pins stand at the end of a ten-pin bowling lane?
        fr: Combien de quilles se dressent au bout d'une piste de bowling ?
        es: ¿Cuántos bolos hay al final de una pista de bolos (bowling)?
        de: Wie viele Pins stehen am Ende einer Bowlingbahn?
        it: Quanti birilli ci sono in fondo a una pista da bowling?
        pt: Quantos pinos ficam no fim de uma pista de boliche?
        ja: ボウリングのレーンの先に立っているピンの数は？
        ko: 볼링 레인 끝에 서 있는 핀은 몇 개일까요?
        zh: 保龄球道尽头立着几个球瓶？
        ar: كم قارورة تقف في نهاية مسار البولينغ؟

        # sp.decathlon sports 2
        *: 10 | 5 | 7 | 12
        en: How many events are in a decathlon?
        fr: Combien d'épreuves compte un décathlon ?
        es: ¿Cuántas pruebas tiene un decatlón?
        de: Aus wie vielen Disziplinen besteht ein Zehnkampf?
        it: Quante prove ci sono in un decathlon?
        pt: Quantas provas tem um decatlo?
        ja: 十種競技は何種目？
        ko: 10종 경기는 몇 종목으로 이루어져 있을까요?
        zh: 十项全能有几个项目？
        ar: كم مسابقة في العشاري (الديكاثلون)؟

        # sp.triathlon sports 2
        en: A triathlon combines swimming, cycling and what? | Running | Rowing | Skiing | Climbing
        fr: Un triathlon combine natation, vélo et quoi ? | Course à pied | Aviron | Ski | Escalade
        es: Un triatlón combina natación, ciclismo y… | Carrera a pie | Remo | Esquí | Escalada
        de: Ein Triathlon verbindet Schwimmen, Radfahren und was? | Laufen | Rudern | Skifahren | Klettern
        it: Un triathlon unisce nuoto, ciclismo e che cosa? | Corsa | Canottaggio | Sci | Arrampicata
        pt: O triatlo combina natação, ciclismo e o quê? | Corrida | Remo | Esqui | Escalada
        ja: トライアスロンは水泳、自転車と何を組み合わせた競技？ | ランニング | ボート | スキー | クライミング
        ko: 철인 3종 경기는 수영, 사이클과 무엇을 합친 경기일까요? | 달리기 | 조정 | 스키 | 등반
        zh: 铁人三项包括游泳、自行车和什么？ | 跑步 | 赛艇 | 滑雪 | 攀岩
        ar: يجمع الترايثلون بين السباحة وركوب الدراجة وماذا؟ | الجري | التجديف | التزلج | التسلق

        # sp.oval-ball sports 1
        en: Which of these sports is played with an oval ball? | Rugby | Football (soccer) | Basketball | Volleyball
        fr: Lequel de ces sports se joue avec un ballon ovale ? | Le rugby | Le football | Le basket-ball | Le volley-ball
        es: ¿Cuál de estos deportes se juega con un balón ovalado? | Rugby | Fútbol | Baloncesto | Voleibol
        de: Welche dieser Sportarten spielt man mit einem ovalen Ball? | Rugby | Fußball | Basketball | Volleyball
        it: Quale di questi sport si gioca con un pallone ovale? | Rugby | Calcio | Pallacanestro | Pallavolo
        pt: Qual destes esportes é jogado com uma bola oval? | Rúgbi | Futebol | Basquete | Vôlei
        ja: この中で楕円形のボールを使うスポーツは？ | ラグビー | サッカー | バスケットボール | バレーボール
        ko: 다음 중 타원형 공을 쓰는 스포츠는? | 럭비 | 축구 | 농구 | 배구
        zh: 下面哪项运动使用椭圆形的球？ | 橄榄球 | 足球 | 篮球 | 排球
        ar: أيّ هذه الرياضات تُلعب بكرة بيضاوية؟ | الرغبي | كرة القدم | كرة السلة | الكرة الطائرة

        # sp.karate-belt sports 2
        en: In karate, which belt colour usually shows the highest rank? | Black | White | Yellow | Green
        fr: Au karaté, quelle couleur de ceinture indique en général le plus haut niveau ? | Noire | Blanche | Jaune | Verte
        es: En kárate, ¿qué color de cinturón suele indicar el grado más alto? | Negro | Blanco | Amarillo | Verde
        de: Welche Gürtelfarbe zeigt im Karate meist den höchsten Rang? | Schwarz | Weiß | Gelb | Grün
        it: Nel karate, quale colore di cintura indica di solito il grado più alto? | Nera | Bianca | Gialla | Verde
        pt: No caratê, que cor de faixa costuma indicar o grau mais alto? | Preta | Branca | Amarela | Verde
        ja: 空手でふつう最も上の段位を示す帯の色は？ | 黒 | 白 | 黄 | 緑
        ko: 가라테에서 보통 가장 높은 단계를 나타내는 띠 색은? | 검은색 | 흰색 | 노란색 | 초록색
        zh: 空手道中通常哪种颜色的腰带代表最高级别？ | 黑色 | 白色 | 黄色 | 绿色
        ar: في الكاراتيه، أي لون حزام يدلّ عادةً على أعلى رتبة؟ | الأسود | الأبيض | الأصفر | الأخضر

        # sp.ping-pong sports 1
        en: Which sport is also called ping-pong? | Table tennis | Squash | Padel | Badminton
        fr: Quel sport appelle-t-on aussi ping-pong ? | Le tennis de table | Le squash | Le padel | Le badminton
        es: ¿Qué deporte se llama también ping-pong? | Tenis de mesa | Squash | Pádel | Bádminton
        de: Welche Sportart heißt auch Pingpong? | Tischtennis | Squash | Padel | Badminton
        it: Quale sport si chiama anche ping-pong? | Tennis da tavolo | Squash | Padel | Badminton
        pt: Que esporte também é chamado de pingue-pongue? | Tênis de mesa | Squash | Padel | Badminton
        ja: 「ピンポン」とも呼ばれるスポーツは？ | 卓球 | スカッシュ | パデル | バドミントン
        ko: '핑퐁'이라고도 부르는 스포츠는? | 탁구 | 스쿼시 | 파델 | 배드민턴
        zh: 哪项运动又叫“乒乓”？ | 乒乓球 | 壁球 | 板式网球 | 羽毛球
        ar: أي رياضة تُسمّى أيضًا «بينغ بونغ»؟ | كرة الطاولة | الإسكواش | البادل | الريشة الطائرة

        # sp.goalkeeper sports 1
        en: In football (soccer), which player may handle the ball in their own area? | The goalkeeper | The captain | The striker | The referee
        fr: Au football, quel joueur peut toucher le ballon des mains dans sa surface ? | Le gardien de but | Le capitaine | L'attaquant | L'arbitre
        es: En el fútbol, ¿qué jugador puede tocar el balón con las manos en su área? | El portero | El capitán | El delantero | El árbitro
        de: Welcher Fußballspieler darf den Ball im eigenen Strafraum mit den Händen spielen? | Der Torwart | Der Kapitän | Der Stürmer | Der Schiedsrichter
        it: Nel calcio, quale giocatore può toccare il pallone con le mani nella propria area? | Il portiere | Il capitano | L'attaccante | L'arbitro
        pt: No futebol, que jogador pode pegar a bola com as mãos na própria área? | O goleiro | O capitão | O atacante | O árbitro
        ja: サッカーで、自陣のペナルティーエリア内で手を使ってよい選手は？ | ゴールキーパー | キャプテン | フォワード | 審判
        ko: 축구에서 자기 페널티 구역 안에서 손을 쓸 수 있는 선수는? | 골키퍼 | 주장 | 공격수 | 심판
        zh: 足球比赛中，哪名球员可以在本方禁区内用手触球？ | 守门员 | 队长 | 前锋 | 裁判
        ar: في كرة القدم، أي لاعب يمكنه لمس الكرة بيديه داخل منطقته؟ | حارس المرمى | القائد | المهاجم | الحكم

        # sp.olympic-flame sports 2
        en: Where is the Olympic flame lit before each Games? | Olympia, in Greece | Rome | Paris | Geneva
        fr: Où la flamme olympique est-elle allumée avant chaque Jeux ? | À Olympie, en Grèce | À Rome | À Paris | À Genève
        es: ¿Dónde se enciende la llama olímpica antes de cada Juegos? | En Olimpia, Grecia | En Roma | En París | En Ginebra
        de: Wo wird das olympische Feuer vor allen Spielen entzündet? | In Olympia, Griechenland | In Rom | In Paris | In Genf
        it: Dove si accende la fiamma olimpica prima di ogni Giochi? | A Olimpia, in Grecia | A Roma | A Parigi | A Ginevra
        pt: Onde a chama olímpica é acesa antes de cada edição dos Jogos? | Em Olímpia, na Grécia | Em Roma | Em Paris | Em Genebra
        ja: オリンピックの聖火が毎回採火される場所は？ | ギリシャのオリンピア | ローマ | パリ | ジュネーブ
        ko: 올림픽 성화를 매번 채화하는 곳은? | 그리스의 올림피아 | 로마 | 파리 | 제네바
        zh: 每届奥运会的圣火在哪里点燃？ | 希腊奥林匹亚 | 罗马 | 巴黎 | 日内瓦
        ar: أين تُشعل الشعلة الأولمبية قبل كل دورة؟ | في أولمبيا باليونان | في روما | في باريس | في جنيف

        # sp.red-card sports 1
        en: In football (soccer), what does a red card mean? | The player is sent off | A warning | A goal | Half-time
        fr: Au football, que signifie un carton rouge ? | Le joueur est expulsé | Un avertissement | Un but | La mi-temps
        es: En el fútbol, ¿qué significa una tarjeta roja? | El jugador es expulsado | Una advertencia | Un gol | El descanso
        de: Was bedeutet im Fußball eine Rote Karte? | Der Spieler muss vom Platz | Eine Verwarnung | Ein Tor | Halbzeit
        it: Nel calcio, che cosa significa un cartellino rosso? | Il giocatore è espulso | Un'ammonizione | Un gol | L'intervallo
        pt: No futebol, o que significa um cartão vermelho? | O jogador é expulso | Uma advertência | Um gol | O intervalo
        ja: サッカーでレッドカードが出るとどうなる？ | 選手は退場 | 警告だけ | 得点 | ハーフタイム
        ko: 축구에서 레드카드는 무엇을 뜻할까요? | 선수 퇴장 | 경고 | 득점 | 하프타임
        zh: 足球比赛中红牌意味着什么？ | 球员被罚下场 | 警告 | 进球 | 中场休息
        ar: في كرة القدم، ماذا تعني البطاقة الحمراء؟ | طرد اللاعب | إنذار | هدف | الاستراحة

        # sp.fastest-stroke sports 2
        en: Which swimming stroke is usually the fastest? | Front crawl (freestyle) | Breaststroke | Backstroke | Butterfly
        fr: Quelle nage est en général la plus rapide ? | Le crawl | La brasse | Le dos crawlé | Le papillon
        es: ¿Qué estilo de natación suele ser el más rápido? | El crol (estilo libre) | La braza | La espalda | La mariposa
        de: Welcher Schwimmstil ist meist der schnellste? | Kraulen (Freistil) | Brustschwimmen | Rückenschwimmen | Schmetterling
        it: Quale stile di nuoto è di solito il più veloce? | Lo stile libero (crawl) | La rana | Il dorso | La farfalla
        pt: Qual estilo de natação costuma ser o mais rápido? | Crawl (nado livre) | Peito | Costas | Borboleta
        ja: ふつういちばん速い泳ぎ方は？ | クロール（自由形） | 平泳ぎ | 背泳ぎ | バタフライ
        ko: 보통 가장 빠른 수영 영법은? | 자유형(크롤) | 평영 | 배영 | 접영
        zh: 通常哪种泳姿最快？ | 自由泳（爬泳） | 蛙泳 | 仰泳 | 蝶泳
        ar: أي أسلوب سباحة هو الأسرع عادةً؟ | الزحف على البطن (الحرة) | الصدر | الظهر | الفراشة

        # sp.capoeira sports 2
        en: Capoeira, a mix of martial art and dance, comes from which country? | Brazil | Portugal | Mexico | Spain
        fr: La capoeira, mélange d'art martial et de danse, vient de quel pays ? | Le Brésil | Le Portugal | Le Mexique | L'Espagne
        es: ¿De qué país es la capoeira, mezcla de arte marcial y danza? | Brasil | Portugal | México | España
        de: Aus welchem Land stammt Capoeira, eine Mischung aus Kampfkunst und Tanz? | Brasilien | Portugal | Mexiko | Spanien
        it: Da quale Paese viene la capoeira, un misto di arte marziale e danza? | Brasile | Portogallo | Messico | Spagna
        pt: De que país vem a capoeira, mistura de luta e dança? | Brasil | Portugal | México | Espanha
        ja: 格闘技とダンスが混ざったカポエイラはどの国生まれ？ | ブラジル | ポルトガル | メキシコ | スペイン
        ko: 무술과 춤이 섞인 카포에이라는 어느 나라에서 왔을까요? | 브라질 | 포르투갈 | 멕시코 | 스페인
        zh: 融合武术与舞蹈的卡波耶拉来自哪个国家？ | 巴西 | 葡萄牙 | 墨西哥 | 西班牙
        ar: من أي بلد جاءت الكابويرا، مزيج فنون القتال والرقص؟ | البرازيل | البرتغال | المكسيك | إسبانيا

        # sp.kabaddi sports 3
        en: Kabaddi is a traditional team sport from which region? | South Asia | South America | Scandinavia | Australia
        fr: Le kabaddi est un sport d'équipe traditionnel de quelle région ? | L'Asie du Sud | L'Amérique du Sud | La Scandinavie | L'Australie
        es: ¿De qué región es el kabaddi, un deporte de equipo tradicional? | Asia del Sur | América del Sur | Escandinavia | Australia
        de: Aus welcher Region stammt der traditionelle Mannschaftssport Kabaddi? | Südasien | Südamerika | Skandinavien | Australien
        it: Da quale regione viene il kabaddi, uno sport di squadra tradizionale? | Asia meridionale | Sud America | Scandinavia | Australia
        pt: De que região é o kabaddi, um esporte coletivo tradicional? | Sul da Ásia | América do Sul | Escandinávia | Austrália
        ja: 伝統的なチームスポーツ、カバディが生まれた地域は？ | 南アジア | 南アメリカ | 北欧 | オーストラリア
        ko: 전통 단체 경기 카바디는 어느 지역에서 왔을까요? | 남아시아 | 남아메리카 | 북유럽 | 오스트레일리아
        zh: 卡巴迪这项传统团队运动来自哪个地区？ | 南亚 | 南美洲 | 北欧 | 澳大利亚
        ar: الكبادي رياضة جماعية تقليدية من أي منطقة؟ | جنوب آسيا | أمريكا الجنوبية | إسكندنافيا | أستراليا

        # sp.biathlon sports 3
        en: The biathlon combines cross-country skiing and what? | Rifle shooting | Swimming | Ice skating | Archery
        fr: Le biathlon combine le ski de fond et quoi ? | Le tir à la carabine | La natation | Le patinage | Le tir à l'arc
        es: El biatlón combina el esquí de fondo y… | El tiro con carabina | La natación | El patinaje | El tiro con arco
        de: Biathlon verbindet Skilanglauf mit was? | Schießen mit dem Gewehr | Schwimmen | Eislaufen | Bogenschießen
        it: Il biathlon unisce lo sci di fondo e che cosa? | Il tiro con la carabina | Il nuoto | Il pattinaggio | Il tiro con l'arco
        pt: O biatlo combina esqui cross-country e o quê? | Tiro com carabina | Natação | Patinação | Tiro com arco
        ja: バイアスロンはクロスカントリースキーと何を組み合わせた競技？ | ライフル射撃 | 水泳 | スケート | アーチェリー
        ko: 바이애슬론은 크로스컨트리 스키와 무엇을 합친 경기일까요? | 소총 사격 | 수영 | 스케이트 | 양궁
        zh: 冬季两项是越野滑雪加上什么？ | 步枪射击 | 游泳 | 滑冰 | 射箭
        ar: يجمع البياثلون بين التزلج الريفي وماذا؟ | الرماية بالبندقية | السباحة | التزلج على الجليد | الرماية بالقوس

        # sp.hat-trick sports 2
        *: 3 | 2 | 4 | 5
        en: In football (soccer), a hat-trick is how many goals by one player in a match?
        fr: Au football, un triplé (coup du chapeau), c'est combien de buts d'un même joueur dans un match ?
        es: En el fútbol, ¿cuántos goles de un mismo jugador en un partido son un hat-trick (triplete)?
        de: Wie viele Tore eines Spielers in einem Spiel sind im Fußball ein Hattrick?
        it: Nel calcio, una tripletta (hat-trick) sono quanti gol di uno stesso giocatore in una partita?
        pt: No futebol, um hat-trick são quantos gols do mesmo jogador numa partida?
        ja: サッカーのハットトリックとは、1試合で1人が何点決めること？
        ko: 축구에서 해트트릭은 한 선수가 한 경기에서 몇 골을 넣는 것일까요?
        zh: 足球里的“帽子戏法”是一名球员在一场比赛中进几个球？
        ar: في كرة القدم، الهاتريك هو كم هدفًا يسجّلها لاعب واحد في مباراة؟

        # sp.grand-slams sports 3
        *: 4 | 3 | 5 | 6
        en: How many Grand Slam tournaments are there in tennis each year?
        fr: Combien de tournois du Grand Chelem y a-t-il chaque année au tennis ?
        es: ¿Cuántos torneos de Grand Slam hay cada año en el tenis?
        de: Wie viele Grand-Slam-Turniere gibt es im Tennis jedes Jahr?
        it: Quanti tornei del Grande Slam ci sono ogni anno nel tennis?
        pt: Quantos torneios de Grand Slam há no tênis a cada ano?
        ja: テニスのグランドスラム大会は毎年いくつ？
        ko: 테니스의 그랜드 슬램 대회는 해마다 몇 개일까요?
        zh: 网球每年有几项大满贯赛事？
        ar: كم بطولة «غراند سلام» في التنس كل عام؟

        # sp.baseball-bases sports 2
        *: 4 | 3 | 5 | 6
        en: How many bases are on a baseball field, counting home plate?
        fr: Combien de bases compte un terrain de baseball, marbre compris ?
        es: ¿Cuántas bases hay en un campo de béisbol, contando el home?
        de: Wie viele Bases hat ein Baseballfeld, die Home Plate mitgezählt?
        it: Quante basi ci sono in un campo da baseball, contando casa base?
        pt: Quantas bases há num campo de beisebol, contando a home plate?
        ja: 本塁を含めて、野球場の塁はいくつ？
        ko: 홈 베이스를 포함해 야구장의 베이스는 몇 개일까요?
        zh: 算上本垒，棒球场上有几个垒？
        ar: كم قاعدة في ملعب البيسبول، مع قاعدة البداية (الهوم)؟

        # sp.surfing sports 3
        en: Surfing has its roots in which part of the world? | Polynesia, including Hawaii | The Canary Islands | The Caribbean | Iceland
        fr: Le surf a ses racines dans quelle partie du monde ? | La Polynésie, dont Hawaï | Les Canaries | Les Caraïbes | L'Islande
        es: ¿En qué parte del mundo tiene sus raíces el surf? | La Polinesia, incluida Hawái | Las Canarias | El Caribe | Islandia
        de: Wo auf der Welt liegen die Wurzeln des Surfens? | In Polynesien, einschließlich Hawaii | Auf den Kanaren | In der Karibik | In Island
        it: In quale parte del mondo ha le sue radici il surf? | La Polinesia, Hawaii compresa | Le Canarie | I Caraibi | L'Islanda
        pt: Em que parte do mundo o surfe tem suas raízes? | Na Polinésia, incluindo o Havaí | Nas Canárias | No Caribe | Na Islândia
        ja: サーフィンのルーツがある地域は？ | ハワイを含むポリネシア | カナリア諸島 | カリブ海 | アイスランド
        ko: 서핑이 시작된 곳은 세계의 어느 지역일까요? | 하와이를 포함한 폴리네시아 | 카나리아 제도 | 카리브해 | 아이슬란드
        zh: 冲浪起源于世界哪个地区？ | 包括夏威夷在内的波利尼西亚 | 加那利群岛 | 加勒比 | 冰岛
        ar: أين تعود جذور رياضة ركوب الأمواج؟ | بولينيزيا ومنها هاواي | جزر الكناري | الكاريبي | آيسلندا

        # sp.checkmate sports 1
        en: How do you win a game of chess? | By checkmating the king | By taking the queen | By taking every piece | By reaching the far row
        fr: Comment gagne-t-on une partie d'échecs ? | En faisant échec et mat au roi | En prenant la dame | En prenant toutes les pièces | En atteignant la dernière rangée
        es: ¿Cómo se gana una partida de ajedrez? | Dando jaque mate al rey | Capturando la dama | Capturando todas las piezas | Llegando a la última fila
        de: Wie gewinnt man eine Schachpartie? | Indem man den König mattsetzt | Indem man die Dame schlägt | Indem man alle Figuren schlägt | Indem man die letzte Reihe erreicht
        it: Come si vince una partita a scacchi? | Dando scacco matto al re | Mangiando la regina | Mangiando tutti i pezzi | Arrivando all'ultima riga
        pt: Como se vence uma partida de xadrez? | Dando xeque-mate no rei | Capturando a dama | Capturando todas as peças | Chegando à última fileira
        ja: チェスで勝つにはどうする？ | キングをチェックメイトする | クイーンを取る | 駒を全部取る | いちばん奥の列に着く
        ko: 체스에서 이기려면 어떻게 해야 할까요? | 킹을 체크메이트한다 | 퀸을 잡는다 | 모든 말을 잡는다 | 맨 끝 줄에 도착한다
        zh: 怎样赢得一盘国际象棋？ | 将死对方的王 | 吃掉对方的后 | 吃光所有棋子 | 走到最后一排
        ar: كيف تفوز في لعبة الشطرنج؟ | بإيقاع ملك الخصم في «كش مات» | بأخذ الوزير | بأخذ كل القطع | بالوصول إلى الصف الأخير
        """
}
