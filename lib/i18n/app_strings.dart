/// Simple in-memory i18n. Use `S.of(context)` to access translations.
///
/// Languages: English (en), Finnish (fi), Swedish (sv).
/// All translations live in this single file for easy editing.

enum AppLanguage {
  en('English', 'English'),
  fi('fi', 'Suomi'),
  sv('sv', 'Svenska');

  final String code;
  final String displayName;
  const AppLanguage(this.code, this.displayName);

  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (l) => l.code == code || l.name == code,
      orElse: () => AppLanguage.en,
    );
  }

  /// English name of the language — used in LLM system prompts so the model
  /// answers in the chosen language.
  String get llmName => switch (this) {
        AppLanguage.en => 'English',
        AppLanguage.fi => 'Finnish',
        AppLanguage.sv => 'Swedish',
      };
}

class AppStrings {
  final AppLanguage lang;
  const AppStrings(this.lang);

  String _pick(Map<AppLanguage, String> map) =>
      map[lang] ?? map[AppLanguage.en] ?? '';

  // ── Nav ─────────────────────────────────────────────────────────────────
  String get navHome => _pick({
        AppLanguage.en: 'Home',
        AppLanguage.fi: 'Koti',
        AppLanguage.sv: 'Hem',
      });
  String get navMap => _pick({
        AppLanguage.en: 'Map',
        AppLanguage.fi: 'Kartta',
        AppLanguage.sv: 'Karta',
      });
  String get navSearch => _pick({
        AppLanguage.en: 'Search',
        AppLanguage.fi: 'Haku',
        AppLanguage.sv: 'Sök',
      });
  String get navChat => _pick({
        AppLanguage.en: 'Chat',
        AppLanguage.fi: 'Keskustelu',
        AppLanguage.sv: 'Chatt',
      });
  String get navProfile => _pick({
        AppLanguage.en: 'Profile',
        AppLanguage.fi: 'Profiili',
        AppLanguage.sv: 'Profil',
      });

  // ── Home ────────────────────────────────────────────────────────────────
  String get goodMorning => _pick({
        AppLanguage.en: 'Good morning',
        AppLanguage.fi: 'Hyvää huomenta',
        AppLanguage.sv: 'God morgon',
      });
  String get goodAfternoon => _pick({
        AppLanguage.en: 'Good afternoon',
        AppLanguage.fi: 'Hyvää iltapäivää',
        AppLanguage.sv: 'God eftermiddag',
      });
  String get goodEvening => _pick({
        AppLanguage.en: 'Good evening',
        AppLanguage.fi: 'Hyvää iltaa',
        AppLanguage.sv: 'God kväll',
      });
  String get welcomeMessage => _pick({
        AppLanguage.en: 'Welcome to University of Oulu Botanical Garden',
        AppLanguage.fi: 'Tervetuloa Oulun yliopiston kasvitieteelliseen puutarhaan',
        AppLanguage.sv: 'Välkommen till Uleåborgs universitets botaniska trädgård',
      });
  String get bloomingNow => _pick({
        AppLanguage.en: 'Blooming now',
        AppLanguage.fi: 'Kukkii nyt',
        AppLanguage.sv: 'Blommar nu',
      });
  String get statusOpen => _pick({
        AppLanguage.en: 'Open',
        AppLanguage.fi: 'Auki',
        AppLanguage.sv: 'Öppet',
      });
  String get sectionDidYouKnow => _pick({
        AppLanguage.en: 'Did You Know?',
        AppLanguage.fi: 'Tiesitkö?',
        AppLanguage.sv: 'Visste du?',
      });
  String get sectionExplore => _pick({
        AppLanguage.en: 'Explore',
        AppLanguage.fi: 'Tutki',
        AppLanguage.sv: 'Utforska',
      });
  String get sectionGarden => _pick({
        AppLanguage.en: 'Garden',
        AppLanguage.fi: 'Puutarha',
        AppLanguage.sv: 'Trädgård',
      });

  // ── Feature cards ──────────────────────────────────────────────────────
  String get identifyAPlant => _pick({
        AppLanguage.en: 'Identify a Plant',
        AppLanguage.fi: 'Tunnista kasvi',
        AppLanguage.sv: 'Identifiera en växt',
      });
  String get pointCameraToPlant => _pick({
        AppLanguage.en: 'Point camera to a plant and explore',
        AppLanguage.fi: 'Suuntaa kamera kasviin ja tutki',
        AppLanguage.sv: 'Rikta kameran mot en växt och utforska',
      });
  String get plantHunt => _pick({
        AppLanguage.en: 'Plant Hunt',
        AppLanguage.fi: 'Kasvijahti',
        AppLanguage.sv: 'Växtjakt',
      });
  String get plantHuntSubtitle => _pick({
        AppLanguage.en: 'Quests · Badge · Gift',
        AppLanguage.fi: 'Tehtäviä · Merkki · Lahja',
        AppLanguage.sv: 'Uppdrag · Märke · Gåva',
      });
  String get inBloom => _pick({
        AppLanguage.en: 'In Bloom',
        AppLanguage.fi: 'Kukkii',
        AppLanguage.sv: 'Blommar',
      });
  String get gardenMap => _pick({
        AppLanguage.en: 'Garden Map',
        AppLanguage.fi: 'Puutarhakartta',
        AppLanguage.sv: 'Trädgårdskarta',
      });
  String get gardenDiary => _pick({
        AppLanguage.en: 'Garden Diary',
        AppLanguage.fi: 'Puutarhapäiväkirja',
        AppLanguage.sv: 'Trädgårdsdagbok',
      });
  String get gardenDiarySub => _pick({
        AppLanguage.en: 'Your photos — keep them private or share',
        AppLanguage.fi: 'Omat kuvasi — pidä yksityisinä tai jaa',
        AppLanguage.sv: 'Dina foton — behåll privat eller dela',
      });
  String get knowPlants => _pick({
        AppLanguage.en: 'Know Our Plants',
        AppLanguage.fi: 'Tunne kasvit',
        AppLanguage.sv: 'Lär känna växterna',
      });
  String get knowPlantsSub => _pick({
        AppLanguage.en: "Browse the garden's own plant records",
        AppLanguage.fi: 'Selaa puutarhan omia kasvitietoja',
        AppLanguage.sv: 'Bläddra i trädgårdens växtregister',
      });
  String get navigatingMap => _pick({
        AppLanguage.en: 'Navigating Map',
        AppLanguage.fi: 'Reittikartta',
        AppLanguage.sv: 'Navigeringskarta',
      });
  String get navigatingMapSub => _pick({
        AppLanguage.en: 'Walk from any point to any point',
        AppLanguage.fi: 'Kävele pisteestä toiseen',
        AppLanguage.sv: 'Gå från punkt till punkt',
      });
  String get trails => _pick({
        AppLanguage.en: 'Trails',
        AppLanguage.fi: 'Polut',
        AppLanguage.sv: 'Stigar',
      });
  String get soundscape => _pick({
        AppLanguage.en: 'Soundscape',
        AppLanguage.fi: 'Äänimaisema',
        AppLanguage.sv: 'Ljudlandskap',
      });
  String get events => _pick({
        AppLanguage.en: 'Events',
        AppLanguage.fi: 'Tapahtumat',
        AppLanguage.sv: 'Evenemang',
      });
  String get upcomingEvents => _pick({
        AppLanguage.en: 'Upcoming Events',
        AppLanguage.fi: 'Tulevat tapahtumat',
        AppLanguage.sv: 'Kommande evenemang',
      });
  String get startNewChat => _pick({
        AppLanguage.en: 'Start a new conversation',
        AppLanguage.fi: 'Aloita uusi keskustelu',
        AppLanguage.sv: 'Starta en ny konversation',
      });
  String get identifyOrSearchToBegin => _pick({
        AppLanguage.en: 'Identify a plant or search by name',
        AppLanguage.fi: 'Tunnista kasvi tai etsi nimellä',
        AppLanguage.sv: 'Identifiera en växt eller sök efter namn',
      });
  String get tapToView => _pick({
        AppLanguage.en: 'Tap to view',
        AppLanguage.fi: 'Avaa napauttamalla',
        AppLanguage.sv: 'Tryck för att visa',
      });
  String get pin => _pick({
        AppLanguage.en: 'Pin',
        AppLanguage.fi: 'Kiinnitä',
        AppLanguage.sv: 'Fäst',
      });
  String get unpin => _pick({
        AppLanguage.en: 'Unpin',
        AppLanguage.fi: 'Poista kiinnitys',
        AppLanguage.sv: 'Lossa',
      });
  String get delete => _pick({
        AppLanguage.en: 'Delete',
        AppLanguage.fi: 'Poista',
        AppLanguage.sv: 'Ta bort',
      });
  String get pinnedSection => _pick({
        AppLanguage.en: 'Pinned',
        AppLanguage.fi: 'Kiinnitetyt',
        AppLanguage.sv: 'Fästa',
      });
  String get recentChats => _pick({
        AppLanguage.en: 'Recent',
        AppLanguage.fi: 'Viimeisimmät',
        AppLanguage.sv: 'Senaste',
      });
  String get generalBotany => _pick({
        AppLanguage.en: 'General botany',
        AppLanguage.fi: 'Kasvitieteen yleisesti',
        AppLanguage.sv: 'Allmän botanik',
      });
  String get askMeAnythingPlants => _pick({
        AppLanguage.en: 'Ask me anything about plants & gardening',
        AppLanguage.fi: 'Kysy mitä tahansa kasveista ja puutarhanhoidosta',
        AppLanguage.sv: 'Fråga mig vad som helst om växter & trädgårdsskötsel',
      });
  String get deleteChatTitle => _pick({
        AppLanguage.en: 'Delete this chat?',
        AppLanguage.fi: 'Poista tämä keskustelu?',
        AppLanguage.sv: 'Ta bort denna chatt?',
      });
  String get deleteChatBody => _pick({
        AppLanguage.en: 'This conversation will be permanently removed.',
        AppLanguage.fi: 'Tämä keskustelu poistetaan pysyvästi.',
        AppLanguage.sv: 'Denna konversation tas bort permanent.',
      });
  String get rename => _pick({
        AppLanguage.en: 'Rename',
        AppLanguage.fi: 'Nimeä uudelleen',
        AppLanguage.sv: 'Byt namn',
      });
  String get renameChatTitle => _pick({
        AppLanguage.en: 'Rename chat',
        AppLanguage.fi: 'Nimeä keskustelu uudelleen',
        AppLanguage.sv: 'Byt namn på chatt',
      });
  String get newName => _pick({
        AppLanguage.en: 'New name',
        AppLanguage.fi: 'Uusi nimi',
        AppLanguage.sv: 'Nytt namn',
      });
  String get save => _pick({
        AppLanguage.en: 'Save',
        AppLanguage.fi: 'Tallenna',
        AppLanguage.sv: 'Spara',
      });
  String get copy => _pick({
        AppLanguage.en: 'Copy',
        AppLanguage.fi: 'Kopioi',
        AppLanguage.sv: 'Kopiera',
      });
  String get edit => _pick({
        AppLanguage.en: 'Edit',
        AppLanguage.fi: 'Muokkaa',
        AppLanguage.sv: 'Redigera',
      });
  String get copied => _pick({
        AppLanguage.en: 'Copied to clipboard',
        AppLanguage.fi: 'Kopioitu leikepöydälle',
        AppLanguage.sv: 'Kopierat till urklipp',
      });
  String get editMessage => _pick({
        AppLanguage.en: 'Edit message',
        AppLanguage.fi: 'Muokkaa viestiä',
        AppLanguage.sv: 'Redigera meddelande',
      });
  String get selectAll => _pick({
        AppLanguage.en: 'Select all',
        AppLanguage.fi: 'Valitse kaikki',
        AppLanguage.sv: 'Markera alla',
      });
  String get deselectAll => _pick({
        AppLanguage.en: 'Deselect all',
        AppLanguage.fi: 'Poista valinnat',
        AppLanguage.sv: 'Avmarkera alla',
      });
  String selectedCount(int n) => _pick({
        AppLanguage.en: '$n selected',
        AppLanguage.fi: '$n valittu',
        AppLanguage.sv: '$n markerade',
      });
  String get deleteSelectedTitle => _pick({
        AppLanguage.en: 'Delete selected chats?',
        AppLanguage.fi: 'Poista valitut keskustelut?',
        AppLanguage.sv: 'Ta bort markerade chattar?',
      });
  String get report => _pick({
        AppLanguage.en: 'Report',
        AppLanguage.fi: 'Ilmoita',
        AppLanguage.sv: 'Rapportera',
      });

  // ── Auth ───────────────────────────────────────────────────────────────
  String get welcomeBack => _pick({
        AppLanguage.en: 'Welcome back',
        AppLanguage.fi: 'Tervetuloa takaisin',
        AppLanguage.sv: 'Välkommen tillbaka',
      });
  String get signInSubtitle => _pick({
        AppLanguage.en: 'Sign in to continue exploring',
        AppLanguage.fi: 'Kirjaudu sisään jatkaaksesi tutkimista',
        AppLanguage.sv: 'Logga in för att fortsätta utforska',
      });
  String get email => _pick({
        AppLanguage.en: 'Email',
        AppLanguage.fi: 'Sähköposti',
        AppLanguage.sv: 'E-post',
      });
  String get password => _pick({
        AppLanguage.en: 'Password',
        AppLanguage.fi: 'Salasana',
        AppLanguage.sv: 'Lösenord',
      });
  String get displayName => _pick({
        AppLanguage.en: 'Display name',
        AppLanguage.fi: 'Käyttäjänimi',
        AppLanguage.sv: 'Visningsnamn',
      });
  String get signIn => _pick({
        AppLanguage.en: 'Sign in',
        AppLanguage.fi: 'Kirjaudu sisään',
        AppLanguage.sv: 'Logga in',
      });
  String get signUp => _pick({
        AppLanguage.en: 'Sign up',
        AppLanguage.fi: 'Rekisteröidy',
        AppLanguage.sv: 'Registrera dig',
      });
  String get createAccount => _pick({
        AppLanguage.en: 'Create account',
        AppLanguage.fi: 'Luo tili',
        AppLanguage.sv: 'Skapa konto',
      });
  String get noAccountQuestion => _pick({
        AppLanguage.en: "Don't have an account? ",
        AppLanguage.fi: 'Eikö sinulla ole tiliä? ',
        AppLanguage.sv: 'Har du inget konto? ',
      });
  String get continueWithGoogle => _pick({
        AppLanguage.en: 'Continue with Google',
        AppLanguage.fi: 'Jatka Googlella',
        AppLanguage.sv: 'Fortsätt med Google',
      });
  String get forgotPassword => _pick({
        AppLanguage.en: 'Forgot password?',
        AppLanguage.fi: 'Unohditko salasanan?',
        AppLanguage.sv: 'Glömt lösenord?',
      });
  String get resetPassword => _pick({
        AppLanguage.en: 'Reset password',
        AppLanguage.fi: 'Palauta salasana',
        AppLanguage.sv: 'Återställ lösenord',
      });
  String get resetPasswordBody => _pick({
        AppLanguage.en:
            'Enter your email and we\'ll send you a link to reset your password.',
        AppLanguage.fi:
            'Anna sähköpostiosoitteesi, niin lähetämme linkin salasanan palauttamiseksi.',
        AppLanguage.sv:
            'Ange din e-post så skickar vi en länk för att återställa ditt lösenord.',
      });
  String get resetLinkSent => _pick({
        AppLanguage.en: 'Reset link sent! Check your email. 📧',
        AppLanguage.fi: 'Palautuslinkki lähetetty! Tarkista sähköpostisi. 📧',
        AppLanguage.sv: 'Återställningslänk skickad! Kolla din e-post. 📧',
      });
  String get send => _pick({
        AppLanguage.en: 'Send',
        AppLanguage.fi: 'Lähetä',
        AppLanguage.sv: 'Skicka',
      });
  String get or => _pick({
        AppLanguage.en: 'or',
        AppLanguage.fi: 'tai',
        AppLanguage.sv: 'eller',
      });

  // ── Profile ────────────────────────────────────────────────────────────
  String get profile => _pick({
        AppLanguage.en: 'Profile',
        AppLanguage.fi: 'Profiili',
        AppLanguage.sv: 'Profil',
      });
  String get free => _pick({
        AppLanguage.en: 'FREE',
        AppLanguage.fi: 'ILMAINEN',
        AppLanguage.sv: 'GRATIS',
      });
  String get premium => _pick({
        AppLanguage.en: 'PREMIUM',
        AppLanguage.fi: 'PREMIUM',
        AppLanguage.sv: 'PREMIUM',
      });
  String get dailyUsage => _pick({
        AppLanguage.en: 'Daily Usage',
        AppLanguage.fi: 'Päivittäinen käyttö',
        AppLanguage.sv: 'Daglig användning',
      });
  String get aiChats => _pick({
        AppLanguage.en: 'AI Chats',
        AppLanguage.fi: 'AI-keskustelut',
        AppLanguage.sv: 'AI-chattar',
      });
  String get plantHuntsLabel => _pick({
        AppLanguage.en: 'Plant Hunts',
        AppLanguage.fi: 'Kasvijahdit',
        AppLanguage.sv: 'Växtjakter',
      });

  // ── Home feature card subtitles ───────────────────────────────────────
  String get seasonSection => _pick({
        AppLanguage.en: 'Season · Section',
        AppLanguage.fi: 'Kausi · Alue',
        AppLanguage.sv: 'Säsong · Område',
      });
  String get gpsSections => _pick({
        AppLanguage.en: 'GPS · Sections',
        AppLanguage.fi: 'GPS · Alueet',
        AppLanguage.sv: 'GPS · Områden',
      });
  String get selfGuidedGps => _pick({
        AppLanguage.en: 'Self-guided · GPS',
        AppLanguage.fi: 'Itseopastettu · GPS',
        AppLanguage.sv: 'Självguidad · GPS',
      });
  String get ambientLive => _pick({
        AppLanguage.en: 'Ambient · Live',
        AppLanguage.fi: 'Ympäristöääni · Live',
        AppLanguage.sv: 'Omgivande · Live',
      });
  String get toursHours => _pick({
        AppLanguage.en: 'Tours · Hours',
        AppLanguage.fi: 'Kierrokset · Aukioloajat',
        AppLanguage.sv: 'Turer · Öppettider',
      });
  String get pestIssueNote => _pick({
        AppLanguage.en: 'Pest · Issue · Note',
        AppLanguage.fi: 'Tuholainen · Vika · Huomio',
        AppLanguage.sv: 'Skadedjur · Problem · Notering',
      });

  // ── Map screen ────────────────────────────────────────────────────────
  String get searchSectionHint => _pick({
        AppLanguage.en: 'Search a section…',
        AppLanguage.fi: 'Etsi aluetta…',
        AppLanguage.sv: 'Sök ett område…',
      });
  String get directions => _pick({
        AppLanguage.en: 'Directions',
        AppLanguage.fi: 'Reittiohjeet',
        AppLanguage.sv: 'Vägbeskrivning',
      });
  String get findingRoute => _pick({
        AppLanguage.en: 'Finding route…',
        AppLanguage.fi: 'Etsitään reittiä…',
        AppLanguage.sv: 'Söker rutt…',
      });
  String get clearRoute => _pick({
        AppLanguage.en: 'Clear route',
        AppLanguage.fi: 'Tyhjennä reitti',
        AppLanguage.sv: 'Rensa rutt',
      });

  // ── Bloom screen ──────────────────────────────────────────────────────
  String get inBloomTitle => _pick({
        AppLanguage.en: 'In Bloom Now',
        AppLanguage.fi: 'Kukassa nyt',
        AppLanguage.sv: 'Blommar nu',
      });
  String get bloomSubtitle => _pick({
        AppLanguage.en: 'Plants currently flowering at the garden',
        AppLanguage.fi: 'Puutarhassa kukkivat kasvit',
        AppLanguage.sv: 'Växter som blommar i trädgården',
      });
  String get loadingBlooms => _pick({
        AppLanguage.en: 'Loading current blooms…',
        AppLanguage.fi: 'Ladataan kukintaa…',
        AppLanguage.sv: 'Laddar blommor…',
      });

  // ── Trails ────────────────────────────────────────────────────────────
  String get trailsTitle => _pick({
        AppLanguage.en: 'Self-Guided Trails',
        AppLanguage.fi: 'Itseopastetut polut',
        AppLanguage.sv: 'Självguidade stigar',
      });
  String get chooseTrail => _pick({
        AppLanguage.en: 'Choose a trail',
        AppLanguage.fi: 'Valitse polku',
        AppLanguage.sv: 'Välj en stig',
      });
  String get beginnerTrail => _pick({
        AppLanguage.en: 'Beginner',
        AppLanguage.fi: 'Aloittelija',
        AppLanguage.sv: 'Nybörjare',
      });
  String get explorerTrail => _pick({
        AppLanguage.en: 'Explorer',
        AppLanguage.fi: 'Tutkija',
        AppLanguage.sv: 'Utforskare',
      });
  String get fullGardenTrail => _pick({
        AppLanguage.en: 'Full Garden',
        AppLanguage.fi: 'Koko puutarha',
        AppLanguage.sv: 'Hela trädgården',
      });

  // ── Soundscape ────────────────────────────────────────────────────────
  String get soundscapeTitle => _pick({
        AppLanguage.en: 'Garden Soundscape',
        AppLanguage.fi: 'Puutarhan äänimaisema',
        AppLanguage.sv: 'Trädgårdens ljudlandskap',
      });
  String get soundscapeBody => _pick({
        AppLanguage.en: 'Listen to the live ambient sound of the garden',
        AppLanguage.fi: 'Kuuntele puutarhan elävää ympäristön ääntä',
        AppLanguage.sv: 'Lyssna på trädgårdens levande ljud',
      });

  // ── Report ────────────────────────────────────────────────────────────
  String get reportTitle => _pick({
        AppLanguage.en: 'Report a Find',
        AppLanguage.fi: 'Ilmoita havainto',
        AppLanguage.sv: 'Rapportera ett fynd',
      });
  String get reportSubtitle => _pick({
        AppLanguage.en: 'Tell garden staff about a pest, damage, or rare find',
        AppLanguage.fi: 'Kerro henkilökunnalle tuholaisesta, vauriosta tai harvinaisesta löydöstä',
        AppLanguage.sv: 'Berätta för personalen om skadedjur, skada eller sällsynt fynd',
      });
  String get submitReport => _pick({
        AppLanguage.en: 'Submit report',
        AppLanguage.fi: 'Lähetä ilmoitus',
        AppLanguage.sv: 'Skicka rapport',
      });

  // ── Event visibility ──────────────────────────────────────────────────
  String get openToAll => _pick({
        AppLanguage.en: 'Open to all',
        AppLanguage.fi: 'Avoin kaikille',
        AppLanguage.sv: 'Öppet för alla',
      });
  String get privateEvent => _pick({
        AppLanguage.en: 'Private',
        AppLanguage.fi: 'Yksityinen',
        AppLanguage.sv: 'Privat',
      });
  String get visibility => _pick({
        AppLanguage.en: 'Visibility',
        AppLanguage.fi: 'Näkyvyys',
        AppLanguage.sv: 'Synlighet',
      });

  // ── Admin panel drill-downs ───────────────────────────────────────────
  String get registeredAt => _pick({
        AppLanguage.en: 'Registered',
        AppLanguage.fi: 'Rekisteröitynyt',
        AppLanguage.sv: 'Registrerad',
      });
  String get featureUsage => _pick({
        AppLanguage.en: 'Feature Usage',
        AppLanguage.fi: 'Ominaisuuksien käyttö',
        AppLanguage.sv: 'Funktionsanvändning',
      });
  String get adminAllUsers => _pick({
        AppLanguage.en: 'All Users',
        AppLanguage.fi: 'Kaikki käyttäjät',
        AppLanguage.sv: 'Alla användare',
      });
  String get adminPremiumUsers => _pick({
        AppLanguage.en: 'Premium Users',
        AppLanguage.fi: 'Premium-käyttäjät',
        AppLanguage.sv: 'Premiumanvändare',
      });
  String get adminActiveToday => _pick({
        AppLanguage.en: 'Active Today',
        AppLanguage.fi: 'Aktiiviset tänään',
        AppLanguage.sv: 'Aktiva idag',
      });
  String get adminChatsToday => _pick({
        AppLanguage.en: 'Chats Today',
        AppLanguage.fi: 'Keskustelut tänään',
        AppLanguage.sv: 'Chattar idag',
      });
  String get noUsersMatch => _pick({
        AppLanguage.en: 'No users match this filter',
        AppLanguage.fi: 'Ei suodatusta vastaavia käyttäjiä',
        AppLanguage.sv: 'Inga användare matchar filtret',
      });
  String chatsToday(int n) => _pick({
        AppLanguage.en: '$n chats today',
        AppLanguage.fi: '$n keskustelua tänään',
        AppLanguage.sv: '$n chattar idag',
      });
  String get adminBadge => _pick({
        AppLanguage.en: 'ADMIN',
        AppLanguage.fi: 'YLLÄPITÄJÄ',
        AppLanguage.sv: 'ADMIN',
      });

  // ── Gardener access control (admin user list) ─────────────────────────
  String get gardenerBadge => _pick({
        AppLanguage.en: 'GARDENER',
        AppLanguage.fi: 'PUUTARHURI',
        AppLanguage.sv: 'TRÄDGÅRDSMÄSTARE',
      });
  String get makeGardener => _pick({
        AppLanguage.en: 'Make gardener',
        AppLanguage.fi: 'Tee puutarhuriksi',
        AppLanguage.sv: 'Gör till trädgårdsmästare',
      });
  String get removeGardener => _pick({
        AppLanguage.en: 'Remove gardener access',
        AppLanguage.fi: 'Poista puutarhurioikeudet',
        AppLanguage.sv: 'Ta bort trädgårdsmästaråtkomst',
      });
  String get gardenerPromoted => _pick({
        AppLanguage.en: 'Promoted to gardener — can now update plant records.',
        AppLanguage.fi: 'Ylennetty puutarhuriksi — voi nyt päivittää kasvitietoja.',
        AppLanguage.sv: 'Befordrad till trädgårdsmästare — kan nu uppdatera växtuppgifter.',
      });
  String get gardenerRemoved => _pick({
        AppLanguage.en: 'Gardener access removed.',
        AppLanguage.fi: 'Puutarhurioikeudet poistettu.',
        AppLanguage.sv: 'Trädgårdsmästaråtkomst borttagen.',
      });
  String get roleChangeFailed => _pick({
        AppLanguage.en: 'Could not change role',
        AppLanguage.fi: 'Roolin vaihto epäonnistui',
        AppLanguage.sv: 'Kunde inte ändra roll',
      });

  // ── Feature usage chart ───────────────────────────────────────────────
  String get totalUses => _pick({
        AppLanguage.en: 'Total uses',
        AppLanguage.fi: 'Käyttökerrat yhteensä',
        AppLanguage.sv: 'Totala användningar',
      });
  String get featurePlantId => _pick({
        AppLanguage.en: 'Plant ID',
        AppLanguage.fi: 'Kasvitunnistus',
        AppLanguage.sv: 'Växtidentifiering',
      });
  String get featurePlantHunt => _pick({
        AppLanguage.en: 'Plant Hunt',
        AppLanguage.fi: 'Kasvijahti',
        AppLanguage.sv: 'Växtjakt',
      });
  String get featureChat => _pick({
        AppLanguage.en: 'AI Chat',
        AppLanguage.fi: 'AI-keskustelu',
        AppLanguage.sv: 'AI-chatt',
      });
  String get featureBloom => _pick({
        AppLanguage.en: 'Bloom Calendar',
        AppLanguage.fi: 'Kukkakalenteri',
        AppLanguage.sv: 'Blomkalender',
      });
  String get featureMap => _pick({
        AppLanguage.en: 'Map',
        AppLanguage.fi: 'Kartta',
        AppLanguage.sv: 'Karta',
      });
  String get featureTrails => _pick({
        AppLanguage.en: 'Trails',
        AppLanguage.fi: 'Polut',
        AppLanguage.sv: 'Stigar',
      });
  String get featureSoundscape => _pick({
        AppLanguage.en: 'Soundscape',
        AppLanguage.fi: 'Äänimaisema',
        AppLanguage.sv: 'Ljudlandskap',
      });
  String get featureSearch => _pick({
        AppLanguage.en: 'Search',
        AppLanguage.fi: 'Haku',
        AppLanguage.sv: 'Sök',
      });
  String get featureReport => _pick({
        AppLanguage.en: 'Reports',
        AppLanguage.fi: 'Ilmoitukset',
        AppLanguage.sv: 'Rapporter',
      });
  String get featureEvent => _pick({
        AppLanguage.en: 'Events',
        AppLanguage.fi: 'Tapahtumat',
        AppLanguage.sv: 'Evenemang',
      });
  String get noDataYet => _pick({
        AppLanguage.en: 'No usage data yet',
        AppLanguage.fi: 'Ei käyttötietoja vielä',
        AppLanguage.sv: 'Inga användningsdata ännu',
      });

  // ── Holiday hours editor ──────────────────────────────────────────────
  String get editHolidays => _pick({
        AppLanguage.en: 'Edit Holiday Hours',
        AppLanguage.fi: 'Muokkaa pyhäpäivien aukioloja',
        AppLanguage.sv: 'Redigera helgöppettider',
      });
  String get pasteFromWebsite => _pick({
        AppLanguage.en: 'Paste from website',
        AppLanguage.fi: 'Liitä verkkosivulta',
        AppLanguage.sv: 'Klistra in från webbplats',
      });
  String get pasteHolidayInstructions => _pick({
        AppLanguage.en:
            'Copy the holiday hours block from oulu.fi/botanical-garden and paste below. We\'ll parse each line into an editable row.',
        AppLanguage.fi:
            'Kopioi pyhäpäivien aukioloajat osoitteesta oulu.fi/kasvitieteellinen ja liitä alle. Jokainen rivi tulee muokattavaksi.',
        AppLanguage.sv:
            'Kopiera helgtiderna från oulu.fi/botanical-garden och klistra in nedan. Vi tolkar varje rad till en redigerbar rad.',
      });
  String get parse => _pick({
        AppLanguage.en: 'Parse',
        AppLanguage.fi: 'Jäsennä',
        AppLanguage.sv: 'Tolka',
      });
  String parsedCount(int n) => _pick({
        AppLanguage.en: 'Parsed $n entries',
        AppLanguage.fi: '$n riviä jäsennetty',
        AppLanguage.sv: '$n poster tolkade',
      });
  String get addRow => _pick({
        AppLanguage.en: 'Add row',
        AppLanguage.fi: 'Lisää rivi',
        AppLanguage.sv: 'Lägg till rad',
      });
  String get dateLabel => _pick({
        AppLanguage.en: 'Date / label',
        AppLanguage.fi: 'Päivä / nimike',
        AppLanguage.sv: 'Datum / etikett',
      });
  String get hours => _pick({
        AppLanguage.en: 'Hours',
        AppLanguage.fi: 'Tunnit',
        AppLanguage.sv: 'Timmar',
      });
  String get holidaysSaved => _pick({
        AppLanguage.en: 'Holiday hours saved!',
        AppLanguage.fi: 'Pyhäpäivät tallennettu!',
        AppLanguage.sv: 'Helgtider sparade!',
      });
  String get scrapeFailedAlert => _pick({
        AppLanguage.en:
            'Auto-scrape failed — holiday hours may be outdated. Edit them now.',
        AppLanguage.fi:
            'Automaattinen haku epäonnistui — pyhäpäivien aukiolot voivat olla vanhentuneet. Muokkaa nyt.',
        AppLanguage.sv:
            'Automatisk skrapning misslyckades — helgtiderna kan vara föråldrade. Redigera nu.',
      });
  String lastUpdated(String when) => _pick({
        AppLanguage.en: 'Last updated $when',
        AppLanguage.fi: 'Päivitetty viimeksi $when',
        AppLanguage.sv: 'Senast uppdaterad $when',
      });

  // ── Event details ─────────────────────────────────────────────────────
  String get eventDetails => _pick({
        AppLanguage.en: 'Event details',
        AppLanguage.fi: 'Tapahtuman tiedot',
        AppLanguage.sv: 'Evenemangsdetaljer',
      });
  String get eventAttendeesLabel => _pick({
        AppLanguage.en: 'Expected attendees',
        AppLanguage.fi: 'Odotetut osallistujat',
        AppLanguage.sv: 'Förväntade deltagare',
      });
  String get eventOrganizer => _pick({
        AppLanguage.en: 'Organizer',
        AppLanguage.fi: 'Järjestäjä',
        AppLanguage.sv: 'Arrangör',
      });
  String get close => _pick({
        AppLanguage.en: 'Close',
        AppLanguage.fi: 'Sulje',
        AppLanguage.sv: 'Stäng',
      });

  // ── Bloom screen body ─────────────────────────────────────────────────
  String get checkingBlooms => _pick({
        AppLanguage.en: 'Checking what\'s blooming…',
        AppLanguage.fi: 'Tarkistetaan mitä kukkii…',
        AppLanguage.sv: 'Kollar vad som blommar…',
      });

  // ── Auth bodies ───────────────────────────────────────────────────────
  String get joinBotanicaSubtitle => _pick({
        AppLanguage.en: 'Join Botanica and start exploring',
        AppLanguage.fi: 'Liity Botanicaan ja aloita tutkiminen',
        AppLanguage.sv: 'Gå med i Botanica och börja utforska',
      });

  // ── Paywall ───────────────────────────────────────────────────────────
  String get premiumTitle => _pick({
        AppLanguage.en: 'Botanica Premium',
        AppLanguage.fi: 'Botanica Premium',
        AppLanguage.sv: 'Botanica Premium',
      });
  String get unlockFullExperience => _pick({
        AppLanguage.en: 'Unlock the full garden experience',
        AppLanguage.fi: 'Avaa täysi puutarhakokemus',
        AppLanguage.sv: 'Lås upp hela trädgårdsupplevelsen',
      });

  // ── AI Model screen ───────────────────────────────────────────────────
  String get chatEngine => _pick({
        AppLanguage.en: 'Chat Engine',
        AppLanguage.fi: 'Keskustelumoottori',
        AppLanguage.sv: 'Chattmotor',
      });
  String get activeEngine => _pick({
        AppLanguage.en: 'Active engine',
        AppLanguage.fi: 'Aktiivinen moottori',
        AppLanguage.sv: 'Aktiv motor',
      });

  // ── Plant Hunt ────────────────────────────────────────────────────────
  String questNumber(String n) => _pick({
        AppLanguage.en: 'Quest #$n',
        AppLanguage.fi: 'Tehtävä #$n',
        AppLanguage.sv: 'Uppdrag #$n',
      });
  String get yourClue => _pick({
        AppLanguage.en: 'Your clue:',
        AppLanguage.fi: 'Vihjeesi:',
        AppLanguage.sv: 'Din ledtråd:',
      });
  String get retakePhoto => _pick({
        AppLanguage.en: 'Retake photo',
        AppLanguage.fi: 'Ota uusi kuva',
        AppLanguage.sv: 'Ta nytt foto',
      });
  String get tapToOpenCamera => _pick({
        AppLanguage.en: 'Tap to open camera',
        AppLanguage.fi: 'Napauta avataksesi kamera',
        AppLanguage.sv: 'Tryck för att öppna kameran',
      });
  String get takeAPhotoOfThePlant => _pick({
        AppLanguage.en: 'Take a photo of the plant!',
        AppLanguage.fi: 'Ota kuva kasvista!',
        AppLanguage.sv: 'Ta ett foto av växten!',
      });
  String get takePhoto => _pick({
        AppLanguage.en: 'Take Photo',
        AppLanguage.fi: 'Ota kuva',
        AppLanguage.sv: 'Ta foto',
      });
  String get checkingYourAnswer => _pick({
        AppLanguage.en: 'Checking your answer…',
        AppLanguage.fi: 'Tarkistetaan vastausta…',
        AppLanguage.sv: 'Kontrollerar ditt svar…',
      });
  String get theAnswerIs => _pick({
        AppLanguage.en: 'The answer is',
        AppLanguage.fi: 'Vastaus on',
        AppLanguage.sv: 'Svaret är',
      });
  String get tapToKnowTheAnswer => _pick({
        AppLanguage.en: 'Tap to know the answer',
        AppLanguage.fi: 'Napauta nähdäksesi vastaus',
        AppLanguage.sv: 'Tryck för att se svaret',
      });
  String get tryAgain => _pick({
        AppLanguage.en: 'Try Again',
        AppLanguage.fi: 'Yritä uudelleen',
        AppLanguage.sv: 'Försök igen',
      });
  String get submitAnswer => _pick({
        AppLanguage.en: 'Submit Answer',
        AppLanguage.fi: 'Lähetä vastaus',
        AppLanguage.sv: 'Skicka svar',
      });
  String get backToHome => _pick({
        AppLanguage.en: 'Back to Home',
        AppLanguage.fi: 'Takaisin kotiin',
        AppLanguage.sv: 'Tillbaka till start',
      });
  String get goFindItToContinue => _pick({
        AppLanguage.en:
            'Now go find it and submit your answer to continue! 🌿',
        AppLanguage.fi:
            'Mene nyt etsimään se ja lähetä vastauksesi jatkaaksesi! 🌿',
        AppLanguage.sv:
            'Gå nu och hitta den och skicka in ditt svar för att fortsätta! 🌿',
      });
  String get nextQuest => _pick({
        AppLanguage.en: 'Next Quest →',
        AppLanguage.fi: 'Seuraava tehtävä →',
        AppLanguage.sv: 'Nästa uppdrag →',
      });
  String get claimYourBadge => _pick({
        AppLanguage.en: '🏆 Claim Your Badge!',
        AppLanguage.fi: '🏆 Lunasta merkkisi!',
        AppLanguage.sv: '🏆 Hämta ditt märke!',
      });

  // ── Report screen ─────────────────────────────────────────────────────
  String get reportSaved => _pick({
        AppLanguage.en: 'Report Saved!',
        AppLanguage.fi: 'Ilmoitus tallennettu!',
        AppLanguage.sv: 'Rapport sparad!',
      });
  String get whereIsThisStored => _pick({
        AppLanguage.en: 'Where is this stored?',
        AppLanguage.fi: 'Missä tämä on tallennettu?',
        AppLanguage.sv: 'Var lagras detta?',
      });
  String get emailGardenStaff => _pick({
        AppLanguage.en: 'Email Garden Staff  📧',
        AppLanguage.fi: 'Lähetä sähköposti henkilökunnalle  📧',
        AppLanguage.sv: 'E-posta trädgårdspersonalen  📧',
      });
  String get viewAllReports => _pick({
        AppLanguage.en: 'View All Reports',
        AppLanguage.fi: 'Näytä kaikki ilmoitukset',
        AppLanguage.sv: 'Visa alla rapporter',
      });
  String get newReport => _pick({
        AppLanguage.en: 'New Report',
        AppLanguage.fi: 'Uusi ilmoitus',
        AppLanguage.sv: 'Ny rapport',
      });
  String get analyzingImage => _pick({
        AppLanguage.en: 'AI analysing image…',
        AppLanguage.fi: 'Tekoäly analysoi kuvaa…',
        AppLanguage.sv: 'AI analyserar bilden…',
      });
  String get categoryLabel => _pick({
        AppLanguage.en: 'Category',
        AppLanguage.fi: 'Luokka',
        AppLanguage.sv: 'Kategori',
      });
  String get savedReports => _pick({
        AppLanguage.en: 'Saved Reports',
        AppLanguage.fi: 'Tallennetut ilmoitukset',
        AppLanguage.sv: 'Sparade rapporter',
      });
  String get noReportsYet => _pick({
        AppLanguage.en: 'No reports yet.',
        AppLanguage.fi: 'Ei ilmoituksia vielä.',
        AppLanguage.sv: 'Inga rapporter ännu.',
      });
  String get noEmailAppFound => _pick({
        AppLanguage.en: 'No email app found on this device.',
        AppLanguage.fi: 'Tällä laitteella ei löydy sähköpostisovellusta.',
        AppLanguage.sv: 'Ingen e-postapp hittades på denna enhet.',
      });

  // ── Generic ───────────────────────────────────────────────────────────
  String get errorPrefix => _pick({
        AppLanguage.en: 'Error',
        AppLanguage.fi: 'Virhe',
        AppLanguage.sv: 'Fel',
      });

  // ── Trail screen labels ───────────────────────────────────────────────
  String trailStopOf(int current, int total) => _pick({
        AppLanguage.en: 'Stop $current of $total',
        AppLanguage.fi: 'Pysähdys $current / $total',
        AppLanguage.sv: 'Stopp $current av $total',
      });
  String get lookForLabel => _pick({
        AppLanguage.en: 'Look for',
        AppLanguage.fi: 'Etsi',
        AppLanguage.sv: 'Leta efter',
      });
  String get funFactLabel => _pick({
        AppLanguage.en: 'Fun fact',
        AppLanguage.fi: 'Hauska fakta',
        AppLanguage.sv: 'Roligt faktum',
      });
  String get howToGetThere => _pick({
        AppLanguage.en: 'How to get there',
        AppLanguage.fi: 'Miten löydät perille',
        AppLanguage.sv: 'Hur du tar dig dit',
      });
  String get whatToLookFor => _pick({
        AppLanguage.en: 'What to look for',
        AppLanguage.fi: 'Mitä etsiä',
        AppLanguage.sv: 'Vad du letar efter',
      });
  String get didYouKnow => _pick({
        AppLanguage.en: 'Did you know?',
        AppLanguage.fi: 'Tiesitkö?',
        AppLanguage.sv: 'Visste du?',
      });
  String get markAsFound => _pick({
        AppLanguage.en: 'Mark as found',
        AppLanguage.fi: 'Merkitse löydetyksi',
        AppLanguage.sv: 'Markera som hittad',
      });
  String get nextStop => _pick({
        AppLanguage.en: 'Next stop',
        AppLanguage.fi: 'Seuraava pysähdys',
        AppLanguage.sv: 'Nästa stopp',
      });
  String get previous => _pick({
        AppLanguage.en: 'Previous',
        AppLanguage.fi: 'Edellinen',
        AppLanguage.sv: 'Föregående',
      });
  String get finishTrail => _pick({
        AppLanguage.en: 'Finish Trail',
        AppLanguage.fi: 'Päätä polku',
        AppLanguage.sv: 'Avsluta stigen',
      });
  String get stopsLabel => _pick({
        AppLanguage.en: 'stops',
        AppLanguage.fi: 'pysähdystä',
        AppLanguage.sv: 'stopp',
      });
  String get minWalkFromPrev => _pick({
        AppLanguage.en: 'min walk from previous stop',
        AppLanguage.fi: 'min kävelyä edellisestä pysähdyksestä',
        AppLanguage.sv: 'min promenad från föregående stopp',
      });
  String get liveGps => _pick({
        AppLanguage.en: 'Live GPS',
        AppLanguage.fi: 'GPS päällä',
        AppLanguage.sv: 'Live GPS',
      });
  String get tapNoGps => _pick({
        AppLanguage.en: 'Tap — No GPS',
        AppLanguage.fi: 'Napauta — ei GPS:ää',
        AppLanguage.sv: 'Tryck — ingen GPS',
      });
  String get locating => _pick({
        AppLanguage.en: 'Locating…',
        AppLanguage.fi: 'Paikannetaan…',
        AppLanguage.sv: 'Lokaliserar…',
      });
  String get youHaveArrived => _pick({
        AppLanguage.en: 'You have arrived!',
        AppLanguage.fi: 'Olet perillä!',
        AppLanguage.sv: 'Du har kommit fram!',
      });
  String get veryClose => _pick({
        AppLanguage.en: 'very close!',
        AppLanguage.fi: 'aivan vieressä!',
        AppLanguage.sv: 'mycket nära!',
      });
  String get keepWalking => _pick({
        AppLanguage.en: 'keep walking',
        AppLanguage.fi: 'jatka kävelyä',
        AppLanguage.sv: 'fortsätt gå',
      });
  String get away => _pick({
        AppLanguage.en: 'away',
        AppLanguage.fi: 'päässä',
        AppLanguage.sv: 'bort',
      });

  // ── Soundscape body ──────────────────────────────────────────────────
  String get soundscapeTip => _pick({
        AppLanguage.en: 'Move closer to plants for clearer ambient capture',
        AppLanguage.fi: 'Mene lähemmäs kasveja saadaksesi selkeämmän äänen',
        AppLanguage.sv: 'Gå närmare växter för tydligare ljud',
      });

  // ── Form validators ──────────────────────────────────────────────────
  String get enterYourEmail => _pick({
        AppLanguage.en: 'Enter your email',
        AppLanguage.fi: 'Syötä sähköpostiosoitteesi',
        AppLanguage.sv: 'Ange din e-post',
      });
  String get invalidEmail => _pick({
        AppLanguage.en: 'Invalid email',
        AppLanguage.fi: 'Virheellinen sähköposti',
        AppLanguage.sv: 'Ogiltig e-post',
      });
  String get atLeast6Chars => _pick({
        AppLanguage.en: 'At least 6 characters',
        AppLanguage.fi: 'Vähintään 6 merkkiä',
        AppLanguage.sv: 'Minst 6 tecken',
      });
  String get enterYourName => _pick({
        AppLanguage.en: 'Enter your name',
        AppLanguage.fi: 'Syötä nimesi',
        AppLanguage.sv: 'Ange ditt namn',
      });

  // ── Force update ──────────────────────────────────────────────────────
  String get updateRequired => _pick({
        AppLanguage.en: 'Update required',
        AppLanguage.fi: 'Päivitys vaaditaan',
        AppLanguage.sv: 'Uppdatering krävs',
      });
  String get updateRequiredBody => _pick({
        AppLanguage.en:
            'A new version of Botanica is available. Please update to continue.',
        AppLanguage.fi:
            'Uusi versio Botanicasta on saatavilla. Päivitä jatkaaksesi.',
        AppLanguage.sv:
            'En ny version av Botanica finns tillgänglig. Uppdatera för att fortsätta.',
      });
  String get updateNow => _pick({
        AppLanguage.en: 'Update now',
        AppLanguage.fi: 'Päivitä nyt',
        AppLanguage.sv: 'Uppdatera nu',
      });
  String get newFact => _pick({
        AppLanguage.en: 'New fact',
        AppLanguage.fi: 'Uusi fakta',
        AppLanguage.sv: 'Nytt faktum',
      });
  String get loadingFact => _pick({
        AppLanguage.en: 'Loading a fresh fact…',
        AppLanguage.fi: 'Ladataan uutta faktaa…',
        AppLanguage.sv: 'Laddar ett färskt faktum…',
      });
  String get todayLabel => _pick({
        AppLanguage.en: 'today',
        AppLanguage.fi: 'tänään',
        AppLanguage.sv: 'idag',
      });
  String get settings => _pick({
        AppLanguage.en: 'Settings',
        AppLanguage.fi: 'Asetukset',
        AppLanguage.sv: 'Inställningar',
      });
  String get account => _pick({
        AppLanguage.en: 'Account',
        AppLanguage.fi: 'Tili',
        AppLanguage.sv: 'Konto',
      });
  String get signOut => _pick({
        AppLanguage.en: 'Sign out',
        AppLanguage.fi: 'Kirjaudu ulos',
        AppLanguage.sv: 'Logga ut',
      });
  String get signOutConfirmTitle => _pick({
        AppLanguage.en: 'Sign out?',
        AppLanguage.fi: 'Kirjaudu ulos?',
        AppLanguage.sv: 'Logga ut?',
      });
  String get signOutConfirmBody => _pick({
        AppLanguage.en: 'You can sign back in anytime.',
        AppLanguage.fi: 'Voit kirjautua takaisin milloin tahansa.',
        AppLanguage.sv: 'Du kan logga in igen när som helst.',
      });
  String get cancel => _pick({
        AppLanguage.en: 'Cancel',
        AppLanguage.fi: 'Peruuta',
        AppLanguage.sv: 'Avbryt',
      });
  String get language => _pick({
        AppLanguage.en: 'Language',
        AppLanguage.fi: 'Kieli',
        AppLanguage.sv: 'Språk',
      });
  String get selectLanguage => _pick({
        AppLanguage.en: 'Select language',
        AppLanguage.fi: 'Valitse kieli',
        AppLanguage.sv: 'Välj språk',
      });
  String get upgradeToPremium => _pick({
        AppLanguage.en: 'Upgrade to Premium',
        AppLanguage.fi: 'Päivitä Premiumiin',
        AppLanguage.sv: 'Uppgradera till Premium',
      });
  String get premiumBenefits => _pick({
        AppLanguage.en: 'Unlimited chats · Seasonal hunts · Offline maps',
        AppLanguage.fi: 'Rajattomat keskustelut · Kausijahdit · Offline-kartat',
        AppLanguage.sv: 'Obegränsade chattar · Säsongsjakter · Offlinekartor',
      });

  // ── Chat ───────────────────────────────────────────────────────────────
  String get chatsTitle => _pick({
        AppLanguage.en: 'Chats',
        AppLanguage.fi: 'Keskustelut',
        AppLanguage.sv: 'Chattar',
      });
  String get noChatsYet => _pick({
        AppLanguage.en: 'No conversations yet',
        AppLanguage.fi: 'Ei keskusteluja vielä',
        AppLanguage.sv: 'Inga konversationer ännu',
      });
  String get noChatsYetBody => _pick({
        AppLanguage.en:
            'Identify a plant from the camera or search to start chatting. Your conversations stay here forever.',
        AppLanguage.fi:
            'Tunnista kasvi kameralla tai haulla aloittaaksesi keskustelun. Keskustelusi säilyvät täällä ikuisesti.',
        AppLanguage.sv:
            'Identifiera en växt med kameran eller sök för att börja chatta. Dina konversationer sparas här för alltid.',
      });
  String get askAboutThisPlant => _pick({
        AppLanguage.en: 'Ask about this plant…',
        AppLanguage.fi: 'Kysy tästä kasvista…',
        AppLanguage.sv: 'Fråga om denna växt…',
      });
  String get chatTabPlant => _pick({
        AppLanguage.en: 'Plant',
        AppLanguage.fi: 'Kasvi',
        AppLanguage.sv: 'Växt',
      });
  String get chatTabChat => _pick({
        AppLanguage.en: 'Chat',
        AppLanguage.fi: 'Keskustelu',
        AppLanguage.sv: 'Chatt',
      });

  // ── Plant hunt / generic ──────────────────────────────────────────────
  String get messages => _pick({
        AppLanguage.en: 'messages',
        AppLanguage.fi: 'viestiä',
        AppLanguage.sv: 'meddelanden',
      });
  String get message => _pick({
        AppLanguage.en: 'message',
        AppLanguage.fi: 'viesti',
        AppLanguage.sv: 'meddelande',
      });
  String get chatLimitReached => _pick({
        AppLanguage.en:
            "You've reached today's free chat limit (10 conversations/day). 🌿\n\nUpgrade to **Premium** for unlimited chats, or come back tomorrow!",
        AppLanguage.fi:
            'Olet saavuttanut päivittäisen ilmaiskeskustelurajan (10 keskustelua/päivä). 🌿\n\nPäivitä **Premiumiin** rajattomia keskusteluja varten tai palaa huomenna!',
        AppLanguage.sv:
            'Du har nått dagens gratis chattgräns (10 konversationer/dag). 🌿\n\nUppgradera till **Premium** för obegränsade chattar, eller kom tillbaka imorgon!',
      });

  // ── Search screen ─────────────────────────────────────────────────────
  String get searchPlants => _pick({
        AppLanguage.en: 'Search Plants',
        AppLanguage.fi: 'Etsi kasveja',
        AppLanguage.sv: 'Sök växter',
      });
  String get notABotanicalSearch => _pick({
        AppLanguage.en:
            'Hmm, that doesn\'t look like a plant. Try searching for a tree, flower, or any plant. 🌿',
        AppLanguage.fi:
            'Hmm, tämä ei näytä kasvilta. Kokeile hakea puuta, kukkaa tai mitä tahansa kasvia. 🌿',
        AppLanguage.sv:
            'Hmm, det ser inte ut som en växt. Sök efter ett träd, en blomma eller någon växt. 🌿',
      });
  String get identifyTagline => _pick({
        AppLanguage.en: 'Point. Snap. Discover.',
        AppLanguage.fi: 'Suuntaa. Kuvaa. Löydä.',
        AppLanguage.sv: 'Sikta. Knäpp. Upptäck.',
      });
  String get searchHint => _pick({
        AppLanguage.en: 'Scientific or common name...',
        AppLanguage.fi: 'Tieteellinen tai yleinen nimi...',
        AppLanguage.sv: 'Vetenskapligt eller vanligt namn...',
      });
  String get quickSearches => _pick({
        AppLanguage.en: 'Quick searches',
        AppLanguage.fi: 'Pikahaut',
        AppLanguage.sv: 'Snabbsökningar',
      });
  String get searchFailed => _pick({
        AppLanguage.en: 'Search failed',
        AppLanguage.fi: 'Haku epäonnistui',
        AppLanguage.sv: 'Sökningen misslyckades',
      });
  String get poweredByAI => _pick({
        AppLanguage.en: 'Powered by AI',
        AppLanguage.fi: 'Tekoälyn voimalla',
        AppLanguage.sv: 'Drivs av AI',
      });

  // ── Plant Result screen ──────────────────────────────────────────────
  String get tabPlant => _pick({
        AppLanguage.en: 'Plant',
        AppLanguage.fi: 'Kasvi',
        AppLanguage.sv: 'Växt',
      });
  String get tabChat => _pick({
        AppLanguage.en: 'Chat',
        AppLanguage.fi: 'Keskustelu',
        AppLanguage.sv: 'Chatt',
      });
  String get scientificNameLabel => _pick({
        AppLanguage.en: 'Scientific Name',
        AppLanguage.fi: 'Tieteellinen nimi',
        AppLanguage.sv: 'Vetenskapligt namn',
      });
  String get familyLabel => _pick({
        AppLanguage.en: 'Family',
        AppLanguage.fi: 'Heimo',
        AppLanguage.sv: 'Familj',
      });
  String get commonNameLabel => _pick({
        AppLanguage.en: 'Common Name',
        AppLanguage.fi: 'Yleinen nimi',
        AppLanguage.sv: 'Vanligt namn',
      });
  String get finnishNameLabel => _pick({
        AppLanguage.en: 'Finnish Name',
        AppLanguage.fi: 'Suomenkielinen nimi',
        AppLanguage.sv: 'Finskt namn',
      });
  String get originRegionLabel => _pick({
        AppLanguage.en: 'Origin Region',
        AppLanguage.fi: 'Alkuperäalue',
        AppLanguage.sv: 'Ursprungsregion',
      });
  String get findItInLabel => _pick({
        AppLanguage.en: 'Find it in',
        AppLanguage.fi: 'Löydät täältä',
        AppLanguage.sv: 'Hitta den i',
      });
  String get descriptionUpper => _pick({
        AppLanguage.en: 'DESCRIPTION',
        AppLanguage.fi: 'KUVAUS',
        AppLanguage.sv: 'BESKRIVNING',
      });
  String get funFactUpper => _pick({
        AppLanguage.en: 'FUN FACT',
        AppLanguage.fi: 'HAUSKA FAKTA',
        AppLanguage.sv: 'KUL FAKTA',
      });
  String get noPlantDetected => _pick({
        AppLanguage.en: '⚠️ No plant detected',
        AppLanguage.fi: '⚠️ Kasvia ei tunnistettu',
        AppLanguage.sv: '⚠️ Ingen växt upptäcktes',
      });
  String get descriptionLabel => _pick({
        AppLanguage.en: 'Description',
        AppLanguage.fi: 'Kuvaus',
        AppLanguage.sv: 'Beskrivning',
      });
  String get typeYourQuestion => _pick({
        AppLanguage.en: 'Type your question…',
        AppLanguage.fi: 'Kirjoita kysymyksesi…',
        AppLanguage.sv: 'Skriv din fråga…',
      });
  String get askAnythingAboutPlant => _pick({
        AppLanguage.en: 'Ask anything about\nthis plant!',
        AppLanguage.fi: 'Kysy mitä tahansa\ntästä kasvista!',
        AppLanguage.sv: 'Fråga vad som helst om\ndenna växt!',
      });
  String get askAboutThisPlantHint => _pick({
        AppLanguage.en: 'Ask about this plant...',
        AppLanguage.fi: 'Kysy tästä kasvista...',
        AppLanguage.sv: 'Fråga om denna växt...',
      });
  String get thinking => _pick({
        AppLanguage.en: 'Thinking...',
        AppLanguage.fi: 'Mietin...',
        AppLanguage.sv: 'Tänker...',
      });

  // ── Garden schedule ───────────────────────────────────────────────────
  String get statusClosed => _pick({
        AppLanguage.en: 'Closed',
        AppLanguage.fi: 'Suljettu',
        AppLanguage.sv: 'Stängt',
      });
  String get opensAt => _pick({
        AppLanguage.en: 'Opens at',
        AppLanguage.fi: 'Avautuu',
        AppLanguage.sv: 'Öppnar',
      });
  String get closesAt => _pick({
        AppLanguage.en: 'Closes at',
        AppLanguage.fi: 'Sulkeutuu',
        AppLanguage.sv: 'Stänger',
      });

  // ── Developed by ──────────────────────────────────────────────────────
  String get developedBy => _pick({
        AppLanguage.en: 'Developed by',
        AppLanguage.fi: 'Kehittäjä',
        AppLanguage.sv: 'Utvecklat av',
      });

  // ── Drawer ────────────────────────────────────────────────────────────
  String get menu => _pick({
        AppLanguage.en: 'Menu',
        AppLanguage.fi: 'Valikko',
        AppLanguage.sv: 'Meny',
      });
  String get adminPanel => _pick({
        AppLanguage.en: 'Admin Panel',
        AppLanguage.fi: 'Hallintapaneeli',
        AppLanguage.sv: 'Administratörspanel',
      });
  String get organizeEvent => _pick({
        AppLanguage.en: 'Organize Event',
        AppLanguage.fi: 'Järjestä tapahtuma',
        AppLanguage.sv: 'Anordna evenemang',
      });

  // ── Event form ────────────────────────────────────────────────────────
  String get eventPlanner => _pick({
        AppLanguage.en: 'Event Planner',
        AppLanguage.fi: 'Tapahtuman suunnittelija',
        AppLanguage.sv: 'Evenemangsplanerare',
      });
  String get eventPlannerSubtitle => _pick({
        AppLanguage.en: 'Submit your event proposal for review.',
        AppLanguage.fi: 'Lähetä tapahtumaehdotuksesi tarkistettavaksi.',
        AppLanguage.sv: 'Skicka in ditt evenemangsförslag för granskning.',
      });
  String get eventName => _pick({
        AppLanguage.en: 'Event name',
        AppLanguage.fi: 'Tapahtuman nimi',
        AppLanguage.sv: 'Evenemangsnamn',
      });
  String get eventDescription => _pick({
        AppLanguage.en: 'Description',
        AppLanguage.fi: 'Kuvaus',
        AppLanguage.sv: 'Beskrivning',
      });
  String get eventAttendees => _pick({
        AppLanguage.en: 'Expected attendees',
        AppLanguage.fi: 'Odotetut osallistujat',
        AppLanguage.sv: 'Förväntade deltagare',
      });
  String get eventDate => _pick({
        AppLanguage.en: 'Date',
        AppLanguage.fi: 'Päivämäärä',
        AppLanguage.sv: 'Datum',
      });
  String get eventTime => _pick({
        AppLanguage.en: 'Time',
        AppLanguage.fi: 'Aika',
        AppLanguage.sv: 'Tid',
      });
  String get eventStartTime => _pick({
        AppLanguage.en: 'Start time',
        AppLanguage.fi: 'Alkamisaika',
        AppLanguage.sv: 'Starttid',
      });
  String get eventEndTime => _pick({
        AppLanguage.en: 'End time',
        AppLanguage.fi: 'Päättymisaika',
        AppLanguage.sv: 'Sluttid',
      });
  String get eventSpace => _pick({
        AppLanguage.en: 'Space requirements',
        AppLanguage.fi: 'Tilatarpeet',
        AppLanguage.sv: 'Utrymmeskrav',
      });
  String get submitForApproval => _pick({
        AppLanguage.en: 'Submit for approval',
        AppLanguage.fi: 'Lähetä hyväksyttäväksi',
        AppLanguage.sv: 'Skicka för godkännande',
      });
  String get eventSubmitted => _pick({
        AppLanguage.en: 'Event submitted! 🎉 Garden staff will review and contact you.',
        AppLanguage.fi: 'Tapahtuma lähetetty! 🎉 Puutarhan henkilökunta käsittelee ja ottaa yhteyttä.',
        AppLanguage.sv: 'Evenemang inskickat! 🎉 Trädgårdspersonalen granskar och kontaktar dig.',
      });
  String get required => _pick({
        AppLanguage.en: 'Required',
        AppLanguage.fi: 'Pakollinen',
        AppLanguage.sv: 'Krävs',
      });

  // ── Admin panel ───────────────────────────────────────────────────────
  String get totalUsers => _pick({
        AppLanguage.en: 'Total users',
        AppLanguage.fi: 'Käyttäjiä yhteensä',
        AppLanguage.sv: 'Totalt antal användare',
      });
  String get premiumUsers => _pick({
        AppLanguage.en: 'Premium users',
        AppLanguage.fi: 'Premium-käyttäjät',
        AppLanguage.sv: 'Premiumanvändare',
      });
  String get activeToday => _pick({
        AppLanguage.en: 'Active today',
        AppLanguage.fi: 'Aktiiviset tänään',
        AppLanguage.sv: 'Aktiva idag',
      });
  String get totalChats => _pick({
        AppLanguage.en: 'Total chats today',
        AppLanguage.fi: 'Keskusteluja tänään',
        AppLanguage.sv: 'Totala chattar idag',
      });
  String get pendingEvents => _pick({
        AppLanguage.en: 'Pending event requests',
        AppLanguage.fi: 'Odottavat tapahtumapyynnöt',
        AppLanguage.sv: 'Väntande evenemangsförfrågningar',
      });
  String get approve => _pick({
        AppLanguage.en: 'Approve',
        AppLanguage.fi: 'Hyväksy',
        AppLanguage.sv: 'Godkänn',
      });
  String get reject => _pick({
        AppLanguage.en: 'Reject',
        AppLanguage.fi: 'Hylkää',
        AppLanguage.sv: 'Avvisa',
      });
  String get statsOverview => _pick({
        AppLanguage.en: 'Stats Overview',
        AppLanguage.fi: 'Tilastot',
        AppLanguage.sv: 'Statistiköversikt',
      });
  String get noUsersYet => _pick({
        AppLanguage.en: 'No users yet',
        AppLanguage.fi: 'Ei käyttäjiä vielä',
        AppLanguage.sv: 'Inga användare ännu',
      });
  String get noPendingEvents => _pick({
        AppLanguage.en: 'No pending events',
        AppLanguage.fi: 'Ei odottavia tapahtumia',
        AppLanguage.sv: 'Inga väntande evenemang',
      });
  String get visitorReports => _pick({
        AppLanguage.en: 'Visitor reports',
        AppLanguage.fi: 'Käyttäjien ilmoitukset',
        AppLanguage.sv: 'Besökarrapporter',
      });
  String get noReports => _pick({
        AppLanguage.en: 'No reports yet',
        AppLanguage.fi: 'Ei ilmoituksia vielä',
        AppLanguage.sv: 'Inga rapporter ännu',
      });

  // ── About Us ──────────────────────────────────────────────────────────
  String get aboutUs => _pick({
        AppLanguage.en: 'About Us',
        AppLanguage.fi: 'Tietoa meistä',
        AppLanguage.sv: 'Om oss',
      });
  String get aboutGarden => _pick({
        AppLanguage.en: 'About the Garden',
        AppLanguage.fi: 'Tietoa puutarhasta',
        AppLanguage.sv: 'Om trädgården',
      });
  String get openingHours => _pick({
        AppLanguage.en: 'Opening hours',
        AppLanguage.fi: 'Aukioloajat',
        AppLanguage.sv: 'Öppettider',
      });
  String get greenhouses => _pick({
        AppLanguage.en: 'Greenhouses',
        AppLanguage.fi: 'Kasvihuoneet',
        AppLanguage.sv: 'Växthus',
      });
  String get outdoorGarden => _pick({
        AppLanguage.en: 'Outdoor garden',
        AppLanguage.fi: 'Ulkopuutarha',
        AppLanguage.sv: 'Utomhusträdgård',
      });
  String get holidayHours => _pick({
        AppLanguage.en: 'Holiday hours 2026',
        AppLanguage.fi: 'Pyhäpäivien aukioloajat 2026',
        AppLanguage.sv: 'Helgöppettider 2026',
      });
  String get admissionFee => _pick({
        AppLanguage.en: 'Admission fee',
        AppLanguage.fi: 'Pääsymaksu',
        AppLanguage.sv: 'Inträdesavgift',
      });
  String get directionsAndParking => _pick({
        AppLanguage.en: 'Directions & parking',
        AppLanguage.fi: 'Ajo-ohjeet ja pysäköinti',
        AppLanguage.sv: 'Vägbeskrivning & parkering',
      });
  String get photography => _pick({
        AppLanguage.en: 'Photography',
        AppLanguage.fi: 'Valokuvaus',
        AppLanguage.sv: 'Fotografering',
      });
  String get contact => _pick({
        AppLanguage.en: 'Contact',
        AppLanguage.fi: 'Yhteystiedot',
        AppLanguage.sv: 'Kontakt',
      });
  String get openInMaps => _pick({
        AppLanguage.en: 'Open in Maps',
        AppLanguage.fi: 'Avaa kartassa',
        AppLanguage.sv: 'Öppna i karta',
      });
  String get freeEntrance => _pick({
        AppLanguage.en: 'Free entrance · Voluntary admission 5 €',
        AppLanguage.fi: 'Vapaa pääsy · Vapaaehtoinen pääsymaksu 5 €',
        AppLanguage.sv: 'Fritt inträde · Frivillig inträdesavgift 5 €',
      });

  // ── Paywall ───────────────────────────────────────────────────────────
  String get planMonthly => _pick({AppLanguage.en: 'Monthly', AppLanguage.fi: 'Kuukausi', AppLanguage.sv: 'Månad'});
  String get planYearly => _pick({AppLanguage.en: 'Yearly', AppLanguage.fi: 'Vuosi', AppLanguage.sv: 'År'});
  String get planLifetime => _pick({AppLanguage.en: 'Lifetime', AppLanguage.fi: 'Elinikäinen', AppLanguage.sv: 'Livstid'});
  String get perMonthLbl => _pick({AppLanguage.en: 'per month', AppLanguage.fi: 'per kuukausi', AppLanguage.sv: 'per månad'});
  String get perYearLbl => _pick({AppLanguage.en: 'per year', AppLanguage.fi: 'per vuosi', AppLanguage.sv: 'per år'});
  String get oneTimeLbl => _pick({AppLanguage.en: 'one-time', AppLanguage.fi: 'kertamaksu', AppLanguage.sv: 'engångs'});
  String get save44 => _pick({AppLanguage.en: 'Save 44%', AppLanguage.fi: 'Säästä 44 %', AppLanguage.sv: 'Spara 44 %'});
  String get bestValueBadge => _pick({AppLanguage.en: 'Best value', AppLanguage.fi: 'Paras hinta', AppLanguage.sv: 'Bäst värde'});
  String get benefitUnlimitedChatsTitle => _pick({AppLanguage.en: 'Unlimited AI chats', AppLanguage.fi: 'Rajattomat tekoälykeskustelut', AppLanguage.sv: 'Obegränsade AI-chattar'});
  String get benefitUnlimitedChatsBody => _pick({AppLanguage.en: 'Ask anything about any plant, anytime', AppLanguage.fi: 'Kysy mistä tahansa kasvista milloin tahansa', AppLanguage.sv: 'Fråga vad som helst om vilken växt som helst, när som helst'});
  String get benefitSeasonalHuntsTitle => _pick({AppLanguage.en: 'Seasonal Plant Hunts', AppLanguage.fi: 'Kausittaiset kasvijahdit', AppLanguage.sv: 'Säsongsbetonade växtjakter'});
  String get benefitSeasonalHuntsBody => _pick({AppLanguage.en: 'New challenges every season', AppLanguage.fi: 'Uusia haasteita joka kaudella', AppLanguage.sv: 'Nya utmaningar varje säsong'});
  String get benefitOfflineMapsTitle => _pick({AppLanguage.en: 'Offline maps & trails', AppLanguage.fi: 'Offline-kartat ja polut', AppLanguage.sv: 'Offline-kartor & stigar'});
  String get benefitOfflineMapsBody => _pick({AppLanguage.en: 'Use the app without internet', AppLanguage.fi: 'Käytä sovellusta ilman nettiä', AppLanguage.sv: 'Använd appen utan internet'});
  String get benefitUnlimitedHistoryTitle => _pick({AppLanguage.en: 'Unlimited history', AppLanguage.fi: 'Rajaton historia', AppLanguage.sv: 'Obegränsad historik'});
  String get benefitUnlimitedHistoryBody => _pick({AppLanguage.en: 'Keep every plant ID and chat forever', AppLanguage.fi: 'Säilytä kaikki tunnistukset ja chatit ikuisesti', AppLanguage.sv: 'Behåll varje växtidentifiering och chatt för alltid'});
  String get benefitMemberBadgeTitle => _pick({AppLanguage.en: 'Garden member badge', AppLanguage.fi: 'Puutarhan jäsenmerkki', AppLanguage.sv: 'Trädgårdsmedlemsmärke'});
  String get benefitMemberBadgeBody => _pick({AppLanguage.en: 'Special perks at the gift shop', AppLanguage.fi: 'Erikoisetuja lahjakaupassa', AppLanguage.sv: 'Specialförmåner i presentbutiken'});
  String startPlan(String plan) => _pick({AppLanguage.en: 'Start $plan', AppLanguage.fi: 'Aloita $plan', AppLanguage.sv: 'Starta $plan'});
  String get cancelAnytime => _pick({AppLanguage.en: 'Cancel anytime. Restoring previous purchases is supported.', AppLanguage.fi: 'Peru milloin tahansa. Aiempien ostosten palauttaminen tuettu.', AppLanguage.sv: 'Avbryt när som helst. Återställning av tidigare köp stöds.'});
  String get welcomePremium => _pick({AppLanguage.en: '🎉 Welcome to Premium!', AppLanguage.fi: '🎉 Tervetuloa Premiumiin!', AppLanguage.sv: '🎉 Välkommen till Premium!'});

  // ── AI model screen ───────────────────────────────────────────────────
  String get engineCloudTitle => _pick({AppLanguage.en: 'Cloud LLM', AppLanguage.fi: 'Pilvi-LLM', AppLanguage.sv: 'Moln-LLM'});
  String get engineCloudActive => _pick({AppLanguage.en: 'Groq · Fast · Free tier', AppLanguage.fi: 'Groq · Nopea · Ilmainen taso', AppLanguage.sv: 'Groq · Snabb · Gratisnivå'});
  String get engineCloudOff => _pick({AppLanguage.en: 'Not configured — add API key in api_config.dart', AppLanguage.fi: 'Ei määritetty — lisää API-avain tiedostoon api_config.dart', AppLanguage.sv: 'Inte konfigurerad — lägg till API-nyckel i api_config.dart'});
  String get statusActive => _pick({AppLanguage.en: 'Active', AppLanguage.fi: 'Käytössä', AppLanguage.sv: 'Aktiv'});
  String get statusOff => _pick({AppLanguage.en: 'Off', AppLanguage.fi: 'Pois', AppLanguage.sv: 'Av'});
  String get statusInstalled => _pick({AppLanguage.en: 'Installed', AppLanguage.fi: 'Asennettu', AppLanguage.sv: 'Installerad'});
  String get statusNotInstalled => _pick({AppLanguage.en: 'Not installed', AppLanguage.fi: 'Ei asennettu', AppLanguage.sv: 'Inte installerad'});
  String get statusAvailable => _pick({AppLanguage.en: 'Available', AppLanguage.fi: 'Saatavilla', AppLanguage.sv: 'Tillgänglig'});
  String get engineGemmaTitle => _pick({AppLanguage.en: 'On-device Gemma (fallback)', AppLanguage.fi: 'Laitteella oleva Gemma (varalla)', AppLanguage.sv: 'Gemma på enheten (reserv)'});
  String get engineGemmaInstalled => _pick({AppLanguage.en: 'Installed · Works offline', AppLanguage.fi: 'Asennettu · Toimii ilman nettiä', AppLanguage.sv: 'Installerad · Fungerar offline'});
  String get engineGemmaNotInstalled => _pick({AppLanguage.en: 'Optional 530MB download', AppLanguage.fi: 'Valinnainen 530 Mt lataus', AppLanguage.sv: 'Valfri 530 MB nedladdning'});
  String get engineGeminiTitle => _pick({AppLanguage.en: 'Gemini (last resort)', AppLanguage.fi: 'Gemini (viimeinen vaihtoehto)', AppLanguage.sv: 'Gemini (sista utvägen)'});
  String get engineGeminiBody => _pick({AppLanguage.en: 'Always available · €0.0002/message', AppLanguage.fi: 'Aina saatavilla · 0,0002 €/viesti', AppLanguage.sv: 'Alltid tillgänglig · 0,0002 €/meddelande'});
  String get offlineFallbackHeader => _pick({AppLanguage.en: 'OFFLINE FALLBACK', AppLanguage.fi: 'OFFLINE-VARAJÄRJESTELMÄ', AppLanguage.sv: 'OFFLINE-RESERV'});
  String get offlineFallbackBody => _pick({AppLanguage.en: 'Want chat to work even without internet? Download a small on-device model as backup.', AppLanguage.fi: 'Haluatko, että chat toimii myös ilman nettiä? Lataa pieni laitteella toimiva malli varmuudeksi.', AppLanguage.sv: 'Vill du att chatten fungerar utan internet? Ladda ner en liten lokal modell som reserv.'});
  String get downloadOfflineModel => _pick({AppLanguage.en: 'Download 530MB offline model', AppLanguage.fi: 'Lataa 530 Mt offline-malli', AppLanguage.sv: 'Ladda ner 530 MB offline-modell'});
  String get downloading => _pick({AppLanguage.en: 'Downloading…', AppLanguage.fi: 'Ladataan…', AppLanguage.sv: 'Laddar ner…'});
  String get offlineReady => _pick({AppLanguage.en: '✅ On-device fallback ready!', AppLanguage.fi: '✅ Laitteella oleva varalla valmiina!', AppLanguage.sv: '✅ Reserv på enheten redo!'});
  String get aiModelFooter => _pick({AppLanguage.en: 'ℹ️ The cloud LLM handles all chats by default — no download needed. The on-device model is only used if cloud fails (no internet).', AppLanguage.fi: 'ℹ️ Pilvi-LLM käsittelee oletuksena kaikki chatit — latausta ei tarvita. Laitteella olevaa mallia käytetään vain, jos pilvi ei toimi (ei nettiä).', AppLanguage.sv: 'ℹ️ Moln-LLM hanterar alla chattar som standard — ingen nedladdning behövs. Den lokala modellen används bara om molnet inte fungerar (ingen internet).'});

  // ── Events screen ─────────────────────────────────────────────────────
  String get upcomingEventsTitle => _pick({AppLanguage.en: 'Upcoming Events', AppLanguage.fi: 'Tulevat tapahtumat', AppLanguage.sv: 'Kommande evenemang'});
  String get noEventsYet => _pick({AppLanguage.en: 'No upcoming events', AppLanguage.fi: 'Ei tulevia tapahtumia', AppLanguage.sv: 'Inga kommande evenemang'});
  String get noEventsBody => _pick({AppLanguage.en: 'Check back soon — new events are announced regularly.', AppLanguage.fi: 'Kurkkaa pian uudelleen — uusia tapahtumia ilmoitetaan säännöllisesti.', AppLanguage.sv: 'Kom tillbaka snart — nya evenemang tillkännages regelbundet.'});
  String get rsvp => _pick({AppLanguage.en: 'RSVP', AppLanguage.fi: 'Ilmoittaudu', AppLanguage.sv: 'Anmäl dig'});
  String get rsvped => _pick({AppLanguage.en: 'You\'re going!', AppLanguage.fi: 'Olet menossa!', AppLanguage.sv: 'Du är med!'});
  String get cancelRsvp => _pick({AppLanguage.en: 'Cancel RSVP', AppLanguage.fi: 'Peru ilmoittautuminen', AppLanguage.sv: 'Avbryt anmälan'});
  String get privateEventLabel => _pick({AppLanguage.en: 'Private', AppLanguage.fi: 'Yksityinen', AppLanguage.sv: 'Privat'});
  String get publicEventLabel => _pick({AppLanguage.en: 'Open to all', AppLanguage.fi: 'Avoin kaikille', AppLanguage.sv: 'Öppet för alla'});
  String get eventStarts => _pick({AppLanguage.en: 'Starts', AppLanguage.fi: 'Alkaa', AppLanguage.sv: 'Börjar'});
  String get eventLocation => _pick({AppLanguage.en: 'Location', AppLanguage.fi: 'Sijainti', AppLanguage.sv: 'Plats'});
  String attendingCount(int n) => _pick({AppLanguage.en: '$n attending', AppLanguage.fi: '$n osallistuu', AppLanguage.sv: '$n deltar'});

  // ── Soundscape ────────────────────────────────────────────────────────
  String get tapToRecord => _pick({AppLanguage.en: 'Tap to start recording', AppLanguage.fi: 'Napauta aloittaaksesi nauhoituksen', AppLanguage.sv: 'Tryck för att börja spela in'});
  String get recording => _pick({AppLanguage.en: 'Recording…', AppLanguage.fi: 'Nauhoitetaan…', AppLanguage.sv: 'Spelar in…'});
  String get tapToStop => _pick({AppLanguage.en: 'Tap to stop', AppLanguage.fi: 'Napauta lopettaaksesi', AppLanguage.sv: 'Tryck för att stoppa'});
  String get analyzingAudio => _pick({AppLanguage.en: 'Analyzing audio…', AppLanguage.fi: 'Analysoidaan ääntä…', AppLanguage.sv: 'Analyserar ljud…'});
  String get yourSoundscape => _pick({AppLanguage.en: 'Your soundscape', AppLanguage.fi: 'Sinun äänimaisemasi', AppLanguage.sv: 'Ditt ljudlandskap'});
  String get recordAgain => _pick({AppLanguage.en: 'Record again', AppLanguage.fi: 'Nauhoita uudelleen', AppLanguage.sv: 'Spela in igen'});
  String get micPermissionNeeded => _pick({AppLanguage.en: 'Microphone permission required', AppLanguage.fi: 'Mikrofonin käyttöoikeus tarvitaan', AppLanguage.sv: 'Mikrofontillstånd krävs'});

  // ── Map ───────────────────────────────────────────────────────────────
  String get filterAll => _pick({AppLanguage.en: 'All', AppLanguage.fi: 'Kaikki', AppLanguage.sv: 'Alla'});
  String get filterBlooming => _pick({AppLanguage.en: 'Blooming', AppLanguage.fi: 'Kukassa', AppLanguage.sv: 'Blommar'});
  String get filterMedicinal => _pick({AppLanguage.en: 'Medicinal', AppLanguage.fi: 'Lääke', AppLanguage.sv: 'Medicinal'});
  String get filterTrees => _pick({AppLanguage.en: 'Trees', AppLanguage.fi: 'Puut', AppLanguage.sv: 'Träd'});
  String get noPlantsFound => _pick({AppLanguage.en: 'No plants match your search', AppLanguage.fi: 'Hakuasi vastaavia kasveja ei löytynyt', AppLanguage.sv: 'Inga växter matchar din sökning'});
  String get yourLocation => _pick({AppLanguage.en: 'Your location', AppLanguage.fi: 'Sijaintisi', AppLanguage.sv: 'Din plats'});

  // ── Report form ───────────────────────────────────────────────────────
  String get reportDescriptionLabel => _pick({AppLanguage.en: 'Description', AppLanguage.fi: 'Kuvaus', AppLanguage.sv: 'Beskrivning'});
  String get reportDescriptionHint => _pick({AppLanguage.en: 'What did you notice? (optional)', AppLanguage.fi: 'Mitä huomasit? (valinnainen)', AppLanguage.sv: 'Vad la du märke till? (valfritt)'});
  String get reportLocationLabel => _pick({AppLanguage.en: 'Location', AppLanguage.fi: 'Sijainti', AppLanguage.sv: 'Plats'});
  String get reportLocationHint => _pick({AppLanguage.en: 'Where in the garden? (e.g. near the pond)', AppLanguage.fi: 'Missä puutarhassa? (esim. lammikon lähellä)', AppLanguage.sv: 'Var i trädgården? (t.ex. nära dammen)'});
  String get reportTakePhoto => _pick({AppLanguage.en: 'Take photo', AppLanguage.fi: 'Ota kuva', AppLanguage.sv: 'Ta foto'});
  String get reportRetakePhoto => _pick({AppLanguage.en: 'Retake photo', AppLanguage.fi: 'Ota kuva uudelleen', AppLanguage.sv: 'Ta nytt foto'});

  // ── Home extras ───────────────────────────────────────────────────────
  String get didYouKnowHeader => _pick({AppLanguage.en: 'Did you know?', AppLanguage.fi: 'Tiesitkö?', AppLanguage.sv: 'Visste du?'});

  // ── Profile / Settings ────────────────────────────────────────────────
  String get profileTitle => _pick({AppLanguage.en: 'Profile', AppLanguage.fi: 'Profiili', AppLanguage.sv: 'Profil'});
  String get settingsTitle => _pick({AppLanguage.en: 'Settings', AppLanguage.fi: 'Asetukset', AppLanguage.sv: 'Inställningar'});
  String get preferences => _pick({AppLanguage.en: 'Preferences', AppLanguage.fi: 'Asetukset', AppLanguage.sv: 'Inställningar'});
  String get notifications => _pick({AppLanguage.en: 'Notifications', AppLanguage.fi: 'Ilmoitukset', AppLanguage.sv: 'Notiser'});
  String get languageLabel => _pick({AppLanguage.en: 'Language', AppLanguage.fi: 'Kieli', AppLanguage.sv: 'Språk'});
  String get manageSubscription => _pick({AppLanguage.en: 'Manage subscription', AppLanguage.fi: 'Hallinnoi tilausta', AppLanguage.sv: 'Hantera prenumeration'});
  String get freeMember => _pick({AppLanguage.en: 'Free member', AppLanguage.fi: 'Ilmaisjäsen', AppLanguage.sv: 'Gratismedlem'});
  String get premiumMember => _pick({AppLanguage.en: 'Premium member', AppLanguage.fi: 'Premium-jäsen', AppLanguage.sv: 'Premiummedlem'});
  String get historyTitle => _pick({AppLanguage.en: 'History', AppLanguage.fi: 'Historia', AppLanguage.sv: 'Historik'});

  // ── Chat ──────────────────────────────────────────────────────────────
  String get askAnythingPlaceholder => _pick({AppLanguage.en: 'Ask anything…', AppLanguage.fi: 'Kysy mitä tahansa…', AppLanguage.sv: 'Fråga vad som helst…'});
  String get chatWelcome => _pick({AppLanguage.en: 'Hi! I\'m your plant guide. Ask me about any plant in the garden.', AppLanguage.fi: 'Hei! Olen kasviopastasi. Kysy mistä tahansa puutarhan kasvista.', AppLanguage.sv: 'Hej! Jag är din växtguide. Fråga mig om vilken växt som helst i trädgården.'});
  String get chatThinking => _pick({AppLanguage.en: 'Thinking…', AppLanguage.fi: 'Mietitään…', AppLanguage.sv: 'Tänker…'});
  String get chatError => _pick({AppLanguage.en: 'Sorry, something went wrong. Try again?', AppLanguage.fi: 'Pahoittelut, jotain meni pieleen. Yritä uudelleen?', AppLanguage.sv: 'Tyvärr gick något fel. Försök igen?'});
  String get newChat => _pick({AppLanguage.en: 'New chat', AppLanguage.fi: 'Uusi chat', AppLanguage.sv: 'Ny chatt'});

  // ── Admin ─────────────────────────────────────────────────────────────
  String get addEvent => _pick({AppLanguage.en: 'Add event', AppLanguage.fi: 'Lisää tapahtuma', AppLanguage.sv: 'Lägg till evenemang'});

  // ── Soundscape visualizer ─────────────────────────────────────────────
  String get findQuietSpot => _pick({AppLanguage.en: 'Find a quiet spot, hold still, and let the garden speak.', AppLanguage.fi: 'Etsi rauhallinen paikka, pysy paikallaan ja anna puutarhan puhua.', AppLanguage.sv: 'Hitta en lugn plats, stå still och låt trädgården tala.'});
  String get startingMic => _pick({AppLanguage.en: 'Starting microphone…', AppLanguage.fi: 'Käynnistetään mikrofonia…', AppLanguage.sv: 'Startar mikrofon…'});
  String get dbSilence => _pick({AppLanguage.en: 'Silence', AppLanguage.fi: 'Hiljaisuus', AppLanguage.sv: 'Tystnad'});
  String get dbVeryQuiet => _pick({AppLanguage.en: 'Very quiet', AppLanguage.fi: 'Erittäin hiljainen', AppLanguage.sv: 'Mycket tyst'});
  String get dbQuiet => _pick({AppLanguage.en: 'Quiet', AppLanguage.fi: 'Hiljainen', AppLanguage.sv: 'Tyst'});
  String get dbModerate => _pick({AppLanguage.en: 'Moderate', AppLanguage.fi: 'Kohtalainen', AppLanguage.sv: 'Måttlig'});
  String get dbLoud => _pick({AppLanguage.en: 'Loud', AppLanguage.fi: 'Voimakas', AppLanguage.sv: 'Hög'});
  String get dbVeryLoud => _pick({AppLanguage.en: 'Very loud', AppLanguage.fi: 'Erittäin voimakas', AppLanguage.sv: 'Mycket hög'});
  String retrying(String err) => _pick({AppLanguage.en: 'Retrying… $err', AppLanguage.fi: 'Yritetään uudelleen… $err', AppLanguage.sv: 'Försöker igen… $err'});
  String get listeningToGarden => _pick({AppLanguage.en: '🌿  listening to the garden  🌿', AppLanguage.fi: '🌿  kuunnellaan puutarhaa  🌿', AppLanguage.sv: '🌿  lyssnar på trädgården  🌿'});
  String get micPermBodyPerm => _pick({AppLanguage.en: 'Microphone access was permanently denied.\n\nSettings → Apps → Botanica AR → Permissions → Microphone → Allow.', AppLanguage.fi: 'Mikrofonin käyttöoikeus evättiin pysyvästi.\n\nAsetukset → Sovellukset → Botanica AR → Käyttöoikeudet → Mikrofoni → Salli.', AppLanguage.sv: 'Mikrofonåtkomst nekades permanent.\n\nInställningar → Appar → Botanica AR → Behörigheter → Mikrofon → Tillåt.'});
  String get micPermBody => _pick({AppLanguage.en: 'Microphone permission is needed\nto visualise ambient sound.', AppLanguage.fi: 'Mikrofonin käyttöoikeus tarvitaan\nympäröivän äänen näyttämiseen.', AppLanguage.sv: 'Mikrofonbehörighet behövs\nför att visualisera omgivningsljud.'});
  String get openSettings => _pick({AppLanguage.en: 'Open Settings', AppLanguage.fi: 'Avaa asetukset', AppLanguage.sv: 'Öppna inställningar'});
  String get grantPermission => _pick({AppLanguage.en: 'Grant Permission', AppLanguage.fi: 'Myönnä lupa', AppLanguage.sv: 'Ge tillstånd'});
  String get noAudioArrived => _pick({AppLanguage.en: 'Microphone opened but no audio arrived.\n\nSettings → Apps → Botanica AR → Permissions\n→ set Microphone to "Allow"', AppLanguage.fi: 'Mikrofoni avattu, mutta ääntä ei saapunut.\n\nAsetukset → Sovellukset → Botanica AR → Käyttöoikeudet\n→ aseta Mikrofoni tilaan "Salli"', AppLanguage.sv: 'Mikrofonen öppnades men inget ljud kom in.\n\nInställningar → Appar → Botanica AR → Behörigheter\n→ ställ in Mikrofon till "Tillåt"'});
  String get tryAgainBtn => _pick({AppLanguage.en: 'Try Again', AppLanguage.fi: 'Yritä uudelleen', AppLanguage.sv: 'Försök igen'});
  String get settingsBtn => _pick({AppLanguage.en: 'Settings', AppLanguage.fi: 'Asetukset', AppLanguage.sv: 'Inställningar'});
  String get nowLabel => _pick({AppLanguage.en: 'Now', AppLanguage.fi: 'Nyt', AppLanguage.sv: 'Nu'});
  String get aiAnalysisLabel => _pick({AppLanguage.en: 'AI Analysis', AppLanguage.fi: 'Tekoälyanalyysi', AppLanguage.sv: 'AI-analys'});
  String get gettingLocation => _pick({AppLanguage.en: 'Getting location…', AppLanguage.fi: 'Haetaan sijaintia…', AppLanguage.sv: 'Hämtar plats…'});
  String get gpsLabel => _pick({AppLanguage.en: 'GPS', AppLanguage.fi: 'GPS', AppLanguage.sv: 'GPS'});
  String get addNoteHint => _pick({AppLanguage.en: 'Add your note (optional)…', AppLanguage.fi: 'Lisää muistiinpanosi (valinnainen)…', AppLanguage.sv: 'Lägg till din anteckning (valfritt)…'});
  String get notSignedIn => _pick({AppLanguage.en: 'Not signed in', AppLanguage.fi: 'Ei kirjautunut', AppLanguage.sv: 'Inte inloggad'});
  String get youAreOffline => _pick({AppLanguage.en: 'You are offline — some features may be unavailable', AppLanguage.fi: 'Olet offline-tilassa — jotkin toiminnot eivät ehkä toimi', AppLanguage.sv: 'Du är offline — vissa funktioner kan vara otillgängliga'});
  String get noBloomsToday => _pick({AppLanguage.en: 'No blooms tracked right now', AppLanguage.fi: 'Ei seurattuja kukintoja juuri nyt', AppLanguage.sv: 'Inga blommor spårade just nu'});
  String get noBloomsBody => _pick({AppLanguage.en: 'Check back soon — staff update bloom status weekly.', AppLanguage.fi: 'Kurkkaa pian uudelleen — henkilökunta päivittää kukinnan tilan viikoittain.', AppLanguage.sv: 'Kom tillbaka snart — personalen uppdaterar blomstatus varje vecka.'});
  String chatsLeftToday(int n) => _pick({AppLanguage.en: '$n chats left today', AppLanguage.fi: '$n chattia jäljellä tänään', AppLanguage.sv: '$n chattar kvar idag'});
  String get unlimitedChats => _pick({AppLanguage.en: 'Unlimited chats', AppLanguage.fi: 'Rajattomat chatit', AppLanguage.sv: 'Obegränsade chattar'});
  String get eventFull => _pick({AppLanguage.en: 'Event full', AppLanguage.fi: 'Tapahtuma täynnä', AppLanguage.sv: 'Evenemanget fullt'});
  String get joinWaitlist => _pick({AppLanguage.en: 'Join waitlist', AppLanguage.fi: 'Liity jonotuslistalle', AppLanguage.sv: 'Gå med i väntelistan'});
  String spotsLeft(int n) => _pick({AppLanguage.en: '$n spots left', AppLanguage.fi: '$n paikkaa jäljellä', AppLanguage.sv: '$n platser kvar'});
  String get rsvpCapacity => _pick({AppLanguage.en: 'RSVP capacity', AppLanguage.fi: 'Ilmoittautumisraja', AppLanguage.sv: 'Anmälningsgräns'});
  String get rsvpCapacityHint => _pick({AppLanguage.en: 'Leave 0 for unlimited', AppLanguage.fi: 'Jätä 0 = rajaton', AppLanguage.sv: 'Lämna 0 för obegränsat'});
  String get viewOnOuluFi => _pick({AppLanguage.en: 'View on oulu.fi', AppLanguage.fi: 'Avaa oulu.fi-sivulla', AppLanguage.sv: 'Visa på oulu.fi'});
}

/// Access the current strings for a BuildContext.
class S {
  static AppStrings of(AppLanguage lang) => AppStrings(lang);
}
