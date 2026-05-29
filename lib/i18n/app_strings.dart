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
  String get directions => _pick({
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
}

/// Access the current strings for a BuildContext.
class S {
  static AppStrings of(AppLanguage lang) => AppStrings(lang);
}
