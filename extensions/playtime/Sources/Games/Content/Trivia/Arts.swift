extension Games.QuizBank {
    // Arts: painting, books, music, dance and buildings from many places.
    static let arts = """
        # arts.mona-lisa arts 1
        en: Who painted the Mona Lisa? | Leonardo da Vinci | Michelangelo | Raphael | Botticelli
        fr: Qui a peint La Joconde ? | Léonard de Vinci | Michel-Ange | Raphaël | Botticelli
        es: ¿Quién pintó la Mona Lisa? | Leonardo da Vinci | Miguel Ángel | Rafael | Botticelli
        de: Wer malte die Mona Lisa? | Leonardo da Vinci | Michelangelo | Raffael | Botticelli
        it: Chi dipinse la Gioconda? | Leonardo da Vinci | Michelangelo | Raffaello | Botticelli
        pt: Quem pintou a Mona Lisa? | Leonardo da Vinci | Michelangelo | Rafael | Botticelli
        ja: 「モナ・リザ」を描いたのは？ | レオナルド・ダ・ヴィンチ | ミケランジェロ | ラファエロ | ボッティチェリ
        ko: '모나리자'를 그린 사람은? | 레오나르도 다빈치 | 미켈란젤로 | 라파엘로 | 보티첼리
        zh: 《蒙娜丽莎》是谁画的？ | 达·芬奇 | 米开朗琪罗 | 拉斐尔 | 波提切利
        ar: من رسم الموناليزا؟ | ليوناردو دا فينشي | مايكل أنجلو | رافائيل | بوتيتشيلي

        # arts.starry-night arts 1
        en: Who painted "The Starry Night"? | Vincent van Gogh | Claude Monet | Pablo Picasso | Salvador Dalí
        fr: Qui a peint « La Nuit étoilée » ? | Vincent van Gogh | Claude Monet | Pablo Picasso | Salvador Dalí
        es: ¿Quién pintó «La noche estrellada»? | Vincent van Gogh | Claude Monet | Pablo Picasso | Salvador Dalí
        de: Wer malte „Die Sternennacht“? | Vincent van Gogh | Claude Monet | Pablo Picasso | Salvador Dalí
        it: Chi dipinse «Notte stellata»? | Vincent van Gogh | Claude Monet | Pablo Picasso | Salvador Dalí
        pt: Quem pintou "A Noite Estrelada"? | Vincent van Gogh | Claude Monet | Pablo Picasso | Salvador Dalí
        ja: 「星月夜」を描いたのは？ | フィンセント・ファン・ゴッホ | クロード・モネ | パブロ・ピカソ | サルバドール・ダリ
        ko: '별이 빛나는 밤'을 그린 사람은? | 빈센트 반 고흐 | 클로드 모네 | 파블로 피카소 | 살바도르 달리
        zh: 《星月夜》是谁画的？ | 梵高 | 莫奈 | 毕加索 | 达利
        ar: من رسم لوحة «ليلة النجوم»؟ | فنسنت فان غوخ | كلود مونيه | بابلو بيكاسو | سلفادور دالي

        # arts.sistine arts 2
        en: Who painted the ceiling of the Sistine Chapel? | Michelangelo | Leonardo da Vinci | Raphael | Caravaggio
        fr: Qui a peint le plafond de la chapelle Sixtine ? | Michel-Ange | Léonard de Vinci | Raphaël | Le Caravage
        es: ¿Quién pintó el techo de la Capilla Sixtina? | Miguel Ángel | Leonardo da Vinci | Rafael | Caravaggio
        de: Wer malte die Decke der Sixtinischen Kapelle? | Michelangelo | Leonardo da Vinci | Raffael | Caravaggio
        it: Chi dipinse la volta della Cappella Sistina? | Michelangelo | Leonardo da Vinci | Raffaello | Caravaggio
        pt: Quem pintou o teto da Capela Sistina? | Michelangelo | Leonardo da Vinci | Rafael | Caravaggio
        ja: システィーナ礼拝堂の天井画を描いたのは？ | ミケランジェロ | レオナルド・ダ・ヴィンチ | ラファエロ | カラヴァッジョ
        ko: 시스티나 성당의 천장화를 그린 사람은? | 미켈란젤로 | 레오나르도 다빈치 | 라파엘로 | 카라바조
        zh: 西斯廷礼拜堂的天顶画是谁画的？ | 米开朗琪罗 | 达·芬奇 | 拉斐尔 | 卡拉瓦乔
        ar: من رسم سقف كنيسة سيستينا؟ | مايكل أنجلو | ليوناردو دا فينشي | رافائيل | كارافاجو

        # arts.guernica arts 2
        en: Who painted "Guernica"? | Pablo Picasso | Salvador Dalí | Joan Miró | Francisco Goya
        fr: Qui a peint « Guernica » ? | Pablo Picasso | Salvador Dalí | Joan Miró | Francisco de Goya
        es: ¿Quién pintó el «Guernica»? | Pablo Picasso | Salvador Dalí | Joan Miró | Francisco de Goya
        de: Wer malte „Guernica“? | Pablo Picasso | Salvador Dalí | Joan Miró | Francisco de Goya
        it: Chi dipinse «Guernica»? | Pablo Picasso | Salvador Dalí | Joan Miró | Francisco Goya
        pt: Quem pintou "Guernica"? | Pablo Picasso | Salvador Dalí | Joan Miró | Francisco de Goya
        ja: 「ゲルニカ」を描いたのは？ | パブロ・ピカソ | サルバドール・ダリ | ジョアン・ミロ | フランシスコ・デ・ゴヤ
        ko: '게르니카'를 그린 사람은? | 파블로 피카소 | 살바도르 달리 | 호안 미로 | 프란시스코 고야
        zh: 《格尔尼卡》是谁画的？ | 毕加索 | 达利 | 米罗 | 戈雅
        ar: من رسم «غرنيكا»؟ | بابلو بيكاسو | سلفادور دالي | خوان ميرو | فرانثيسكو غويا

        # arts.great-wave arts 2
        en: Who made the woodblock print "The Great Wave off Kanagawa"? | Hokusai | Hiroshige | Utamaro | Sesshū
        fr: Qui a réalisé l'estampe « La Grande Vague de Kanagawa » ? | Hokusai | Hiroshige | Utamaro | Sesshū
        es: ¿Quién hizo el grabado «La gran ola de Kanagawa»? | Hokusai | Hiroshige | Utamaro | Sesshū
        de: Wer schuf den Holzschnitt „Die große Welle vor Kanagawa“? | Hokusai | Hiroshige | Utamaro | Sesshū
        it: Chi realizzò la stampa «La grande onda di Kanagawa»? | Hokusai | Hiroshige | Utamaro | Sesshū
        pt: Quem fez a xilogravura "A Grande Onda de Kanagawa"? | Hokusai | Hiroshige | Utamaro | Sesshū
        ja: 「神奈川沖浪裏」を描いたのは？ | 葛飾北斎 | 歌川広重 | 喜多川歌麿 | 雪舟
        ko: 목판화 '가나가와 해변의 높은 파도 아래'를 만든 사람은? | 가쓰시카 호쿠사이 | 우타가와 히로시게 | 기타가와 우타마로 | 셋슈
        zh: 版画《神奈川冲浪里》的作者是谁？ | 葛饰北斋 | 歌川广重 | 喜多川歌麿 | 雪舟
        ar: من صنع الطبعة الخشبية «الموجة العظيمة قبالة كاناغاوا»؟ | هوكوساي | هيروشيغه | أوتامارو | سيشو

        # arts.water-lilies arts 2
        en: Which painter made a famous series of "Water Lilies"? | Claude Monet | Edgar Degas | Paul Cézanne | Henri Matisse
        fr: Quel peintre a réalisé la célèbre série des « Nymphéas » ? | Claude Monet | Edgar Degas | Paul Cézanne | Henri Matisse
        es: ¿Qué pintor hizo la famosa serie de los «Nenúfares»? | Claude Monet | Edgar Degas | Paul Cézanne | Henri Matisse
        de: Welcher Maler schuf die berühmte Serie der „Seerosen“? | Claude Monet | Edgar Degas | Paul Cézanne | Henri Matisse
        it: Quale pittore realizzò la famosa serie delle «Ninfee»? | Claude Monet | Edgar Degas | Paul Cézanne | Henri Matisse
        pt: Que pintor fez a famosa série das "Ninfeias"? | Claude Monet | Edgar Degas | Paul Cézanne | Henri Matisse
        ja: 「睡蓮」の連作で有名な画家は？ | クロード・モネ | エドガー・ドガ | ポール・セザンヌ | アンリ・マティス
        ko: '수련' 연작으로 유명한 화가는? | 클로드 모네 | 에드가 드가 | 폴 세잔 | 앙리 마티스
        zh: 哪位画家创作了著名的《睡莲》系列？ | 莫奈 | 德加 | 塞尚 | 马蒂斯
        ar: أي رسام أبدع سلسلة «زنابق الماء» الشهيرة؟ | كلود مونيه | إدغار ديغا | بول سيزان | هنري ماتيس

        # arts.the-scream arts 2
        en: Who painted "The Scream"? | Edvard Munch | Gustav Klimt | Vincent van Gogh | Egon Schiele
        fr: Qui a peint « Le Cri » ? | Edvard Munch | Gustav Klimt | Vincent van Gogh | Egon Schiele
        es: ¿Quién pintó «El grito»? | Edvard Munch | Gustav Klimt | Vincent van Gogh | Egon Schiele
        de: Wer malte „Der Schrei“? | Edvard Munch | Gustav Klimt | Vincent van Gogh | Egon Schiele
        it: Chi dipinse «L'urlo»? | Edvard Munch | Gustav Klimt | Vincent van Gogh | Egon Schiele
        pt: Quem pintou "O Grito"? | Edvard Munch | Gustav Klimt | Vincent van Gogh | Egon Schiele
        ja: 「叫び」を描いたのは？ | エドヴァルド・ムンク | グスタフ・クリムト | フィンセント・ファン・ゴッホ | エゴン・シーレ
        ko: '절규'를 그린 사람은? | 에드바르 뭉크 | 구스타프 클림트 | 빈센트 반 고흐 | 에곤 실레
        zh: 《呐喊》是谁画的？ | 蒙克 | 克里姆特 | 梵高 | 席勒
        ar: من رسم لوحة «الصرخة»؟ | إدفارت مونك | غوستاف كليمت | فنسنت فان غوخ | إيغون شيله

        # arts.romeo-juliet arts 1
        en: Who wrote "Romeo and Juliet"? | William Shakespeare | Charles Dickens | Jane Austen | Oscar Wilde
        fr: Qui a écrit « Roméo et Juliette » ? | William Shakespeare | Charles Dickens | Jane Austen | Oscar Wilde
        es: ¿Quién escribió «Romeo y Julieta»? | William Shakespeare | Charles Dickens | Jane Austen | Oscar Wilde
        de: Wer schrieb „Romeo und Julia“? | William Shakespeare | Charles Dickens | Jane Austen | Oscar Wilde
        it: Chi scrisse «Romeo e Giulietta»? | William Shakespeare | Charles Dickens | Jane Austen | Oscar Wilde
        pt: Quem escreveu "Romeu e Julieta"? | William Shakespeare | Charles Dickens | Jane Austen | Oscar Wilde
        ja: 『ロミオとジュリエット』を書いたのは？ | ウィリアム・シェイクスピア | チャールズ・ディケンズ | ジェイン・オースティン | オスカー・ワイルド
        ko: '로미오와 줄리엣'을 쓴 사람은? | 윌리엄 셰익스피어 | 찰스 디킨스 | 제인 오스틴 | 오스카 와일드
        zh: 《罗密欧与朱丽叶》的作者是谁？ | 莎士比亚 | 狄更斯 | 简·奥斯汀 | 王尔德
        ar: من كتب «روميو وجولييت»؟ | ويليام شكسبير | تشارلز ديكنز | جين أوستن | أوسكار وايلد

        # arts.don-quixote arts 1
        en: Who wrote "Don Quixote"? | Miguel de Cervantes | Lope de Vega | Gabriel García Márquez | Federico García Lorca
        fr: Qui a écrit « Don Quichotte » ? | Miguel de Cervantes | Lope de Vega | Gabriel García Márquez | Federico García Lorca
        es: ¿Quién escribió «Don Quijote de la Mancha»? | Miguel de Cervantes | Lope de Vega | Gabriel García Márquez | Federico García Lorca
        de: Wer schrieb „Don Quijote“? | Miguel de Cervantes | Lope de Vega | Gabriel García Márquez | Federico García Lorca
        it: Chi scrisse il «Don Chisciotte»? | Miguel de Cervantes | Lope de Vega | Gabriel García Márquez | Federico García Lorca
        pt: Quem escreveu "Dom Quixote"? | Miguel de Cervantes | Lope de Vega | Gabriel García Márquez | Federico García Lorca
        ja: 『ドン・キホーテ』を書いたのは？ | ミゲル・デ・セルバンテス | ロペ・デ・ベガ | ガブリエル・ガルシア＝マルケス | フェデリコ・ガルシア・ロルカ
        ko: '돈키호테'를 쓴 사람은? | 미겔 데 세르반테스 | 로페 데 베가 | 가브리엘 가르시아 마르케스 | 페데리코 가르시아 로르카
        zh: 《堂吉诃德》的作者是谁？ | 塞万提斯 | 洛佩·德·维加 | 加西亚·马尔克斯 | 洛尔卡
        ar: من كتب «دون كيخوته»؟ | ميغيل دي ثيربانتس | لوبي دي فيغا | غابرييل غارسيا ماركيز | فيديريكو غارسيا لوركا

        # arts.solitude arts 2
        en: Who wrote "One Hundred Years of Solitude"? | Gabriel García Márquez | Pablo Neruda | Jorge Luis Borges | Isabel Allende
        fr: Qui a écrit « Cent ans de solitude » ? | Gabriel García Márquez | Pablo Neruda | Jorge Luis Borges | Isabel Allende
        es: ¿Quién escribió «Cien años de soledad»? | Gabriel García Márquez | Pablo Neruda | Jorge Luis Borges | Isabel Allende
        de: Wer schrieb „Hundert Jahre Einsamkeit“? | Gabriel García Márquez | Pablo Neruda | Jorge Luis Borges | Isabel Allende
        it: Chi scrisse «Cent'anni di solitudine»? | Gabriel García Márquez | Pablo Neruda | Jorge Luis Borges | Isabel Allende
        pt: Quem escreveu "Cem Anos de Solidão"? | Gabriel García Márquez | Pablo Neruda | Jorge Luis Borges | Isabel Allende
        ja: 『百年の孤独』を書いたのは？ | ガブリエル・ガルシア＝マルケス | パブロ・ネルーダ | ホルヘ・ルイス・ボルヘス | イサベル・アジェンデ
        ko: '백 년 동안의 고독'을 쓴 사람은? | 가브리엘 가르시아 마르케스 | 파블로 네루다 | 호르헤 루이스 보르헤스 | 이사벨 아옌데
        zh: 《百年孤独》的作者是谁？ | 加西亚·马尔克斯 | 聂鲁达 | 博尔赫斯 | 伊莎贝尔·阿连德
        ar: من كتب «مئة عام من العزلة»؟ | غابرييل غارسيا ماركيز | بابلو نيرودا | خورخي لويس بورخيس | إيزابيل الليندي

        # arts.les-miserables arts 2
        en: Who wrote "Les Misérables"? | Victor Hugo | Alexandre Dumas | Émile Zola | Gustave Flaubert
        fr: Qui a écrit « Les Misérables » ? | Victor Hugo | Alexandre Dumas | Émile Zola | Gustave Flaubert
        es: ¿Quién escribió «Los miserables»? | Victor Hugo | Alejandro Dumas | Émile Zola | Gustave Flaubert
        de: Wer schrieb „Die Elenden“ („Les Misérables“)? | Victor Hugo | Alexandre Dumas | Émile Zola | Gustave Flaubert
        it: Chi scrisse «I miserabili»? | Victor Hugo | Alexandre Dumas | Émile Zola | Gustave Flaubert
        pt: Quem escreveu "Os Miseráveis"? | Victor Hugo | Alexandre Dumas | Émile Zola | Gustave Flaubert
        ja: 『レ・ミゼラブル』を書いたのは？ | ヴィクトル・ユーゴー | アレクサンドル・デュマ | エミール・ゾラ | ギュスターヴ・フローベール
        ko: '레 미제라블'을 쓴 사람은? | 빅토르 위고 | 알렉상드르 뒤마 | 에밀 졸라 | 귀스타브 플로베르
        zh: 《悲惨世界》的作者是谁？ | 雨果 | 大仲马 | 左拉 | 福楼拜
        ar: من كتب «البؤساء»؟ | فيكتور هوغو | ألكسندر دوما | إميل زولا | غوستاف فلوبير

        # arts.genji arts 3
        en: Who wrote "The Tale of Genji", about 1,000 years ago? | Murasaki Shikibu | Sei Shōnagon | Matsuo Bashō | Natsume Sōseki
        fr: Qui a écrit le « Dit du Genji », il y a environ mille ans ? | Murasaki Shikibu | Sei Shōnagon | Matsuo Bashō | Natsume Sōseki
        es: ¿Quién escribió «La historia de Genji», hace unos mil años? | Murasaki Shikibu | Sei Shōnagon | Matsuo Bashō | Natsume Sōseki
        de: Wer schrieb vor etwa tausend Jahren „Die Geschichte vom Prinzen Genji“? | Murasaki Shikibu | Sei Shōnagon | Matsuo Bashō | Natsume Sōseki
        it: Chi scrisse la «Storia di Genji», circa mille anni fa? | Murasaki Shikibu | Sei Shōnagon | Matsuo Bashō | Natsume Sōseki
        pt: Quem escreveu "O Romance de Genji", há cerca de mil anos? | Murasaki Shikibu | Sei Shōnagon | Matsuo Bashō | Natsume Sōseki
        ja: 約1000年前に『源氏物語』を書いたのは？ | 紫式部 | 清少納言 | 松尾芭蕉 | 夏目漱石
        ko: 약 1000년 전에 '겐지 이야기'를 쓴 사람은? | 무라사키 시키부 | 세이 쇼나곤 | 마쓰오 바쇼 | 나쓰메 소세키
        zh: 约一千年前写下《源氏物语》的是谁？ | 紫式部 | 清少纳言 | 松尾芭蕉 | 夏目漱石
        ar: من كتب «حكاية غينجي» قبل نحو ألف عام؟ | موراساكي شيكيبو | سي شوناغون | ماتسوو باشو | ناتسومي سوسيكي

        # arts.little-prince arts 2
        en: Who wrote "The Little Prince"? | Antoine de Saint-Exupéry | Jules Verne | Victor Hugo | Albert Camus
        fr: Qui a écrit « Le Petit Prince » ? | Antoine de Saint-Exupéry | Jules Verne | Victor Hugo | Albert Camus
        es: ¿Quién escribió «El principito»? | Antoine de Saint-Exupéry | Julio Verne | Victor Hugo | Albert Camus
        de: Wer schrieb „Der kleine Prinz“? | Antoine de Saint-Exupéry | Jules Verne | Victor Hugo | Albert Camus
        it: Chi scrisse «Il piccolo principe»? | Antoine de Saint-Exupéry | Jules Verne | Victor Hugo | Albert Camus
        pt: Quem escreveu "O Pequeno Príncipe"? | Antoine de Saint-Exupéry | Júlio Verne | Victor Hugo | Albert Camus
        ja: 『星の王子さま』を書いたのは？ | アントワーヌ・ド・サン＝テグジュペリ | ジュール・ヴェルヌ | ヴィクトル・ユーゴー | アルベール・カミュ
        ko: '어린 왕자'를 쓴 사람은? | 앙투안 드 생텍쥐페리 | 쥘 베른 | 빅토르 위고 | 알베르 카뮈
        zh: 《小王子》的作者是谁？ | 圣埃克苏佩里 | 儒勒·凡尔纳 | 雨果 | 加缪
        ar: من كتب «الأمير الصغير»؟ | أنطوان دو سانت إكزوبيري | جول فيرن | فيكتور هوغو | ألبير كامو

        # arts.scheherazade arts 2
        en: Scheherazade is the storyteller of which collection? | One Thousand and One Nights | Aesop's Fables | Grimms' Fairy Tales | The Canterbury Tales
        fr: Shéhérazade est la conteuse de quel recueil ? | Les Mille et Une Nuits | Les Fables d'Ésope | Les Contes de Grimm | Les Contes de Canterbury
        es: ¿De qué colección es narradora Sherezade? | Las mil y una noches | Las fábulas de Esopo | Los cuentos de Grimm | Los cuentos de Canterbury
        de: Scheherazade ist die Erzählerin welcher Sammlung? | Tausendundeine Nacht | Äsops Fabeln | Grimms Märchen | Die Canterbury-Erzählungen
        it: Shahrazād è la narratrice di quale raccolta? | Le mille e una notte | Le favole di Esopo | Le fiabe dei Grimm | I racconti di Canterbury
        pt: Sherazade é a narradora de qual coletânea? | As Mil e Uma Noites | As Fábulas de Esopo | Os Contos de Grimm | Os Contos da Cantuária
        ja: シェヘラザードが物語を語るのは？ | 千夜一夜物語 | イソップ物語 | グリム童話 | カンタベリー物語
        ko: 셰에라자드가 이야기를 들려주는 작품은? | 천일야화 | 이솝 우화 | 그림 동화 | 캔터베리 이야기
        zh: 山鲁佐德是哪部故事集的讲述者？ | 《一千零一夜》 | 《伊索寓言》 | 《格林童话》 | 《坎特伯雷故事集》
        ar: شهرزاد هي راوية أي مجموعة قصص؟ | ألف ليلة وليلة | حكايات إيسوب | حكايات الأخوين غريم | حكايات كانتربري

        # arts.divine-comedy arts 2
        en: Who wrote the "Divine Comedy"? | Dante Alighieri | Petrarch | Giovanni Boccaccio | Virgil
        fr: Qui a écrit « La Divine Comédie » ? | Dante Alighieri | Pétrarque | Boccace | Virgile
        es: ¿Quién escribió la «Divina comedia»? | Dante Alighieri | Petrarca | Boccaccio | Virgilio
        de: Wer schrieb die „Göttliche Komödie“? | Dante Alighieri | Petrarca | Boccaccio | Vergil
        it: Chi scrisse la «Divina Commedia»? | Dante Alighieri | Francesco Petrarca | Giovanni Boccaccio | Virgilio
        pt: Quem escreveu a "Divina Comédia"? | Dante Alighieri | Petrarca | Boccaccio | Virgílio
        ja: 『神曲』を書いたのは？ | ダンテ・アリギエーリ | ペトラルカ | ボッカッチョ | ウェルギリウス
        ko: '신곡'을 쓴 사람은? | 단테 알리기에리 | 페트라르카 | 보카치오 | 베르길리우스
        zh: 《神曲》的作者是谁？ | 但丁 | 彼特拉克 | 薄伽丘 | 维吉尔
        ar: من كتب «الكوميديا الإلهية»؟ | دانتي أليغييري | بترارك | بوكاتشو | فرجيل

        # arts.deaf-composer arts 2
        en: Which composer kept writing music after he became deaf? | Ludwig van Beethoven | Wolfgang Amadeus Mozart | Johann Sebastian Bach | Antonio Vivaldi
        fr: Quel compositeur a continué à composer après être devenu sourd ? | Ludwig van Beethoven | Wolfgang Amadeus Mozart | Jean-Sébastien Bach | Antonio Vivaldi
        es: ¿Qué compositor siguió componiendo después de quedarse sordo? | Ludwig van Beethoven | Wolfgang Amadeus Mozart | Johann Sebastian Bach | Antonio Vivaldi
        de: Welcher Komponist komponierte weiter, nachdem er taub geworden war? | Ludwig van Beethoven | Wolfgang Amadeus Mozart | Johann Sebastian Bach | Antonio Vivaldi
        it: Quale compositore continuò a comporre dopo essere diventato sordo? | Ludwig van Beethoven | Wolfgang Amadeus Mozart | Johann Sebastian Bach | Antonio Vivaldi
        pt: Que compositor continuou compondo depois de ficar surdo? | Ludwig van Beethoven | Wolfgang Amadeus Mozart | Johann Sebastian Bach | Antonio Vivaldi
        ja: 耳が聞こえなくなっても作曲を続けた作曲家は？ | ベートーヴェン | モーツァルト | バッハ | ヴィヴァルディ
        ko: 귀가 들리지 않게 된 뒤에도 작곡을 계속한 작곡가는? | 베토벤 | 모차르트 | 바흐 | 비발디
        zh: 哪位作曲家在失聪后仍继续作曲？ | 贝多芬 | 莫扎特 | 巴赫 | 维瓦尔第
        ar: أي مؤلف موسيقي واصل التأليف بعد أن فقد سمعه؟ | بيتهوفن | موتسارت | باخ | فيفالدي

        # arts.four-seasons arts 2
        en: Who composed "The Four Seasons"? | Antonio Vivaldi | Wolfgang Amadeus Mozart | Johann Sebastian Bach | George Frideric Handel
        fr: Qui a composé « Les Quatre Saisons » ? | Antonio Vivaldi | Wolfgang Amadeus Mozart | Jean-Sébastien Bach | Georg Friedrich Haendel
        es: ¿Quién compuso «Las cuatro estaciones»? | Antonio Vivaldi | Wolfgang Amadeus Mozart | Johann Sebastian Bach | Georg Friedrich Händel
        de: Wer komponierte „Die vier Jahreszeiten“? | Antonio Vivaldi | Wolfgang Amadeus Mozart | Johann Sebastian Bach | Georg Friedrich Händel
        it: Chi compose «Le quattro stagioni»? | Antonio Vivaldi | Wolfgang Amadeus Mozart | Johann Sebastian Bach | Georg Friedrich Händel
        pt: Quem compôs "As Quatro Estações"? | Antonio Vivaldi | Wolfgang Amadeus Mozart | Johann Sebastian Bach | Georg Friedrich Händel
        ja: 『四季』を作曲したのは？ | ヴィヴァルディ | モーツァルト | バッハ | ヘンデル
        ko: '사계'를 작곡한 사람은? | 비발디 | 모차르트 | 바흐 | 헨델
        zh: 《四季》是谁作曲的？ | 维瓦尔第 | 莫扎特 | 巴赫 | 亨德尔
        ar: من ألّف «الفصول الأربعة»؟ | فيفالدي | موتسارت | باخ | هاندل

        # arts.piano-keys arts 2
        *: 88 | 76 | 61 | 100
        en: How many keys does a standard piano have?
        fr: Combien de touches compte un piano standard ?
        es: ¿Cuántas teclas tiene un piano estándar?
        de: Wie viele Tasten hat ein normales Klavier?
        it: Quanti tasti ha un pianoforte standard?
        pt: Quantas teclas tem um piano padrão?
        ja: 一般的なピアノの鍵盤の数は？
        ko: 일반적인 피아노의 건반 수는?
        zh: 标准钢琴有多少个琴键？
        ar: كم مفتاحًا في البيانو العادي؟

        # arts.violin-strings arts 1
        *: 4 | 3 | 5 | 6
        en: How many strings does a violin usually have?
        fr: Combien de cordes un violon a-t-il en général ?
        es: ¿Cuántas cuerdas tiene normalmente un violín?
        de: Wie viele Saiten hat eine Geige normalerweise?
        it: Quante corde ha di solito un violino?
        pt: Quantas cordas um violino costuma ter?
        ja: バイオリンの弦はふつう何本？
        ko: 바이올린의 줄은 보통 몇 개일까요?
        zh: 小提琴通常有几根弦？
        ar: كم وترًا للكمان عادةً؟

        # arts.conductor arts 1
        en: What do we call the person who leads an orchestra? | The conductor | The composer | The soloist | The drummer
        fr: Comment appelle-t-on la personne qui dirige un orchestre ? | Le chef d'orchestre | Le compositeur | Le soliste | Le batteur
        es: ¿Cómo se llama la persona que dirige una orquesta? | El director de orquesta | El compositor | El solista | El baterista
        de: Wie heißt die Person, die ein Orchester leitet? | Dirigent | Komponist | Solist | Schlagzeuger
        it: Come si chiama la persona che guida un'orchestra? | Il direttore d'orchestra | Il compositore | Il solista | Il batterista
        pt: Como se chama a pessoa que rege uma orquestra? | O maestro | O compositor | O solista | O baterista
        ja: オーケストラをまとめて指揮する人は？ | 指揮者 | 作曲家 | 独奏者 | ドラマー
        ko: 오케스트라를 이끄는 사람을 무엇이라고 할까요? | 지휘자 | 작곡가 | 독주자 | 드러머
        zh: 带领乐团演奏的人叫什么？ | 指挥 | 作曲家 | 独奏者 | 鼓手
        ar: ماذا نسمّي الشخص الذي يقود الأوركسترا؟ | قائد الأوركسترا (المايسترو) | المؤلف الموسيقي | العازف المنفرد | عازف الطبول

        # arts.blue-yellow arts 1
        en: Mixing blue and yellow paint makes which colour? | Green | Purple | Orange | Brown
        fr: Quelle couleur obtient-on en mélangeant du bleu et du jaune ? | Vert | Violet | Orange | Marron
        es: ¿Qué color sale al mezclar pintura azul y amarilla? | Verde | Morado | Naranja | Marrón
        de: Welche Farbe entsteht, wenn man Blau und Gelb mischt? | Grün | Lila | Orange | Braun
        it: Che colore si ottiene mescolando blu e giallo? | Verde | Viola | Arancione | Marrone
        pt: Que cor se obtém misturando tinta azul e amarela? | Verde | Roxo | Laranja | Marrom
        ja: 青と黄色の絵の具を混ぜると何色になる？ | 緑 | 紫 | オレンジ | 茶色
        ko: 파란 물감과 노란 물감을 섞으면 무슨 색이 될까요? | 초록색 | 보라색 | 주황색 | 갈색
        zh: 蓝色和黄色颜料混在一起会变成什么颜色？ | 绿色 | 紫色 | 橙色 | 棕色
        ar: ما اللون الناتج عن خلط الأزرق والأصفر؟ | الأخضر | البنفسجي | البرتقالي | البني

        # arts.red-white arts 1
        en: Mixing red and white paint makes which colour? | Pink | Orange | Purple | Grey
        fr: Quelle couleur obtient-on en mélangeant du rouge et du blanc ? | Rose | Orange | Violet | Gris
        es: ¿Qué color sale al mezclar pintura roja y blanca? | Rosa | Naranja | Morado | Gris
        de: Welche Farbe entsteht, wenn man Rot und Weiß mischt? | Rosa | Orange | Lila | Grau
        it: Che colore si ottiene mescolando rosso e bianco? | Rosa | Arancione | Viola | Grigio
        pt: Que cor se obtém misturando tinta vermelha e branca? | Rosa | Laranja | Roxo | Cinza
        ja: 赤と白の絵の具を混ぜると何色になる？ | ピンク | オレンジ | 紫 | 灰色
        ko: 빨간 물감과 흰 물감을 섞으면 무슨 색이 될까요? | 분홍색 | 주황색 | 보라색 | 회색
        zh: 红色和白色颜料混在一起会变成什么颜色？ | 粉色 | 橙色 | 紫色 | 灰色
        ar: ما اللون الناتج عن خلط الأحمر والأبيض؟ | الوردي | البرتقالي | البنفسجي | الرمادي

        # arts.liberty arts 2
        en: The Statue of Liberty was a gift from which country? | France | The United Kingdom | Spain | Italy
        fr: La statue de la Liberté était un cadeau de quel pays ? | La France | Le Royaume-Uni | L'Espagne | L'Italie
        es: ¿Qué país regaló la Estatua de la Libertad? | Francia | Reino Unido | España | Italia
        de: Von welchem Land war die Freiheitsstatue ein Geschenk? | Frankreich | Großbritannien | Spanien | Italien
        it: La Statua della Libertà fu un dono di quale Paese? | Francia | Regno Unito | Spagna | Italia
        pt: A Estátua da Liberdade foi um presente de qual país? | França | Reino Unido | Espanha | Itália
        ja: 自由の女神像を贈った国は？ | フランス | イギリス | スペイン | イタリア
        ko: 자유의 여신상을 선물한 나라는? | 프랑스 | 영국 | 스페인 | 이탈리아
        zh: 自由女神像是哪个国家赠送的？ | 法国 | 英国 | 西班牙 | 意大利
        ar: تمثال الحرية كان هدية من أي دولة؟ | فرنسا | المملكة المتحدة | إسبانيا | إيطاليا

        # arts.eiffel arts 1
        en: In which city is the Eiffel Tower? | Paris | London | Rome | Brussels
        fr: Dans quelle ville se trouve la tour Eiffel ? | Paris | Londres | Rome | Bruxelles
        es: ¿En qué ciudad está la torre Eiffel? | París | Londres | Roma | Bruselas
        de: In welcher Stadt steht der Eiffelturm? | Paris | London | Rom | Brüssel
        it: In quale città si trova la Torre Eiffel? | Parigi | Londra | Roma | Bruxelles
        pt: Em que cidade fica a Torre Eiffel? | Paris | Londres | Roma | Bruxelas
        ja: エッフェル塔がある都市は？ | パリ | ロンドン | ローマ | ブリュッセル
        ko: 에펠탑이 있는 도시는? | 파리 | 런던 | 로마 | 브뤼셀
        zh: 埃菲尔铁塔在哪座城市？ | 巴黎 | 伦敦 | 罗马 | 布鲁塞尔
        ar: في أي مدينة يقع برج إيفل؟ | باريس | لندن | روما | بروكسل

        # arts.sagrada arts 2
        en: Who designed the Sagrada Família in Barcelona? | Antoni Gaudí | Le Corbusier | Frank Lloyd Wright | Zaha Hadid
        fr: Qui a conçu la Sagrada Família de Barcelone ? | Antoni Gaudí | Le Corbusier | Frank Lloyd Wright | Zaha Hadid
        es: ¿Quién diseñó la Sagrada Familia de Barcelona? | Antoni Gaudí | Le Corbusier | Frank Lloyd Wright | Zaha Hadid
        de: Wer entwarf die Sagrada Família in Barcelona? | Antoni Gaudí | Le Corbusier | Frank Lloyd Wright | Zaha Hadid
        it: Chi progettò la Sagrada Família di Barcellona? | Antoni Gaudí | Le Corbusier | Frank Lloyd Wright | Zaha Hadid
        pt: Quem projetou a Sagrada Família, em Barcelona? | Antoni Gaudí | Le Corbusier | Frank Lloyd Wright | Zaha Hadid
        ja: バルセロナのサグラダ・ファミリアを設計したのは？ | アントニ・ガウディ | ル・コルビュジエ | フランク・ロイド・ライト | ザハ・ハディド
        ko: 바르셀로나의 사그라다 파밀리아를 설계한 사람은? | 안토니 가우디 | 르코르뷔지에 | 프랭크 로이드 라이트 | 자하 하디드
        zh: 巴塞罗那圣家堂是谁设计的？ | 高迪 | 勒·柯布西耶 | 弗兰克·劳埃德·赖特 | 扎哈·哈迪德
        ar: من صمّم كنيسة العائلة المقدسة (ساغرادا فاميليا) في برشلونة؟ | أنطوني غاودي | لو كوربوزييه | فرانك لويد رايت | زها حديد

        # arts.alhambra arts 2
        en: The Alhambra palace stands in which city? | Granada | Seville | Córdoba | Toledo
        fr: Dans quelle ville se trouve le palais de l'Alhambra ? | Grenade | Séville | Cordoue | Tolède
        es: ¿En qué ciudad está la Alhambra? | Granada | Sevilla | Córdoba | Toledo
        de: In welcher Stadt steht die Alhambra? | Granada | Sevilla | Córdoba | Toledo
        it: In quale città si trova l'Alhambra? | Granada | Siviglia | Cordova | Toledo
        pt: Em que cidade fica o palácio de Alhambra? | Granada | Sevilha | Córdoba | Toledo
        ja: アルハンブラ宮殿がある都市は？ | グラナダ | セビリア | コルドバ | トレド
        ko: 알람브라 궁전이 있는 도시는? | 그라나다 | 세비야 | 코르도바 | 톨레도
        zh: 阿尔罕布拉宫在哪座城市？ | 格拉纳达 | 塞维利亚 | 科尔多瓦 | 托莱多
        ar: في أي مدينة يقع قصر الحمراء؟ | غرناطة | إشبيلية | قرطبة | طليطلة

        # arts.swan-lake arts 3
        en: Who composed the ballet "Swan Lake"? | Pyotr Tchaikovsky | Igor Stravinsky | Sergei Prokofiev | Sergei Rachmaninoff
        fr: Qui a composé le ballet « Le Lac des cygnes » ? | Piotr Tchaïkovski | Igor Stravinsky | Sergueï Prokofiev | Sergueï Rachmaninov
        es: ¿Quién compuso el ballet «El lago de los cisnes»? | Piotr Chaikovski | Ígor Stravinski | Serguéi Prokófiev | Serguéi Rajmáninov
        de: Wer komponierte das Ballett „Schwanensee“? | Pjotr Tschaikowski | Igor Strawinsky | Sergei Prokofjew | Sergei Rachmaninow
        it: Chi compose il balletto «Il lago dei cigni»? | Pëtr Čajkovskij | Igor Stravinskij | Sergej Prokof'ev | Sergej Rachmaninov
        pt: Quem compôs o balé "O Lago dos Cisnes"? | Piotr Tchaikovsky | Igor Stravinsky | Serguei Prokofiev | Serguei Rachmaninoff
        ja: バレエ『白鳥の湖』を作曲したのは？ | チャイコフスキー | ストラヴィンスキー | プロコフィエフ | ラフマニノフ
        ko: 발레 '백조의 호수'를 작곡한 사람은? | 차이콥스키 | 스트라빈스키 | 프로코피예프 | 라흐마니노프
        zh: 芭蕾舞剧《天鹅湖》是谁作曲的？ | 柴可夫斯基 | 斯特拉文斯基 | 普罗科菲耶夫 | 拉赫玛尼诺夫
        ar: من ألّف باليه «بحيرة البجع»؟ | تشايكوفسكي | سترافينسكي | بروكوفييف | رحمانينوف

        # arts.haiku arts 2
        *: 17 | 14 | 21 | 31
        en: How many sound units (syllables) does a traditional haiku have?
        fr: Combien de syllabes (sons) compte un haïku traditionnel ?
        es: ¿Cuántas sílabas (sonidos) tiene un haiku tradicional?
        de: Wie viele Silben (Laute) hat ein traditionelles Haiku?
        it: Quante sillabe (suoni) ha un haiku tradizionale?
        pt: Quantas sílabas (sons) tem um haicai tradicional?
        ja: 俳句はふつう何音でできている？
        ko: 전통 하이쿠는 모두 몇 음절일까요?
        zh: 传统俳句一共有多少个音？
        ar: كم مقطعًا صوتيًا في قصيدة الهايكو التقليدية؟

        # arts.origami arts 1
        en: Origami is the art of folding what? | Paper | Cloth | Metal | Leaves
        fr: L'origami est l'art de plier quoi ? | Du papier | Du tissu | Du métal | Des feuilles d'arbre
        es: El origami es el arte de doblar… | Papel | Tela | Metal | Hojas de árbol
        de: Origami ist die Kunst, was zu falten? | Papier | Stoff | Metall | Blätter
        it: L'origami è l'arte di piegare… | La carta | La stoffa | Il metallo | Le foglie
        pt: Origami é a arte de dobrar o quê? | Papel | Tecido | Metal | Folhas
        ja: 折り紙は何を折る遊び・芸術？ | 紙 | 布 | 金属 | 木の葉
        ko: 종이접기(오리가미)는 무엇을 접는 예술일까요? | 종이 | 천 | 금속 | 나뭇잎
        zh: 折纸艺术折的是什么？ | 纸 | 布 | 金属 | 树叶
        ar: الأوريغامي فنّ طيّ ماذا؟ | الورق | القماش | المعدن | أوراق الشجر

        # arts.flamenco arts 1
        en: Flamenco music and dance come from which country? | Spain | Argentina | Brazil | Italy
        fr: De quel pays viennent la musique et la danse flamenco ? | L'Espagne | L'Argentine | Le Brésil | L'Italie
        es: ¿De qué país son la música y el baile flamenco? | España | Argentina | Brasil | Italia
        de: Aus welchem Land stammen Flamenco-Musik und -Tanz? | Spanien | Argentinien | Brasilien | Italien
        it: Da quale Paese vengono la musica e la danza flamenco? | Spagna | Argentina | Brasile | Italia
        pt: De que país vêm a música e a dança flamenca? | Espanha | Argentina | Brasil | Itália
        ja: フラメンコの音楽と踊りはどの国のもの？ | スペイン | アルゼンチン | ブラジル | イタリア
        ko: 플라멩코 음악과 춤은 어느 나라에서 왔을까요? | 스페인 | 아르헨티나 | 브라질 | 이탈리아
        zh: 弗拉明戈音乐和舞蹈来自哪个国家？ | 西班牙 | 阿根廷 | 巴西 | 意大利
        ar: من أي بلد تأتي موسيقى ورقص الفلامنكو؟ | إسبانيا | الأرجنتين | البرازيل | إيطاليا

        # arts.tango arts 2
        en: The tango was born around the Río de la Plata in which countries? | Argentina and Uruguay | Spain and Portugal | Mexico and Cuba | Brazil and Chile
        fr: Le tango est né autour du Río de la Plata, dans quels pays ? | L'Argentine et l'Uruguay | L'Espagne et le Portugal | Le Mexique et Cuba | Le Brésil et le Chili
        es: ¿En qué países nació el tango, a orillas del Río de la Plata? | Argentina y Uruguay | España y Portugal | México y Cuba | Brasil y Chile
        de: In welchen Ländern am Río de la Plata entstand der Tango? | Argentinien und Uruguay | Spanien und Portugal | Mexiko und Kuba | Brasilien und Chile
        it: In quali Paesi nacque il tango, intorno al Río de la Plata? | Argentina e Uruguay | Spagna e Portogallo | Messico e Cuba | Brasile e Cile
        pt: Em que países nasceu o tango, às margens do Rio da Prata? | Argentina e Uruguai | Espanha e Portugal | México e Cuba | Brasil e Chile
        ja: タンゴが生まれたラプラタ川流域の国は？ | アルゼンチンとウルグアイ | スペインとポルトガル | メキシコとキューバ | ブラジルとチリ
        ko: 탱고가 탄생한 라플라타강 유역의 나라는? | 아르헨티나와 우루과이 | 스페인과 포르투갈 | 멕시코와 쿠바 | 브라질과 칠레
        zh: 探戈诞生在拉普拉塔河畔的哪两个国家？ | 阿根廷和乌拉圭 | 西班牙和葡萄牙 | 墨西哥和古巴 | 巴西和智利
        ar: في أي بلدين حول ريو دي لا بلاتا وُلد التانغو؟ | الأرجنتين والأوروغواي | إسبانيا والبرتغال | المكسيك وكوبا | البرازيل وتشيلي

        # arts.samba arts 1
        en: Samba is most associated with which country? | Brazil | Argentina | Spain | Mexico
        fr: La samba est surtout associée à quel pays ? | Le Brésil | L'Argentine | L'Espagne | Le Mexique
        es: ¿Con qué país se asocia sobre todo la samba? | Brasil | Argentina | España | México
        de: Mit welchem Land verbindet man Samba am meisten? | Brasilien | Argentinien | Spanien | Mexiko
        it: A quale Paese è associata soprattutto la samba? | Brasile | Argentina | Spagna | Messico
        pt: O samba é mais associado a qual país? | Brasil | Argentina | Espanha | México
        ja: サンバといえばどの国？ | ブラジル | アルゼンチン | スペイン | メキシコ
        ko: 삼바로 가장 유명한 나라는? | 브라질 | 아르헨티나 | 스페인 | 멕시코
        zh: 桑巴舞最常与哪个国家联系在一起？ | 巴西 | 阿根廷 | 西班牙 | 墨西哥
        ar: بأي بلد ترتبط السامبا أكثر من غيره؟ | البرازيل | الأرجنتين | إسبانيا | المكسيك

        # arts.kabuki arts 2
        en: Kabuki is a traditional theatre from which country? | Japan | China | Korea | India
        fr: Le kabuki est un théâtre traditionnel de quel pays ? | Le Japon | La Chine | La Corée | L'Inde
        es: ¿De qué país es el kabuki, un teatro tradicional? | Japón | China | Corea | India
        de: Kabuki ist ein traditionelles Theater aus welchem Land? | Japan | China | Korea | Indien
        it: Il kabuki è un teatro tradizionale di quale Paese? | Giappone | Cina | Corea | India
        pt: O kabuki é um teatro tradicional de qual país? | Japão | China | Coreia | Índia
        ja: 歌舞伎はどの国の伝統演劇？ | 日本 | 中国 | 韓国 | インド
        ko: 가부키는 어느 나라의 전통 연극일까요? | 일본 | 중국 | 한국 | 인도
        zh: 歌舞伎是哪个国家的传统戏剧？ | 日本 | 中国 | 韩国 | 印度
        ar: الكابوكي مسرح تقليدي من أي بلد؟ | اليابان | الصين | كوريا | الهند

        # arts.sitar arts 3
        en: The sitar is a string instrument from which country? | India | China | Turkey | Japan
        fr: Le sitar est un instrument à cordes de quel pays ? | L'Inde | La Chine | La Turquie | Le Japon
        es: ¿De qué país es el sitar, un instrumento de cuerda? | India | China | Turquía | Japón
        de: Die Sitar ist ein Saiteninstrument aus welchem Land? | Indien | China | Türkei | Japan
        it: Il sitar è uno strumento a corde di quale Paese? | India | Cina | Turchia | Giappone
        pt: A cítara indiana (sitar) é um instrumento de cordas de qual país? | Índia | China | Turquia | Japão
        ja: 弦楽器シタールはどの国の楽器？ | インド | 中国 | トルコ | 日本
        ko: 현악기 시타르는 어느 나라 악기일까요? | 인도 | 중국 | 튀르키예 | 일본
        zh: 西塔琴是哪个国家的弦乐器？ | 印度 | 中国 | 土耳其 | 日本
        ar: السيتار آلة وترية من أي بلد؟ | الهند | الصين | تركيا | اليابان

        # arts.glass-pyramid arts 2
        en: A glass pyramid marks the entrance of which museum? | The Louvre | The Prado | The British Museum | The Uffizi
        fr: Une pyramide de verre marque l'entrée de quel musée ? | Le Louvre | Le Prado | Le British Museum | Les Offices
        es: ¿Qué museo tiene una pirámide de cristal en su entrada? | El Louvre | El Prado | El Museo Británico | Los Uffizi
        de: Eine Glaspyramide markiert den Eingang welches Museums? | Louvre | Prado | British Museum | Uffizien
        it: Una piramide di vetro segna l'ingresso di quale museo? | Il Louvre | Il Prado | Il British Museum | Gli Uffizi
        pt: Uma pirâmide de vidro marca a entrada de qual museu? | O Louvre | O Prado | O Museu Britânico | A Galeria Uffizi
        ja: ガラスのピラミッドが入り口にある美術館は？ | ルーヴル美術館 | プラド美術館 | 大英博物館 | ウフィツィ美術館
        ko: 유리 피라미드가 입구에 있는 박물관은? | 루브르 박물관 | 프라도 미술관 | 영국 박물관 | 우피치 미술관
        zh: 哪座博物馆的入口有一座玻璃金字塔？ | 卢浮宫 | 普拉多博物馆 | 大英博物馆 | 乌菲兹美术馆
        ar: هرم زجاجي يميّز مدخل أي متحف؟ | اللوفر | البرادو | المتحف البريطاني | أوفيزي

        # arts.homer arts 2
        en: Who is said to have composed the Iliad and the Odyssey? | Homer | Sophocles | Plato | Virgil
        fr: À qui attribue-t-on l'Iliade et l'Odyssée ? | Homère | Sophocle | Platon | Virgile
        es: ¿A quién se atribuyen la Ilíada y la Odisea? | Homero | Sófocles | Platón | Virgilio
        de: Wem werden die Ilias und die Odyssee zugeschrieben? | Homer | Sophokles | Platon | Vergil
        it: A chi sono attribuite l'Iliade e l'Odissea? | Omero | Sofocle | Platone | Virgilio
        pt: A quem são atribuídas a Ilíada e a Odisseia? | Homero | Sófocles | Platão | Virgílio
        ja: 『イリアス』と『オデュッセイア』の作者とされるのは？ | ホメロス | ソポクレス | プラトン | ウェルギリウス
        ko: '일리아스'와 '오디세이아'의 작가로 알려진 사람은? | 호메로스 | 소포클레스 | 플라톤 | 베르길리우스
        zh: 相传《伊利亚特》和《奥德赛》的作者是谁？ | 荷马 | 索福克勒斯 | 柏拉图 | 维吉尔
        ar: إلى من تُنسب الإلياذة والأوديسة؟ | هوميروس | سوفوكليس | أفلاطون | فرجيل

        # arts.hamlet arts 2
        en: Shakespeare's Hamlet is a prince of which country? | Denmark | England | Scotland | Norway
        fr: Hamlet, de Shakespeare, est prince de quel pays ? | Le Danemark | L'Angleterre | L'Écosse | La Norvège
        es: ¿De qué país es príncipe el Hamlet de Shakespeare? | Dinamarca | Inglaterra | Escocia | Noruega
        de: Von welchem Land ist Shakespeares Hamlet ein Prinz? | Dänemark | England | Schottland | Norwegen
        it: Di quale Paese è principe l'Amleto di Shakespeare? | Danimarca | Inghilterra | Scozia | Norvegia
        pt: Hamlet, de Shakespeare, é príncipe de qual país? | Dinamarca | Inglaterra | Escócia | Noruega
        ja: シェイクスピアのハムレットはどの国の王子？ | デンマーク | イングランド | スコットランド | ノルウェー
        ko: 셰익스피어의 햄릿은 어느 나라의 왕자일까요? | 덴마크 | 잉글랜드 | 스코틀랜드 | 노르웨이
        zh: 莎士比亚笔下的哈姆雷特是哪个国家的王子？ | 丹麦 | 英格兰 | 苏格兰 | 挪威
        ar: هاملت في مسرحية شكسبير أمير أي بلد؟ | الدنمارك | إنجلترا | اسكتلندا | النرويج

        # arts.mozart-birthplace arts 2
        en: Mozart was born in what is now which country? | Austria | Germany | Italy | Switzerland
        fr: Mozart est né dans ce qui est aujourd'hui quel pays ? | L'Autriche | L'Allemagne | L'Italie | La Suisse
        es: ¿En qué país actual nació Mozart? | Austria | Alemania | Italia | Suiza
        de: Im Gebiet welches heutigen Landes wurde Mozart geboren? | Österreich | Deutschland | Italien | Schweiz
        it: In quale Paese di oggi nacque Mozart? | Austria | Germania | Italia | Svizzera
        pt: Mozart nasceu no que hoje é qual país? | Áustria | Alemanha | Itália | Suíça
        ja: モーツァルトが生まれた場所は、今のどの国？ | オーストリア | ドイツ | イタリア | スイス
        ko: 모차르트가 태어난 곳은 오늘날 어느 나라일까요? | 오스트리아 | 독일 | 이탈리아 | 스위스
        zh: 莫扎特出生的地方在今天的哪个国家？ | 奥地利 | 德国 | 意大利 | 瑞士
        ar: وُلد موتسارت فيما يُعرف اليوم بأي بلد؟ | النمسا | ألمانيا | إيطاليا | سويسرا

        # arts.cubism arts 3
        en: Pablo Picasso helped found which art movement? | Cubism | Impressionism | Baroque | Pop art
        fr: Pablo Picasso a contribué à fonder quel mouvement artistique ? | Le cubisme | L'impressionnisme | Le baroque | Le pop art
        es: ¿Qué movimiento artístico ayudó a fundar Pablo Picasso? | El cubismo | El impresionismo | El barroco | El arte pop
        de: Welche Kunstrichtung begründete Pablo Picasso mit? | Den Kubismus | Den Impressionismus | Den Barock | Die Pop-Art
        it: Quale movimento artistico contribuì a fondare Pablo Picasso? | Il cubismo | L'impressionismo | Il barocco | La pop art
        pt: Que movimento artístico Pablo Picasso ajudou a fundar? | O cubismo | O impressionismo | O barroco | A pop art
        ja: パブロ・ピカソが始めた芸術運動は？ | キュビスム | 印象派 | バロック | ポップアート
        ko: 파블로 피카소가 함께 창시한 미술 사조는? | 입체파(큐비즘) | 인상파 | 바로크 | 팝아트
        zh: 毕加索参与创立了哪个艺术流派？ | 立体主义 | 印象派 | 巴洛克 | 波普艺术
        ar: أي حركة فنية شارك بابلو بيكاسو في تأسيسها؟ | التكعيبية | الانطباعية | الباروك | فن البوب

        # arts.the-thinker arts 3
        en: Who sculpted "The Thinker"? | Auguste Rodin | Michelangelo | Donatello | Gian Lorenzo Bernini
        fr: Qui a sculpté « Le Penseur » ? | Auguste Rodin | Michel-Ange | Donatello | Le Bernin
        es: ¿Quién esculpió «El pensador»? | Auguste Rodin | Miguel Ángel | Donatello | Gian Lorenzo Bernini
        de: Wer schuf die Skulptur „Der Denker“? | Auguste Rodin | Michelangelo | Donatello | Gian Lorenzo Bernini
        it: Chi scolpì «Il pensatore»? | Auguste Rodin | Michelangelo | Donatello | Gian Lorenzo Bernini
        pt: Quem esculpiu "O Pensador"? | Auguste Rodin | Michelangelo | Donatello | Gian Lorenzo Bernini
        ja: 彫刻「考える人」をつくったのは？ | オーギュスト・ロダン | ミケランジェロ | ドナテッロ | ベルニーニ
        ko: 조각 '생각하는 사람'을 만든 사람은? | 오귀스트 로댕 | 미켈란젤로 | 도나텔로 | 베르니니
        zh: 雕塑《思想者》的作者是谁？ | 罗丹 | 米开朗琪罗 | 多纳泰罗 | 贝尔尼尼
        ar: من نحت تمثال «المفكّر»؟ | أوغست رودان | مايكل أنجلو | دوناتيلو | برنيني
        """
}
