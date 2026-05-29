# Guide SonarQube — projet firstSign

Ce guide explique **pas-à-pas** comment relancer une analyse SonarQube complète sur ce dépôt, depuis une machine **Ubuntu** ou **Windows**. Il est rédigé pour qu'un développeur junior puisse le suivre sans connaissance préalable de SonarQube.

> **À retenir** : le projet est déjà calibré. Le fichier [sonar-project.properties](../sonar-project.properties) contient toutes les exclusions, les règles ignorées et les chemins de couverture. **Vous n'avez pas à le modifier** pour relancer le scan : il suffit de monter le serveur, générer la couverture, puis lancer le scanner.

---

## 1. Ce que vous allez obtenir

À la fin de ce guide, vous aurez :

- un serveur **SonarQube** local accessible sur http://localhost:9000
- un rapport de couverture Ruby (`coverage/coverage.json`) généré par RSpec + SimpleCov
- un projet `firstSign` dans SonarQube avec :
  - le bilan **Bugs / Vulnerabilities / Code Smells / Security Hotspots**
  - le pourcentage de couverture
  - le taux de duplication

L'opération complète prend ~15 min (premier lancement) puis ~5 min (lancements suivants).

---

## 2. Prérequis communs (Ubuntu **et** Windows)

| Outil                     | Version min       | Pourquoi                                        |
|---------------------------|-------------------|-------------------------------------------------|
| **Docker Desktop / Engine** | 24+              | Lance le serveur SonarQube sans installation Java |
| **Java JDK**              | **17+**           | Requis par `sonar-scanner` (le CLI)             |
| **Ruby**                  | `4.0.1` (cf. [Gemfile](../Gemfile)) | Pour générer la couverture via RSpec   |
| **Node.js**               | 20 LTS            | Pour `yarn install` (dépendances JS analysées)  |
| **Yarn**                  | 1.x               | Idem                                             |
| **Git**                   | n'importe         | Pour cloner le dépôt                            |
| **8 Go de RAM libres**    | —                 | SonarQube + Elasticsearch embarqué              |

> Le `sonar-scanner` que vous installerez plus bas embarque sa propre JRE depuis la version 5+, mais Docker doit pouvoir tourner correctement : vérifiez `docker --version` avant de continuer.

---

## 3. Cloner le dépôt et installer les dépendances projet

```bash
git clone <url-du-depot> esign
cd esign
git checkout refactor/sonarqube-quality-fixes   # ou la branche à analyser
```

Ensuite, dans le dossier du projet :

```bash
bundle install      # installe les gems Ruby (RSpec, SimpleCov, etc.)
yarn install        # installe les paquets JS (analysés par Sonar)
```

> Si `bundle install` échoue sur `libvips` / `libpdfium`, voir la section **8. Problèmes fréquents** plus bas.

---

## 4. Lancer le serveur SonarQube (Docker — méthode recommandée)

C'est **la méthode la plus simple** et identique sur Ubuntu et Windows.

### 4.1 Démarrer le conteneur

```bash
docker run -d --name sonarqube \
  -p 9000:9000 \
  -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
  sonarqube:lts-community
```

> Sur Ubuntu, si Docker refuse l'allocation mémoire d'Elasticsearch :
> ```bash
> sudo sysctl -w vm.max_map_count=262144
> ```
> Pour rendre ça permanent, ajoutez `vm.max_map_count=262144` dans `/etc/sysctl.conf`.

> Sur Windows, vérifiez que Docker Desktop a au moins **4 Go de RAM** alloués dans **Settings → Resources**.

### 4.2 Attendre que le serveur soit prêt

Le démarrage prend 1 à 2 minutes. Suivez les logs :

```bash
docker logs -f sonarqube
```

Quand vous voyez `SonarQube is operational`, ouvrez http://localhost:9000 dans votre navigateur.

### 4.3 Première connexion

- **Identifiant** : `admin`
- **Mot de passe** : `admin`

SonarQube vous demandera de changer le mot de passe. **Notez-le** — vous en aurez besoin pour générer un token et pour le script Python d'analyse des hotspots.

### 4.4 Créer le projet et générer un token

1. Cliquez sur **Create a local project**.
2. **Project display name** : `firstSign`
3. **Project key** : `firstSign` (⚠️ identique à `sonar.projectKey` de [sonar-project.properties:1](../sonar-project.properties#L1))
4. **Main branch name** : `main` (peu importe, on scan une branche locale).
5. Choisissez **Use the global setting** pour la quality gate.
6. Sur l'écran "Analyse Method", sélectionnez **Locally**.
7. Cliquez **Generate a token**, nommez-le `local-scanner`, **copiez-le immédiatement** (il ne sera plus affiché ensuite).

Sauvegardez ce token dans une variable d'environnement (utile pour la suite) :

**Ubuntu (bash/zsh)** :
```bash
export SONAR_TOKEN="sqp_xxxxxxxxxxxxxxxxxxxxxxxx"
```

**Windows (PowerShell)** :
```powershell
$env:SONAR_TOKEN = "sqp_xxxxxxxxxxxxxxxxxxxxxxxx"
```

---

## 5. Installer `sonar-scanner` (le CLI qui envoie le code à SonarQube)

### 5.1 Sur Ubuntu

```bash
# 1. Télécharger
cd /opt
sudo wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-6.2.1.4610-linux-x64.zip
sudo unzip sonar-scanner-cli-6.2.1.4610-linux-x64.zip
sudo mv sonar-scanner-6.2.1.4610-linux-x64 sonar-scanner

# 2. Ajouter au PATH (zsh ou bash)
echo 'export PATH="$PATH:/opt/sonar-scanner/bin"' >> ~/.bashrc
source ~/.bashrc

# 3. Vérifier
sonar-scanner --version
```

Vous devez voir une ligne du type `SonarScanner 6.2.x.xxxx`.

### 5.2 Sur Windows

1. Téléchargez le ZIP depuis [https://docs.sonarsource.com/sonarqube-community/analyzing-source-code/scanners/sonarscanner/](https://docs.sonarsource.com/sonarqube-community/analyzing-source-code/scanners/sonarscanner/) (section **Windows**).
2. Dézippez dans `C:\sonar-scanner` (pas d'espace dans le chemin !).
3. Ajoutez `C:\sonar-scanner\bin` au **PATH** :
   - **Démarrer → Variables d'environnement** → onglet **Système** → **Path** → **Modifier** → **Nouveau** → coller `C:\sonar-scanner\bin`.
4. Ouvrez un **nouveau** PowerShell et vérifiez :
   ```powershell
   sonar-scanner --version
   ```

> **Note Windows** : si la commande renvoie `'sonar-scanner' n'est pas reconnu`, fermez **tous** les terminaux et rouvrez-en un — le PATH n'est rechargé qu'à l'ouverture d'une nouvelle session.

---

## 6. Générer le rapport de couverture (RSpec + SimpleCov)

SonarQube affiche `0 % de couverture` si vous oubliez cette étape. C'est l'erreur la plus fréquente.

### 6.1 Lancer la suite de tests avec couverture

À la racine du projet :

**Ubuntu** :
```bash
COVERAGE=true bundle exec rspec
```

**Windows (PowerShell)** :
```powershell
$env:COVERAGE = "true"
bundle exec rspec
```

> ⚠️ Sur **Windows**, si vous utilisez **WSL2** (recommandé pour ce projet Rails), utilisez la commande Ubuntu dans votre terminal WSL — pas dans PowerShell. Sinon, `libvips` et `libpdfium` ne fonctionneront pas.

### 6.2 Vérifier que la couverture a été générée

Après l'exécution des tests, ces fichiers doivent exister :

```
coverage/
├── coverage.json     ← lu par SonarQube (voir sonar-project.properties:32)
├── lcov.info         ← format alternatif
└── index.html        ← rapport HTML lisible dans un navigateur
```

Si `coverage/coverage.json` est absent, **ne lancez pas le scanner** : il marquerait toute la base à 0 %. Vérifiez d'abord :

```bash
ls -lh coverage/coverage.json   # Ubuntu
dir coverage\coverage.json      # Windows
```

> **Astuce** : pour un retour rapide sans tester toute la suite, vous pouvez cibler un répertoire :
> ```bash
> COVERAGE=true bundle exec rspec spec/lib
> ```
> mais le rapport sera **partiel**. Pour une analyse SonarQube fidèle, **lancez toute la suite**.

---

## 7. Lancer l'analyse SonarQube

À la racine du projet :

**Ubuntu** :
```bash
sonar-scanner \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.token=$SONAR_TOKEN
```

**Windows (PowerShell)** :
```powershell
sonar-scanner `
  -D"sonar.host.url=http://localhost:9000" `
  -D"sonar.token=$env:SONAR_TOKEN"
```

Le scanner :

1. Lit [sonar-project.properties](../sonar-project.properties) (clé projet, exclusions, règles ignorées, chemin de couverture)
2. Analyse les sources Ruby, JS, Vue, ERB, CSS
3. Envoie le tout au serveur

Durée typique : 3 à 6 min selon la machine.

À la fin, vous verrez :
```
INFO  EXECUTION SUCCESS
INFO  More about the report processing at http://localhost:9000/api/ce/task?id=...
```

Ouvrez http://localhost:9000/dashboard?id=firstSign — le rapport est là.

---

## 8. (Optionnel) Marquer les Security Hotspots comme reviewés

Le projet inclut un script qui marque automatiquement les hotspots déjà analysés comme **SAFE** avec une justification.

```bash
SONAR_TOKEN_OR_PASSWORD="$SONAR_TOKEN" python3 scripts/sonar_review_hotspots.py
```

Voir [scripts/sonar_review_hotspots.py](../scripts/sonar_review_hotspots.py) pour la liste des règles couvertes et les justifications. Lancez `--dry-run` d'abord pour voir ce qui sera changé sans modifier le serveur :

```bash
python3 scripts/sonar_review_hotspots.py --dry-run
```

---

## 9. Lire le rapport

Sur http://localhost:9000/dashboard?id=firstSign :

| Indicateur          | Cible projet              |
|---------------------|---------------------------|
| **Bugs**            | 0 (bloquant en CI)        |
| **Vulnerabilities** | 0                         |
| **Code Smells**     | < 100 (informatif)        |
| **Coverage**        | > 70 % sur `lib/` + `app/controllers/` |
| **Duplications**    | < 3 %                     |
| **Quality Gate**    | **Passed** (vert)         |

Si la **Quality Gate** est rouge :
- Cliquez dessus pour voir **quelle condition** a échoué.
- 99 % du temps : un nouveau bug introduit ou couverture en baisse sur du code modifié.

---

## 10. Problèmes fréquents

### `Math.random is used to generate IDs` apparaît dans le rapport
→ Doit être **0** sur cette branche. Si vous en voyez, c'est qu'un nouveau commit l'a réintroduit. Préférer `crypto.randomUUID()` (voir le pattern dans [signature_step.vue:706](../app/javascript/submission_form/signature_step.vue#L706)).

### Coverage = 0 % sur tous les fichiers
→ Vous avez lancé `sonar-scanner` **sans** `COVERAGE=true bundle exec rspec` au préalable. Refaire l'étape 6.

### `Failed to upload report : Connection refused`
→ Le serveur Sonar n'est pas prêt. `docker ps` doit montrer le conteneur **Up** depuis ≥ 2 min. Sinon `docker logs sonarqube | tail -50`.

### `Not authorized` à la fin du scan
→ Le token est invalide ou expiré. Régénérez-le : http://localhost:9000/account/security → **Generate Token**.

### Ubuntu : `vm.max_map_count is too low`
→ ElasticSearch (embarqué) exige une limite plus haute :
```bash
sudo sysctl -w vm.max_map_count=262144
```

### Windows : `libvips not found` quand `bundle exec rspec` tourne
→ Le projet utilise `ruby-vips` qui ne s'installe **pas proprement** sous Windows natif. Utiliser **WSL2** :
```powershell
wsl --install -d Ubuntu-22.04
```
puis suivre la procédure Ubuntu **depuis WSL**.

### `bundle install` échoue sur `libpdfium`
→ Installer la lib système :
- **Ubuntu** : télécharger `libpdfium.so` depuis `docusealco/pdfium-binaries` (Releases GitHub) et la placer dans `/usr/lib/`.
- **WSL2** : idem qu'Ubuntu.

### Le scanner ne voit pas les fichiers `.vue`
→ Le bridge JS/TS est exclu via [sonar-project.properties:21-22](../sonar-project.properties#L21-L22). Les `.vue` sont analysés **via le bridge HTML/JS** automatiquement, pas besoin d'action.

### Je veux re-scanner une branche différente
→ Pas besoin de recréer le projet Sonar : changez de branche dans Git, relancez les étapes 6 et 7. La clé projet (`firstSign`) reste la même ; SonarQube stocke chaque analyse comme une nouvelle version.

---

## 11. Récapitulatif — la check-list courte

Une fois tout installé, à chaque nouvelle analyse :

```bash
# 1. Démarrer Sonar (s'il est arrêté)
docker start sonarqube

# 2. Lancer la suite avec couverture
COVERAGE=true bundle exec rspec

# 3. Lancer le scan
sonar-scanner -Dsonar.token=$SONAR_TOKEN
```

C'est tout. Ouvrez ensuite http://localhost:9000/dashboard?id=firstSign.

---

## 12. Pour aller plus loin

- **Documentation officielle** : https://docs.sonarsource.com/sonarqube-community/
- **Liste des règles Ruby/JS appliquées** : http://localhost:9000/profiles (page **Quality Profiles**)
- **Modifier les exclusions / règles ignorées** : éditer [sonar-project.properties](../sonar-project.properties) en suivant la convention déjà en place (chaque section porte un commentaire qui explique le **pourquoi**).
- **Ajouter une règle à ignorer** : ajouter une entrée à la liste `sonar.issue.ignore.multicriteria`, puis définir `ruleKey` et `resourceKey`. Documenter le **pourquoi** au-dessus.

> ⚠️ **Ne supprimez jamais** une exclusion sans comprendre pourquoi elle est là. Chaque entrée est annotée — lisez le commentaire avant de modifier.
