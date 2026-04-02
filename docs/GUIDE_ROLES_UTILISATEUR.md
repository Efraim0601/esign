# Guide utilisateur — rôles AFB et parcours métier

Ce document décrit les **rôles** (profils AFB), le **parcours** depuis la connexion jusqu’à l’assignation des signataires, et des **cas d’usage** types. Il complète la matrice de droits implémentée dans `lib/ability.rb`.

---

## 0. Compte administrateur par défaut (déploiement self-hosted)

Lors du premier démarrage en **production** (hors mode multitenant), si aucun utilisateur n’existe encore avec l’e-mail configuré, l’application crée automatiquement :

- **E-mail** : `admin@afb.com` (surchargeable avec `DEFAULT_ADMIN_EMAIL`)
- **Mot de passe** : `admin` (surchargeable avec `DEFAULT_ADMIN_PASSWORD` ; si vous mettez moins de 6 caractères, le hash est appliqué hors validation Devise, car Devise impose normalement 6 caractères minimum)

Compte **AFB** minimal : nom `AFB`, fuseau `UTC`, langue `fr-FR` (variables `DEFAULT_ACCOUNT_NAME`, `DEFAULT_ACCOUNT_TIMEZONE`, `DEFAULT_ACCOUNT_LOCALE`).

Désactiver la création automatique : `DEFAULT_ADMIN_SEED=false`.

**Sécurité** : changez ce mot de passe immédiatement après le premier accès (profil ou console Rails).

---

## 1. Les cinq rôles (résumé)

| Rôle | Rôle métier type | En pratique |
|------|------------------|-------------|
| **Administrateur** | Admin système | Tout le périmètre : compte, utilisateurs, rôles, SMTP, API, webhooks, branding, modèles, toutes les soumissions. |
| **Éditeur** | Chef de service, secrétariat de direction | Tout le cycle documentaire (modèles, dossiers, envois, suivi de **toutes** les soumissions du compte). **Pas** d’accès aux paramètres « plateforme » (compte institutionnel, SMTP, clé API, webhooks, configs chiffrées). |
| **Membre** | Responsable, manager | **Ses** modèles : création, modification, suppression. **Lecture** des modèles des autres ; duplication et envoi à partir des modèles disponibles. **Ses** soumissions en modification complète ; **lecture seule** sur les soumissions des collègues (pas d’archivage / BCC / annulation / renvoi sur leurs envois). |
| **Agent** | Collaborateur, agence | **Lecture** des modèles existants, **envoi** pour signature, **suivi uniquement de ses propres** soumissions. Pas de création ni modification de modèles ; pas de gestion des dossiers au sens « organisation ». |
| **Observateur** | Auditeur, contrôle | **Consultation** des modèles, soumissions et tableaux de bord. Aucune action d’envoi, de modification de signataire, de création de dossier ou de paramétrage. |

---

## 2. Connexion

1. Ouvrir l’URL de l’application (HTTP/HTTPS selon votre déploiement).
2. Saisir **e-mail** et **mot de passe** (écran de session Devise à la racine de l’app).
3. Si la **double authentification** est exigée pour votre compte, saisir le code à l’étape suivante.
4. Après connexion, vous arrivez sur le **tableau de bord** ; le menu et les actions disponibles dépendent de votre **rôle**.

**Cas d’usage**

- **Première installation** : un assistant crée le compte via l’assistant initial (`/setup`) ; le premier utilisateur reçoit le rôle par défaut (**Agent**) tant qu’un administrateur ne le promeut pas.
- **Réinvitation** : un administrateur régénère une invitation ; l’utilisateur définit son mot de passe via le lien reçu par e-mail.

---

## 3. Chargement et organisation des dossiers (modèles)

Les **dossiers** structurent les **modèles** (templates) dans l’interface.

| Rôle | Dossiers / arborescence |
|------|-------------------------|
| Administrateur, Éditeur, Membre | Peuvent **créer, renommer, déplacer** des dossiers et y classer les modèles. |
| Agent | **Consultation** de l’arborescence ; pas de gestion des dossiers. |
| Observateur | **Consultation** uniquement (pas de création ni réorganisation). |

**Cas d’usage — Membre**

1. Se connecter.
2. Ouvrir la liste des **modèles**.
3. Créer un **dossier** « Contrats 2026 » et y déposer un nouveau modèle ou en déplacer un existant **dont il est auteur**.
4. Ouvrir un modèle **d’un collègue** : il peut le **lire** et le **dupliquer** pour préparer un envoi, sans modifier l’original.

**Cas d’usage — Agent**

1. Parcourir les dossiers pour **trouver** le modèle imposé par la procédure.
2. Ouvrir le modèle et lancer un **envoi pour signature** (sans modifier la structure du modèle).

---

## 4. Assignation des personnes pour signer

Le flux type est : **modèle → nouvelle soumission → signataires (ordre, e-mails, champs)** → envoi.

| Rôle | Créer une soumission | Modifier les signataires (avant signature) | Renvoi / annulation |
|------|----------------------|--------------------------------------------|---------------------|
| Administrateur, Éditeur | Oui, sur tout modèle du compte | Oui, pour **toutes** les soumissions | Oui, sur toutes |
| Membre | Oui (modèles visibles / duplicables selon les règles du compte) | Oui pour **ses** soumissions ; **non** pour celles des autres | Idem (propre / autres) |
| Agent | Oui à partir des modèles existants | Oui **uniquement** pour **ses** soumissions | Renvoi / annulation **uniquement** sur **ses** soumissions |
| Observateur | Non | Non | Non |

Les **champs** du formulaire de signataire (nom, e-mail, message, etc.) ne sont modifiables par les rôles **Agent** et **Membre** que si la soumission est **la leur** (créateur de la soumission). L’**Observateur** ne modifie jamais les fiches signataires.

**Cas d’usage — Éditeur**

1. Ouvrir un modèle critique.
2. Cliquer pour **ajouter des destinataires** et définir l’ordre de signature.
3. Envoyer ; suivre l’état dans la liste globale des soumissions.
4. En cas de blocage, **renvoyer l’invitation** ou **annuler** même si le dossier a été créé par un autre utilisateur.

**Cas d’usage — Agent terrain**

1. Choisir le modèle « Mandat agence X ».
2. Saisir les e-mails des clients et envoyer.
3. Corriger une coquille sur un signataire **avant** ouverture du formulaire — **uniquement** sur **cette** soumission.
4. Ne pas voir les soumissions créées par le siège (hors périmètre « propre ») : pas d’accès détail, pas d’actions.

**Cas d’usage — Observateur (audit)**

1. Consulter la **liste des soumissions** et ouvrir une fiche pour preuve ou contrôle.
2. Télécharger les pièces / consulter l’audit si l’interface le propose en lecture.
3. Aucune action qui ferait progresser ou modifier le circuit de signature.

---

## 5. Paramètres et administration (réservés en grande partie à l’admin)

Actions typiquement réservées à l’**Administrateur** :

- Utilisateurs et **rôles** (`/settings/users`, édition d’un utilisateur — hors auto-modification du rôle).
- **Compte** institutionnel (nom, langue, fuseau, URL en self-hosted).
- **SMTP**, **webhooks**, **clé API**, **branding**, stockage, certificats e-sign, etc.

L’**Éditeur** n’accède pas à ces écrans au niveau des autorisations ; il reste concentré sur les **documents**.

---

## 6. Récapitulatif visuel du parcours

```text
Connexion
    → Tableau de bord
        → Dossiers / modèles (lecture ou gestion selon rôle)
            → Nouvelle soumission (si autorisé)
                → Signataires + envoi
                    → Suivi (étendue selon rôle : toutes les soumissions vs les siennes uniquement)
```

---

## 7. Fichiers techniques de référence

- Matrice CanCan : `lib/ability.rb`
- Tests RSpec associés : `spec/models/ability_spec.rb`
- Journal des changements de rôle (mail + historique) : modèle `RoleChangeLog`, édition utilisateur

Pour toute évolution des règles métier, aligner **en priorité** la matrice AFB, puis `ability.rb`, puis les specs.
