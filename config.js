/* =========================================================
   MA BOUTIQUE — boutique
   Configuration centrale : catalogue, thèmes, réglages.
   Tout se règle ici, jamais dans le HTML.

   ---------------------------------------------------------
   VERSION NETTOYÉE
   Ce fichier ne contient AUCUN secret.
   Rappel : ce fichier est public (il est servi par GitHub
   Pages). Tout ce qu'on y écrit est lisible par n'importe
   qui. Un jeton, un mot de passe ou une clé d'API n'a donc
   rien à y faire.

   Les deux valeurs ci-dessous (SUPABASE_URL et SUPABASE_CLE)
   sont PUBLIQUES par nature : la clé « publishable » est faite
   pour vivre dans un site. Ce qui doit rester secret, c'est la
   clé « secret » / « service_role » du projet — elle ne doit
   jamais figurer ici.

   Pour recevoir les commandes : elles passent par les
   fonctions Supabase (voir README). Le jeton du bot Telegram
   reste dans les secrets Supabase, jamais ici.
   ---------------------------------------------------------
   ========================================================= */

/* Adresse du projet et clé publique. Ces deux lignes doivent
   rester AVANT var BOUTIQUE : le reste du site les utilise. */
 var URL_BASE = 'https://jrmcyurpaedspxileshx.supabase.co';
 var CLE_PUBLIQUE = 'sb_publishable_exN3GbYVHQ6QfHfRl7mGdQ_U4Gj_T9f';

var BOUTIQUE = {

  nom: "MA BOUTIQUE",

  /* Deposez votre logo sous le nom logo.png a la racine du depot.
     Tant qu'il est absent, le nom de la boutique s'affiche. */
  logo: "logo.png",
  slogan: "",   /* ce qui s'affiche sous le nom */
  baseline: "",   /* vos horaires, en une ligne */

  /* -------------------------------------------------------
     ZONE DE LIVRAISON
     La zone desservie par le commerce.
     Mettre toutes: false et departements: ["69"] pour
     restreindre a un departement.
     ------------------------------------------------------- */
  zone: {
    nom: "votre zone",
    departements: [],
    toutes: true
  },

  /* -------------------------------------------------------
     APPARENCE — thème par défaut
     ------------------------------------------------------- */
  theme: "nuit-acide",

  /* -------------------------------------------------------
     LIVRAISON — 5 étapes
     ------------------------------------------------------- */
  etapes: [
    { cle: "attente",   label: "Commande reçue",         emoji: "⏳", texte: "Nous avons bien reçu votre commande." },
    { cle: "preparee",  label: "En préparation",         emoji: "🚀", texte: "Votre commande est en cours de préparation." },
    { cle: "tournee",   label: "En tournée de livraison", emoji: "🛵", texte: "Votre commande a quitté la boutique." },
    { cle: "route",     label: "En route vers vous",     emoji: "🎯", texte: "Le livreur arrive dans quelques minutes." },
    { cle: "livree",    label: "Livrée",                 emoji: "✅", texte: "Commande livrée. Merci !" }
  ],

  /* -------------------------------------------------------
     CATALOGUE — 5 produits pour commencer
     ------------------------------------------------------- */
  produits: [
    {
      id: "p1",
      nom: "Produit exemple 1",
      rayon: "Vos rayons",
      emoji: "☕",
      format: "250 g",
      prix: 14.50,
      stock: "disponible",
      badge: "",
      description: "Grains lavés, notes florales et fruitées. Torréfaction claire, idéale en filtre.",
      medias: []
    },
    {
      id: "p2",
      medias: [],
      nom: "Produit exemple 2",
      rayon: "Vos rayons",
      emoji: "🫘",
      format: "1 kg",
      prix: 32.00,
      stock: "disponible",
      badge: "Nouveau",
      description: "Assemblage 70 % arabica, 30 % robusta. Corps franc, crema dense, parfait pour la machine du comptoir."
    },
    {
      id: "p3",
      medias: [],
      nom: "Produit exemple 3",
      rayon: "Thés",
      emoji: "🍵",
      format: "100 g",
      prix: 18.00,
      stock: "disponible",
      badge: "",
      description: "Récolte de printemps, feuilles roulées à la main. Infusion végétale, légèrement umami."
    },
    {
      id: "p4",
      medias: [],
      nom: "Produit exemple",
      rayon: "Accessoires",
      emoji: "🏺",
      format: "35 cl",
      prix: 24.00,
      stock: "disponible",
      badge: "Limité",
      description: "Description de votre produit."
    },
    {
      id: "p5",
      medias: [],
      nom: "Pack exemple",
      rayon: "Coffrets",
      emoji: "🎁",
      format: "3 × 100 g",
      prix: 39.00,
      stock: "rupture",
      badge: "",
      description: "Description de votre pack exemple."
    }
  ],

  /* -------------------------------------------------------
     PALETTES — préréglages de couleurs
     ------------------------------------------------------- */
  palettes: {
    /* Palette reprise de Winterfell38 (theme.js, ACTIVE_THEME = "neonNuit"). */
    "neon-nuit": { nom: "Neon nuit", fond: "#0a0618", carte: "#170e2e", texte: "#f4f0ff", doux: "#a99cd6", accent: "#00f0ff", accentTexte: "#150726", bordure: "rgba(255,255,255,.10)" },
    "nuit-acide": { nom: "Nuit acide", fond: "#0a0a0f", carte: "#141419", texte: "#ffffff", doux: "#a9b0bd", accent: "#d4f24a", accentTexte: "#14170a", bordure: "rgba(255,255,255,.10)" },
    "vert-fluo": { nom: "Vert fluo", fond: "#06120a", carte: "#0f1d14", texte: "#ffffff", doux: "#9dc4ab", accent: "#39ff88", accentTexte: "#04170b", bordure: "rgba(255,255,255,.10)" },
    "rose-neon": { nom: "Rose neon", fond: "#12060f", carte: "#200d1a", texte: "#ffffff", doux: "#c9a2bd", accent: "#ff4fb8", accentTexte: "#1c0413", bordure: "rgba(255,255,255,.10)" },
    "cyan-electrique": { nom: "Cyan electrique", fond: "#04121a", carte: "#0c1f2b", texte: "#ffffff", doux: "#93bfd1", accent: "#22e8ff", accentTexte: "#02161d", bordure: "rgba(255,255,255,.10)" },
    "violet-neon": { nom: "Violet neon", fond: "#0e0618", carte: "#1a0f29", texte: "#ffffff", doux: "#b6a3cf", accent: "#a855ff", accentTexte: "#150526", bordure: "rgba(255,255,255,.10)" },
    "orange-brule": { nom: "Orange brule", fond: "#140902", carte: "#22130a", texte: "#fff7f0", doux: "#cdab93", accent: "#ff7a1a", accentTexte: "#1d0c02", bordure: "rgba(255,255,255,.10)" },
    "jaune-cyber": { nom: "Jaune cyber", fond: "#12110a", carte: "#1e1c10", texte: "#ffffff", doux: "#c9c395", accent: "#ffe600", accentTexte: "#1a1804", bordure: "rgba(255,255,255,.10)" },
    "rouge-neon": { nom: "Rouge neon", fond: "#130306", carte: "#210a0f", texte: "#ffffff", doux: "#cfa2a9", accent: "#ff2e4d", accentTexte: "#1c0308", bordure: "rgba(255,255,255,.10)" },
    "turquoise": { nom: "Turquoise", fond: "#03130f", carte: "#0a2019", texte: "#ffffff", doux: "#93c6b8", accent: "#00ffc8", accentTexte: "#02170f", bordure: "rgba(255,255,255,.10)" },
    "magenta": { nom: "Magenta", fond: "#12040e", carte: "#20091a", texte: "#ffffff", doux: "#c99cbe", accent: "#ff00a0", accentTexte: "#1b0314", bordure: "rgba(255,255,255,.10)" },
    "bleu-electrique": { nom: "Bleu electrique", fond: "#050a1a", carte: "#0d1529", texte: "#ffffff", doux: "#9aa9c9", accent: "#2f6dff", accentTexte: "#030818", bordure: "rgba(255,255,255,.10)" },
    "vert-lime": { nom: "Vert lime", fond: "#0b1204", carte: "#151f0a", texte: "#ffffff", doux: "#b3c68f", accent: "#b6ff00", accentTexte: "#101704", bordure: "rgba(255,255,255,.10)" },
    "corail-neon": { nom: "Corail neon", fond: "#140706", carte: "#22100e", texte: "#fff8f6", doux: "#cfaca7", accent: "#ff5c3d", accentTexte: "#1d0603", bordure: "rgba(255,255,255,.10)" },
    "parme": { nom: "Parme", fond: "#0c0714", carte: "#171021", texte: "#ffffff", doux: "#ada2c4", accent: "#c77dff", accentTexte: "#120821", bordure: "rgba(255,255,255,.10)" },
    "azur": { nom: "Azur", fond: "#03101f", carte: "#0a1b2e", texte: "#ffffff", doux: "#95b0c9", accent: "#00b3ff", accentTexte: "#02111f", bordure: "rgba(255,255,255,.10)" },
    "pistache": { nom: "Pistache", fond: "#0d1206", carte: "#181f0c", texte: "#ffffff", doux: "#b8c69d", accent: "#9fff3d", accentTexte: "#111607", bordure: "rgba(255,255,255,.10)" },
    "fuchsia": { nom: "Fuchsia", fond: "#14030c", carte: "#220817", texte: "#ffffff", doux: "#cb9cba", accent: "#ff1f8f", accentTexte: "#1d0310", bordure: "rgba(255,255,255,.10)" },
    "or-neon": { nom: "Or neon", fond: "#12100a", carte: "#1f1c11", texte: "#fffdf5", doux: "#cbc196", accent: "#ffd400", accentTexte: "#1a1604", bordure: "rgba(255,255,255,.10)" },
    "menthe": { nom: "Menthe", fond: "#04120d", carte: "#0a1e16", texte: "#ffffff", doux: "#94c7b6", accent: "#00ffa3", accentTexte: "#03180f", bordure: "rgba(255,255,255,.10)" },
    "indigo": { nom: "Indigo", fond: "#070718", carte: "#101026", texte: "#ffffff", doux: "#9d9dc9", accent: "#5a5aff", accentTexte: "#05051a", bordure: "rgba(255,255,255,.10)" },
    "framboise": { nom: "Framboise", fond: "#130408", carte: "#210a12", texte: "#fff6f9", doux: "#ce9caa", accent: "#ff3d7f", accentTexte: "#1c0308", bordure: "rgba(255,255,255,.10)" },
    "citron": { nom: "Citron", fond: "#10120a", carte: "#1c1f10", texte: "#ffffff", doux: "#c6c795", accent: "#eaff00", accentTexte: "#181a04", bordure: "rgba(255,255,255,.10)" },
    "sarcelle": { nom: "Sarcelle", fond: "#031210", carte: "#0a1f1c", texte: "#ffffff", doux: "#93c6c1", accent: "#00ffd5", accentTexte: "#021715", bordure: "rgba(255,255,255,.10)" },
    "prune": { nom: "Prune", fond: "#0f0613", carte: "#1b0e20", texte: "#ffffff", doux: "#b8a2c4", accent: "#b14fff", accentTexte: "#160822", bordure: "rgba(255,255,255,.10)" },
    "cuivre": { nom: "Cuivre", fond: "#140b06", carte: "#22150e", texte: "#fff9f4", doux: "#cfb0a0", accent: "#ff9a3d", accentTexte: "#1d0f05", bordure: "rgba(255,255,255,.10)" },
    "bleu-glace": { nom: "Bleu glace", fond: "#061018", carte: "#0d1c28", texte: "#ffffff", doux: "#9db8c7", accent: "#3ddbff", accentTexte: "#04141d", bordure: "rgba(255,255,255,.10)" },
    "vert-jade": { nom: "Vert jade", fond: "#04120c", carte: "#0a1e15", texte: "#ffffff", doux: "#96c7b2", accent: "#00e676", accentTexte: "#03170f", bordure: "rgba(255,255,255,.10)" },
    "rose-bonbon": { nom: "Rose bonbon", fond: "#140611", carte: "#220f1d", texte: "#ffffff", doux: "#ca9dbd", accent: "#ff69b4", accentTexte: "#1d0617", bordure: "rgba(255,255,255,.10)" },
    "laser": { nom: "Laser", fond: "#0a0412", carte: "#150a1f", texte: "#ffffff", doux: "#a89dc4", accent: "#ff00ff", accentTexte: "#100520", bordure: "rgba(255,255,255,.10)" },
    "ultra-violet": { nom: "Ultra violet", fond: "#080414", carte: "#120b22", texte: "#ffffff", doux: "#a49dc9", accent: "#8b00ff", accentTexte: "#0d051d", bordure: "rgba(255,255,255,.10)" },

    /* -------------------------------------------------------
       PALETTES DE WINTERFELL38
       Copie integrale de theme.js (36 palettes). Sur les
       cases claires, la couleur d'ecriture des boutons est
       passee au blanc pour rester lisible.
       ------------------------------------------------------- */
    "neonSunset": { nom: "Néon couchant", fond: "#12061f", carte: "#1f0b33", texte: "#fff4fb", doux: "#c9a8d9", accent: "#ff2e88", accentTexte: "#14170a", secondaire: "#ffb400", accent2: "#00e5ff", degrade: "linear-gradient(135deg,#ff2e88 0%,#ff7a00 50%,#ffd000 100%)", bordure: "rgba(255,255,255,.10)" },
    "tropical": { nom: "Tropicale", fond: "#03201f", carte: "#073833", texte: "#f0fffb", doux: "#9fd8cc", accent: "#00f5a0", accentTexte: "#14170a", secondaire: "#ff6b6b", accent2: "#ffe66d", degrade: "linear-gradient(135deg,#00f5a0,#00d9f5,#ffe66d)", bordure: "rgba(255,255,255,.10)" },
    "cyberpunk": { nom: "Cyberpunk", fond: "#0a0a12", carte: "#16162a", texte: "#f5f5ff", doux: "#a0a0c8", accent: "#fcee0a", accentTexte: "#14170a", secondaire: "#ff003c", accent2: "#00f0ff", degrade: "linear-gradient(135deg,#fcee0a,#ff003c,#00f0ff)", bordure: "rgba(255,255,255,.10)" },
    "candyPop": { nom: "Bonbon", fond: "#fff0f8", carte: "#ffffff", texte: "#3a0a2e", doux: "#8a5a7e", accent: "#ff3ea5", accentTexte: "#ffffff", secondaire: "#7b2ff7", accent2: "#00c2ff", degrade: "linear-gradient(135deg,#ff3ea5,#ff9a3e,#7b2ff7)", bordure: "rgba(255,255,255,.10)" },
    "oceanDeep": { nom: "Océan profond", fond: "#020c1b", carte: "#0a1f3a", texte: "#e6f4ff", doux: "#8fb3d9", accent: "#00b4ff", accentTexte: "#14170a", secondaire: "#7af0ff", accent2: "#ff8a00", degrade: "linear-gradient(135deg,#0052d4,#4364f7,#6fb1fc)", bordure: "rgba(255,255,255,.10)" },
    "royalGold": { nom: "Or royal", fond: "#140f05", carte: "#251c0b", texte: "#fff8e7", doux: "#d6c49a", accent: "#ffc947", accentTexte: "#14170a", secondaire: "#b8860b", accent2: "#ff4d6d", degrade: "linear-gradient(135deg,#f7971e,#ffd200,#fff1a8)", bordure: "rgba(255,255,255,.10)" },
    "aurora": { nom: "Aurore", fond: "#050816", carte: "#111735", texte: "#f2f6ff", doux: "#a6b0d6", accent: "#7cff6b", accentTexte: "#14170a", secondaire: "#b06bff", accent2: "#ff6bd6", degrade: "linear-gradient(135deg,#7cff6b,#00e1ff,#b06bff,#ff6bd6)", bordure: "rgba(255,255,255,.10)" },
    "lavaFire": { nom: "Lave", fond: "#1a0500", carte: "#2e0c02", texte: "#fff3ec", doux: "#e0a990", accent: "#ff4500", accentTexte: "#14170a", secondaire: "#ffae00", accent2: "#ffe14d", degrade: "linear-gradient(135deg,#8e0e00,#ff4500,#ffae00)", bordure: "rgba(255,255,255,.10)" },
    "electricViolet": { nom: "Violet électrique", fond: "#0d0221", carte: "#1b0a3d", texte: "#f6efff", doux: "#b8a3e0", accent: "#9d4edd", accentTexte: "#14170a", secondaire: "#f72585", accent2: "#4cc9f0", degrade: "linear-gradient(135deg,#f72585,#7209b7,#4cc9f0)", bordure: "rgba(255,255,255,.10)" },
    "mintFresh": { nom: "Menthe fraîche", fond: "#f2fffa", carte: "#ffffff", texte: "#0b3b2e", doux: "#5f8a7c", accent: "#00c896", accentTexte: "#ffffff", secondaire: "#ff7aa2", accent2: "#ffb800", degrade: "linear-gradient(135deg,#00c896,#7af5c6,#ffe27a)", bordure: "rgba(255,255,255,.10)" },
    "peachy": { nom: "Pêche", fond: "#fff6f0", carte: "#ffffff", texte: "#3d1d10", doux: "#9a6a55", accent: "#ff7e5f", accentTexte: "#ffffff", secondaire: "#feb47b", accent2: "#6a5cff", degrade: "linear-gradient(135deg,#ff7e5f,#feb47b,#ffd6a5)", bordure: "rgba(255,255,255,.10)" },
    "rainbow": { nom: "Arc-en-ciel", fond: "#0b0b0f", carte: "#18181f", texte: "#ffffff", doux: "#b5b5c5", accent: "#ff0080", accentTexte: "#14170a", secondaire: "#7928ca", accent2: "#00dfd8", degrade: "linear-gradient(90deg,#ff0000,#ff8000,#ffee00,#00d03a,#00a8ff,#7a00ff,#ff00c8)", bordure: "rgba(255,255,255,.10)" },
    "emerald": { nom: "Émeraude", fond: "#021a10", carte: "#06301e", texte: "#eafff4", doux: "#93cfb0", accent: "#00e676", accentTexte: "#14170a", secondaire: "#ffd740", accent2: "#40c4ff", degrade: "linear-gradient(135deg,#00b09b,#96c93d)", bordure: "rgba(255,255,255,.10)" },
    "sakura": { nom: "Sakura", fond: "#fff5f8", carte: "#ffffff", texte: "#401426", doux: "#a06a80", accent: "#ff5c8a", accentTexte: "#ffffff", secondaire: "#ffa6c1", accent2: "#3ec1d3", degrade: "linear-gradient(135deg,#ff5c8a,#ffa6c1,#ffd1dc)", bordure: "rgba(255,255,255,.10)" },
    "midnightBlue": { nom: "Bleu de minuit", fond: "#000814", carte: "#001d3d", texte: "#eaf2ff", doux: "#8aa4c8", accent: "#ffc300", accentTexte: "#14170a", secondaire: "#ffd60a", accent2: "#4ea8de", degrade: "linear-gradient(135deg,#003566,#ffc300)", bordure: "rgba(255,255,255,.10)" },
    "miami": { nom: "Miami", fond: "#170026", carte: "#2b0145", texte: "#fff0ff", doux: "#d8a6e6", accent: "#ff3cac", accentTexte: "#14170a", secondaire: "#2b86c5", accent2: "#00fff0", degrade: "linear-gradient(135deg,#ff3cac,#784ba0,#2b86c5)", bordure: "rgba(255,255,255,.10)" },
    "neonNuit": { nom: "Néon nuit", fond: "#0a0618", carte: "#170e2e", texte: "#f4f0ff", doux: "#a99cd6", accent: "#8a2be2", accentTexte: "#14170a", secondaire: "#ff7a00", accent2: "#00f0ff", degrade: "linear-gradient(135deg,#8a2be2 0%,#ff2e88 45%,#ff7a00 100%)", bordure: "rgba(255,255,255,.10)" },
    "bubblegum": { nom: "Bubblegum", fond: "#1a0620", carte: "#2d0b38", texte: "#fff2ff", doux: "#d9a6e0", accent: "#ff5fd2", accentTexte: "#14170a", secondaire: "#ffe066", accent2: "#41e0ff", degrade: "linear-gradient(135deg,#ff5fd2,#ff9a3e 55%,#ffe066)", bordure: "rgba(255,255,255,.10)" },
    "sunsetMiami": { nom: "Coucher Miami", fond: "#150726", carte: "#26103f", texte: "#fff0fa", doux: "#cfa3dd", accent: "#ff8a3d", accentTexte: "#14170a", secondaire: "#ff2e63", accent2: "#00e0d0", degrade: "linear-gradient(135deg,#ff2e63,#ff8a3d 50%,#ffd166)", bordure: "rgba(255,255,255,.10)" },
    "toxicGreen": { nom: "Vert toxique", fond: "#04120a", carte: "#0a2416", texte: "#eefff5", doux: "#8fd8b0", accent: "#39ff14", accentTexte: "#14170a", secondaire: "#ffd400", accent2: "#00d9ff", degrade: "linear-gradient(135deg,#39ff14,#b6ff00 55%,#ffd400)", bordure: "rgba(255,255,255,.10)" },
    "royalPurple": { nom: "Violet royal", fond: "#0b0420", carte: "#1a0a3a", texte: "#f3eaff", doux: "#b49ada", accent: "#a832ff", accentTexte: "#14170a", secondaire: "#ff3d81", accent2: "#ffd400", degrade: "linear-gradient(135deg,#a832ff 0%,#ff3d81 55%,#ffd400 100%)", bordure: "rgba(255,255,255,.10)" },
    "neonCyan": { nom: "Cyan néon", fond: "#04121a", carte: "#0a2436", texte: "#eafaff", doux: "#8dc4d8", accent: "#00e5ff", accentTexte: "#14170a", secondaire: "#7c4dff", accent2: "#ff2e88", degrade: "linear-gradient(135deg,#00e5ff,#7c4dff 55%,#ff2e88)", bordure: "rgba(255,255,255,.10)" },
    "hotCoral": { nom: "Corail vif", fond: "#1c0710", carte: "#330f1f", texte: "#fff3f6", doux: "#e0a3b4", accent: "#ff4d6d", accentTexte: "#14170a", secondaire: "#ff9a3e", accent2: "#4de1ff", degrade: "linear-gradient(135deg,#ff4d6d,#ff9a3e 55%,#ffe066)", bordure: "rgba(255,255,255,.10)" },
    "sunsetGold": { nom: "Or du couchant", fond: "#150b06", carte: "#2a160d", texte: "#fff8ee", doux: "#dcc0a2", accent: "#ff9e00", accentTexte: "#14170a", secondaire: "#ff6b35", accent2: "#ffd60a", degrade: "linear-gradient(135deg,#ff6b35,#ff9e00 50%,#ffd60a)", bordure: "rgba(255,255,255,.10)" },
    "tropicalNeon": { nom: "Tropicale néon", fond: "#04201c", carte: "#0a3a33", texte: "#f0fffc", doux: "#93dbcb", accent: "#00f5a0", accentTexte: "#14170a", secondaire: "#ff4d9d", accent2: "#ffe066", degrade: "linear-gradient(135deg,#00f5a0,#00d9f5 50%,#ff4d9d)", bordure: "rgba(255,255,255,.10)" },
    "neonMagenta": { nom: "Magenta néon", fond: "#0d0316", carte: "#1c0730", texte: "#ffeafc", doux: "#c98fd8", accent: "#ff00d4", accentTexte: "#14170a", secondaire: "#8a2be2", accent2: "#00ffc8", degrade: "linear-gradient(135deg,#ff00d4 0%,#8a2be2 50%,#00ffc8 100%)", bordure: "rgba(255,255,255,.10)" },
    "acidLime": { nom: "Vert acide", fond: "#061206", carte: "#0e2610", texte: "#f2ffe8", doux: "#9fd68a", accent: "#c6ff00", accentTexte: "#14170a", secondaire: "#00ff88", accent2: "#ff2ec4", degrade: "linear-gradient(135deg,#c6ff00,#00ff88 55%,#ff2ec4)", bordure: "rgba(255,255,255,.10)" },
    "ultraviolence": { nom: "Ultraviolence", fond: "#07021a", carte: "#140a3a", texte: "#efe8ff", doux: "#a48fe0", accent: "#b026ff", accentTexte: "#14170a", secondaire: "#00e5ff", accent2: "#ff007a", degrade: "linear-gradient(135deg,#b026ff,#ff007a 55%,#00e5ff)", bordure: "rgba(255,255,255,.10)" },
    "synthwave": { nom: "Synthwave", fond: "#0b0121", carte: "#1a0538", texte: "#ffeaf1", doux: "#c48fd0", accent: "#ff2e97", accentTexte: "#14170a", secondaire: "#00d9ff", accent2: "#ffd400", degrade: "linear-gradient(135deg,#ff2e97,#7b2ff7 50%,#00d9ff)", bordure: "rgba(255,255,255,.10)" },
    "vaporWave": { nom: "Vaporwave", fond: "#120b2e", carte: "#221347", texte: "#fdf0ff", doux: "#b79ad8", accent: "#ff6ec7", accentTexte: "#14170a", secondaire: "#00e0d0", accent2: "#b06bff", degrade: "linear-gradient(135deg,#ff6ec7,#b06bff 50%,#00e0d0)", bordure: "rgba(255,255,255,.10)" },
    "neonBlood": { nom: "Sang néon", fond: "#14030a", carte: "#280616", texte: "#fff0f4", doux: "#db93a8", accent: "#ff003c", accentTexte: "#14170a", secondaire: "#ff5c00", accent2: "#00e5ff", degrade: "linear-gradient(135deg,#ff003c,#ff5c00 55%,#ffd400)", bordure: "rgba(255,255,255,.10)" },
    "electricBlue": { nom: "Bleu électrique", fond: "#03091c", carte: "#071638", texte: "#eaf4ff", doux: "#8fb4e0", accent: "#0f7cff", accentTexte: "#14170a", secondaire: "#00f0ff", accent2: "#ff2ec4", degrade: "linear-gradient(135deg,#0f7cff,#00f0ff 50%,#ff2ec4)", bordure: "rgba(255,255,255,.10)" },
    "neonMandarin": { nom: "Mandarine néon", fond: "#160800", carte: "#2b1103", texte: "#fff5ea", doux: "#e0b597", accent: "#ff6a00", accentTexte: "#14170a", secondaire: "#ffd000", accent2: "#00f0ff", degrade: "linear-gradient(135deg,#ff6a00,#ffd000 55%,#00f0ff)", bordure: "rgba(255,255,255,.10)" },
    "iceNeon": { nom: "Néon glacé", fond: "#04101a", carte: "#081f33", texte: "#ecfaff", doux: "#93c4d8", accent: "#6ef0ff", accentTexte: "#14170a", secondaire: "#a06bff", accent2: "#ff5fd2", degrade: "linear-gradient(135deg,#6ef0ff,#a06bff 50%,#ff5fd2)", bordure: "rgba(255,255,255,.10)" },
    "neonJungle": { nom: "Jungle néon", fond: "#04140c", carte: "#08281a", texte: "#effff6", doux: "#8fd8b4", accent: "#00ff9d", accentTexte: "#14170a", secondaire: "#c6ff00", accent2: "#ff2e88", degrade: "linear-gradient(135deg,#00ff9d,#c6ff00 55%,#ff2e88)", bordure: "rgba(255,255,255,.10)" },
    "custom": { nom: "Personnalisée", fond: "#101010", carte: "#1c1c1c", texte: "#ffffff", doux: "#aaaaaa", accent: "#ff00aa", accentTexte: "#14170a", secondaire: "#00ffaa", accent2: "#ffaa00", degrade: "linear-gradient(135deg,#ff00aa,#00ffaa)", bordure: "rgba(255,255,255,.10)" },

  },

  /* -------------------------------------------------------
     SON — invisible pour le visiteur
     0 = muet · 0.05 = à peine perceptible · 0.3 = présent
     ------------------------------------------------------- */
  son: {
    volume: 0.03,
    fichiers: ["p.m4a", "p.mp3", "ambiance.m4a", "ambiance.mp3"],
    actif: true
  },

  /* -------------------------------------------------------
     LIVRAISON — frais et seuil
     ------------------------------------------------------- */
  livraison: {
  frais: 10,
  gratuiteAPartirDe: 100,
  seuil: 100,
  minimum: 50
},

  /* -------------------------------------------------------
     NOTIFICATIONS — adresses des fonctions serveur

     Ces adresses sont PUBLIQUES par nature : elles ne
     contiennent aucun secret. Le jeton du bot Telegram vit
     dans les secrets Supabase, jamais ici.

     Pour desactiver un envoi, passez « active » a false.
     ------------------------------------------------------- */
  notifications: {
    url: "https://jrmcyurpaedspxileshx.supabase.co/functions/v1/notifier-commande",
    active: true
  },

  notifEtape: {
    url: "https://jrmcyurpaedspxileshx.supabase.co/functions/v1/notifier-etape",
    active: true
  },

  /* -------------------------------------------------------
     Il n'y a volontairement PLUS ici :
       - adminMotDePasse  (contrôle côté client = aucun contrôle)
       - telegram.jeton   (un secret dans un fichier public)

     Voir le README pour la mise en place.
     ------------------------------------------------------- */
};
