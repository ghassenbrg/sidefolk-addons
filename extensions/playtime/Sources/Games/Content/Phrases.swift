import Foundation

extension Games {
    /// The short words the games' boards show (topic and level names, pad and card names, buttons, the Today tile,
    /// the reasons a move is refused), keyed, in all ten languages. The companion's own lines are not here: those are
    /// Sidefolk's keyed cues (`line`), written and translated in the app. `{name}` is the companion's name, `{n}`
    /// and the like are numbers or words the adapter fills in. French says vous, German du, as Sidefolk does.
    ///
    /// One line per key: `key | en | fr | es | de | it | pt-BR | ja | ko | zh-Hans | ar`.
    enum Phrases {
        static let table: [String: Text] = {
            var table: [String: Text] = [:]
            for line in source.split(separator: "\n") where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                let f = fields(String(line))
                table[f[0]] = Text(byKey: Dictionary(uniqueKeysWithValues: zip(Language.allCases.map(\.key), f.dropFirst())))
            }
            return table
        }()

        /// The phrase in `language`, with `{key}` placeholders filled from `values`.
        static func text(_ key: String, _ language: Language, _ values: [String: String] = [:]) -> String {
            values.reduce(table[key]?[language] ?? key) { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) }
        }

        /// Lines that don't have all eleven fields, for the content test.
        static var malformed: [String] {
            source.split(separator: "\n").map(String.init).filter { fields($0).count != Language.allCases.count + 1 || fields($0).contains("") }
        }

        static let source = """
            level.easy | Easy | Facile | Fácil | Leicht | Facile | Fácil | かんたん | 쉬움 | 简单 | سهل
            level.fair | Fair | Normal | Normal | Normal | Normale | Normal | ふつう | 보통 | 普通 | متوسط
            level.hard | Hard | Difficile | Difícil | Schwer | Difficile | Difícil | むずかしい | 어려움 | 困难 | صعب
            category.mix | Mix | Mélange | Mezcla | Gemischt | Misto | Misturado | ミックス | 섞어서 | 综合 | منوعات
            category.science | Science | Sciences | Ciencia | Wissenschaft | Scienza | Ciência | 科学 | 과학 | 科学 | علوم
            category.space | Space | Espace | Espacio | Weltraum | Spazio | Espaço | 宇宙 | 우주 | 太空 | الفضاء
            category.geography | Geography | Géographie | Geografía | Geografie | Geografia | Geografia | 地理 | 지리 | 地理 | جغرافيا
            category.history | History | Histoire | Historia | Geschichte | Storia | História | 歴史 | 역사 | 历史 | تاريخ
            category.nature | Nature | Nature | Naturaleza | Natur | Natura | Natureza | 自然 | 자연 | 自然 | الطبيعة
            category.food | Food | Cuisine | Comida | Essen | Cibo | Comida | 食べ物 | 음식 | 美食 | الطعام
            category.arts | Arts | Arts | Arte | Kunst | Arte | Artes | 芸術 | 예술 | 艺术 | الفنون
            category.tech | Tech | Technologie | Tecnología | Technik | Tecnologia | Tecnologia | テクノロジー | 기술 | 科技 | التقنية
            category.sports | Sports | Sport | Deportes | Sport | Sport | Esportes | スポーツ | 스포츠 | 体育 | الرياضة
            category.mediterranean | Tunisia & the Mediterranean | La Tunisie et la Méditerranée | Túnez y el Mediterráneo | Tunesien und das Mittelmeer | La Tunisia e il Mediterraneo | Tunísia e o Mediterrâneo | チュニジアと地中海 | 튀니지와 지중해 | 突尼斯与地中海 | تونس والبحر المتوسط
            words.animals | Animals | Animaux | Animales | Tiere | Animali | Animais | 動物 | 동물 | 动物 | حيوانات
            words.food | Food | Nourriture | Comida | Essen | Cibo | Comida | 食べ物 | 음식 | 食物 | طعام
            words.home | At home | À la maison | En casa | Zu Hause | In casa | Em casa | 家の中 | 집 안 | 家里 | في البيت
            words.nature | Nature | Nature | Naturaleza | Natur | Natura | Natureza | 自然 | 자연 | 自然 | الطبيعة
            words.clothes | Clothes | Vêtements | Ropa | Kleidung | Vestiti | Roupas | 服 | 옷 | 衣服 | ملابس
            words.transport | Getting around | Transports | Transporte | Verkehr | Trasporti | Transporte | 乗り物 | 탈것 | 交通 | المواصلات
            words.sports | Sports | Sports | Deportes | Sport | Sport | Esportes | スポーツ | 스포츠 | 运动 | رياضة
            words.music | Music | Musique | Música | Musik | Musica | Música | 音楽 | 음악 | 音乐 | موسيقى
            pad.wave | Wave | Salut | Saludo | Winken | Saluto | Aceno | 手をふる | 손 흔들기 | 挥手 | تلويح
            pad.hop | Hop | Saut | Salto | Hüpfer | Saltello | Pulo | ジャンプ | 깡충 | 跳一跳 | قفزة
            pad.spin | Spin | Tour | Giro | Drehung | Giravolta | Giro | くるり | 빙글 | 转圈 | دوران
            pad.bow | Bow | Révérence | Reverencia | Verbeugung | Inchino | Reverência | おじぎ | 인사 | 鞠躬 | انحناءة
            pad.otherWave | Other wave | Salut de l'autre main | Saludo con la otra mano | Mit der anderen Hand winken | Saluto con l'altra mano | Aceno com a outra mão | 反対の手でふる | 반대 손 흔들기 | 换只手挥 | تلويح باليد الأخرى
            symbol.moon | Moon | Lune | Luna | Mond | Luna | Lua | 月 | 달 | 月亮 | قمر
            symbol.leaf | Leaf | Feuille | Hoja | Blatt | Foglia | Folha | 葉っぱ | 나뭇잎 | 叶子 | ورقة شجر
            symbol.anchor | Anchor | Ancre | Ancla | Anker | Ancora | Âncora | いかり | 닻 | 锚 | مرساة
            symbol.star | Star | Étoile | Estrella | Stern | Stella | Estrela | 星 | 별 | 星星 | نجمة
            symbol.heart | Heart | Cœur | Corazón | Herz | Cuore | Coração | ハート | 하트 | 爱心 | قلب
            symbol.sun | Sun | Soleil | Sol | Sonne | Sole | Sol | 太陽 | 해 | 太阳 | شمس
            symbol.cloud | Cloud | Nuage | Nube | Wolke | Nuvola | Nuvem | 雲 | 구름 | 云朵 | سحابة
            symbol.flower | Flower | Fleur | Flor | Blume | Fiore | Flor | 花 | 꽃 | 花朵 | زهرة
            symbol.fish | Fish | Poisson | Pez | Fisch | Pesce | Peixe | 魚 | 물고기 | 鱼 | سمكة
            symbol.bell | Bell | Cloche | Campana | Glocke | Campana | Sino | ベル | 종 | 铃铛 | جرس
            symbol.key | Key | Clé | Llave | Schlüssel | Chiave | Chave | かぎ | 열쇠 | 钥匙 | مفتاح
            symbol.drop | Drop | Goutte | Gota | Tropfen | Goccia | Gota | しずく | 물방울 | 水滴 | قطرة
            answer.yes | Yes | Oui | Sí | Ja | Sì | Sim | はい | 네 | 是 | نعم
            answer.no | No | Non | No | Nein | No | Não | いいえ | 아니요 | 不是 | لا
            answer.unsure | Not sure | Je ne sais pas | No estoy seguro | Weiß nicht | Non lo so | Não sei | わからない | 잘 모르겠어요 | 不确定 | لست متأكدًا
            answer.higher | Higher | Plus haut | Más alto | Höher | Più alto | Maior | もっと大きい | 더 커요 | 更大 | أكبر
            answer.lower | Lower | Plus bas | Más bajo | Niedriger | Più basso | Menor | もっと小さい | 더 작아요 | 更小 | أصغر
            answer.right | That's it! | C'est ça ! | ¡Ese es! | Genau! | Esatto! | Isso mesmo! | 当たり！ | 맞아요! | 对了！ | صحيح!
            numbers.ask | Is it {n}? | C'est {n} ? | ¿Es el {n}? | Ist es die {n}? | È il {n}? | É {n}? | {n}かな？ | {n}인가요? | 是{n}吗？ | هل هو {n}؟
            numbers.range | Between {low} and {high} | Entre {low} et {high} | Entre {low} y {high} | Zwischen {low} und {high} | Tra {low} e {high} | Entre {low} e {high} | {low}から{high}のあいだ | {low}에서 {high} 사이 | 在{low}和{high}之间 | بين {low} و{high}
            numbers.higher | Higher! | Plus haut ! | ¡Más alto! | Höher! | Più alto! | Maior! | もっと大きい！ | 더 커요! | 再大一点！ | أكبر!
            numbers.lower | Lower! | Plus bas ! | ¡Más bajo! | Niedriger! | Più basso! | Menor! | もっと小さい！ | 더 작아요! | 再小一点！ | أصغر!
            numbers.found | Found in {n} | Trouvé en {n} | Encontrado en {n} | In {n} gefunden | Trovato in {n} | Achado em {n} | {n}回で当たり | {n}번 만에 맞힘 | {n}次猜中 | وجدته في {n}
            animal.guess | My guess: {name}! | Je dirais : {name} ! | Mi respuesta: ¡{name}! | Ich tippe auf: {name}! | Dico: {name}! | Meu palpite: {name}! | 答えは… {name}！ | 정답은… {name}! | 我猜是：{name}！ | تخميني: {name}!
            animal.whatWasIt | You win! What was it? | Vous avez gagné ! C'était quoi ? | ¡Ganaste! ¿Qué era? | Du hast gewonnen! Was war es? | Hai vinto! Cos'era? | Você venceu! O que era? | あなたの勝ち！何でしたか？ | 이겼어요! 뭐였어요? | 你赢了！是什么动物？ | فزت! ما هو؟
            animal.teach | A yes-or-no question that tells {new} from {old}? | Une question oui ou non qui distingue {new} de {old} ? | ¿Una pregunta de sí o no que distinga {new} de {old}? | Eine Ja-Nein-Frage, die {new} von {old} unterscheidet? | Una domanda sì o no che distingua {new} da {old}? | Uma pergunta de sim ou não que diferencie {new} de {old}? | {new}と{old}を見分ける「はい・いいえ」の質問は？ | {new}와(과) {old}을(를) 구별하는 예/아니요 질문은? | 用一个是非题区分{new}和{old}？ | سؤال بنعم أو لا يميّز {new} عن {old}؟
            animal.answerForNew | And for {new}, the answer is… | Et pour {new}, la réponse est… | Y para {new}, la respuesta es… | Und bei {new} lautet die Antwort… | E per {new} la risposta è… | E para {new}, a resposta é… | {new}の場合、答えは… | {new}의 경우 답은… | 对{new}来说，答案是… | وبالنسبة إلى {new}، الجواب…
            paws.steady | Steady… | Prêts… | Atención… | Achtung… | Pronti… | Atenção… | よーい… | 준비… | 预备… | استعد…
            paws.boop | Boop! | Boop ! | ¡Bup! | Bupp! | Bup! | Bup! | ポン！ | 콕! | 啵！ | بوب!
            paws.tooSoon | Too soon! | Trop tôt ! | ¡Demasiado pronto! | Zu früh! | Troppo presto! | Cedo demais! | 早すぎ！ | 너무 빨라요! | 太早了！ | مبكر جدًا!
            paws.times | You {you} ms · {name} {companion} ms | Vous {you} ms · {name} {companion} ms | Tú {you} ms · {name} {companion} ms | Du {you} ms · {name} {companion} ms | Tu {you} ms · {name} {companion} ms | Você {you} ms · {name} {companion} ms | あなた {you} ms · {name} {companion} ms | 나 {you}ms · {name} {companion}ms | 你 {you} 毫秒 · {name} {companion} 毫秒 | أنت {you} م.ث · {name} {companion} م.ث
            cups.pick | Which cup? | Quel gobelet ? | ¿Qué vaso? | Welcher Becher? | Quale bicchiere? | Qual copo? | どのカップ？ | 어느 컵일까요? | 哪个杯子？ | أيّ كوب؟
            cups.sneaky | Sneaky | Filou | Tramposo | Schlitzohr | Furbetto | Malandro | いたずら | 장난꾸러기 | 调皮 | مشاغب
            sticks.lesson | Leave one more than a multiple of four: 17, 13, 9, 5, then 1. | Laissez un de plus qu'un multiple de quatre : 17, 13, 9, 5, puis 1. | Deja uno más que un múltiplo de cuatro: 17, 13, 9, 5 y luego 1. | Lass eins mehr als ein Vielfaches von vier übrig: 17, 13, 9, 5, dann 1. | Lascia uno in più di un multiplo di quattro: 17, 13, 9, 5, poi 1. | Deixe um a mais que um múltiplo de quatro: 17, 13, 9, 5 e depois 1. | 4の倍数より1多く残そう：17、13、9、5、そして1。 | 4의 배수보다 하나 더 남기세요: 17, 13, 9, 5, 그리고 1. | 留下比4的倍数多1的数：17、13、9、5，最后是1。 | اترك عددًا يزيد واحدًا على مضاعفات الأربعة: 17، 13، 9، 5، ثم 1.
            sticks.groups | Every round, make four together. | À chaque tour, faites quatre à deux. | En cada ronda, sumad cuatro entre los dos. | Jede Runde macht ihr zusammen vier. | A ogni giro, fate quattro in due. | A cada rodada, façam quatro juntos. | 毎回、ふたりで合わせて4本に。 | 매번 둘이 합쳐 4개가 되게 하세요. | 每一轮，两人合起来拿4根。 | في كل جولة، اجعلا المجموع أربعة.
            quiz.of | {n} of {total} | {n} sur {total} | {n} de {total} | {n} von {total} | {n} di {total} | {n} de {total} | {n}／{total}問 | {total}문제 중 {n}번 | 第{n}题，共{total}题 | {n} من {total}
            quiz.sealed | {name} has picked | {name} a choisi | {name} ya eligió | {name} hat gewählt | {name} ha scelto | {name} já escolheu | {name}は選んだよ | {name}: 선택 완료 | {name}已选好 | {name} اختار
            quiz.lifeline | Ask {name} | Demander à {name} | Pregúntale a {name} | {name} fragen | Chiedi a {name} | Pergunte a {name} | {name}に聞く | {name}에게 묻기 | 问问{name} | اسأل {name}
            quiz.endless | Endless | Sans fin | Sin fin | Endlos | Senza fine | Sem fim | エンドレス | 무제한 | 无尽模式 | بلا نهاية
            quiz.relaxed | Relaxed | Tranquille | Tranquilo | Entspannt | Rilassato | Tranquilo | のんびり | 느긋하게 | 轻松 | هادئ
            quiz.quick | Quick | Rapide | Rápido | Schnell | Veloce | Rápido | スピード | 빠르게 | 快速 | سريع
            daily.title | Daily Word | Le mot du jour | La palabra del día | Wort des Tages | La parola del giorno | Palavra do dia | 今日のことば | 오늘의 단어 | 每日成语 | كلمة اليوم
            daily.notPlayed | Not played yet | Pas encore joué | Aún sin jugar | Noch nicht gespielt | Non ancora giocato | Ainda não jogado | まだ遊んでいません | 아직 안 했어요 | 今天还没玩 | لم تلعب بعد
            daily.solved | Solved in {n} | Trouvé en {n} | Resuelto en {n} | In {n} gelöst | Risolto in {n} | Resolvido em {n} | {n}回で正解 | {n}번 만에 성공 | {n}次猜中 | حُلّت في {n}
            daily.missed | Missed today | Raté aujourd'hui | Hoy no salió | Heute nicht geschafft | Oggi niente | Hoje não deu | 今日は残念 | 오늘은 실패 | 今天没猜中 | لم تُحلّ اليوم
            daily.streak | Streak {n} | Série de {n} | Racha de {n} | Serie: {n} | Serie di {n} | Sequência de {n} | {n}日連続 | {n}일 연속 | 连续{n}天 | سلسلة: {n}
            refusal.taken | That one's taken. | Déjà pris. | Ya está ocupado. | Schon belegt. | Già preso. | Já foi escolhido. | そこはもう埋まっています。 | 이미 선택됐어요. | 这里已经有了。 | هذا مأخوذ.
            refusal.not_your_turn | Not your turn yet. | Ce n'est pas encore votre tour. | Aún no es tu turno. | Du bist noch nicht dran. | Non è ancora il tuo turno. | Ainda não é sua vez. | まだあなたの番ではありません。 | 아직 차례가 아니에요. | 还没轮到你。 | ليس دورك بعد.
            refusal.wrong_length | That word isn't the right length. | Ce mot n'a pas la bonne longueur. | Esa palabra no tiene la longitud correcta. | Das Wort hat nicht die richtige Länge. | La parola non ha la lunghezza giusta. | Essa palavra não tem o tamanho certo. | 文字数が合いません。 | 글자 수가 맞지 않아요. | 字数不对。 | طول الكلمة غير صحيح.
            refusal.not_letters | Use the game's letters. | Utilisez les lettres du jeu. | Usa las letras del juego. | Nimm die Buchstaben des Spiels. | Usa le lettere del gioco. | Use as letras do jogo. | ゲームの文字を使ってください。 | 게임 글자를 써 주세요. | 请用游戏里的字。 | استخدم حروف اللعبة.
            refusal.not_a_word | That's not in the word list. | Ce mot n'est pas dans la liste. | Esa palabra no está en la lista. | Das Wort steht nicht in der Liste. | Questa parola non è nella lista. | Essa palavra não está na lista. | その言葉はリストにありません。 | 목록에 없는 단어예요. | 词库里没有这个词。 | هذه الكلمة ليست في القائمة.
            refusal.already_guessed | You tried that one already. | Vous l'avez déjà essayé. | Ya lo probaste. | Das hattest du schon. | L'hai già provato. | Você já tentou essa. | それはもう試しました。 | 이미 해 봤어요. | 已经试过了。 | جرّبته من قبل.
            refusal.out_of_range | Pick a number from 1 to 100. | Choisissez un nombre de 1 à 100. | Elige un número del 1 al 100. | Wähle eine Zahl von 1 bis 100. | Scegli un numero da 1 a 100. | Escolha um número de 1 a 100. | 1から100までの数にしてください。 | 1부터 100까지 숫자를 골라 주세요. | 请选1到100之间的数。 | اختر رقمًا من 1 إلى 100.
            refusal.hint_used | The hint is used up. | L'indice a déjà servi. | Ya usaste la pista. | Der Tipp ist schon verbraucht. | L'aiuto è già stato usato. | A dica já foi usada. | ヒントはもう使いました。 | 힌트를 이미 썼어요. | 提示已经用过了。 | استُخدم التلميح من قبل.
            refusal.same_animal | That's the animal I guessed. | C'est l'animal que j'ai proposé. | Ese es el animal que dije. | Das habe ich doch geraten. | È l'animale che ho detto io. | Esse é o animal que eu disse. | それは私が言った動物です。 | 제가 말한 동물이에요. | 这就是我猜的动物。 | هذا هو الحيوان الذي خمّنته.
            refusal.empty | Please write both. | Écrivez les deux, s'il vous plaît. | Escribe las dos cosas, por favor. | Bitte schreib beides. | Scrivi entrambe le cose, per favore. | Escreva as duas coisas, por favor. | 両方とも書いてください。 | 둘 다 적어 주세요. | 请两项都填写。 | اكتب الاثنين من فضلك.
            refusal.too_long | That's a bit long. | C'est un peu long. | Es un poco largo. | Das ist etwas lang. | È un po' lungo. | Está um pouco longo. | 少し長すぎます。 | 조금 길어요. | 有点太长了。 | هذا طويل قليلًا.
            refusal.bad_take | Take 1, 2 or 3 sticks. | Prenez 1, 2 ou 3 bâtons. | Toma 1, 2 o 3 palitos. | Nimm 1, 2 oder 3 Stäbchen. | Prendi 1, 2 o 3 bastoncini. | Pegue 1, 2 ou 3 palitos. | 1〜3本取ってください。 | 1~3개를 가져가세요. | 拿1到3根。 | خذ عودًا أو اثنين أو ثلاثة.
            """
    }
}
