import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../i18n/app_strings.dart';
import '../services/language_service.dart';
import '../services/usage_tracking_service.dart';

// ─── Data ────────────────────────────────────────────────────────────────────

class _Stop {
  final int n;
  final String name;
  final String emoji;
  final String sectionName;
  final LatLng location;
  final String navInstruction;
  final String lookFor;
  final String funFact;
  final int walkMinutesFromPrev;

  const _Stop({
    required this.n,
    required this.name,
    required this.emoji,
    required this.sectionName,
    required this.location,
    required this.navInstruction,
    required this.lookFor,
    required this.funFact,
    this.walkMinutesFromPrev = 0,
  });
}

class _Trail {
  final String name;
  final String emoji;
  final String duration;
  final String distance;
  final String description;
  final Color color;
  final List<_Stop> stops;

  const _Trail({
    required this.name,
    required this.emoji,
    required this.duration,
    required this.distance,
    required this.description,
    required this.color,
    required this.stops,
  });
}

// Tiny language picker used by trail content.
String _t(AppLanguage l, String en, String fi, String sv) {
  switch (l) {
    case AppLanguage.fi:
      return fi;
    case AppLanguage.sv:
      return sv;
    case AppLanguage.en:
      return en;
  }
}

// ─── Trail definitions (per language) ─────────────────────────────────────────

List<_Trail> _trailsFor(AppLanguage l) => [
  _Trail(
    name: _t(l, 'Medicinal Plants Trail', 'Lääkekasvien polku', 'Medicinalväxternas stig'),
    emoji: '💊',
    duration: _t(l, '45 min', '45 min', '45 min'),
    distance: _t(l, '1.2 km', '1,2 km', '1,2 km'),
    color: const Color(0xFFE65100),
    description: _t(l,
      'Explore plants used in Finnish traditional medicine — from ancient sleep remedies to modern antibiotics.',
      'Tutustu suomalaisen kansanlääkinnän kasveihin — muinaisista unilääkkeistä nykyaikaisiin antibiootteihin.',
      'Utforska växter som används i finsk traditionell medicin — från forntida sömnmedel till moderna antibiotika.',
    ),
    stops: [
      _Stop(
        n: 1,
        name: _t(l, 'Valerian', 'Rohtovirmajuuri', 'Läkevänderot'),
        emoji: '🌿',
        sectionName: _t(l, 'Medicinal & Economic Section', 'Lääke- ja hyötykasvien osasto', 'Medicinal- och nyttoväxtavdelningen'),
        location: const LatLng(65.0601, 25.4740),
        navInstruction: _t(l,
          'Start at the main entrance gate. Walk straight along the central path for about 150 m. Turn left at the wooden sign "Medicinal & Economic Plants". The fenced section is on your right — open the gate and close it behind you (keeps the hares out!).',
          'Aloita pääportilta. Kävele suoraan keskuspolkua noin 150 m. Käänny vasemmalle puukyltin "Lääke- ja hyötykasvit" kohdalla. Aidattu osasto on oikealla — avaa portti ja sulje se perässäsi (estää jänikset!).',
          'Börja vid huvudingången. Gå rakt längs centralstigen i ca 150 m. Sväng vänster vid träskylten "Medicinal- & nyttoväxter". Det inhägnade området är till höger — öppna grinden och stäng efter dig (håller hararna ute!).',
        ),
        lookFor: _t(l,
          'Look for tall, feathery stems up to 1.5 m high with clusters of tiny pale-pink flowers at the top. Crush a leaf gently — the earthy, slightly musty smell is unmistakeable.',
          'Etsi jopa 1,5 m korkeita höyhenmäisiä varsia, joiden latvassa on rypäleinä pieniä vaaleanpunaisia kukkia. Murskaa lehti varovasti — maanläheinen, hieman tunkkainen tuoksu on tunnistettavissa.',
          'Leta efter höga, fjäderlika stjälkar upp till 1,5 m med kluster av små ljusrosa blommor i toppen. Krossa ett blad försiktigt — den jordiga, lätt unkna doften är omisskännlig.',
        ),
        funFact: _t(l,
          'Valerian root has been used as a sleep aid since ancient Rome. Today it is still sold in Finnish pharmacies.',
          'Rohtovirmajuurta on käytetty unilääkkeenä antiikin Roomasta lähtien. Sitä myydään edelleen suomalaisissa apteekeissa.',
          'Vänderot har använts som sömnmedel sedan antikens Rom. Den säljs fortfarande på finska apotek.',
        ),
        walkMinutesFromPrev: 0,
      ),
      _Stop(
        n: 2,
        name: _t(l, "St. John's Wort", 'Mäkikuisma', 'Johannesört'),
        emoji: '🌼',
        sectionName: _t(l, 'Medicinal & Economic Section', 'Lääke- ja hyötykasvien osasto', 'Medicinal- och nyttoväxtavdelningen'),
        location: const LatLng(65.0602, 25.4742),
        navInstruction: _t(l,
          "Stay inside the fenced area. Walk 20 m further along the right-hand border bed. St. John's Wort is two plots after the Valerian.",
          'Pysy aidatulla alueella. Kävele 20 m eteenpäin oikeanpuoleista reunapenkkiä pitkin. Mäkikuisma on kaksi ruutua virmajuuren jälkeen.',
          'Stanna inom det inhägnade området. Gå 20 m längre längs den högra kantrabatten. Johannesört är två rutor efter vänderoten.',
        ),
        lookFor: _t(l,
          'Bright yellow star-shaped flowers with tiny black dots around the petal edges. Hold a leaf up to the light — you will see translucent oil glands that look like tiny windows.',
          'Kirkkaankeltaisia tähtimäisiä kukkia, joiden terälehtien reunoilla on pieniä mustia pisteitä. Pidä lehteä valoa vasten — näet läpikuultavia öljyrauhasia kuin pieniä ikkunoita.',
          'Klargula stjärnformade blommor med små svarta prickar längs kronbladens kanter. Håll ett blad mot ljuset — du ser genomskinliga oljekörtlar som små fönster.',
        ),
        funFact: _t(l,
          "Approved in Germany as a prescription antidepressant. Blooms around the Midsummer festival — hence the name St. John's (midsummer saint).",
          'Saksassa hyväksytty reseptilääkkeeksi masennukseen. Kukkii juhannuksen aikoihin — siitä nimi (Johannes = juhannuksen pyhimys).',
          'Godkänd i Tyskland som receptbelagt antidepressivt medel. Blommar vid midsommar — därav namnet Johannes (midsommarhelgonet).',
        ),
        walkMinutesFromPrev: 1,
      ),
      _Stop(
        n: 3,
        name: _t(l, 'Chamomile', 'Kamomilla', 'Kamomill'),
        emoji: '🌸',
        sectionName: _t(l, 'Medicinal & Economic Section', 'Lääke- ja hyötykasvien osasto', 'Medicinal- och nyttoväxtavdelningen'),
        location: const LatLng(65.0603, 25.4741),
        navInstruction: _t(l,
          'Continue along the same border bed for another 15 m. Chamomile is at the corner of the bed, closest to the apple trees.',
          'Jatka samaa reunapenkkiä vielä 15 m. Kamomilla on penkin kulmassa, lähimpänä omenapuita.',
          'Fortsätt längs samma kantrabatt i ytterligare 15 m. Kamomill står i rabattens hörn, närmast äppelträden.',
        ),
        lookFor: _t(l,
          'Small daisy-like flowers with white petals around a dome-shaped yellow centre. Kneel down — the apple-like scent at ground level is strong.',
          'Pieniä päivänkakkaramaisia kukkia, valkoiset terälehdet ja kupera keltainen keskus. Kyykisty — omenamainen tuoksu maan tasolla on voimakas.',
          'Små prästkrageliknande blommor med vita kronblad runt ett kupolformat gult centrum. Böj dig ner — äppledoften vid marken är stark.',
        ),
        funFact: _t(l,
          "One of Europe's most important medicinal herbs. Finnish grandmothers have brewed chamomile tea for upset stomachs for centuries.",
          'Yksi Euroopan tärkeimmistä lääkekasveista. Suomalaiset mummot ovat keittäneet kamomillateetä vatsavaivoihin vuosisatojen ajan.',
          'En av Europas viktigaste medicinalväxter. Finska mormödrar har bryggt kamomillte mot magbesvär i århundraden.',
        ),
        walkMinutesFromPrev: 1,
      ),
      _Stop(
        n: 4,
        name: _t(l, 'Arctic Cloudberry', 'Lakka', 'Hjortron'),
        emoji: '🍊',
        sectionName: _t(l, 'Woodlands', 'Metsäalue', 'Skogsområdet'),
        location: const LatLng(65.0608, 25.4718),
        navInstruction: _t(l,
          'Exit through the gate of the medicinal section and turn right. Follow the main path north for about 200 m until you see the treeline. Enter the Woodlands area — look for the low bog-like bed on the left just inside the forest edge.',
          'Poistu lääkekasviosaston portista ja käänny oikealle. Seuraa pääpolkua pohjoiseen noin 200 m, kunnes näet puurajan. Astu metsäalueelle — etsi matala suomainen penkki vasemmalla heti metsänreunan sisällä.',
          'Gå ut genom medicinalavdelningens grind och sväng höger. Följ huvudstigen norrut i ca 200 m tills du ser trädgränsen. Gå in i skogsområdet — leta efter den låga myrliknande rabatten till vänster precis innanför skogskanten.',
        ),
        lookFor: _t(l,
          'A low creeping plant (10–25 cm tall) with roundish, crinkled leaves. In summer, ripe berries are amber-orange, one per stem. Earlier in the season, look for a single white flower per plant.',
          'Matala maanmyötäinen kasvi (10–25 cm), pyöreähköt rypistyneet lehdet. Kesällä kypsät marjat ovat keltaisenoransseja, yksi per varsi. Aikaisemmin kaudella jokaisessa kasvissa on yksi valkoinen kukka.',
          'En låg krypande växt (10–25 cm) med rundade, skrynkliga blad. På sommaren är mogna bär bärnstensorange, ett per stjälk. Tidigare på säsongen — leta efter en vit blomma per planta.',
        ),
        funFact: _t(l,
          '"The gold of Lapland" — cloudberries are so prized in Finland that locals guard their secret picking spots fiercely.',
          '"Lapin kulta" — lakat ovat Suomessa niin arvostettuja, että paikalliset varjelevat salaisia poimintapaikkojaan tarkasti.',
          '"Lapplands guld" — hjortron är så uppskattade i Finland att lokalbefolkningen vaktar sina hemliga plockställen ihärdigt.',
        ),
        walkMinutesFromPrev: 5,
      ),
      _Stop(
        n: 5,
        name: _t(l, 'Wild Garlic', 'Karhunlaukka', 'Ramslök'),
        emoji: '🧄',
        sectionName: _t(l, 'Woodlands', 'Metsäalue', 'Skogsområdet'),
        location: const LatLng(65.0609, 25.4717),
        navInstruction: _t(l,
          'Stay in the Woodlands area. Walk 30 m deeper into the birch grove. Wild Garlic grows in a shaded patch near the small wooden bench.',
          'Pysy metsäalueella. Kävele 30 m syvemmälle koivikkoon. Karhunlaukka kasvaa varjoisalla läiskällä pienen puupenkin lähellä.',
          'Stanna i skogsområdet. Gå 30 m djupare in i björkdungen. Ramslök växer i en skuggad fläck nära den lilla träbänken.',
        ),
        lookFor: _t(l,
          'Broad, bright-green lance-shaped leaves growing in clusters at ground level. Even before you see it, you may smell the gentle garlic aroma — especially after rain.',
          'Leveitä, kirkkaanvihreitä keihäänmuotoisia lehtiä, jotka kasvavat ryppäissä maanrajassa. Ennen kuin näet sen, voit tuntea miedon valkosipulin tuoksun — etenkin sateen jälkeen.',
          'Breda, klargröna lansformade blad som växer i klungor vid marknivå. Innan du ens ser den kan du känna den milda vitlöksdoften — särskilt efter regn.',
        ),
        funFact: _t(l,
          'Finnish forest people historically used wild garlic as a spring tonic after the long winter. It has stronger antibacterial compounds than cultivated garlic.',
          'Suomalaiset metsäläiset käyttivät karhunlaukkaa kevätterveysruokana pitkän talven jälkeen. Sen antibakteeriset yhdisteet ovat vahvempia kuin viljellyssä valkosipulissa.',
          'Finska skogsfolk använde historiskt ramslök som vårtonikum efter den långa vintern. Den har starkare antibakteriella föreningar än odlad vitlök.',
        ),
        walkMinutesFromPrev: 2,
      ),
    ],
  ),

  _Trail(
    name: _t(l, 'Arctic Plants Trail', 'Arktisten kasvien polku', 'Arktiska växternas stig'),
    emoji: '⛰️',
    duration: _t(l, '30 min', '30 min', '30 min'),
    distance: _t(l, '0.8 km', '0,8 km', '0,8 km'),
    color: const Color(0xFF546E7A),
    description: _t(l,
      'Discover extraordinary plants that survive -40 °C, track the sun, and carpet the mountains of Lapland.',
      'Tutustu poikkeuksellisiin kasveihin, jotka selviävät -40 °C pakkasista, seuraavat aurinkoa ja peittävät Lapin tunturit.',
      'Upptäck extraordinära växter som överlever -40 °C, följer solen och täcker Lapplands fjäll.',
    ),
    stops: [
      _Stop(
        n: 1,
        name: _t(l, 'Lapland Rhododendron', 'Lapinalppiruusu', 'Lapsk alpros'),
        emoji: '🪻',
        sectionName: _t(l, 'Fennoscandian Mountain Section', 'Fennoskandian tunturiosasto', 'Fennoskandiska fjällavdelningen'),
        location: const LatLng(65.0598, 25.4735),
        navInstruction: _t(l,
          'From the main entrance, take the central path and continue past the ornamental beds. After about 200 m you will see a rocky raised mound on the right — that is the Fennoscandian Mountain Section. Climb the gentle slope.',
          'Pääportilta seuraa keskuspolkua ja jatka koristepenkkien ohi. Noin 200 m kuluttua näet oikealla kivisen kohouman — se on Fennoskandian tunturiosasto. Nouse loivaa rinnettä.',
          'Från huvudingången, ta centralstigen och fortsätt förbi prydnadsrabatterna. Efter ca 200 m ser du en stenig upphöjd kulle till höger — det är fennoskandiska fjällavdelningen. Gå upp för den lätta sluttningen.',
        ),
        lookFor: _t(l,
          'A low woody shrub (40–60 cm) with small, dark evergreen leaves that curl under in winter. In May–June, vivid purple-pink flower clusters appear before the leaves fully open.',
          'Matala puuvartinen pensas (40–60 cm), pienet tummat ainavihannat lehdet, jotka käpristyvät talvella. Touko–kesäkuussa ilmestyy hehkuvan purppuranpunaisia kukkaryppäitä ennen lehtien täydellistä aukeamista.',
          'En låg vedartad buske (40–60 cm) med små, mörka vintergröna blad som rullar in sig på vintern. I maj–juni dyker livligt purpurrosa blomklasar upp innan bladen helt slagit ut.',
        ),
        funFact: _t(l,
          'Grows above the treeline in Lapland at altitudes up to 1 000 m. The flowers appear so early that they are often still dusted with snow.',
          'Kasvaa Lapissa puurajan yläpuolella jopa 1 000 m korkeudessa. Kukat ilmestyvät niin aikaisin, että ne ovat usein vielä lumen peitossa.',
          'Växer ovanför trädgränsen i Lappland på upp till 1 000 m höjd. Blommorna kommer så tidigt att de ofta fortfarande är pudrade med snö.',
        ),
        walkMinutesFromPrev: 0,
      ),
      _Stop(
        n: 2,
        name: _t(l, 'Arctic Poppy', 'Arktinen unikko', 'Polarvallmo'),
        emoji: '🌼',
        sectionName: _t(l, 'Fennoscandian Mountain Section', 'Fennoskandian tunturiosasto', 'Fennoskandiska fjällavdelningen'),
        location: const LatLng(65.0599, 25.4736),
        navInstruction: _t(l,
          'Stay on the rocky mound. Walk 15 m to your right along the summit path. Arctic Poppy is in the open sunny patch between two granite boulders.',
          'Pysy kivisellä kohoumalla. Kävele 15 m oikealle huippupolkua pitkin. Arktinen unikko on avoimella aurinkoisella alueella kahden graniittilohkareen välissä.',
          'Stanna på stenkullen. Gå 15 m åt höger längs toppstigen. Polarvallmo finns på den öppna soliga ytan mellan två granitblock.',
        ),
        lookFor: _t(l,
          'Delicate, tissue-paper-thin yellow or white petals on a single hairy stem. Watch the flower — it slowly rotates to face the sun throughout the day.',
          'Hentoja, silkkipaperinohkaisia keltaisia tai valkoisia terälehtiä karvaisella varrella. Tarkkaile kukkaa — se kääntyy hitaasti auringon mukaan pitkin päivää.',
          'Tunna, silkespapperslika gula eller vita kronblad på en ensam hårig stjälk. Iaktta blomman — den vrider sig långsamt mot solen under dagen.',
        ),
        funFact: _t(l,
          'Arctic Poppies track the sun (heliotropism) to create a warm microclimate inside the flower — raising the temperature by up to 10 °C to attract and reward pollinators.',
          'Arktiset unikot seuraavat aurinkoa (heliotropismi) luodakseen lämpimän mikroilmaston kukan sisälle — nostaen lämpötilaa jopa 10 °C houkutellakseen ja palkitakseen pölyttäjiä.',
          'Polarvallmo följer solen (heliotropism) för att skapa ett varmt mikroklimat inuti blomman — höjer temperaturen med upp till 10 °C för att locka och belöna pollinatörer.',
        ),
        walkMinutesFromPrev: 1,
      ),
      _Stop(
        n: 3,
        name: _t(l, 'Mountain Avens', 'Lapinvuokko', 'Fjällsippa'),
        emoji: '🌸',
        sectionName: _t(l, 'Fennoscandian Mountain Section', 'Fennoskandian tunturiosasto', 'Fennoskandiska fjällavdelningen'),
        location: const LatLng(65.0599, 25.4737),
        navInstruction: _t(l,
          'Continue 20 m along the rocky mound towards the north edge. Mountain Avens forms a mat just before the descent.',
          'Jatka 20 m kivistä kohoumaa pitkin pohjoisreunaa kohti. Lapinvuokko muodostaa maton juuri ennen laskeumaa.',
          'Fortsätt 20 m längs stenkullen mot norra kanten. Fjällsippa bildar en matta precis före nedstigningen.',
        ),
        lookFor: _t(l,
          'A creeping mat-forming plant with small, deeply lobed dark green leaves (white underneath). Eight-petalled white flowers, similar to a small rose. In autumn the feathery seed heads look like a silver cloud.',
          'Mattomainen ryömivä kasvi pienin, syvään liuskaisin tummanvihrein lehdin (valkoinen alapuoli). Kahdeksanteräinen valkoinen kukka, kuin pieni ruusu. Syksyllä höyhenmäiset siemenrykelmät näyttävät hopeapilveltä.',
          'En krypande mattbildande växt med små, djupt flikiga mörkgröna blad (vita undertill). Vita blommor med åtta kronblad, lik en liten ros. På hösten ser de fjäderlika fröhuvudena ut som ett silvermoln.',
        ),
        funFact: _t(l,
          "Finland's national flower. Survives under snow at -40 °C and can live for over 100 years. It is the first plant to colonise bare ground after a glacier retreats.",
          'Suomen kansalliskukka. Selviää lumen alla -40 °C pakkasessa ja voi elää yli 100 vuotta. Se on ensimmäinen kasvi, joka asuttaa paljaan maan jäätikön vetäydyttyä.',
          'Finlands nationalblomma. Överlever under snön vid -40 °C och kan leva i över 100 år. Den är första växten att kolonisera barmark efter att en glaciär dragit sig tillbaka.',
        ),
        walkMinutesFromPrev: 2,
      ),
      _Stop(
        n: 4,
        name: _t(l, 'Cloudberry (Arctic Meadow)', 'Lakka (arktinen niitty)', 'Hjortron (arktisk äng)'),
        emoji: '🍊',
        sectionName: _t(l, 'Grasslands & Meadows', 'Ruohostot ja niityt', 'Gräsmarker & ängar'),
        location: const LatLng(65.0605, 25.4725),
        navInstruction: _t(l,
          'Descend from the rocky mound and turn left (west). Follow the gravel path about 100 m to the Grasslands & Meadows area — you will see open meadow ahead.',
          'Laskeudu kiviseltä kohoumalta ja käänny vasemmalle (länteen). Seuraa soratietä noin 100 m ruohosto- ja niittyalueelle — näet edessäsi avoimen niityn.',
          'Gå ned från stenkullen och sväng vänster (väster). Följ grusgången ca 100 m till gräsmarks- och ängsområdet — du ser öppen äng framför dig.',
        ),
        lookFor: _t(l,
          'The same treasured cloudberry you may know from Finnish markets. Here it grows in its natural bog-meadow habitat alongside cowslip and ox-eye daisies.',
          'Sama arvostettu lakka jonka tunnet Suomen toreilta. Täällä se kasvaa luonnollisessa suoniittyelinympäristössään keto-orvokin ja päivänkakkaroiden seurassa.',
          'Samma uppskattade hjortron du kanske känner från finska marknader. Här växer det i sin naturliga myrängsmiljö tillsammans med gullviva och prästkragar.',
        ),
        funFact: _t(l,
          'Finland exports cloudberry jam to Japan and Germany, where it fetches premium prices. A single plant produces only one berry per season.',
          'Suomi vie lakkahilloa Japaniin ja Saksaan, missä siitä maksetaan korkeita hintoja. Yksi kasvi tuottaa vain yhden marjan kaudessa.',
          'Finland exporterar hjortronsylt till Japan och Tyskland där den får höga priser. En enda planta producerar bara ett bär per säsong.',
        ),
        walkMinutesFromPrev: 4,
      ),
    ],
  ),

  _Trail(
    name: _t(l, 'Greenhouse Grand Tour', 'Kasvihuoneiden suurkierros', 'Växthusens stora rundtur'),
    emoji: '🌴',
    duration: _t(l, '40 min', '40 min', '40 min'),
    distance: _t(l, '0.4 km', '0,4 km', '0,4 km'),
    color: const Color(0xFF795548),
    description: _t(l,
      'The official route from the guide: Aula → Romeo (tropical & subtropical) → Julia (Mediterranean, succulents & temperate). 9 hand-picked highlights from the Kasvihuoneopas.',
      'Virallinen reitti oppaasta: Aula → Romeo (trooppinen & subtrooppinen) → Julia (Välimeri, sukkulentit & lauhkea). 9 valittua kohokohtaa Kasvihuoneoppaasta.',
      'Den officiella rutten från guiden: Aula → Romeo (tropisk & subtropisk) → Julia (Medelhavet, suckulenter & tempererad). 9 utvalda höjdpunkter från Kasvihuoneopas.',
    ),
    stops: [
      _Stop(
        n: 1,
        name: _t(l, 'Aula — Ferns & Terrariums', 'Aula — saniaiset & terraariot', 'Aula — ormbunkar & terrarier'),
        emoji: '🌿',
        sectionName: _t(l, 'Aula — Entrance Hall', 'Aula — sisäänkäyntihalli', 'Aula — entréhall'),
        location: const LatLng(65.0596, 25.4713),
        navInstruction: _t(l,
          'Enter through the main greenhouse door. You are now in the Aula — the entrance hall connecting both glass pyramids. The fern section (saniaiosasto) is on your left, terrariums (terraariot) on your right.',
          'Astu sisään kasvihuoneen pääovesta. Olet nyt Aulassa — molempia lasipyramideja yhdistävässä eteishallissa. Saniaisosasto on vasemmalla, terraariot oikealla.',
          'Gå in genom växthusens huvuddörr. Du är nu i Aulan — entréhallen som förbinder båda glaspyramiderna. Ormbunksavdelningen är till vänster, terrarierna till höger.',
        ),
        lookFor: _t(l,
          'Floor-to-ceiling ferns of dozens of species. In the glass terrariums, look for tiny banana plants (Musa) and Tillandsia air plants growing without any soil, fed entirely by the humid air.',
          'Lattiasta kattoon ulottuvia kymmenien lajien saniaisia. Lasiterraarioissa etsi pieniä banaanikasveja (Musa) ja Tillandsia-ilmakasveja, jotka kasvavat ilman maata pelkän kostean ilman varassa.',
          'Ormbunkar från golv till tak av dussintals arter. I glasterrarierna — leta efter små bananplantor (Musa) och Tillandsia-luftväxter som växer utan jord, helt försörjda av den fuktiga luften.',
        ),
        funFact: _t(l,
          'Ferns are among the oldest plant groups on Earth — they were already growing when dinosaurs first appeared, 360 million years ago.',
          'Saniaiset ovat maapallon vanhimpia kasviryhmiä — ne kasvoivat jo ennen dinosaurusten ilmestymistä, 360 miljoonaa vuotta sitten.',
          'Ormbunkar är bland jordens äldsta växtgrupper — de växte redan när dinosaurierna först dök upp, för 360 miljoner år sedan.',
        ),
        walkMinutesFromPrev: 0,
      ),
      _Stop(
        n: 2,
        name: _t(l, 'Chocolate Tree (Theobroma cacao)', 'Kaakaopuu (Theobroma cacao)', 'Kakaoträd (Theobroma cacao)'),
        emoji: '🍫',
        sectionName: _t(l, 'Romeo — Tropical Section', 'Romeo — trooppinen osasto', 'Romeo — tropisk avdelning'),
        location: const LatLng(65.0597, 25.4708),
        navInstruction: _t(l,
          'Walk through the Aula into the Romeo greenhouse (left pyramid). The Chocolate tree is in the tropical section — follow signs for Trooppinen osasto. Look for the label "Theobroma cacao".',
          'Kävele Aulan läpi Romeon kasvihuoneeseen (vasen pyramidi). Kaakaopuu on trooppisella osastolla — seuraa "Trooppinen osasto" -kylttejä. Etsi nimikyltti "Theobroma cacao".',
          'Gå genom Aulan in i Romeo-växthuset (vänstra pyramiden). Kakaoträdet finns i den tropiska avdelningen — följ skyltarna mot Trooppinen osasto. Leta efter skylten "Theobroma cacao".',
        ),
        lookFor: _t(l,
          'A small tree with large glossy leaves. The cocoa pods grow directly from the trunk and main branches (not from the tips) — an unusual growth pattern called cauliflory. Pods are large, ribbed and turn yellow or red when ripe.',
          'Pieni puu, jolla on suuret kiiltävät lehdet. Kaakaopalot kasvavat suoraan rungosta ja päähaaroista (eivät kärjistä) — epätavallista kasvua kutsutaan kauliflorisuudeksi. Palot ovat suuria, harjanteisia ja muuttuvat keltaisiksi tai punaisiksi kypsyessään.',
          'Ett litet träd med stora glansiga blad. Kakaobaljorna växer direkt från stammen och huvudgrenarna (inte från spetsarna) — ett ovanligt växtmönster som kallas kauliflori. Baljorna är stora, räfflade och blir gula eller röda när de mognar.',
        ),
        funFact: _t(l,
          'Every chocolate bar in the world starts here. The scientific name "Theobroma" means "food of the gods" in Greek. One tree produces enough beans for about 50 chocolate bars per year.',
          'Jokainen suklaapatukka maailmassa alkaa täältä. Tieteellinen nimi "Theobroma" tarkoittaa kreikaksi "jumalten ruokaa". Yksi puu tuottaa vuodessa papuja noin 50 suklaapatukan verran.',
          'Varje chokladkaka i världen börjar här. Det vetenskapliga namnet "Theobroma" betyder "gudarnas mat" på grekiska. Ett träd producerar bönor till ca 50 chokladkakor per år.',
        ),
        walkMinutesFromPrev: 2,
      ),
      _Stop(
        n: 3,
        name: _t(l, 'Coffee Plant (Coffea)', 'Kahvipensas (Coffea)', 'Kaffebuske (Coffea)'),
        emoji: '☕',
        sectionName: _t(l, 'Romeo — Tropical Section', 'Romeo — trooppinen osasto', 'Romeo — tropisk avdelning'),
        location: const LatLng(65.0597, 25.4708),
        navInstruction: _t(l,
          'Stay in the tropical section. The Coffee plant is a few metres from the Chocolate tree — look for the small dark-green glossy shrub with a label "Coffea".',
          'Pysy trooppisella osastolla. Kahvipensas on muutaman metrin päässä kaakaopuusta — etsi pieni tummanvihreä kiiltävä pensas, nimikyltti "Coffea".',
          'Stanna i tropiska avdelningen. Kaffeplantan står några meter från kakaoträdet — leta efter den lilla mörkgröna glansiga busken med skylten "Coffea".',
        ),
        lookFor: _t(l,
          'A shrub or small tree with very dark, waxy, oval leaves. In season, look for small white fragrant flowers or red "coffee cherry" fruits. Each cherry contains two coffee beans inside.',
          'Pensas tai pieni puu, jolla on hyvin tummat, vahamaiset, soikeat lehdet. Kaudella etsi pieniä valkoisia tuoksuvia kukkia tai punaisia "kahvikirsikoita". Jokaisen kirsikan sisällä on kaksi kahvipapua.',
          'En buske eller litet träd med mycket mörka, vaxiga, ovala blad. I säsong — leta efter små vita doftande blommor eller röda "kaffekörsbär". Varje körsbär innehåller två kaffebönor.',
        ),
        funFact: _t(l,
          'Your morning coffee starts as a red berry on this plant. Coffee originated in Ethiopia — legend says a goat herder noticed his goats stayed awake all night after eating the berries.',
          'Aamukahvisi alkaa punaisena marjana tässä kasvissa. Kahvi on kotoisin Etiopiasta — legendan mukaan vuohipaimen huomasi vuohiensa pysyvän valveilla koko yön syötyään marjoja.',
          'Ditt morgonkaffe börjar som ett rött bär på denna planta. Kaffe kommer ursprungligen från Etiopien — enligt legenden upptäckte en getherde att hans getter höll sig vakna hela natten efter att ha ätit bären.',
        ),
        walkMinutesFromPrev: 1,
      ),
      _Stop(
        n: 4,
        name: _t(l, 'Cycas — The Dinosaur Plant', 'Käpypalmu — dinosauruskasvi', 'Kottepalm — dinosauriaväxten'),
        emoji: '🦕',
        sectionName: _t(l, 'Romeo — Tropical Section', 'Romeo — trooppinen osasto', 'Romeo — tropisk avdelning'),
        location: const LatLng(65.0597, 25.4709),
        navInstruction: _t(l,
          'Still in the tropical section. Look for the stiff, feather-like palm with a very rough, armoured trunk — it resembles a small palm but is in an entirely different plant family. Label: Cycas revoluta.',
          'Edelleen trooppisella osastolla. Etsi jäykkää, höyhenmäistä palmua, jolla on hyvin karkea, panssaroitu runko — muistuttaa pientä palmua mutta on aivan eri kasvisukua. Nimikyltti: Cycas revoluta.',
          'Fortfarande i tropiska avdelningen. Leta efter den styva, fjäderlika palmen med en mycket grov, pansrad stam — den liknar en liten palm men tillhör en helt annan växtfamilj. Skylt: Cycas revoluta.',
        ),
        lookFor: _t(l,
          'A symmetrical crown of stiff, dark-green pinnate fronds radiating from a central trunk covered with old leaf bases. New fronds emerge from the centre curled like a fist, then slowly unfurl.',
          'Symmetrinen kruunu jäykkiä, tummanvihreitä parilehdyköitä, jotka säteilevät keskusrungosta, jonka pinta on vanhojen lehtien tyngiä. Uudet lehdet nousevat keskeltä rystysmäisesti käpristyneinä ja avautuvat hitaasti.',
          'En symmetrisk krona av styva, mörkgröna parbladiga vippor som strålar ut från en central stam täckt av gamla bladbaser. Nya vippor uppstår från mitten ihoprullade som en knytnäve och rullas långsamt ut.',
        ),
        funFact: _t(l,
          'This exact plant design has been unchanged for 200 million years — real dinosaurs walked past plants that looked identical to this one. It is one of the slowest-growing plants on Earth, adding one ring of leaves per year.',
          'Tämä kasvimuoto on pysynyt muuttumattomana 200 miljoonaa vuotta — todelliset dinosaurukset kulkivat tämän näköisten kasvien ohi. Se on yksi maailman hitaimmin kasvavia kasveja, lisäten yhden lehtirenkaan vuodessa.',
          'Denna exakta växtdesign har varit oförändrad i 200 miljoner år — riktiga dinosaurier gick förbi växter som såg likadana ut som denna. Det är en av jordens långsammast växande växter, lägger till en ring av blad per år.',
        ),
        walkMinutesFromPrev: 1,
      ),
      _Stop(
        n: 5,
        name: _t(l, 'Eucalyptus', 'Eukalyptus', 'Eukalyptus'),
        emoji: '🐨',
        sectionName: _t(l, 'Romeo — Subtropical Summer', 'Romeo — subtrooppinen kesäosasto', 'Romeo — subtropisk sommar'),
        location: const LatLng(65.0598, 25.4708),
        navInstruction: _t(l,
          'Move into the subtropical summer section of Romeo (Subtrooppinen kesäisteiden osasto). The Eucalyptus is one of the tallest plants — look up.',
          'Siirry Romeon subtrooppiseen kesäosastoon (Subtrooppinen kesäisteiden osasto). Eukalyptus on yksi korkeimmista kasveista — katso ylös.',
          'Gå in i Romeos subtropiska sommarsektion (Subtrooppinen kesäisteiden osasto). Eukalyptusen är en av de högsta växterna — titta upp.',
        ),
        lookFor: _t(l,
          'Long, narrow, blue-grey leaves that hang vertically (not horizontally) to reduce sun exposure. Crush a leaf gently between your fingers — the strong menthol-like scent is unmistakeable.',
          'Pitkiä, kapeita, sinertävänharmaita lehtiä, jotka roikkuvat pystysuoraan (eivät vaakaan) auringonpaisteen vähentämiseksi. Murskaa lehti varovasti sormien välissä — voimakas mentholimainen tuoksu on tunnistettavissa.',
          'Långa, smala, blågrå blad som hänger lodrätt (inte vågrätt) för att minska solexponering. Krossa ett blad försiktigt mellan fingrarna — den starka mentolliknande doften är omisskännlig.',
        ),
        funFact: _t(l,
          'Koalas eat almost nothing else. Eucalyptus leaves are toxic to most animals but koalas evolved a specialised liver to detoxify them. It is also one of the fastest-growing trees on the planet.',
          'Koalat eivät syö juuri muuta. Eukalyptuksen lehdet ovat myrkyllisiä useimmille eläimille, mutta koalat ovat kehittäneet erikoistuneen maksan niiden hajottamiseen. Se on myös yksi planeetan nopeimmin kasvavia puita.',
          'Koalor äter nästan ingenting annat. Eukalyptusblad är giftiga för de flesta djur, men koalor har utvecklat en specialiserad lever för att avgifta dem. Det är också ett av planetens snabbast växande träd.',
        ),
        walkMinutesFromPrev: 2,
      ),
      _Stop(
        n: 6,
        name: _t(l, 'Julia — Olive Tree (Olea europaea)', 'Julia — Oliivipuu (Olea europaea)', 'Julia — Olivträd (Olea europaea)'),
        emoji: '🫒',
        sectionName: _t(l, 'Julia — Subtropical Winter', 'Julia — subtrooppinen talviosasto', 'Julia — subtropisk vinter'),
        location: const LatLng(65.0597, 25.4718),
        navInstruction: _t(l,
          'Walk back through the Aula and into the Julia greenhouse (right pyramid). Enter the subtropical winter section (Subtrooppinen talvisteiden osasto). The Olive tree is one of the largest specimens — look for the gnarled, twisted grey trunk.',
          'Kävele takaisin Aulan läpi Julian kasvihuoneeseen (oikea pyramidi). Astu subtrooppiseen talviosastoon (Subtrooppinen talvisteiden osasto). Oliivipuu on yksi suurimmista yksilöistä — etsi rosoinen, kierteinen harmaa runko.',
          'Gå tillbaka genom Aulan och in i Julia-växthuset (högra pyramiden). Gå in i den subtropiska vinteravdelningen (Subtrooppinen talvisteiden osasto). Olivträdet är en av de största exemplaren — leta efter den knotiga, vridna grå stammen.',
        ),
        lookFor: _t(l,
          'Silver-green narrow leaves, extremely gnarled and twisted grey trunk. In season, small black or green olives may be visible on the branches.',
          'Hopeanvihreitä kapeita lehtiä, äärimmäisen rosoinen ja kierteinen harmaa runko. Kaudella oksilla saattaa näkyä pieniä mustia tai vihreitä oliiveja.',
          'Silvergröna smala blad, extremt knotig och vriden grå stam. I säsong kan små svarta eller gröna oliver synas på grenarna.',
        ),
        funFact: _t(l,
          'Some olive trees alive today were growing during the Roman Empire — over 2 000 years old. The oldest known olive tree in the world is on Crete and is estimated to be 3 000 years old, still producing olives.',
          'Jotkin nykyään elävät oliivipuut kasvoivat jo Rooman valtakunnan aikana — yli 2 000 vuotta vanhoja. Maailman vanhimman tunnetun oliivipuun arvioidaan olevan Kreetalla noin 3 000 vuotta vanha, ja se tuottaa edelleen oliiveja.',
          'Vissa olivträd som lever idag växte under Romarriket — över 2 000 år gamla. Det äldsta kända olivträdet i världen finns på Kreta och uppskattas vara 3 000 år gammalt, och producerar fortfarande oliver.',
        ),
        walkMinutesFromPrev: 3,
      ),
      _Stop(
        n: 7,
        name: _t(l, 'Agave — The Century Plant', 'Agave — vuosisadan kasvi', 'Agave — sekelväxten'),
        emoji: '🌵',
        sectionName: _t(l, 'Julia — Succulents & Dry', 'Julia — sukkulentit & kuivat', 'Julia — suckulenter & torrt'),
        location: const LatLng(65.0596, 25.4718),
        navInstruction: _t(l,
          'Move into the succulent and dry section of Julia (Sukkulentti- & kuivatyypin osasto). The Agave is one of the largest rosette plants — sharp spine-tipped leaves.',
          'Siirry Julian sukkulentti- ja kuivaosastoon (Sukkulentti- & kuivatyypin osasto). Agave on yksi suurimmista ruusukekasveista — terävät piikkikärkiset lehdet.',
          'Gå in i Julias suckulent- och torrsektion (Sukkulentti- & kuivatyypin osasto). Agaven är en av de största rosettväxterna — vassa taggspetsade blad.',
        ),
        lookFor: _t(l,
          'A huge rosette of thick, fleshy, grey-green leaves each tipped with a sharp dark spine. The leaves can be over a metre long. Look for the fibrous texture — the Aztecs used it to make rope.',
          'Valtava ruusuke paksuja, mehukkaita, harmaanvihreitä lehtiä, joista jokaisen kärjessä on terävä tumma piikki. Lehdet voivat olla yli metrin pituisia. Tarkkaile kuitumaista rakennetta — atsteekit valmistivat siitä köyttä.',
          'En enorm rosett av tjocka, köttiga, gråa-gröna blad där varje blad är tippat med en vass mörk tagg. Bladen kan vara över en meter långa. Lägg märke till den fibrösa strukturen — aztekerna gjorde rep av den.',
        ),
        funFact: _t(l,
          'The Agave flowers only ONCE in its entire life — after 80 to 100 years — sending up a flower spike up to 8 metres tall, then dies. That is why it is called the "century plant". Tequila is also made from Agave.',
          'Agave kukkii koko elämänsä aikana vain KERRAN — 80–100 vuoden iässä — työntäen jopa 8 metriä korkean kukkavarren, ja kuolee sitten. Siksi sitä kutsutaan "vuosisadan kasviksi". Myös tequila valmistetaan agavesta.',
          'Agaven blommar bara EN gång under hela sitt liv — efter 80 till 100 år — skickar upp en blomstängel på upp till 8 meter och dör sedan. Därför kallas den "sekelväxten". Tequila tillverkas också av agave.',
        ),
        walkMinutesFromPrev: 1,
      ),
      _Stop(
        n: 8,
        name: _t(l, 'Magnolia', 'Magnolia', 'Magnolia'),
        emoji: '🌸',
        sectionName: _t(l, 'Julia — Temperate Section', 'Julia — lauhkea osasto', 'Julia — tempererad avdelning'),
        location: const LatLng(65.0595, 25.4717),
        navInstruction: _t(l,
          'Walk to the temperate section of Julia (Lauhkean ilmaston osasto). The Magnolia is among the largest trees in this section.',
          'Kävele Julian lauhkean ilmaston osastoon (Lauhkean ilmaston osasto). Magnolia on osaston suurimpia puita.',
          'Gå till Julias tempererade sektion (Lauhkean ilmaston osasto). Magnolian är ett av de största träden i denna sektion.',
        ),
        lookFor: _t(l,
          'Large, waxy, cup-shaped flowers — white to pale pink — that appear before or alongside the large, glossy leaves. The flowers have a subtle lemony scent.',
          'Suuria, vahamaisia, maljamaisia kukkia — valkoisesta vaaleanpunaiseen — jotka ilmestyvät ennen suuria kiiltäviä lehtiä tai niiden kanssa. Kukissa on lievä sitruunainen tuoksu.',
          'Stora, vaxiga, koppformade blommor — vita till ljusrosa — som dyker upp före eller tillsammans med de stora, glansiga bladen. Blommorna har en svag citronartad doft.',
        ),
        funFact: _t(l,
          'Magnolias are one of the most ancient flowering plant lineages on Earth — 95 million years old. They evolved before bees existed, so they are pollinated by beetles instead. Their flowers have no nectar tubes — beetles simply crawl inside.',
          'Magnoliat ovat yksi maapallon vanhimmista kukkivien kasvien sukulinjoista — 95 miljoonaa vuotta vanhoja. Ne kehittyivät ennen mehiläisten olemassaoloa, joten niitä pölyttävät kovakuoriaiset. Niiden kukissa ei ole mesiputkia — kovakuoriaiset yksinkertaisesti ryömivät sisään.',
          'Magnolior är en av jordens äldsta blommande växtgrupper — 95 miljoner år gamla. De utvecklades innan bin fanns, så de pollineras av skalbaggar istället. Deras blommor har inga nektarrör — skalbaggarna kryper helt enkelt in.',
        ),
        walkMinutesFromPrev: 2,
      ),
      _Stop(
        n: 9,
        name: _t(l, 'Peach Tree (Prunus persica)', 'Persikkapuu (Prunus persica)', 'Persikoträd (Prunus persica)'),
        emoji: '🍑',
        sectionName: _t(l, 'Julia — Temperate Section', 'Julia — lauhkea osasto', 'Julia — tempererad avdelning'),
        location: const LatLng(65.0595, 25.4717),
        navInstruction: _t(l,
          'Stay in the temperate section. The Peach tree is nearby the Magnolia — look for the long, narrow, lance-shaped leaves and the label "Prunus persica".',
          'Pysy lauhkean ilmaston osastolla. Persikkapuu on lähellä magnoliaa — etsi pitkät, kapeat, keihäänmuotoiset lehdet ja nimikyltti "Prunus persica".',
          'Stanna i tempererade sektionen. Persikoträdet står nära magnolian — leta efter de långa, smala, lansformade bladen och skylten "Prunus persica".',
        ),
        lookFor: _t(l,
          'A small tree with narrow, pointed leaves and, in season, actual peaches. In spring, look for delicate pink five-petalled blossoms before the leaves appear.',
          'Pieni puu, kapeat suippokärkiset lehdet, ja kaudella oikeita persikoita. Keväällä etsi hentoja vaaleanpunaisia viisiteräisiä kukkia ennen lehtien ilmestymistä.',
          'Ett litet träd med smala, spetsiga blad och, i säsong, riktiga persikor. På våren — leta efter ömtåliga rosa blommor med fem kronblad innan bladen kommer.',
        ),
        funFact: _t(l,
          'The name "persica" means "from Persia" — Europeans first encountered peaches when Alexander the Great brought them from Persia. But they actually originate in China, where they have been cultivated for 4 000 years.',
          'Nimi "persica" tarkoittaa "Persiasta" — eurooppalaiset kohtasivat persikat ensimmäisen kerran, kun Aleksanteri Suuri toi ne Persiasta. Ne ovat kuitenkin alun perin Kiinasta, missä niitä on viljelty 4 000 vuotta.',
          'Namnet "persica" betyder "från Persien" — européer mötte persikor först när Alexander den store förde dem från Persien. Men de kommer faktiskt ursprungligen från Kina, där de odlats i 4 000 år.',
        ),
        walkMinutesFromPrev: 1,
      ),
    ],
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class TrailScreen extends StatefulWidget {
  const TrailScreen({super.key});

  @override
  State<TrailScreen> createState() => _TrailScreenState();
}

class _TrailScreenState extends State<TrailScreen> {
  int? _activeTrailIndex; // index into _trailsFor(...)
  int _currentStop = 0;

  // GPS
  StreamSubscription<Position>? _posStream;
  LatLng? _userPos;
  bool _gpsActive = false;

  @override
  void initState() {
    super.initState();
    _startGps();
    UsageTrackingService.instance.log(UsageTrackingService.featureTrails);
  }

  Future<void> _startGps() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _gpsActive = false);
      return;
    }

    final status = await Permission.location.request();
    if (!status.isGranted) {
      if (mounted) setState(() => _gpsActive = false);
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _userPos = LatLng(pos.latitude, pos.longitude);
          _gpsActive = true;
        });
      }
    } catch (_) {}

    _posStream?.cancel();
    _posStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 3),
    ).listen((pos) {
      if (mounted) {
        setState(() {
          _userPos = LatLng(pos.latitude, pos.longitude);
          _gpsActive = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _posStream?.cancel();
    super.dispose();
  }

  double? _distanceTo(LatLng target) {
    if (_userPos == null) return null;
    return const Distance().as(LengthUnit.Meter, _userPos!, target);
  }

  bool _hasArrived(LatLng target) {
    final d = _distanceTo(target);
    return d != null && d < 15;
  }

  String _distanceLabel(LatLng target, AppStrings s) {
    final d = _distanceTo(target);
    if (d == null) return '📡 ${s.locating}';
    if (d < 15) return '✅ ${s.youHaveArrived}';
    if (d < 50) return '🟢 ${d.toInt()} m — ${s.veryClose}';
    if (d < 200) return '🟡 ${d.toInt()} m — ${s.keepWalking}';
    return '🔴 ${d.toInt()} m ${s.away}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    final s = lang.strings;
    final trails = _trailsFor(lang.current);
    final activeTrail =
        _activeTrailIndex == null ? null : trails[_activeTrailIndex!];

    return Scaffold(
      backgroundColor: const Color(0xFF0D1F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2E1E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF66BB6A)),
          onPressed: activeTrail != null
              ? () => setState(() {
                    _activeTrailIndex = null;
                    _currentStop = 0;
                  })
              : () => Navigator.pop(context),
        ),
        title: Text(
          activeTrail != null ? activeTrail.name : '🥾 ${s.trailsTitle}',
          style: const TextStyle(
              color: Color(0xFFE8F5E9),
              fontWeight: FontWeight.bold,
              fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          GestureDetector(
            onTap: _gpsActive ? null : _startGps,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _gpsActive ? Icons.gps_fixed : Icons.gps_not_fixed,
                    color: _gpsActive ? Colors.greenAccent : Colors.orange,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _gpsActive ? s.liveGps : s.tapNoGps,
                    style: TextStyle(
                      color: _gpsActive ? Colors.greenAccent : Colors.orange,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: activeTrail != null
          ? _buildActiveTrail(activeTrail, s)
          : _buildTrailList(trails, s),
    );
  }

  // ── Trail list ─────────────────────────────────────────────────────────────

  Widget _buildTrailList(List<_Trail> trails, AppStrings s) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: trails.length,
      itemBuilder: (_, i) {
        final t = trails[i];
        return GestureDetector(
          onTap: () => setState(() {
            _activeTrailIndex = i;
            _currentStop = 0;
          }),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.color.withOpacity(0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(t.emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name,
                              style: const TextStyle(
                                  color: Color(0xFFE8F5E9),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _Chip(
                                  icon: Icons.timer,
                                  label: t.duration,
                                  color: t.color),
                              const SizedBox(width: 8),
                              _Chip(
                                  icon: Icons.route,
                                  label: t.distance,
                                  color: t.color),
                              const SizedBox(width: 8),
                              _Chip(
                                  icon: Icons.flag,
                                  label: '${t.stops.length} ${s.stopsLabel}',
                                  color: t.color),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: t.color),
                  ],
                ),
                const SizedBox(height: 10),
                Text(t.description,
                    style: const TextStyle(
                        color: Color(0xFF4CAF50), fontSize: 13, height: 1.4)),
              ],
            ),
          )
              .animate()
              .slideX(
                  begin: -0.2,
                  duration: 350.ms,
                  delay: Duration(milliseconds: i * 80)),
        );
      },
    );
  }

  // ── Active trail ───────────────────────────────────────────────────────────

  Widget _buildActiveTrail(_Trail trail, AppStrings s) {
    final stop = trail.stops[_currentStop];
    final isFirst = _currentStop == 0;
    final isLast = _currentStop == trail.stops.length - 1;
    final arrived = _hasArrived(stop.location);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          color: const Color(0xFF1A2E1E),
          child: Column(
            children: [
              Row(
                children: List.generate(trail.stops.length, (i) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= _currentStop
                            ? trail.color
                            : trail.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    s.trailStopOf(_currentStop + 1, trail.stops.length),
                    style: TextStyle(color: trail.color, fontSize: 12),
                  ),
                  if (stop.walkMinutesFromPrev > 0)
                    Text(
                      '🚶 ~${stop.walkMinutesFromPrev} ${s.minWalkFromPrev}',
                      style: const TextStyle(
                          color: Color(0xFF4CAF50), fontSize: 11),
                    ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: arrived
                        ? Colors.green[900]!.withOpacity(0.4)
                        : const Color(0xFF1A2E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: arrived
                          ? Colors.greenAccent
                          : trail.color.withOpacity(0.4),
                      width: arrived ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        arrived
                            ? Icons.check_circle
                            : Icons.navigation_outlined,
                        color: arrived ? Colors.greenAccent : trail.color,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _distanceLabel(stop.location, s),
                          style: TextStyle(
                            color:
                                arrived ? Colors.greenAccent : Colors.white70,
                            fontSize: 14,
                            fontWeight: arrived
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Text(stop.emoji,
                        style: const TextStyle(fontSize: 36))
                        .animate()
                        .scale(duration: 400.ms),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stop.name,
                            style: const TextStyle(
                              color: Color(0xFFE8F5E9),
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ).animate().fadeIn(duration: 300.ms),
                          const SizedBox(height: 2),
                          Text(
                            '📍 ${stop.sectionName}',
                            style: TextStyle(
                                color: trail.color, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                _SectionCard(
                  icon: Icons.directions_walk,
                  title: s.howToGetThere,
                  body: stop.navInstruction,
                  color: trail.color,
                ),

                const SizedBox(height: 12),

                _SectionCard(
                  icon: Icons.search,
                  title: s.whatToLookFor,
                  body: stop.lookFor,
                  color: const Color(0xFF66BB6A),
                ),

                const SizedBox(height: 12),

                _SectionCard(
                  icon: Icons.lightbulb_outline,
                  title: s.didYouKnow,
                  body: stop.funFact,
                  color: const Color(0xFF4CAF50),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    if (!isFirst)
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: trail.color,
                            side: BorderSide(color: trail.color),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () =>
                              setState(() => _currentStop--),
                          child: Text('← ${s.previous}'),
                        ),
                      ),
                    if (!isFirst) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: trail.color,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isLast
                            ? () => setState(() {
                                  _activeTrailIndex = null;
                                  _currentStop = 0;
                                })
                            : () => setState(() => _currentStop++),
                        child: Text(
                            isLast ? '${s.finishTrail} ✅' : '${s.nextStop} →'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
                color: Color(0xFFE8F5E9), fontSize: 14, height: 1.6),
          ),
        ],
      ),
    ).animate().slideY(begin: 0.1, duration: 300.ms);
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: color, fontSize: 11)),
      ],
    );
  }
}
