extension Games.WordBank {
    // Balloon Words: each language's own everyday words by category (not translations of one list). Chinese gives
    // characters and the pinyin that is guessed. Spaces, hyphens and Japanese ー are shown, never guessed.
    static let balloonSource = """
        # animals
        en: cat, dog, horse, rabbit, turtle, elephant, giraffe, penguin, dolphin, butterfly, squirrel, kangaroo, octopus, hedgehog, owl, zebra
        fr: chat, chien, cheval, lapin, tortue, éléphant, girafe, pingouin, dauphin, papillon, écureuil, kangourou, pieuvre, hérisson, hibou, zèbre
        es: gato, perro, caballo, conejo, tortuga, elefante, jirafa, pingüino, delfín, mariposa, ardilla, canguro, pulpo, erizo, búho, cebra, araña
        de: Katze, Hund, Pferd, Hase, Schildkröte, Elefant, Giraffe, Pinguin, Delfin, Schmetterling, Eichhörnchen, Känguru, Krake, Igel, Eule, Zebra
        it: gatto, cane, cavallo, coniglio, tartaruga, elefante, giraffa, pinguino, delfino, farfalla, scoiattolo, canguro, polpo, riccio, gufo, zebra
        pt: gato, cachorro, cavalo, coelho, tartaruga, elefante, girafa, pinguim, golfinho, borboleta, esquilo, canguru, polvo, coruja, zebra, macaco
        ja: こねこ, こいぬ, うさぎ, きつね, たぬき, ゴリラ, きりん, ペンギン, イルカ, ちょうちょ, ライオン, カンガルー, くじら, ふくろう, しまうま, あひる, ひつじ
        ko: 고양이, 강아지, 토끼, 여우, 거북이, 코끼리, 기린, 펭귄, 돌고래, 나비, 다람쥐, 캥거루, 문어, 고슴도치, 부엉이, 얼룩말
        zh: 熊猫=xiong mao, 老虎=lao hu, 兔子=tu zi, 狐狸=hu li, 乌龟=wu gui, 大象=da xiang, 长颈鹿=chang jing lu, 企鹅=qi e, 海豚=hai tun, 蝴蝶=hu die, 松鼠=song shu, 袋鼠=dai shu, 章鱼=zhang yu, 刺猬=ci wei, 斑马=ban ma, 猴子=hou zi
        ar: قطة, كلب, حصان, أرنب, سلحفاة, فيل, زرافة, بطريق, دلفين, فراشة, سنجاب, كنغر, أخطبوط, قنفذ, بومة, جمل
        # food
        en: apple, banana, bread, cheese, carrot, tomato, orange, cherry, pancake, noodles, cookie, potato, strawberry, pizza, soup, rice
        fr: pomme, banane, pain, fromage, carotte, tomate, orange, cerise, crêpe, gâteau, biscuit, fraise, salade, soupe, riz, citron
        es: manzana, plátano, pan, queso, zanahoria, tomate, naranja, cereza, galleta, patata, fresa, sopa, arroz, limón, piña, tortilla
        de: Apfel, Banane, Brot, Käse, Karotte, Tomate, Orange, Kirsche, Kuchen, Keks, Kartoffel, Erdbeere, Suppe, Reis, Zitrone, Nudeln
        it: mela, banana, pane, formaggio, carota, pomodoro, arancia, ciliegia, biscotto, patata, fragola, minestra, riso, limone, gelato, pizza
        pt: maçã, banana, pão, queijo, cenoura, tomate, laranja, cereja, biscoito, batata, morango, sopa, arroz, limão, abacaxi, bolo
        ja: りんご, バナナ, ラーメン, グラタン, にんじん, トマト, みかん, さくらんぼ, クッキー, じゃがいも, いちご, おにぎり, ごはん, レモン, うどん, ホットケーキ
        ko: 사과, 바나나, 빵, 치즈, 당근, 토마토, 오렌지, 체리, 과자, 감자, 딸기, 김밥, 수박, 레몬, 국수, 케이크
        zh: 苹果=ping guo, 香蕉=xiang jiao, 面包=mian bao, 奶酪=nai lao, 胡萝卜=hu luo bo, 西红柿=xi hong shi, 橙子=cheng zi, 樱桃=ying tao, 饼干=bing gan, 土豆=tu dou, 草莓=cao mei, 米饭=mi fan, 西瓜=xi gua, 柠檬=ning meng, 面条=mian tiao, 饺子=jiao zi
        ar: تفاحة, موز, خبز, جبنة, جزرة, طماطم, برتقالة, كرز, بسكويت, بطاطا, فراولة, شوربة, أرز, ليمون, بطيخ, كعكة
        # home
        en: chair, table, window, door, pillow, blanket, mirror, kitchen, sofa, lamp, clock, spoon, bottle, carpet, stairs, garden
        fr: chaise, table, fenêtre, porte, oreiller, couverture, miroir, cuisine, canapé, lampe, horloge, cuillère, bouteille, tapis, escalier, jardin
        es: silla, mesa, ventana, puerta, almohada, manta, espejo, cocina, sofá, lámpara, reloj, cuchara, botella, alfombra, escalera, jardín
        de: Stuhl, Tisch, Fenster, Tür, Kissen, Decke, Spiegel, Küche, Sofa, Lampe, Uhr, Löffel, Flasche, Teppich, Treppe, Garten
        it: sedia, tavolo, finestra, porta, cuscino, coperta, specchio, cucina, divano, lampada, orologio, cucchiaio, bottiglia, tappeto, scala, giardino
        pt: cadeira, mesa, janela, porta, travesseiro, cobertor, espelho, cozinha, sofá, lâmpada, relógio, colher, garrafa, tapete, escada, jardim
        ja: ざぶとん, つくえ, カーテン, とびら, まくら, ふとん, かがみ, だいどころ, ソファ, でんき, とけい, スプーン, コップ, じゅうたん, かいだん, れいぞうこ
        ko: 의자, 책상, 창문, 대문, 베개, 이불, 거울, 부엌, 소파, 전등, 시계, 숟가락, 물병, 카펫, 계단, 마당
        zh: 椅子=yi zi, 桌子=zhuo zi, 窗户=chuang hu, 门口=men kou, 枕头=zhen tou, 被子=bei zi, 镜子=jing zi, 厨房=chu fang, 沙发=sha fa, 台灯=tai deng, 钟表=zhong biao, 勺子=shao zi, 瓶子=ping zi, 地毯=di tan, 楼梯=lou ti, 花园=hua yuan
        ar: كرسي, طاولة, نافذة, باب, وسادة, بطانية, مرآة, مطبخ, أريكة, مصباح, ساعة, ملعقة, زجاجة, سجادة, درج, حديقة
        # nature
        en: tree, flower, river, mountain, forest, cloud, rainbow, island, desert, ocean, volcano, leaf, rain, snow, star, moon
        fr: arbre, fleur, rivière, montagne, forêt, nuage, arc-en-ciel, île, désert, océan, volcan, feuille, pluie, neige, étoile, lune
        es: árbol, flor, río, montaña, bosque, nube, arcoíris, isla, desierto, océano, volcán, hoja, lluvia, nieve, estrella, luna
        de: Baum, Blume, Fluss, Berg, Wald, Wolke, Regenbogen, Insel, Wüste, Ozean, Vulkan, Blatt, Regen, Schnee, Stern, Mond
        it: albero, fiore, fiume, montagna, bosco, nuvola, arcobaleno, isola, deserto, oceano, vulcano, foglia, pioggia, neve, stella, luna
        pt: árvore, flor, rio, montanha, floresta, nuvem, arco-íris, ilha, deserto, oceano, vulcão, folha, chuva, neve, estrela, lua
        ja: さくら, たんぽぽ, ひまわり, みずうみ, かざん, はっぱ, あまぐも, ゆきだるま, ほしぞら, たいよう, さばく, おがわ, いなずま, もみじ, どんぐり, ゆうやけ
        ko: 나무, 꽃잎, 강물, 바다, 숲속, 구름, 무지개, 섬마을, 사막, 하늘, 화산, 나뭇잎, 빗물, 눈사람, 별빛, 달빛
        zh: 大树=da shu, 鲜花=xian hua, 河流=he liu, 高山=gao shan, 森林=sen lin, 白云=bai yun, 彩虹=cai hong, 小岛=xiao dao, 沙漠=sha mo, 海洋=hai yang, 火山=huo shan, 树叶=shu ye, 雨水=yu shui, 雪花=xue hua, 星星=xing xing, 月亮=yue liang
        ar: شجرة, زهرة, نهر, جبل, غابة, سحابة, قوس قزح, جزيرة, صحراء, محيط, بركان, ورقة, مطر, ثلج, نجمة, قمر
        # clothes
        en: shirt, trousers, dress, skirt, jacket, sweater, scarf, gloves, socks, shoes, boots, hat, pyjamas, coat, belt, sandals
        fr: chemise, pantalon, robe, jupe, veste, pull, écharpe, gants, chaussettes, chaussures, bottes, chapeau, pyjama, manteau, ceinture, sandales
        es: camisa, pantalón, vestido, falda, chaqueta, jersey, bufanda, guantes, calcetines, zapatos, botas, sombrero, pijama, abrigo, cinturón, sandalias
        de: Hemd, Hose, Kleid, Rock, Jacke, Pullover, Schal, Handschuhe, Socken, Schuhe, Stiefel, Mütze, Schlafanzug, Mantel, Gürtel, Sandalen
        it: camicia, pantaloni, vestito, gonna, giacca, maglione, sciarpa, guanti, calzini, scarpe, stivali, cappello, pigiama, cappotto, cintura, sandali
        pt: camisa, calça, vestido, saia, jaqueta, suéter, cachecol, luvas, meias, sapatos, botas, chapéu, pijama, casaco, cinto, sandálias
        ja: シャツ, ズボン, ワンピース, スカート, うわぎ, カーディガン, マフラー, てぶくろ, くつした, うわばき, ながぐつ, ぼうし, パジャマ, レインコート, ベルト, サンダル
        ko: 셔츠, 바지, 원피스, 치마, 재킷, 스웨터, 목도리, 장갑, 양말, 신발, 장화, 모자, 잠옷, 외투, 허리띠, 샌들
        zh: 衬衫=chen shan, 裤子=ku zi, 裙子=qun zi, 外套=wai tao, 毛衣=mao yi, 围巾=wei jin, 手套=shou tao, 袜子=wa zi, 鞋子=xie zi, 靴子=xue zi, 帽子=mao zi, 睡衣=shui yi, 大衣=da yi, 腰带=yao dai, 凉鞋=liang xie, 背心=bei xin
        ar: قميص, سروال, فستان, تنورة, سترة, كنزة, وشاح, قفازات, جوارب, حذاء, جزمة, قبعة, بيجامة, معطف, حزام, صندل
        # transport
        en: car, bus, train, bicycle, airplane, boat, ship, rocket, taxi, truck, tractor, helicopter, scooter, subway, ferry, tram
        fr: voiture, bus, train, vélo, avion, bateau, navire, fusée, taxi, camion, tracteur, hélicoptère, trottinette, métro, ferry, tramway
        es: coche, autobús, tren, bicicleta, avión, barco, cohete, taxi, camión, tractor, helicóptero, patinete, metro, ferri, tranvía, moto
        de: Auto, Bus, Zug, Fahrrad, Flugzeug, Boot, Schiff, Rakete, Taxi, Lastwagen, Traktor, Hubschrauber, Roller, Fähre, Seilbahn, Motorrad
        it: auto, autobus, treno, bicicletta, aereo, barca, nave, razzo, taxi, camion, trattore, elicottero, monopattino, metro, traghetto, tram
        pt: carro, ônibus, trem, bicicleta, avião, barco, navio, foguete, táxi, caminhão, trator, helicóptero, patinete, metrô, balsa, bonde
        ja: くるま, モノレール, でんしゃ, じてんしゃ, ひこうき, ゴンドラ, ロケット, タクシー, トラック, トラクター, ヘリコプター, ちかてつ, しんかんせん, きしゃ, ヨット, パトカー
        ko: 자동차, 버스, 기차, 자전거, 비행기, 돛단배, 로켓, 택시, 트럭, 트랙터, 헬리콥터, 지하철, 오토바이, 유람선, 전철, 구급차
        zh: 汽车=qi che, 公交车=gong jiao che, 火车=huo che, 自行车=zi xing che, 飞机=fei ji, 轮船=lun chuan, 火箭=huo jian, 出租车=chu zu che, 卡车=ka che, 拖拉机=tuo la ji, 直升机=zhi sheng ji, 地铁=di tie, 摩托车=mo tuo che, 高铁=gao tie, 小船=xiao chuan, 救护车=jiu hu che
        ar: سيارة, حافلة, قطار, دراجة, طائرة, قارب, سفينة, صاروخ, تاكسي, شاحنة, جرار, مروحية, مترو, عبارة, ترام, دراجة نارية
        # sports
        en: football, tennis, swimming, running, skiing, cycling, boxing, judo, karate, rugby, golf, hockey, basketball, volleyball, chess, surfing
        fr: football, tennis, natation, course, ski, cyclisme, judo, karaté, rugby, golf, hockey, basket, volley, échecs, surf, escrime
        es: fútbol, tenis, natación, carrera, esquí, ciclismo, judo, kárate, rugby, golf, hockey, baloncesto, voleibol, ajedrez, surf, gimnasia
        de: Handball, Tennis, Schwimmen, Laufen, Skifahren, Radsport, Judo, Karate, Rugby, Golf, Hockey, Basketball, Volleyball, Schach, Surfen, Turnen
        it: calcio, tennis, nuoto, corsa, sci, ciclismo, judo, karate, rugby, golf, hockey, pallacanestro, pallavolo, scacchi, surf, ginnastica
        pt: futebol, tênis, natação, corrida, esqui, ciclismo, judô, caratê, rúgbi, golfe, hóquei, basquete, vôlei, xadrez, surfe, ginástica
        ja: サッカー, テニス, すいえい, かけっこ, スケート, じゅうどう, からて, ラグビー, ゴルフ, ホッケー, バスケット, バレーボール, チェス, サーフィン, たいそう, すもう
        ko: 축구, 테니스, 수영, 달리기, 스키, 유도, 태권도, 럭비, 골프, 하키, 농구, 배구, 체스, 서핑, 체조, 씨름
        zh: 足球=zu qiu, 网球=wang qiu, 游泳=you yong, 跑步=pao bu, 滑雪=hua xue, 骑车=qi che, 柔道=rou dao, 空手道=kong shou dao, 橄榄球=gan lan qiu, 高尔夫=gao er fu, 冰球=bing qiu, 篮球=lan qiu, 排球=pai qiu, 象棋=xiang qi, 冲浪=chong lang, 体操=ti cao
        ar: كرة القدم, تنس, سباحة, جري, تزلج, ركوب الدراجات, جودو, كاراتيه, رغبي, غولف, هوكي, كرة السلة, كرة الطائرة, شطرنج, ركمجة, جمباز
        # music
        en: piano, guitar, violin, drum, flute, trumpet, harp, song, singer, choir, concert, rhythm, melody, cello, saxophone, xylophone
        fr: piano, guitare, violon, tambour, flûte, trompette, harpe, chanson, chanteur, chorale, concert, rythme, mélodie, violoncelle, saxophone, xylophone
        es: piano, guitarra, violín, tambor, flauta, trompeta, arpa, canción, cantante, coro, concierto, ritmo, melodía, violonchelo, saxofón, xilófono
        de: Klavier, Gitarre, Geige, Trommel, Flöte, Trompete, Harfe, Lied, Sänger, Chor, Konzert, Rhythmus, Melodie, Cello, Saxofon, Xylofon
        it: pianoforte, chitarra, violino, tamburo, flauto, tromba, arpa, canzone, cantante, coro, concerto, ritmo, melodia, violoncello, sassofono, xilofono
        pt: piano, violão, violino, tambor, flauta, trompete, harpa, canção, cantor, coral, concerto, ritmo, melodia, violoncelo, saxofone, xilofone
        ja: ピアノ, ウクレレ, バイオリン, たいこ, たてぶえ, トランペット, オルガン, こもりうた, かしゅ, がっしょう, コンサート, リズム, メロディー, チェロ, もっきん, カスタネット
        ko: 피아노, 기타, 바이올린, 북소리, 피리, 트럼펫, 하프, 노래, 가수, 합창, 연주회, 리듬, 멜로디, 첼로, 실로폰, 장구
        zh: 钢琴=gang qin, 吉他=ji ta, 小提琴=xiao ti qin, 鼓声=gu sheng, 笛子=di zi, 小号=xiao hao, 竖琴=shu qin, 歌曲=ge qu, 歌手=ge shou, 合唱=he chang, 音乐会=yin yue hui, 节奏=jie zou, 旋律=xuan lü, 大提琴=da ti qin, 萨克斯=sa ke si, 琵琶=pi pa
        ar: بيانو, غيتار, كمان, طبل, ناي, بوق, قيثارة, أغنية, مغني, جوقة, حفلة, إيقاع, لحن, عود, ساكسفون, دربكة
        """
}
