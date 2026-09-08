# Vibe Coding Copilot — guide technique de maintenance

Ressource pédagogique statique (FR/NL/EN) enseignant le « vibe coding » avec GitHub Copilot
à l'enseignement supérieur : enseignant·e·s, étudiant·e·s, IT, RH, direction, finances,
recherche, bibliothèque/campus.

Ce document s'adresse à quiconque reprend ou fait évoluer ce projet après cette session
de construction. Il décrit l'architecture réelle, pas une architecture idéale — certains
choix (voir « Dette technique connue ») mériteraient d'être nettoyés avant un usage à très
long terme.

## Site publié

Le site est en ligne : **https://sebplace.github.io/vibe-coding-copilot/** (choix de langue
à la racine, puis `/fr/`, `/nl/`, `/en/`).

**Dépôt de publication (depuis le 29/08/2026)** : `sebplace/vibe-coding-copilot`, branche
`main`, servi **depuis la racine du dépôt** par GitHub Pages. Le site n'est plus un
sous-dossier de `sebplace/sebplace.github.io` : pousser là-bas ne met plus le site à jour.
L'URL publique est inchangée.

Pour publier une mise à jour, utiliser le script (il régénère, vérifie et pousse) :

```powershell
.\deploy.ps1 -Message "Description du changement"
```

**Référencement (vérifié le 08/09/2026)** : `https://sebplace.github.io/robots.txt` et
`/sitemap.xml` renvoient désormais **404** — l'ancien blog Jekyll qui les générait a été
remplacé par une page statique. Le `robots.txt` et le `sitemap.xml` du projet
(`/vibe-coding-copilot/robots.txt` et `/vibe-coding-copilot/sitemap.xml`, 58 URL) répondent
bien en 200 et restent valides pour les pages du projet, mais **un `robots.txt` placé dans un
sous-dossier ne fait pas autorité pour le domaine** : seul celui de la racine compte pour les
robots. Les pages restent indexables ; pour un référencement complet, déclarer le sitemap du
projet dans la Search Console, ou publier un `robots.txt` à la racine du domaine — ce qui
suppose de ne pas casser les autres contenus hébergés sur ce domaine.

## Démarrage rapide

```powershell
# Depuis la racine du projet
python generate_site.py        # régénère tout le HTML (fr/, nl/, en/, index.html)
python check_links.py          # vérifie qu'aucun lien interne n'est cassé
python check_case.py           # vérifie la casse des chemins (Windows est insensible à la
                                # casse, GitHub Pages/Linux ne l'est pas — un lien qui marche
                                # en local peut 404 une fois publié si la casse diffère)
python -m http.server 8765     # sert le site en local
# puis ouvrir http://localhost:8765/fr/index.html
```

Aucune dépendance externe obligatoire : Python standard uniquement pour la génération, HTML/CSS/JS
vanilla pour le rendu (aucune bibliothèque externe, aucun appel réseau à l'exécution par défaut —
même le QR code du kit d'atelier est généré par un script vendored dans `assets/`). Le seul appel
réseau optionnel est l'analytics GoatCounter décrit ci-dessous, désactivé tant que le code de site
n'est pas configuré.

## Analytics & feedback (GoatCounter)

Le site envoie des statistiques de visite **sans cookies, sans données personnelles**, via
[GoatCounter](https://www.goatcounter.com) (gratuit, open source, hébergement EU disponible).

**Activé et en production** (21/08/2026) : compte créé (`vibecodingcopilot`, email vérifié
`splace@microsoft.com`), tableau de bord sur `https://vibecodingcopilot.goatcounter.com`.
`GOATCOUNTER_CODE = "vibecodingcopilot"` dans `site_refresh.py` (ligne ~124) — script injecté et
confirmé en production sur toutes les pages.

Pour changer de compte ou de code de site à l'avenir :
1. Créer/utiliser un compte sur https://www.goatcounter.com et choisir un code de site.
2. Mettre à jour `GOATCOUNTER_CODE` dans `site_refresh.py`.
3. Régénérer (`python generate_site.py`), vérifier, redéployer (voir « Site publié » ci-dessus).

Le script `<script data-goatcounter="…">` est injecté sur chaque page, et le widget « Cette page
t'a-t-elle aidé ? » (visible sur les pages de contenu — cf. `FEEDBACK_WIDGET_PAGES` dans
`site_refresh.py`) envoie un événement `feedback-up-<page>` / `feedback-down-<page>` au clic,
visible dans le tableau de bord GoatCounter sous « Pages » ou via l'onglet Events. Le vote est
mémorisé en `localStorage` (`vcc-feedback-voted-<page>`) pour ne pas relancer la question à chaque
visite. Note : GoatCounter filtre les navigateurs automatisés (Playwright, robots) — seules les
vraies visites humaines apparaissent dans le tableau de bord, ce qui a été vérifié comme un
comportement voulu (pas un bug) lors de la mise en service.

## Rendu sans JavaScript

Le contenu est **visible par défaut**. L'animation d'apparition au défilement est un
enrichissement optionnel, activé seulement si le JavaScript fonctionne :

1. Un court script en ligne dans `<head>` ajoute la classe `js-reveal` à `<html>` avant le
   premier affichage (évite un clignotement du contenu).
2. `assets/script.js` positionne `window.__vccRevealReady = true` quand la logique
   d'apparition démarre.
3. Si ce signal n'arrive pas dans les 2,5 s (script bloqué, échec de chargement, erreur JS,
   extension, poste verrouillé), le script en ligne **retire** `js-reveal` et tout redevient
   visible.

Règle à respecter pour toute évolution : `[data-reveal]` ne doit **jamais** être masqué sans
la classe `js-reveal`, sinon une simple panne du script rend le site entièrement blanc — ce
qui était le cas avant le 08/09/2026. Même principe pour les compteurs (`data-counter`) et
les barres (`data-bar-target`) : le HTML contient déjà la valeur finale, et le JavaScript la
remet à zéro uniquement pour l'animer.

Trois scénarios à vérifier après toute modification de ce mécanisme : JavaScript désactivé,
`script.js` bloqué mais JavaScript actif, et fonctionnement normal.

## Image d'aperçu de partage

`assets/og-image.png` (1200×630) est référencée par `og:image` / `twitter:image` sur toutes
les pages **et sur la page racine**, celle qui est réellement partagée. Les balises
`og:url` et `canonical` pointent vers l'URL absolue de chaque page, et `twitter:card` vaut
`summary_large_image`.

Pour régénérer l'image après un changement de message ou de chiffres : modifier
`build-assets/og-image-template.html`, l'ouvrir dans un navigateur en 1200×630 et en faire
une capture enregistrée sous `assets/og-image.png`. Les chiffres affichés (25 leçons,
36 cas d'usage, 8 métiers) doivent rester cohérents avec le contenu réel du site.

## Sauvegarde de progression

La progression (leçons cochées, quiz, nom du certificat) vit dans le `localStorage` du
navigateur. La page du certificat propose donc un export et une restauration :

- **Export** : produit `vibe-coding-copilot-progression-<lang>.json` (format
  `vibe-coding-copilot-progress`, version 1) à partir des clés `vibecoding_progress_*`,
  `vibecoding_quiz_*` et `vibecoding_certificate_name_*`.
- **Restauration** : n'accepte **que** ces trois préfixes. Un fichier contenant d'autres
  clés voit celles-ci ignorées, et un fichier au format inconnu est refusé avec un message.

Tout se passe dans le navigateur : aucun compte, aucun serveur, aucun envoi.

## Conditions de réutilisation

`LICENSE.md` sépare volontairement deux natures de travail : **MIT** pour le code et le
générateur, **CC BY 4.0** pour le contenu pédagogique, afin que les établissements puissent
adapter le matériel en citant la source. Le fichier rappelle aussi ce qui n'est pas couvert
(marques GitHub/Microsoft, logo GitHub, absence d'affiliation, exactitude des tarifs).
Ce choix est réversible en un commit s'il ne convient pas.

## Dette technique — état réel

Un nettoyage vérifié a été fait le 08/09/2026 :

- `generate_site.py` contenait encore **~517 lignes** de l'ancien moteur de rendu (16
  fonctions `esc`, `render_home`, `render_course`, `render_root_index`…), entièrement
  remplacées par `site_refresh.py` et jamais appelées — `main()` ne fait qu'appeler
  `site_refresh.generate_site()`.
- `site_refresh.py` contenait `nav_course_group_html`, un **doublon** du menu déroulant des
  parcours jamais appelé (le vrai balisage vient d'ailleurs), et un `slugify` inutilisé.

**Méthode de vérification à réutiliser pour tout nettoyage futur** : prendre l'empreinte
SHA-256 des 67 fichiers générés, supprimer, régénérer, comparer. La sortie doit être
strictement identique — c'est ce qui a été constaté ici.

Ce qui reste (`site_refresh.py` ≈ 5 880 lignes) est du contenu et du rendu réellement
utilisés. Une réécriture complète n'apporterait rien de visible aux visiteurs et ferait
courir un risque de régression sur 58 pages : à faire seulement de façon progressive, et
toujours avec la comparaison d'empreintes ci-dessus.

## Architecture — le point le plus important à comprendre

Il y a **deux fichiers Python, mais un seul est réellement le moteur de rendu** :

- **`generate_site.py`** définit le dictionnaire `CONTENT` (clés `en`/`fr`/`nl`) avec le
  contenu *d'origine* du projet (accueil, parcours de cours, bonnes pratiques, à propos...),
  puis délègue tout le travail à `site_refresh.py` :
  ```python
  def main():
      site_refresh.generate_site(CONTENT, ROOT, LANGS, LANG_LABEL)
  ```
- **`site_refresh.py`** (~5300 lignes) est le vrai moteur actif. Sa fonction
  `generate_site(content, root, langs, lang_label)` :
  1. Fusionne en profondeur un dictionnaire `CONTENT_UPDATES` (contenu ajouté au fil des
     itérations : Plans & réalité, 8 scénarios, Premier commit, Construire ou acheter,
     Glossaire, Plan du site, Certificat, Atelier, Diagnostic de maturité, Historique du
     site...) par-dessus le `content` reçu de `generate_site.py`.
  2. Définit **toutes** les fonctions de rendu comme fonctions locales à l'intérieur de
     `generate_site()` : `header_html`, `footer_html`, `page_shell`, `render_home`,
     `render_course`, `render_explorer`, `render_scenarios`, `render_plans`,
     `render_first_commit`, `render_build_vs_buy`, `render_toolkit`, `render_glossary`,
     `render_sitemap`, `render_certificate`, `render_workshop`, `render_maturity`,
     `render_changelog`, `render_wayfinding`, `render_fact_banner`, `render_quiz`,
     `render_course_progress`, `render_root_index`, etc.
  3. Écrit les fichiers HTML dans `fr/`, `nl/`, `en/` + un `index.html` racine de
     redirection, plus `sitemap.xml` et `robots.txt` à la racine.

**Conséquence pratique : pour ajouter ou modifier quoi que ce soit sur le site, on modifie
`site_refresh.py`, pas `generate_site.py`.** `generate_site.py` ne sert plus qu'à fournir le
contenu de base historique et le point d'entrée `main()`.

### Table de routage (`ROUTE_FILENAMES` dans `site_refresh.py`, ligne ~66)

| Clé de route | Fichier généré |
|---|---|
| `home` | `index.html` |
| `explorer` | `cas-usage.html` |
| `scenarios` | `scenarios.html` |
| `plans` | `plans.html` |
| `first_commit` | `first-commit.html` |
| `build_vs_buy` | `build-vs-buy.html` |
| `toolkit` | `toolkit.html` |
| `best_practices` | `best-practices.html` |
| `about` | `about.html` |
| `glossary` | `glossary.html` |
| `workshop` | `workshop.html` |
| `certificate` | `certificate.html` |
| `quick_reference` | `quick-reference.html` |
| `sitemap` | `sitemap.html` |
| `maturity` | `maturity.html` |
| `changelog` | `changelog.html` |

Les 3 parcours de cours (`basics`/`advanced`/`expert`) ont leur propre logique de nom de
fichier basée sur `content[lang]["tracks"][track_key]["slug"]`.

### Comment ajouter une nouvelle page

1. Ajouter une entrée dans `ROUTE_FILENAMES`.
2. Ajouter le contenu de la page dans `CONTENT_UPDATES[lang]["ma_page"] = {...}` pour les
   3 langues (structure parallèle obligatoire — une clé manquante dans une langue provoque
   un `KeyError` au rendu).
3. Écrire une fonction `def render_ma_page(lang): ...` à l'intérieur de `generate_site()`,
   en réutilisant `page_shell()`, `render_wayfinding()`, `render_fact_banner()` si pertinent.
4. Ajouter le mapping `"ma-page.html": render_ma_page(lang)` dans la boucle d'écriture des
   fichiers (chercher `"first-commit.html": render_first_commit(lang)` comme modèle).
5. Rendre la page **découvrable** : l'ajouter à la liste du pied de page (`footer_html`),
   au groupe « RESSOURCES » du menu mobile, et/ou au menu déroulant « Parcours » — **ne
   jamais ajouter un nouvel item de premier niveau dans le menu desktop** (voir contrainte
   ci-dessous).

## Contrainte critique : le menu ne doit jamais déborder

Le menu desktop a été **cassé et corrigé trois fois** pendant cette session (débordement
horizontal). L'équilibre actuel est fragile et intentionnel :

- 7 items de premier niveau + un menu déroulant consolidé « Parcours » (qui contient les
  3 parcours de cours + un lien rapide vers Premier commit) + le sélecteur de langue
  (toujours visible) + une icône de recherche + le bouton hamburger.
- Le menu desktop **ne s'affiche qu'au-dessus de 1720px de large** ; en dessous, tout passe
  par le hamburger (menu mobile, groupé en « APPRENDRE » / « RESSOURCES »).
- **Ne jamais ajouter de nouvel item au menu desktop.** Toute nouvelle page doit passer par
  le pied de page, le menu mobile, ou des liens contextuels dans le contenu.

Après **toute** modification touchant l'en-tête, le CSS global ou l'ajout d'une page,
revérifier l'absence de débordement :

```js
// Dans une session Playwright, après un rechargement avec cache vidé (CDP
// Network.clearBrowserCache — le serveur local met le CSS en cache de façon agressive) :
document.documentElement.scrollWidth <= window.innerWidth + quelques px de marge de scrollbar
// à tester à 1920, 1600, 1440, 1366, 1280, 1024, 768, 390, 375 px
```

## Autres règles établies pendant cette session (à respecter)

- **Écriture inclusive en français** : doublets pour les noms clés au pluriel
  (« les enseignantes et les enseignants »), formes épicènes pour le singulier/générique
  (« la personne », « le personnel »). **Jamais de point médian** (« sûr·e », « un·e »).
  Vérifier avec : `grep -P "[a-zA-Z]\x{00b7}[a-zA-Z]"` sur les fichiers `fr/*.html`.
- **Accents** : toujours taper les caractères accentués directement dans le code Python et
  le HTML brut. Ne jamais utiliser d'échappement `\uXXXX` littéral dans un fichier `.html`
  (les navigateurs ne l'interprètent pas, contrairement à une chaîne Python) — cette règle
  ne s'applique pas aux bibliothèques JS vendored comme `assets/qrcode.min.js`.
- **Aucun fait inventé sur GitHub Copilot** : tous les plans, prix, fonctionnalités et
  statistiques cités viennent de recherches vérifiées sur `docs.github.com` et
  `github.blog` (voir les liens sources déjà intégrés dans le Glossaire, Plans & réalité,
  Scénarios). Toute nouvelle affirmation factuelle doit être vérifiable de la même façon —
  ne pas extrapoler ou inventer un nom de fonctionnalité Copilot.
- **Site 100% statique et hors-ligne** : aucun appel API externe à l'exécution, aucune
  dépendance CDN. Tout algorithme nécessaire (ex. génération de QR code) doit être vendored
  dans `assets/`.
- **`prefers-reduced-motion`** : toute nouvelle animation doit le respecter (voir les
  animations d'apparition au scroll existantes via `[data-reveal]` pour le patron à suivre).
- **Playwright ne peut pas ouvrir les URL `file://`** — toujours servir via
  `python -m http.server 8765` pour visualiser/tester.
- **Cache navigateur agressif** contre le serveur local — après une régénération, vider le
  cache (CDP `Network.clearBrowserCache`) avant de tester, sinon on diagnostique de faux
  problèmes sur du CSS/HTML périmé.

## Suivi de progression et état local (`assets/script.js`)

Les 25 leçons des 3 parcours et les 3 quiz utilisent `localStorage` avec ce schéma de clés :

- `vibecoding_progress_<lang>_<track>_<lessonIndex>` → `"true"` si la leçon est cochée.
- `vibecoding_quiz_<lang>_<track>` → JSON `{passed, score, total}`.
- `vibecoding_certificate_name_<lang>` → nom saisi pour le certificat.
- `vibecoding_lang_banner_dismissed` → bannière de suggestion de langue masquée ou non.

Le nombre de leçons par parcours (`basics: 8, advanced: 9, expert: 8`) est répété dans les
attributs `data-track-counts` du certificat — à garder synchronisé si un parcours change de
longueur.

## Dette technique connue (à nettoyer si quelqu'un a le temps)

- `nav_course_group_html()` dans `site_refresh.py` n'est plus appelée (remplacée par
  `nav_courses_menu_html()` qui consolide les 3 parcours en un seul menu déroulant) mais
  n'a pas été supprimée — code mort inoffensif.
- Le contenu d'origine dans `generate_site.py` (dict `CONTENT`) et les mises à jour dans
  `site_refresh.py` (dict `CONTENT_UPDATES`) sont maintenant fusionnés en profondeur à
  chaque génération — c'est fonctionnel mais rend la recherche du texte source d'une page
  donnée moins évidente (il faut parfois chercher dans les deux fichiers).
- **CSS minifié automatiquement** à chaque génération : `generate_site()` lit
  `assets/style.css` (source lisible, à éditer) et écrit `assets/style.min.css`
  (chargé par toutes les pages) via `minify_css()` — suppression des commentaires et
  des espaces superflus uniquement, aucune transformation risquée. Gain ~20%
  (68,8 Ko → 54,9 Ko). **`assets/script.js` reste volontairement non minifié** :
  un minifieur JS fiable nécessiterait soit une dépendance Node (contraire au choix
  « Python standard uniquement »), soit une regex maison risquée (comment/chaîne
  mal détectés). Le gain potentiel (quelques dizaines de Ko) ne justifiait pas le risque.
- **Piège CSS résolu — `backdrop-filter` et `position: fixed`** : `.site-header` utilise
  `backdrop-filter: blur(10px)`, ce qui crée un nouveau *containing block* pour tout
  descendant en `position: fixed` (comme `.mobile-nav-panel`). Un `bottom: 0` sur ce
  panneau se résout donc contre la boîte de l'en-tête (~65px de haut), pas contre la
  fenêtre — le panneau s'écrasait à quelques pixels. Fix : utiliser une hauteur explicite
  (`height: calc(100vh - 65px)`) plutôt que `bottom: 0`, car les unités `vh` restent
  relatives à la vraie fenêtre quel que soit le containing block. À garder en tête pour
  tout futur élément `position: fixed` imbriqué dans l'en-tête.

## Limites de vérification connues

- Tous les tests de rendu de cette session ont été faits **via Chromium (Playwright)
  uniquement**. Le site n'a **jamais été testé réellement sur Firefox, Safari, ou un
  navigateur mobile physique**. Une revue statique du CSS n'a pas détecté de propriété
  non standard ou expérimentale, mais cela ne remplace pas un test réel.
- Les captures d'écran plein-page (`fullPage: true`) via Playwright peuvent afficher de
  larges zones vides à cause des animations d'apparition au scroll (`[data-reveal]`) qui
  ne se déclenchent pas lors d'une capture automatisée sans vrai défilement — ce n'est
  **pas** un bug du site, seulement un artefact de capture d'écran. Toujours vérifier avec
  un vrai défilement (`page.mouse.wheel`) avant de conclure à un problème d'affichage.

## Où sont les vraies sources factuelles

Les affirmations sur GitHub Copilot (plans, prix, fonctionnalités, statistiques) citées sur
ce site s'appuient sur ces pages, vérifiées en août 2026 :
`docs.github.com/en/copilot/get-started/plans`,
`docs.github.com/en/copilot/get-started/features`,
`docs.github.com/en/copilot/concepts/context/spaces`,
`docs.github.com/en/copilot/concepts/agents/github-copilot-app`,
`docs.github.com/en/copilot/concepts/context/mcp`,
`docs.github.com/en/copilot/concepts/billing/usage-based-billing-for-organizations-and-enterprises`,
`docs.github.com/en/education/...`,
et la recherche 2022 de GitHub sur la productivité
(`github.blog/news-insights/research/research-quantifying-github-copilots-impact-on-developer-productivity-and-happiness/`).
GitHub Copilot évolue vite : revérifier ces pages avant toute mise à jour du contenu, et
mettre à jour le bandeau « faits vérifiés » (`render_fact_banner`) et l'Historique du site
(`render_changelog`) en conséquence.
