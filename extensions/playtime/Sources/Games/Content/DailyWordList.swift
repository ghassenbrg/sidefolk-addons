extension Games.WordBank {
    // Daily Word answers: five letters in the Latin-script languages and Arabic, four kana in Japanese, five jamo
    // (two syllables) in Korean, a four-character idiom (成语) in Chinese. Everyday words, nothing unkind.
    static let dailySource = """
        # daily
        en: apple, beach, bread, brick, cabin, candy, chair, cloud, clock, crane, dance, dream, eagle, earth
        en: field, flame, flute, frost, fruit, giant, glass, grape, grass, heart, honey, horse, house, juice
        en: knife, lemon, light, lunch, maple, melon, money, mouse, music, night, ocean, olive, onion, paint
        en: panda, paper, peach, pearl, piano, pilot, plant, plate, queen, quiet, radio, river, robot, salad
        en: scarf, sheep, shell, shirt, skirt, smile, snake, spoon, stone, storm, sugar, sunny, table, tiger
        en: toast, tooth, towel, tower, train, truck, wagon, water, whale, wheat, wheel, world, zebra, bloom
        en: brave, cheer, coral, daisy, dough, feast, globe, happy, jelly, laugh, lucky, magic, mango, party
        en: petal, quilt, sweet, swing, thumb, tulip, windy, cocoa, otter, raven, badge, beard, bench, berry
        en: chess, crown, fairy, flock, lemur, cider, canoe, camel, koala, llama, moose, sloth, hippo, bunny
        en: puppy, kitty, goose, robin, heron, acorn, bacon, basil, bagel, blush, books, brush, comet, couch
        en: crumb, daily, denim, diary, eager, fable, fancy, fiber, fizzy, flora, focus, forty, frame, fresh
        en: glove, grain, habit, hatch, hobby, igloo, image, ivory, jewel, jolly, kayak, kneel, ladle, latch
        en: lilac, linen, lodge, marsh, medal, minty, mirth, misty, mossy, nerve, noble, novel, nutty, oasis
        en: orbit, organ, ounce, pasta, patch, pause, pedal, penny, perch, plaza, plume, polka, poppy, pouch
        en: prism, prize, proud, quest, quick, quota, rainy, ranch, relax, ripen, roast, rocky, rover, royal
        en: rumba, sauce, scone, shade, shiny, shore, skate, slope, smart, snack, snowy, solar, sound, spice
        en: spark, sprig, stamp, steam, stool, straw, syrup, taffy, teach, tempo, thyme, tidal, topaz, torch
        en: trail, treat, trunk, tunes, udder, uncle, unity, usher, valid, vapor, vault, vivid, vocal, waltz
        en: waves, wharf, whisk, witty, woven, yacht, yeast, yodel, young, yummy, zesty
        fr: arbre, avion, balle, bijou, blanc, bulle, cadre, carte, chant, chien, chose, conte, corde, coton
        fr: crabe, crème, danse, dents, douce, drôle, école, écran, faute, fleur, foire, forêt, fruit, glace
        fr: grain, herbe, hiver, homme, jaune, jeudi, jouet, juste, lampe, lapin, livre, loupe, lundi, magie
        fr: mardi, marée, melon, merci, monde, neige, nuage, océan, ombre, orage, outil, pêche, petit, piano
        fr: pieds, plage, plume, pluie, poire, pomme, porte, poule, prune, radio, reine, repas, rêver, riche
        fr: robot, rouge, route, sable, salle, salon, sapin, sirop, soupe, sucre, table, tarte, temps, terre
        fr: tigre, train, vache, valse, verre, vitre, voile, wagon, zèbre, astre, barbe, biche, bravo, brise
        fr: câble, calme, chaud, colis, craie, cygne, éclat, épice, étude, fable, farce, forme, frère, fumée
        fr: givre, grêle, guide, hibou, image, jambe, joyau, koala, lilas, linge, litre, lueur, matin, olive
        fr: panda, pelle, perle, phare, piste, place, poème, pouce, ruche, sabot, singe, sport, stylo, tasse
        fr: thème, tissu, titre, tuile, usine, vigne, ville, zeste, avril, ourse, cacao, canot, carré, chêne
        fr: clown, cobra, copie, douze, flûte, fusée, gomme, hamac, kayak, laine, lèvre, métal, motte, noyau
        fr: oasis, ongle, pagne, paume, pinte, pivot, plaid, poney, radar, rotin, sauge, stade, sueur, tapis
        fr: tomme, acier, algue, ancre, appel, arche, atlas, bague, balai, banjo, bison, blond, bocal, bonté
        fr: borne, bouée, boule, buche, bûche, cèdre, cidre, corps, coupe, délai, désir, envol, épine, étang
        fr: fiole, foyer, frais, frite, gants, géant, globe, gorge, grive, guêpe, hache, halte, harpe, hêtre
        fr: houle, huile, igloo, jeton, lacet, laser, léger, lotus, loyer, merle, meule, moule, musée, navet
        fr: nappe, noble, nuque, odeur, opale, ortie, ouate, pâtes, pavot, pente, quête, radis, rayon, récit
        fr: règle, rhume, ronce, rosée, rubis, ruban, saule, seuil, taupe, tenue, trace, usage, vague, veste
        fr: vidéo, yacht
        es: árbol, arena, avión, barco, bolsa, brazo, burro, cabra, caldo, calle, campo, canto, carne, carta
        es: cerdo, cielo, cinta, clima, coche, color, comer, crema, cuero, dulce, fruta, fuego, gallo, globo
        es: gorra, grano, hielo, huevo, jabón, joven, juego, jugar, lápiz, leche, libro, limón, lindo, llave
        es: madre, mango, manta, marzo, metro, mundo, museo, nieve, noche, nuevo, olivo, oreja, oveja, padre
        es: palma, panda, papel, pasta, patio, perro, piano, plato, playa, plaza, pluma, pollo, prado, primo
        es: pulpo, queso, radio, reina, ruido, salsa, selva, silla, sobre, suelo, sueño, tarde, tarta, techo
        es: tigre, tinta, torre, trigo, verde, viaje, vuelo, zorro, abeja, amigo, banco, barba, cacao, cajón
        es: calor, canoa, cebra, cisne, disco, fresa, gafas, gusto, hongo, horno, lente, letra, melón, monte
        es: nariz, norte, oasis, panal, pasto, peine, perla, punto, regla, robot, rueda, salón, señal, sello
        es: sitio, traje, trono, valle, vapor, yegua, yogur, acero, aguja, ancla, arroz, atlas, bahía, baile
        es: balde, bolso, bombo, bordo, botón, brisa, broma, cable, cacto, canal, cañón, caoba, carro, casco
        es: cesto, chico, circo, cobre, cofre, coral, corto, cueva, dados, delta, diana, dicha, doble, ducha
        es: enano, falda, feria, fibra, finca, flaco, flora, fondo, freno, ganso, gesto, gorro, grupo, guapo
        es: hacha, hogar, hueso, icono, jarra, jaula, labio, lecho, lento, lince, lista, llama, lugar, lunar
        es: magia, malla, marea, menta, miedo, milla, mitad, molde, mosca, motor, muela, nácar, navío, nieto
        es: ocaso, orden, oruga, otoño, palco, palmo, pañal, parra, pausa, pedal, pesca, pinza, plata, plomo
        es: poema, polvo, poste, prisa, pulga, pulso, rampa, rango, rasgo, recta, reloj, ritmo, rodeo, rombo
        es: ronda, rubio, rumbo, sabor, salud, sauce, siglo, soplo, sorbo, suave, sudor, suela, tabla, talla
        es: tango, tapia, tarro, tecla, telar, tenis, tibio, tilde, timón, tocón, toldo, torta, tramo, trapo
        es: trato, trozo, tucán, turno, vacío, vagón, valor, vello, venta, verbo, villa, viola, visón, yerba
        es: yunta, zanja, zarza, zueco
        de: Apfel, Ampel, Birne, Blatt, Blume, Boden, Brief, Dachs, Dampf, Decke, Draht, Eimer, Engel, Ernte
        de: Farbe, Feder, Fisch, Flöte, Fluss, Gabel, Geige, Glück, Hafen, Hagel, Harfe, Hecke, Honig, Hütte
        de: Insel, Jacke, Kabel, Kamel, Katze, Kerze, Kette, Kiste, Klang, Knopf, Koala, Krone, Kugel, Küche
        de: Lampe, Licht, Linde, Luchs, Maske, Meise, Milch, Möhre, Musik, Nacht, Nadel, Nebel, Nudel, Ozean
        de: Palme, Panda, Pferd, Pilot, Platz, Puppe, Quark, Regen, Reise, Rinde, Sahne, Salat, Schaf, Segel
        de: Sonne, Spiel, Stadt, Stern, Stuhl, Suppe, Tafel, Tanne, Tasse, Teich, Tiger, Tisch, Traum, Tulpe
        de: Vogel, Waage, Wagen, Wolke, Wolle, Wurst, Zange, Zebra, Ziege, Zweig, Fähre, Käfer, Mühle, Abend
        de: Angel, Ärmel, Beere, Besen, Biber, Blitz, Bogen, Brett, Eisen, Fahne, Feuer, Kakao, Karte, Kater
        de: Kleid, Kranz, Lachs, Leder, Liebe, Löwin, Markt, Mauer, Mütze, Pause, Perle, Riese, Rolle, Säule
        de: Schal, Seife, Socke, Stein, Stift, Tante, Wiese, Adler, Anker, Atlas, Bauch, Biene, Bluse, Bohne
        de: Brühe, Brust, Busch, Daune, Diele, Eiche, Essig, Esche, Fabel, Falke, Faser, Feier, Ferse, Föhre
        de: Forst, Frost, Fuchs, Garbe, Gasse, Geist, Gerte, Glanz, Gleis, Gramm, Grill, Gunst, Gurke, Hafer
        de: Halle, Hasel, Hauch, Haube, Heide, Herde, Hirse, Hirte, Höhle, Hügel, Jäger, Kamin, Kanal, Kanne
        de: Kappe, Karre, Kasse, Keule, Klima, Knauf, Kohle, Kraft, Kraut, Kreis, Kunst, Kutte, Lager, Laken
        de: Lanze, Laune, Lauch, Leine, Leser, Linse, Liste, Locke, Lotse, Lunge, Magen, Mappe, Masse, Matte
        de: Menge, Miene, Minze, Mixer, Molch, Moped, Motor, Mulde, Mumie, Nabel, Narbe, Nelke, Neffe, Niere
        de: Ochse, Olive, Orden, Orgel, Otter, Pappe, Paste, Pedal, Pfahl, Pfote, Pinie, Pirat, Pokal, Polka
        de: Posse, Prinz, Probe, Puder, Punkt, Radio, Rampe, Ranke, Rasen, Raupe, Regal, Reich, Rente, Rille
        de: Robbe, Rodel, Roman, Rubin, Rüben, Ruder, Rumpf, Runde, Sache, Sauna, Seide, Senke, Sense, Sesam
        de: Sirup, Skala, Sohle, Sorte, Spitz, Sport, Spule, Staub, Stock, Stoff, Strom, Stube, Stufe, Sturm
        de: Sumpf, Szene, Tacho, Tango, Taube, Tenor, Thron, Tinte, Titel, Torte, Trank, Treue, Truhe, Umweg
        de: Vater, Wachs, Wange, Wanne, Watte, Weber, Weide, Weile, Welle, Welpe, Wespe, Wonne, Zacke, Zeile
        de: Zelle, Zitat, Zunge
        it: acqua, amico, arena, barca, bocca, bosco, brodo, campo, carta, cielo, cigno, colla, corda, cuore
        it: dente, dolce, donna, fiore, fiume, forno, fuoco, gatto, gioco, gonna, grano, isola, latte, leone
        it: letto, libro, lince, mamma, miele, monte, mondo, notte, oliva, palla, panda, panna, parco, pasta
        it: penna, pesca, piano, piede, pizza, porta, prato, radio, ruota, salsa, scala, sedia, selva, sonno
        it: sport, tazza, tenda, terra, tetto, tigre, torre, torta, treno, vento, verde, vespa, vetro, viola
        it: zaino, zebra, zucca, aereo, banco, barba, borsa, bravo, calma, canto, capra, carne, cesto, cuoco
        it: danza, festa, fiaba, gallo, gesso, legno, lente, lepre, mappa, museo, nonna, nonno, opera, panca
        it: perla, pesce, piuma, pollo, ponte, rospo, sasso, stufa, volpe, abete, acero, agave, aglio, ambra
        it: amore, anice, asino, avena, bagno, basco, becco, bimbo, bolla, borgo, botte, bruco, burro, busta
        it: caffè, calza, canoa, casco, cassa, cedro, ceppo, cervo, cinta, circo, cocco, conca, conto, coppa
        it: corno, corsa, corte, costa, crema, croce, culla, curva, dosso, duomo, falco, fango, farro, felce
        it: ferro, fetta, fibra, flora, fonte, forma, gamba, garza, gemma, gioia, gnomo, icona, lampo, lardo
        it: lista, magia, manto, marea, marmo, masso, mazzo, menta, mento, merlo, metro, molla, mosca, mucca
        it: ombra, orata, pacco, padre, palma, pasto, patto, pelle, pigna, pista, pizzo, polpo, porto, pozzo
        it: prova, pugno, pulce, punto, razzo, regno, sacco, salto, scafo, scudo, sella, sorso, spago, stelo
        it: talpa, tasca, tonno, trama, trave, ulivo, uscio, venti, vetta, viale, vigna, villa, volto, zampa
        it: zappa, zolla, zuppa
        pt: areia, banco, barco, bolsa, braço, cabra, caixa, calor, campo, carne, carta, chave, chuva, cinto
        pt: cobra, couro, dança, festa, filme, fogão, fruta, garfo, grama, hotel, jarra, lápis, leite, limão
        pt: livro, manga, massa, melão, metrô, milho, mundo, navio, noite, nuvem, papel, peixe, pente, perna
        pt: pedra, piano, pizza, praia, prato, rádio, roupa, selva, sinal, tarde, terra, tigre, trigo, vento
        pt: verde, vidro, viola, zebra, amora, avião, banho, barba, beijo, bicho, bolha, cacau, canto, circo
        pt: cravo, disco, dente, folha, fonte, forno, gaita, garça, lagoa, lenço, lindo, louça, magia, manta
        pt: março, moeda, nariz, ninho, palha, panda, pavão, porta, pulga, rosto, samba, tinta, abril, altar
        pt: amigo, apito, arroz, atlas, aveia, baile, baixo, balde, bando, banda, barro, bloco, bombo, bravo
        pt: brisa, broto, burro, cacho, calça, calmo, canal, canoa, capim, carro, casco, caule, cerca, cesta
        pt: chalé, chefe, cheio, choro, cinza, clima, clube, colar, conto, coral, corpo, corte, couve, creme
        pt: curso, dócil, dúzia, época, farol, fauna, feira, feixe, ferro, fiapo, fibra, flora, fluxo, frase
        pt: freio, frevo, frita, funil, galho, ganso, gente, geada, globo, golfe, gorro, gosto, grade, grato
        pt: grilo, grito, grupo, gruta, haste, horta, jarro, jeito, jovem, junho, justo, lebre, lente, lesma
        pt: lince, lírio, litro, lombo, longo, louro, lugar, lunar, luvas, macio, maior, manha, marca, mecha
        pt: melro, menta, metal, miado, moita, molho, monte, morro, mosca, motor, mural, museu, nervo, nobre
        pt: norte, notas, nozes, oeste, órgão, palco, palma, parto, passo, pasta, pátio, pausa, pedal, perto
        pt: pesca, piada, pilha, pinho, pista, placa, plano, poema, poeta, polvo, ponte, porco, posto, prado
        pt: praça, prata, prazo, preço, presa, pudim, punho, quilo, raiva, rampa, reino, relva, renda, risco
        pt: ritmo, rocha, rolha, rumor, sábio, salsa, salto, sauna, sério, sítio, sobra, sonho, sopro, sorte
        pt: suave, sushi, tábua, talco, tango, tecla, telha, tempo, tenda, tênis, tiara, tocha, toldo, torre
        pt: torta, traço, trapo, trevo, tribo, trono, truta, turma, usina, vapor, varal, venda, vespa, viela
        pt: zinco
        ja: あさがお, あじさい, いちょう, えんぴつ, おにぎり, おまつり, かぼちゃ, からあげ, きつつき, きゅうり, くじゃく, くつした, けいさつ, こおろぎ
        ja: ことわざ, しまうま, しんぶん, すいとう, せんたく, たいよう, たけのこ, たまねぎ, たんぽぽ, てぶくろ, でんしゃ, ともだち, にんじん, のりもの
        ja: ひこうき, ひまわり, ふうせん, ふくろう, ほしぞら, みずうみ, むらさき, ようふく, れんこん, ろうそく, わたあめ, あまぐも, いなずま, おとうと
        ja: かみなり, かいだん, がっこう, くだもの, げんかん, しあわせ, しょうゆ, すいせん, そらまめ, ちきゅう, どうぶつ, にじいろ, にわとり, はなたば
        ja: はみがき, はるかぜ, まないた, みずたま, もちつき, やまびこ, ゆうやけ, ライオン, りょうり, あおぞら, あめふり, いちばん, おもちゃ, きんぎょ
        ja: けしごむ, さかみち, さんかく, しろくま, すなはま, ちゃわん, つりばし, とびばこ, なわとび, ねこじた, はなぞの, ほうせき, まめまき, ゆりかご
        ja: ペンギン, サンダル, ポケット, ロケット, ラケット, ハンカチ, パジャマ, キャベツ, マラソン, ジャンプ, おはなし, おひさま, おふろば, しおかぜ
        ja: しゃしん, しょくじ, すずらん, そうめん, てんぐさ, とうがん, どんぐり, なのはな, ねむのき, はくさい, ひだまり, ふくびき, ぶらんこ, みのむし
        ja: むぎちゃ, もみのき, やきいも, らくがき, るすばん, いけばな, うぐいす, うみねこ, えだまめ, おおかみ, かいすい, かまくら, きせかえ, くじびき
        ja: くすだま, こうえん, こけもも, しいたけ, せっけん, ぞうきん, だいこん, たこあげ, とうだい, にほんご, はなまる, ふでばこ, まきずし, みつばち
        ja: もくせい, ゆうびん, ようかん, りんどう, わかくさ, いもうと, くつばこ, さかなや, しゃもじ, すきやき, せんせい, とびうお, ふじさん, まくらぎ
        ja: みそしる, めがねや, おりがみ, くまぜみ, しらたま, ともしび, ふうりん, みかづき, やきそば
        ko: 가방, 가을, 감자, 거울, 겨울, 구름, 국수, 기린, 김치, 날씨, 냄비, 바람, 사랑, 하늘
        ko: 우산, 수박, 사진, 시간, 친구, 학교, 지갑, 사탕, 의자, 수건, 침대, 이불, 거실, 부엌
        ko: 마당, 시장, 택시, 배낭, 편지, 잔치, 북채, 장구, 화가, 시인, 작가, 의사, 농부, 소방
        ko: 만두, 라면, 갈비, 사과, 무침, 호박, 양파, 마늘, 버섯, 앵두, 살구, 딸기, 석류, 벌레
        ko: 거북, 문어, 굴비, 연어, 상어, 물개, 참새, 거위, 백조, 표범, 늑대, 판다, 낙타, 폭포
        ko: 계곡, 바위, 자갈, 잔디, 버들, 장미, 해님, 노을, 번개, 안개, 이슬, 우박, 봄비, 여름
        ko: 장마, 태풍, 구슬, 퍼즐, 공기, 썰매, 축구, 농구, 탁구, 수영, 낚시, 소풍, 여행, 등대
        ko: 항구, 터널, 분수, 기와, 대문, 지붕, 계단, 서랍, 액자, 일기, 수첩, 가위, 자석, 현미
        ko: 로켓, 은하, 감기, 기침, 무릎, 배꼽, 반지, 팔찌, 가운, 외투, 단추, 바늘, 열매, 씨앗
        ko: 새싹, 쟁기, 바퀴, 트럭, 헬기, 잠수
        zh: 一心一意, 十全十美, 一帆风顺, 万事如意, 心想事成, 马到成功, 画龙点睛, 守株待兔, 亡羊补牢, 对牛弹琴, 井底之蛙, 狐假虎威
        zh: 画蛇添足, 刻舟求剑, 拔苗助长, 掩耳盗铃, 杯弓蛇影, 叶公好龙, 盲人摸象, 自相矛盾, 滥竽充数, 望梅止渴, 卧薪尝胆, 破釜沉舟
        zh: 四面楚歌, 胸有成竹, 一鸣惊人, 一举两得, 半途而废, 百发百中, 千军万马, 万紫千红, 五颜六色, 七上八下, 九牛一毛, 鸟语花香
        zh: 春暖花开, 风和日丽, 山清水秀, 青出于蓝, 学无止境, 温故知新, 举一反三, 熟能生巧, 持之以恒, 坚持不懈, 自强不息, 实事求是
        zh: 精益求精, 循序渐进, 有条不紊, 井井有条, 一丝不苟, 专心致志, 全神贯注, 聚精会神, 津津有味, 兴高采烈, 欢天喜地, 喜出望外
        zh: 笑逐颜开, 眉开眼笑, 心花怒放, 手舞足蹈, 大惊小怪, 目不转睛, 恍然大悟, 若有所思, 一见如故, 情同手足, 同舟共济, 齐心协力
        zh: 众志成城, 助人为乐, 舍己为人, 拾金不昧, 诚心诚意, 光明磊落, 一言为定, 言而有信, 千方百计, 想方设法, 不可思议, 独一无二
        zh: 举世闻名, 名不虚传, 美不胜收, 琳琅满目, 应有尽有, 五湖四海, 天南地北, 海阔天空, 一望无际, 无边无际, 人山人海, 络绎不绝
        zh: 川流不息, 车水马龙, 冰天雪地, 秋高气爽, 花好月圆, 金玉满堂, 年年有余, 步步高升, 大吉大利, 龙飞凤舞, 龙马精神, 生龙活虎
        zh: 如鱼得水, 鹤立鸡群, 狼吞虎咽, 虎头蛇尾, 对症下药, 雪中送炭, 锦上添花, 水滴石穿, 愚公移山, 精卫填海, 夸父逐日, 女娲补天
        zh: 一日千里, 一目十行, 十拿九稳, 万无一失, 有备无患, 未雨绸缪, 防微杜渐, 当机立断, 随机应变, 因材施教, 有教无类, 不耻下问
        zh: 学而不厌, 诲人不倦, 废寝忘食, 闻鸡起舞, 凿壁偷光, 囊萤映雪, 程门立雪, 孔融让梨, 铁杵成针, 一石二鸟, 三心二意, 两全其美
        zh: 三五成群, 四季如春, 六六大顺, 八仙过海, 九霄云外, 百花齐放, 千山万水, 万里无云, 一清二楚, 一干二净, 一模一样, 一心一德
        zh: 七嘴八舌, 七手八脚, 八面玲珑, 十万火急, 五光十色, 三言两语, 千变万化, 万众一心, 鱼目混珠, 守口如瓶, 胆大心细, 落落大方
        zh: 彬彬有礼, 和蔼可亲, 平易近人, 心平气和, 从容不迫, 不慌不忙, 小心翼翼, 一路平安, 一路顺风, 风调雨顺, 国泰民安, 安居乐业
        zh: 丰衣足食
        ar: مدرسة, مكتبة, حديقة, سيارة, طائرة, نافذة, ملعقة, طاولة, وسادة, حقيبة, سروال, جوارب, صابون, فرشاة
        ar: منشفة, ثلاجة, غسالة, مكنسة, مصباح, حاسوب, ممحاة, مسطرة, سبورة, معلمة, تلميذ, جامعة, مدينة, سفينة
        ar: دراجة, حافلة, شاحنة, صاروخ, ميناء, فراشة, حمامة, عصفور, بطريق, دلفين, غزالة, زرافة, تمساح, دجاجة
        ar: ليمون, زيتون, بطاطا, طماطم, شوربة, سحابة, عاصفة, صحراء, جزيرة, بركان, بحيرة, أسبوع, أغنية, بيانو
        ar: رواية, سينما, سباحة, رياضة, بالون, قلادة, مفتاح, خزانة, مزرعة, منارة, خريطة, بوصلة, مسافر, عائلة
        ar: مهندس, طبيبة, مشمشة, سنجاب, فطيرة, كعكات, عجينة, مروحة, مكواة, سجادة, ستارة, لوحات, ألوان, دفاتر
        ar: حكاية, قصيدة, مجداف, مرساة, محطات, ساعات, منبهة, تقويم, مذكرة, رسالة, طابعة, أكواب, إبريق, فنجان
        ar: صينية, مقلاة, طنجرة, شوكات, مملحة, بستان, واحات, كثبان, حجارة, أشجار, أزهار, زنبقة, بنفسج, سوسنة
        ar: نخلات, تفاحة, كمثرى, رمانة, بطيخة, شمامة, جزرات, بصلات, خيارة, فلفلة, ملفوف, عدسات, غيمات, قزحية
        ar: نجمات, مجرات, شمسية, ليالي, ظهيرة, أمطار
        """
}
