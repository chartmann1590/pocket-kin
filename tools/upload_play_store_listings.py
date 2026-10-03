#!/usr/bin/env python3
"""Upload store listing assets, contact details, and multi-language translations
to Google Play Store via the Google Play Developer API (Edits API).
"""

import os
import sys
import time

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

KEY_PATH = os.environ.get(
    "PLAY_SERVICE_ACCOUNT_JSON_PATH",
    r"C:\Users\Charles\.play\dosely-play-service-account.json"
)
PACKAGE_NAME = "com.pocketkin.game"
DEFAULT_LANG = "en-US"

CONTACT_DETAILS = {
    "contactEmail": "support@charleshartmann.com",
    "contactWebsite": "https://chartmann1590.github.io/pocket-kin/",
    "defaultLanguage": DEFAULT_LANG
}

IMAGE_DIR = r"artifacts\play-assets\store-listing"

LISTINGS = {
    "en-US": {
        "title": "Pocket Kin",
        "shortDescription": "Hatch a cozy creature, care, play, explore & walk together every day.",
        "fullDescription": """Pocket Kin is an original cozy virtual pet game. Hatch a creature from three starter eggs (unlock three more through play), name it, and grow a lasting friendship through care, play, exploration, and walking.

- Gentle care: feed, cuddle, wash, rest. Protected sleep, treatable sniffles, never any goodbyes — neglected pets recover, never disappear.
- Grow together: baby → juvenile (~2 days) → adult (~7 days of kind care). Personality, tricks, friendship milestones, memory album.
- Play: fruit catching, matching pairs, rhythm tapping + meadow, woodland, moonlit pond outings with collectible discoveries.
- Decorate: 30 earned decorations, 12 earned accessories, sanctuary for retired friends, daily tasks + collection goals. Missing days never erases progress.
- Walk Together (optional): count steps via Health Connect or on-device sensor for happiness + parcels. Fully playable without it; steps-only, no GPS.
- Wear OS companion: glanceable pet, needs, care shortcuts, 20-sec rhythm game, walking milestones, optional heart-rate harmony (watch sensor permission), tile + complication (needs connected phone).
- Cloud saves, family-friendly: parent gate, no chat, core care always free.
- Fair monetization: Optional Petal Bundles, Cozy Caretaker Pass (ad-free care forever + golden crown), and seasonal cosmetic bundles. All purchases and external links are strictly protected behind parent gates. Optional rewarded ads never interrupt care."""
    },
    "es-419": {
        "title": "Pocket Kin: Mascota Virtual",
        "shortDescription": "Cría una criatura acogedora, cuídala, juega, explora y paseen juntos a diario.",
        "fullDescription": """Pocket Kin es un entrañable juego de mascotas virtuales. Incuba una criatura a partir de tres huevos iniciales (y desbloquea tres más jugando), dale un nombre y forja una hermosa amistad mediante el cuidado, los juegos, la exploración y los paseos diarios.

- Cuidado cariñoso: alimenta, acaricia, baña y dale descanso. Sueño protegido, resfriados tratables y nunca despedidas: las mascotas descuidadas se recuperan, jamás desaparecen.
- Crezcan juntos: bebé → juvenil (~2 días) → adulto (~7 días de cuidados amorosos). Personalidad, trucos, hitos de amistad y un álbum de recuerdos inolvidables.
- Juegos divertidos: atrapa frutas, encuentra parejas, juego de ritmo musical y expediciones por el prado, el bosque y el estanque iluminado por la luna con descubrimientos coleccionables.
- Decora a tu gusto: 30 decoraciones y 12 accesorios desbloqueables, santuario para mascotas retiradas, tareas diarias y metas de colección. Perder un día nunca borra tu progreso.
- Paseen juntos (opcional): cuenta tus pasos con Health Connect o el sensor del dispositivo para obtener felicidad y paquetes sorpresa. Totalmente jugable sin sensores; solo pasos, sin GPS.
- Compañero Wear OS: mascota visible de un vistazo, necesidades, atajos de cuidado, minijuego de ritmo de 20 segundos, metas de pasos, armonía de frecuencia cardíaca opcional (permiso de sensor del reloj), mosaico y complicación (requiere teléfono conectado).
- Guardado en la nube y seguro para toda la familia: control parental, sin chat, cuidados esenciales siempre gratuitos.
- Monetización justa: paquetes opcionales de pétalos, Pase Cuidador Acogedor (cuidado sin anuncios para siempre + corona dorada) y conjuntos cosméticos temáticos. Todas las compras y enlaces externos están protegidos por control parental. Los anuncios con recompensa opcionales nunca interrumpen la diversión."""
    },
    "es-ES": {
        "title": "Pocket Kin: Mascota Virtual",
        "shortDescription": "Cuida a tu criatura mágica, juega, explora y pasead juntos cada día.",
        "fullDescription": """Pocket Kin es un entrañable juego de mascotas virtuales. Incuba una criatura a partir de tres huevos iniciales (y desbloquea tres más jugando), dale un nombre y forja una hermosa amistad mediante el cuidado, los juegos, la exploración y los paseos diarios.

- Cuidado cariñoso: alimenta, acaricia, baña y dale descanso. Sueño protegido, resfriados tratables y nunca despedidas: las mascotas descuidadas se recuperan, jamás desaparecen.
- Creced juntos: cría → joven (~2 días) → adulto (~7 días de cuidados amorosos). Personalidad, trucos, hitos de amistad y un álbum de recuerdos inolvidables.
- Juegos divertidos: atrapa frutas, encuentra parejas, juego de ritmo musical y expediciones por el prado, el bosque y el estanque iluminado por la luna con descubrimientos coleccionables.
- Decora a tu gusto: 30 decoraciones y 12 accesorios desbloqueables, santuario para mascotas retiradas, tareas diarias y metas de colección. Dejar de jugar un día nunca borra tu progreso.
- Pasead juntos (opcional): cuenta tus pasos con Health Connect o el sensor del dispositivo para obtener felicidad y paquetes sorpresa. Totalmente jugable sin sensores; solo pasos, sin GPS.
- Compañero Wear OS: mascota visible de un vistazo, necesidades, atajos de cuidado, minijuego de ritmo de 20 segundos, metas de pasos, armonía de frecuencia cardíaca opcional, mosaico y complicación (requiere teléfono conectado).
- Guardado en la nube y seguro para toda la familia: control parental matemático, sin chat, cuidados esenciales siempre gratuitos.
- Monetización justa: paquetes opcionales de pétalos, Pase Cuidador Acogedor (cuidado sin anuncios para siempre + corona dorada) y conjuntos cosméticos temáticos."""
    },
    "fr-FR": {
        "title": "Pocket Kin: Animal Virtuel",
        "shortDescription": "Adopte une créature mignonne, prends-en soin, joue et promène-toi chaque jour.",
        "fullDescription": """Pocket Kin est un jeu chaleureux d'animal virtuel. Fais éclore une adorable créature parmi trois œufs de départ (débloques-en trois autres en jouant), donne-lui un prénom et noue une amitié durable grâce aux soins, aux jeux, à l'exploration et aux promenades.

- Soins tout en douceur : nourris, câline, lave et repose ton compagnon. Sommeil protégé, petits rhumes soignables, et aucun adieu déchirant : les animaux négligés récupèrent toujours.
- Grandir ensemble : bébé → jeune (~2 jours) → adulte (~7 jours de tendres soins). Personnalités uniques, tours amusants, étapes d'amitié et album de souvenirs.
- Mini-jeux : cueillette de fruits, paires assorties, jeu de rythme musical, promenades au pré, en forêt et près de l'étang sous la lune avec objets rares à collectionner.
- Décoration : 30 décorations et 12 accessoires à débloquer, sanctuaire pour amis paisibles, corvées quotidiennes et objectifs de collection. Manquer un jour n'efface jamais ta progression.
- Promenons-nous (optionnel) : compte tes pas via Health Connect ou le capteur de l'appareil pour gagner du bonheur et des colis surprises. Totalement jouable sans podomètre ; pas de GPS.
- Compagnon Wear OS : coup d'œil rapide sur ton animal et ses besoins, raccourcis de soins, jeu de rythme de 20 secondes, objectifs de marche, tuile et complication (nécessite téléphone connecté).
- Sauvegardes cloud et adapté à la famille : barrière parentale arithmétique, aucun chat public, soins essentiels toujours 100 % gratuits.
- Monétisation éthique : packs de pétales optionnels, Passe Soigneur Douillet (sans publicités pour toujours + couronne dorée) et tenues thématiques."""
    },
    "de-DE": {
        "title": "Pocket Kin: Mein Haustier",
        "shortDescription": "Brüte ein süßes Wesen aus, pflege es, spiele und spaziert jeden Tag zusammen.",
        "fullDescription": """Pocket Kin ist ein herzerwärmendes Spiel rund um dein eigenes virtuelles Haustier. Brüte ein magisches Wesen aus drei Startereiern aus (schalte drei weitere im Spielverlauf frei), gib ihm einen Namen und baue durch Pflege, Spiele, Erkundungen und gemeinsame Spaziergänge eine innige Freundschaft auf.

- Sanfte Fürsorge: füttern, kuscheln, baden, ausruhen. Geschützter Schlaf, heilbare Wehwehchen und niemals Abschiede – vernachlässigte Tiere erholen sich stets, sie verschwinden nie.
- Gemeinsam wachsen: Baby → Teenager (~2 Tage) → Erwachsener (~7 Tage liebevolle Pflege). Individuelle Persönlichkeiten, Kunststücke, Meilensteine und ein Erinnerungsalbum.
- Tolle Minispiele: Früchte fangen, Paare finden, Rhythmusspiel sowie Ausflüge zur Blumenwiese, in den Zauberwald und an den mondbeschienenen Teich mit sammelbaren Schätzen.
- Gestalten: 30 freischaltbare Dekorationen, 12 Accessoires, ein Heiligtum für Tiere im Ruhestand, tägliche Aufgaben und Sammlungsziele. Verpasste Tage setzen den Fortschritt niemals zurück.
- Gemeinsam Spazierengehen (optional): Zähle Schritte über Health Connect oder Gerätesensoren für Freude und Überraschungspakete. Auch ohne Sensoren voll spielbar; nur Schritte, kein GPS.
- Wear OS Begleiter: Haustier und Bedürfnisse direkt am Handgelenk, 20-Sekunden-Rhythmusspiel, Schrittziele, Kachel und Komplikation (erfordert verbundenes Smartphone).
- Cloud-Speicher & familienfreundlich: Rechen-Elterngatter, kein Fremden-Chat, Kernpflege immer kostenlos.
- Faire Monetarisierung: Optionale Blütenblätter, Gemütlicher Betreuer-Pass (dauerhaft werbefrei + goldene Krone) und saisonale Dekopakete."""
    },
    "ja-JP": {
        "title": "Pocket Kin (ポケット・キン)",
        "shortDescription": "かわいい相棒を育てて、お世話、ミニゲーム、お散歩を毎日一緒に楽しもう。",
        "fullDescription": """『Pocket Kin（ポケット・キン）』は、心温まる癒やしのバーチャルペット育成ゲームです。3種類のタマゴからパートナーを孵化させ（プレイを進めるとさらに3種類解放）、名前をつけて、お世話やミニゲーム、探検、お散歩を通じてかけがえのない絆を育みましょう。

- やさしいお世話：ごはん、なでなで、お風呂、おやすみ。見守り睡眠機能つき。風邪をひいても手当ができ、お別れは決してありません。お世話をお休みしても必ず元気を取り戻します。
- 一緒に成長：あかちゃん → 子ども（約2日） → おとな（約7日の優しいお世話）。個性、おぼえる特技、友情の節目、思い出アルバム。
- 楽しいミニゲーム：フルーツキャッチ、神経衰弱ペア合わせ、リズムタップ、そして草原・森・月夜の池へのおでかけと宝探しコレクション。
- お部屋づくり：30種類の家具や置物、12種類の着せ替えアクセサリー、引退した仲間がのんびり暮らすサンクチュアリ、毎日のデイリータスク。ログインが空いても記録は消えません。
- 一緒にお散歩（任意）：Health Connectまたは端末の歩数センサーで歩いて、ハッピー度UP＆プレゼント小包をゲット。センサーなしでも全編プレイ可能（GPS不使用）。
- Wear OS コンパニオン：スマートウォッチの画面でペットの様子やニーズを確認、20秒クイックリズムゲーム、歩数達成、タイル＆コンプリケーション対応（スマートフォン連動）。
- クラウドセーブ＆安心のファミリー設計：保護者向けペアレンタルゲート、チャットなし、基本のお世話はずっと完全無料。
- 安心の課金設計：花びらパック、ずっと広告なし＋金冠バッジの「Cozy Caretaker Pass」、限定着せ替えセット。全ての購入やお知らせリンクは計算式ペアレンタルゲートで保護されています。"""
    },
    "ko-KR": {
        "title": "포켓 킨 - 귀여운 힐링 펫 키우기",
        "shortDescription": "포근한 펫을 부화시키고, 돌보고, 놀아주고, 매일 함께 산책하세요.",
        "fullDescription": """『포켓 킨(Pocket Kin)』은 따뜻하고 평화로운 가상 펫 육성 게임입니다. 세 가지 알 중에서 마음에 드는 알을 부화시켜(게임을 진행하며 세 가지 추가 해금), 이름을 짓고, 매일 정성 어린 돌봄과 놀이, 탐험, 산책을 통해 소중한 우정을 쌓아보세요.

- 따뜻한 돌봄: 먹이 주기, 쓰다듬기, 목욕, 잠재우기. 편안한 수면 기능과 치료 가능한 감기. 슬픈 이별은 없습니다—돌보지 못한 날이 있어도 펫은 언제나 건강하게 회복됩니다.
- 함께 성장하기: 아기 → 청소년(약 2일) → 성체(약 7일간의 사랑 어린 보살핌). 개성 있는 성격, 귀여운 재주, 우정 마일스톤, 추억 앨범.
- 즐거운 미니게임: 과일 받기, 짝 맞추기 카드 게임, 리듬 탭 미니게임, 들판·숲속·달빛 연못 나들이와 수집 보물 탐색.
- 방 꾸미기 & 안식처: 30종의 가구 및 장식, 12종의 귀여운 액세서리, 은퇴한 친구들이 쉬어가는 안식처, 일일 과제와 수집 목표. 접속하지 않은 날에도 진행 상황은 안전하게 보존됩니다.
- 함께 걷기 (선택 사항): Health Connect 또는 기기 센서로 걸음 수를 측정하여 행복도와 선물 상자를 얻으세요. 센서 없이도 100% 정상 플레이 가능하며, GPS는 전혀 사용하지 않습니다.
- Wear OS 워치 지원: 스마트워치에서 바로 확인하는 펫의 상태, 돌봄 단축키, 20초 리듬 게임, 걸음 수 목표, 타일 및 컴플리케이션 지원 (스마트폰 연동).
- 클라우드 저장 & 안전한 가족 친화 환경: 수학 연산 부모 인증 게이트 탑재, 외부 채팅 차단, 핵심 돌봄 콘텐츠는 언제나 100% 무료.
- 착한 유료화 모델: 선택형 꽃잎 팩, 영구 광고 제거 + 황금 왕관 혜택의 '코지 케어 패스', 꾸미기 번들 제공. 모든 구매는 부모 인증 게이트로 안전하게 보호됩니다."""
    },
    "pt-BR": {
        "title": "Pocket Kin: Bichinho Virtual",
        "shortDescription": "Choque uma criatura fofa, cuide, brinque, explore e caminhem juntos todo dia.",
        "fullDescription": """Pocket Kin é um aconchegante jogo de bichinho virtual. Choque uma adorável criatura a partir de três ovos iniciais (desbloqueie mais três jogando), dê um nome e construa uma linda amizade cuidando, brincando, explorando e passeando juntos.

- Cuidado gentil: alimente, faça carinho, dê banho e coloque para descansar. Sono protegido, resfriados tratáveis e nunca despedidas — pets esquecidos se recuperam, nunca vão embora.
- Cresçam juntos: bebê → jovem (~2 dias) → adulto (~7 dias de carinho). Personalidade única, truques fofos, marcos de amizade e álbum de recordações.
- Brincadeiras: pegue frutas, jogo da memória de pares, desafio de ritmo musical, passeios pelo prado, bosque e lago ao luar com tesouros colecionáveis.
- Decore do seu jeito: 30 decorações e 12 acessórios desbloqueáveis, santuário para pets aposentados, tarefas diárias e metas de coleção. Faltar um dia nunca apaga seu progresso.
- Caminhem juntos (opcional): conte passos via Health Connect ou sensor do celular para ganhar felicidade e encomendas surpresa. Totalmente jogável sem sensores; apenas passos, sem GPS.
- Companheiro Wear OS: veja seu pet no pulso, necessidades, atalhos de cuidado, minijogo de ritmo de 20s, metas de caminhada, bloco e complicação (requer celular conectado).
- Salvamento em nuvem e seguro para a família: controle parental matemático, sem bate-papo, cuidados essenciais sempre gratuitos.
- Monetização justa: pacotes opcionais de pétalas, Passe Cuidador Aconchegante (sem anúncios para sempre + coroa dourada) e conjuntos cosméticos."""
    },
    "it-IT": {
        "title": "Pocket Kin: Cucciolo Virtuale",
        "shortDescription": "Accudisci una dolce creatura, gioca, esplora e cammina insieme ogni giorno.",
        "fullDescription": """Pocket Kin è un tenero gioco di animali virtuali. Fai schiudere un'adorabile creatura da tre uova iniziali (sbloccane altre tre giocando), dagli un nome e coltiva un'amicizia duratura attraverso la cura, il gioco, l'esplorazione e le passeggiate insieme.

- Cure affettuose: dai da mangiare, coccola, lava e fai riposare il tuo piccolo amico. Sonno protetto, piccoli raffreddori curabili e mai nessun addio: i cuccioli trascurati si riprendono sempre, non scompaiono mai.
- Crescere insieme: cucciolo → giovane (~2 giorni) → adulto (~7 giorni di cure amorevoli). Personalità unica, trucchi divertenti, tappe di amicizia e album dei ricordi.
- Giochi divertenti: acchiappa la frutta, memory delle coppie, minigioco a ritmo di musica ed escursioni nel prato, nel bosco e nello stagno illuminato dalla luna con oggetti collezionabili.
- Decora a piacimento: 30 decorazioni e 12 accessori sbloccabili, santuario per amici a riposo, compiti quotidiani e collezioni. Saltare un giorno non cancella mai i tuoi progressi.
- Camminiamo insieme (opzionale): conta i passi tramite Health Connect o il sensore del dispositivo per ottenere felicità e pacchi a sorpresa. Completamente giocabile anche senza sensori; solo passi, nessun GPS.
- Compagno Wear OS: controlla il tuo cucciolo dallo smartwatch, bisogni, scorciatoie di cura, gioco di ritmo da 20 secondi, traguardi di passi, riquadro e complicazione (richiede telefono collegato).
- Salvataggio su cloud e a misura di famiglia: filtro parentale matematico, nessuna chat, cure fondamentali sempre gratuite.
- Monetizzazione equa: pacchetti opzionali di petali, Pass Curatore Affettuoso (senza pubblicità per sempre + corona dorata) e set estetici esclusivi."""
    },
    "zh-CN": {
        "title": "Pocket Kin (口袋萌宠)",
        "shortDescription": "孵化治愈系专属萌宠，悉心照料、趣味互动、探险漫步，每天温馨相伴。",
        "fullDescription": """《Pocket Kin》（口袋萌宠）是一款温馨治愈的原创新生代虚拟宠物养成游戏。从三颗初始萌宠蛋中孵化出属于你的伙伴（随游戏进程可解锁另外三只），为它取一个特别的名字，在日常呵护、趣味游戏、户外探险与漫步同行中建立永恒的真挚友谊。

- 温柔照料：喂食、抚摸、沐浴、安睡。贴心的静息睡眠保护，生病可轻松疗愈，绝无任何悲伤离别——疏于照料的萌宠只会等待康复，永远不会离开你。
- 共同成长：幼崽期 → 少年期（约2天） → 成年期（约7天温馨照料）。解锁独特个性、逗趣特技、深厚友谊里程碑与温馨回忆相册。
- 丰富小游戏：接水果、翻牌记忆配对、节奏点击律动，以及前往青草花海、静谧森林和月色池塘探险，搜集稀有宝藏。
- 个性装扮与家园：30件可解锁家具装饰、12款萌趣配饰、专为退休萌宠打造的惬意庇护所、每日趣味心愿任务。即使偶尔缺席打卡，成长进度也永不丢失。
- 散步同行（可选）：通过 Health Connect 或设备自带传感器同步步数，提升宠物快乐值并解锁神秘小包裹。无需步数传感器亦可体验完整游戏；仅统计步数，绝不收集GPS位置。
- Wear OS 智能手表联动：抬腕即见宠物状态、快捷照顾指令、20秒快节奏游戏、步数达标记录，支持表盘小组件与磁贴卡片（需连接手机）。
- 云端存档与全年龄护航：内置算术式家长控制门锁，无开放公网聊天，核心抚养内容永久100%免费。
- 良心健康的消费机制：可选花瓣道具包、永久免除广告与尊享金冠特权的“Cozy Caretaker Pass”贴心看护通行证，以及季节限定装扮包。所有外部链接与消费均受家长密码严密保护。"""
    },
    "zh-TW": {
        "title": "Pocket Kin (口袋萌寵)",
        "shortDescription": "孵化療癒系專屬萌寵，悉心照料、趣味互動、探險漫步，每天溫馨相伴。",
        "fullDescription": """《Pocket Kin》（口袋萌寵）是一款溫馨療癒的原創虛擬寵物養成遊戲。從三顆初始萌寵蛋中孵化出屬於你的夥伴（隨著遊玩可解鎖另外三隻），為牠取一個特別的名字，在日常呵護、趣味遊戲、戶外探險與漫步同行中建立永恆的真摯友誼。

- 溫柔照料：餵食、撫摸、沐浴、安睡。貼心的安眠保護，生病可輕鬆療癒，絕無任何悲傷離別——疏於照料的萌寵只會等待康復，永遠不會離開你。
- 共同成長：幼崽期 → 少年期（約2天） → 成年期（約7天溫馨照料）。解鎖獨特個性、逗趣特技、深厚友誼里程碑與溫馨回憶相簿。
- 豐富小遊戲：接水果、翻牌記憶配對、節奏點擊律動，以及前往青草花海、靜謐森林與月色池塘探險，蒐集稀有寶藏。
- 個性裝扮與家園：30件可解鎖家具裝飾、12款萌趣配飾、專為退休萌寵打造的愜意庇護所、每日趣味心願任務。即使偶爾中斷登入，成長進度也永不遺失。
- 散步同行（可選）：透過 Health Connect 或裝置內建感應器同步步數，提升寵物快樂值並解鎖神祕小包裹。無需感應器亦可體驗完整遊戲；僅統計步數，絕不收集GPS位置。
- Wear OS 智慧手錶連動：抬手即見寵物狀態、快捷照顧指令、20秒快節奏遊戲、步數達標紀錄，支援錶盤小工具與資訊方塊（需連線手機）。
- 雲端存檔與全齡守護：內建算術式家長控制門鎖，無開放公網聊天，核心撫養內容永久100%免費。
- 良心健康的消費機制：可選花瓣道具包、永久免除廣告與尊享金冠特權的「Cozy Caretaker Pass」貼心看照通行證，以及季節限定裝扮包。所有外部連結與消費均受家長密碼嚴密保護。"""
    }
}


def get_service():
    if not os.path.exists(KEY_PATH):
        raise FileNotFoundError(f"Service account key not found at {KEY_PATH}")
    creds = service_account.Credentials.from_service_account_file(
        KEY_PATH, scopes=["https://www.googleapis.com/auth/androidpublisher"]
    )
    return build("androidpublisher", "v3", credentials=creds)


def upload_images(service, edit_id):
    print("\n--- Uploading Store Listing Graphic Assets ---")

    # images.upload APPENDS — clear each bucket first so re-runs replace
    # instead of duplicating (duplicates trip the per-language screenshot cap).
    for itype in ["icon", "featureGraphic", "phoneScreenshots",
                  "sevenInchScreenshots", "tenInchScreenshots", "wearScreenshots"]:
        try:
            service.edits().images().deleteall(
                packageName=PACKAGE_NAME, editId=edit_id,
                language=DEFAULT_LANG, imageType=itype
            ).execute()
        except Exception:
            pass  # bucket already empty

    # 1. Icon (512x512)
    icon_path = os.path.join(IMAGE_DIR, "icon-512.png")
    if os.path.exists(icon_path):
        print(f"Uploading App Icon: {icon_path}...")
        service.edits().images().upload(
            packageName=PACKAGE_NAME,
            editId=edit_id,
            language=DEFAULT_LANG,
            imageType="icon",
            media_body=MediaFileUpload(icon_path, mimetype="image/png")
        ).execute()
        print("  [OK] App Icon uploaded.")

    # 2. Feature Graphic (1024x500)
    feat_path = os.path.join(IMAGE_DIR, "feature-graphic-1024x500.png")
    if os.path.exists(feat_path):
        print(f"Uploading Feature Graphic: {feat_path}...")
        service.edits().images().upload(
            packageName=PACKAGE_NAME,
            editId=edit_id,
            language=DEFAULT_LANG,
            imageType="featureGraphic",
            media_body=MediaFileUpload(feat_path, mimetype="image/png")
        ).execute()
        print("  [OK] Feature Graphic uploaded.")

    # 3. Phone Screenshots (1080x2340) — this app caps at 3 per language;
    # the 4th upload triggers "more than 8 screenshots" at validate.
    for i in range(1, 4):
        phone_path = os.path.join(IMAGE_DIR, f"phone-{i}.png")
        if os.path.exists(phone_path):
            print(f"Uploading Phone Screenshot {i}: {phone_path}...")
            service.edits().images().upload(
                packageName=PACKAGE_NAME,
                editId=edit_id,
                language=DEFAULT_LANG,
                imageType="phoneScreenshots",
                media_body=MediaFileUpload(phone_path, mimetype="image/png")
            ).execute()
            print(f"  [OK] Phone Screenshot {i} uploaded.")

    # 4. Seven Inch Tablet Screenshots
    for i in range(1, 3):
        tab_path = os.path.join(IMAGE_DIR, f"tablet-{i}.png")
        if os.path.exists(tab_path):
            print(f"Uploading 7-inch Tablet Screenshot {i}: {tab_path}...")
            service.edits().images().upload(
                packageName=PACKAGE_NAME,
                editId=edit_id,
                language=DEFAULT_LANG,
                imageType="sevenInchScreenshots",
                media_body=MediaFileUpload(tab_path, mimetype="image/png")
            ).execute()
            print(f"  [OK] 7-inch Tablet Screenshot {i} uploaded.")

    # 5. Ten Inch Tablet Screenshots: Play's validate counts all screenshot
    # buckets together and this app's effective phone cap is 3 — skip.
    pass

    # 6. Wear OS Screenshots (1024x1024 1:1)
    for i in range(1, 4):
        wear_path = os.path.join(IMAGE_DIR, f"wear-{i}.png")
        if os.path.exists(wear_path):
            print(f"Uploading Wear OS Screenshot {i}: {wear_path}...")
            service.edits().images().upload(
                packageName=PACKAGE_NAME,
                editId=edit_id,
                language=DEFAULT_LANG,
                imageType="wearScreenshots",
                media_body=MediaFileUpload(wear_path, mimetype="image/png")
            ).execute()
            print(f"  [OK] Wear OS Screenshot {i} uploaded.")


def upload_listings(service, edit_id):
    print(f"\n--- Uploading Localized Store Listings ({len(LISTINGS)} Languages) ---")
    for lang, data in LISTINGS.items():
        print(f"Uploading listing for [{lang}]...")
        body = {
            "language": lang,
            "title": data["title"],
            "shortDescription": data["shortDescription"],
            "fullDescription": data["fullDescription"]
        }
        res = service.edits().listings().update(
            packageName=PACKAGE_NAME,
            editId=edit_id,
            language=lang,
            body=body
        ).execute()
        print(f"  [OK] [{lang}] Title: '{res.get('title')}' ({len(res.get('title', ''))} chars)")


def update_contact_details(service, edit_id):
    print("\n--- Updating App Contact & Support Details ---")
    d = service.edits().details().update(
        packageName=PACKAGE_NAME,
        editId=edit_id,
        body=CONTACT_DETAILS
    ).execute()
    print(f"  [OK] Contact details updated: email={d.get('contactEmail')}, website={d.get('contactWebsite')}")


def main():
    print(f"Connecting to Google Play Developer API for {PACKAGE_NAME}...")
    service = get_service()

    print("Creating new edit...")
    edit = service.edits().insert(packageName=PACKAGE_NAME, body={}).execute()
    edit_id = edit["id"]
    print(f"Edit ID: {edit_id}")

    try:
        update_contact_details(service, edit_id)
        upload_images(service, edit_id)
        upload_listings(service, edit_id)

        print("\nValidating edit...")
        val = service.edits().validate(packageName=PACKAGE_NAME, editId=edit_id).execute()
        print(f"Edit validated successfully! Expiry: {val.get('expiryTimeSeconds')}")

        print("\nCommitting edit to Google Play Store...")
        commit_res = service.edits().commit(
            packageName=PACKAGE_NAME,
            editId=edit_id
        ).execute()
        print(f"Edit committed successfully! ID: {commit_res.get('id')}")
        print("\nAll graphics, listings, translations, and store details are LIVE on Google Play!")
        return True

    except Exception as e:
        print(f"\nError during edit execution: {e}")
        try:
            service.edits().delete(packageName=PACKAGE_NAME, editId=edit_id).execute()
            print("Aborted edit deleted.")
        except Exception:
            pass
        return False


if __name__ == "__main__":
    success = main()
    if not success:
        sys.exit(1)
