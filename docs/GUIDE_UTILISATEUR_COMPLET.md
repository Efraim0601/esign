# Guide Utilisateur Complet - FirstSign

**Plateforme de signature électronique de Afriland First Bank**

---

## Table des matières

1. [Présentation de la solution](#1-présentation-de-la-solution)
2. [Concepts fondamentaux](#2-concepts-fondamentaux)
3. [Rôles et permissions](#3-rôles-et-permissions)
4. [Premiers pas](#4-premiers-pas)
5. [Gestion des modèles (templates)](#5-gestion-des-modèles-templates)
6. [Types de champs disponibles](#6-types-de-champs-disponibles)
7. [Envoi de documents pour signature](#7-envoi-de-documents-pour-signature)
8. [Signature par le destinataire](#8-signature-par-le-destinataire)
9. [Scénarios avancés](#9-scénarios-avancés)
10. [Suivi et tableau de bord](#10-suivi-et-tableau-de-bord)
11. [Piste d'audit et conformité](#11-piste-daudit-et-conformité)
12. [Notifications et emails](#12-notifications-et-emails)
13. [Administration](#13-administration)
14. [API et intégrations](#14-api-et-intégrations)
15. [Sécurité et conformité](#15-sécurité-et-conformité)
16. [Dépannage et FAQ](#16-dépannage-et-faq)

---

## 1. Présentation de la solution

### 1.1 Objectif

**FirstSign** est la plateforme de signature électronique interne d'**Afriland First Bank**, conçue pour :

- Éliminer la circulation de documents papier au sein de l'organisation
- Accélérer les processus d'approbation et de validation documentaire
- Garantir la traçabilité et la valeur probante des signatures
- Sécuriser les échanges contractuels avec clients, partenaires et employés
- Fournir un référentiel centralisé des documents signés

### 1.2 À qui s'adresse cette solution ?

FirstSign répond aux besoins de plusieurs familles d'utilisateurs :

- **Directions métier** : conventions de compte, contrats de crédit, ouvertures de compte
- **Ressources humaines** : contrats de travail, avenants, attestations
- **Conformité et audit** : KYC, déclarations, attestations réglementaires
- **Opérations** : bons de commande, ordres de virement, approbations internes
- **Juridique** : contrats commerciaux, NDAs, protocoles d'accord

### 1.3 Bénéfices clés

| Bénéfice | Détail |
|----------|--------|
| **Gain de temps** | Signature en quelques minutes au lieu de plusieurs jours |
| **Traçabilité complète** | Chaque action est horodatée et enregistrée |
| **Valeur probante** | Signatures cryptographiques conformes aux standards PDF |
| **Multi-signataires** | Workflows séquentiels ou parallèles |
| **Self-service** | Les utilisateurs gèrent leurs propres envois |
| **Intégration** | API REST et webhooks pour automatiser les processus |

---

## 2. Concepts fondamentaux

Avant d'utiliser la plateforme, il est essentiel de comprendre les notions clés.

### 2.1 Modèle (Template)

Un **modèle** est un document réutilisable qui définit :

- Le document PDF de base
- Les champs à remplir (texte, signature, date, etc.)
- Les signataires attendus et leur ordre
- Les préférences d'envoi (emails, expiration, rappels)

> Exemple : un modèle « Contrat de travail CDI » peut être utilisé pour générer 100 contrats pour 100 nouveaux employés.

### 2.2 Soumission (Submission)

Une **soumission** est une instance concrète d'un modèle envoyée à des personnes spécifiques pour signature.

> Exemple : « Contrat de travail CDI - Jean Dupont » est une soumission basée sur le modèle « Contrat de travail CDI ».

### 2.3 Signataire (Submitter)

Un **signataire** est une personne invitée à remplir ou signer une soumission. Une soumission peut avoir un ou plusieurs signataires.

### 2.4 Piste d'audit (Audit trail)

Document PDF généré automatiquement recensant tous les événements liés à une soumission : ouverture, consultation, saisie, signature, horodatage, adresse IP.

### 2.5 Cycle de vie d'un document

```
   Modèle créé
        │
        ▼
   Soumission créée ──► Email envoyé aux signataires
                              │
                              ▼
                        Signataire ouvre le lien
                              │
                              ▼
                        Formulaire rempli et signé
                              │
                              ▼
                 ┌────────────┴────────────┐
                 ▼                         ▼
           Tous signé ?                Refusé / Expiré
                 │                         │
                 ▼                         ▼
          Document final            Soumission clôturée
          + Piste d'audit
          + Notifications
```

---

## 3. Rôles et permissions

FirstSign implémente un système de contrôle d'accès basé sur 5 rôles hiérarchiques.

### 3.1 Tableau synoptique des rôles

| Rôle | Modèles | Soumissions | Signataires | Paramètres | Utilisateurs |
|------|---------|-------------|-------------|------------|--------------|
| **Administrateur** | Tous (CRUD) | Toutes (CRUD) | Tous (CRUD) | Accès complet | Gestion complète |
| **Éditeur** | Tous (CRUD) | Toutes (CRUD) | Tous (CRUD) | Aucun accès | Lecture seule |
| **Membre** | Les siens (CRUD) | Les siennes (CRUD) | Les siens (CRUD) | Aucun accès | Lecture seule |
| **Agent** | Lecture seule | Les siennes (CRUD) | Les siens (CRUD) | Aucun accès | Lecture seule |
| **Observateur** | Lecture seule | Lecture seule | Lecture seule | Aucun accès | Lecture seule |

### 3.2 Profils types

- **Administrateur** : responsable IT, administrateur système
- **Éditeur** : chef de département, secrétariat général
- **Membre** : responsable d'unité, manager
- **Agent** : collaborateur terrain, chargé de clientèle
- **Observateur** : auditeur interne, contrôleur

> Pour une description détaillée, consulter [docs/GUIDE_ROLES_UTILISATEUR.md](GUIDE_ROLES_UTILISATEUR.md).

---

## 4. Premiers pas

### 4.1 Connexion à la plateforme

1. Ouvrez votre navigateur à l'URL fournie par votre administrateur
2. Saisissez votre email professionnel et votre mot de passe
3. Si l'authentification à deux facteurs (2FA) est activée :
   - Ouvrez votre application TOTP (Google Authenticator, Microsoft Authenticator)
   - Saisissez le code à 6 chiffres affiché
4. Vous arrivez sur le tableau de bord des soumissions

### 4.2 Première connexion (réception d'une invitation)

1. Vous recevez un email « Invitation à FirstSign » avec un lien de définition de mot de passe
2. Cliquez sur le lien (valable 24h)
3. Définissez un mot de passe fort (min. 8 caractères, mélange de lettres/chiffres/symboles)
4. Confirmez le mot de passe
5. Vous êtes redirigé vers la plateforme

### 4.3 Configuration de l'authentification à deux facteurs

Pour activer la 2FA sur votre compte :

1. Cliquez sur votre profil en haut à droite
2. Sélectionnez **« Configurer la 2FA »**
3. Scannez le QR code avec votre application d'authentification
4. Saisissez le code de validation
5. Sauvegardez les codes de récupération en lieu sûr

### 4.4 Mot de passe oublié

1. Sur la page de connexion, cliquez sur **« Mot de passe oublié »**
2. Saisissez votre email professionnel
3. Consultez votre boîte mail pour le lien de réinitialisation
4. Définissez un nouveau mot de passe

---

## 5. Gestion des modèles (templates)

### 5.1 Créer un nouveau modèle

**Étape 1 : Charger le document**

1. Naviguez vers **Modèles > Nouveau modèle**
2. Donnez un nom explicite au modèle (ex. « Contrat de prêt immobilier »)
3. Téléversez un fichier PDF ou DOCX
4. Attendez l'analyse automatique du document

**Étape 2 : Ajouter les champs**

Dans l'éditeur visuel :

1. Sélectionnez un type de champ dans la barre latérale gauche
2. Glissez-déposez le champ sur le document à l'emplacement souhaité
3. Ajustez les propriétés dans le panneau de droite :
   - **Nom** du champ
   - **Obligatoire** ou facultatif
   - **Assignation** à un signataire spécifique
   - **Valeur par défaut** (si applicable)
   - **Format** (pour les signatures : dessinée, tapée, téléversée)

**Étape 3 : Définir les signataires**

1. Dans l'onglet « Signataires », ajoutez les rôles (ex. « Client », « Banquier »)
2. Choisissez l'ordre de signature :
   - **Préservé** : signature séquentielle dans un ordre défini
   - **Aléatoire** : tous peuvent signer en parallèle
3. Attribuez les champs à chaque signataire

**Étape 4 : Configurer les préférences**

- Message d'invitation personnalisé
- Message de complétion
- Date d'expiration par défaut
- Activation du chaînage (chain link)
- Attachement de la piste d'audit

**Étape 5 : Enregistrer et tester**

- Sauvegardez le modèle
- Utilisez **« Aperçu »** pour vérifier le rendu
- Testez en vous envoyant une soumission

### 5.2 Organiser les modèles en dossiers

1. Dans la liste des modèles, cliquez sur **« Nouveau dossier »**
2. Donnez un nom (ex. « RH », « Juridique », « Commercial »)
3. Glissez-déposez les modèles dans les dossiers
4. Créez des sous-dossiers pour une organisation hiérarchique

### 5.3 Cloner un modèle

Utile pour créer une variante d'un modèle existant :

1. Ouvrez le modèle source
2. Cliquez sur **« Cloner »** dans le menu d'actions
3. Modifiez le clone selon vos besoins
4. Enregistrez sous un nouveau nom

### 5.4 Archiver un modèle

1. Ouvrez le modèle
2. Cliquez sur **« Archiver »**
3. Le modèle n'apparaît plus dans la liste active mais reste accessible via **« Archivés »**
4. Restaurable à tout moment

---

## 6. Types de champs disponibles

FirstSign propose plus de 15 types de champs pour composer vos formulaires.

| Type | Usage typique |
|------|---------------|
| **Texte** | Nom, adresse, description libre |
| **Signature** | Signature manuscrite (dessinée, tapée ou téléversée) |
| **Paraphe (initiales)** | Paraphe rapide en bas de page |
| **Date** | Sélecteur de date |
| **Date de signature** | Horodatage automatique à la signature |
| **Nombre** | Montant, quantité, identifiant numérique |
| **Image** | Photo d'identité, justificatif visuel |
| **Fichier** | Pièce jointe (PDF, Word, Excel) |
| **Liste déroulante** | Choix unique parmi une liste |
| **Cases à cocher multiples** | Choix multiples |
| **Boutons radio** | Choix unique exclusif |
| **Case à cocher** | Accord / consentement binaire |
| **Cellules** | Tableau structuré |
| **Titre / Libellé** | Texte statique non éditable |
| **Barré** | Texte barré (redaction) |
| **Tampon** | Tampon d'approbation automatique |
| **Téléphone (Pro)** | Vérification par SMS |
| **Pièce d'identité (Pro)** | Vérification par scan d'ID |

### 6.1 Formats de signature

Lors de la configuration d'un champ de type **Signature**, plusieurs formats sont disponibles :

- **Dessinée uniquement** : le signataire trace sa signature
- **Tapée uniquement** : le signataire saisit son nom en police manuscrite
- **Téléversée uniquement** : le signataire téléverse une image de sa signature
- **Combinaisons** : dessinée ou tapée, tapée ou téléversée, etc.

---

## 7. Envoi de documents pour signature

### 7.1 Envoi à un signataire unique

1. Depuis la liste des modèles, sélectionnez le modèle souhaité
2. Cliquez sur **« Envoyer pour signature »**
3. Saisissez :
   - **Email** du signataire
   - **Nom** complet (optionnel)
   - **Téléphone** (si vérification SMS)
4. Préremplissez les champs connus (optionnel)
5. Ajustez la date d'expiration si besoin
6. Cliquez sur **« Envoyer »**
7. Le signataire reçoit un email avec un lien personnalisé

### 7.2 Envoi à plusieurs signataires

1. Même procédure qu'en 7.1
2. Ajoutez plusieurs signataires en cliquant sur **« Ajouter un signataire »**
3. Attribuez chaque signataire à un rôle défini dans le modèle
4. Si ordre préservé : définissez la séquence (1er, 2e, 3e...)
5. Envoyez

### 7.3 Envoi en masse (bulk send)

Pour envoyer le même document à plusieurs destinataires :

1. Préparez un fichier CSV ou Excel avec les colonnes :
   - `email` (obligatoire)
   - `name`
   - `phone`
   - Variables personnalisées (ex. `montant`, `date_contrat`)
2. Depuis le modèle, cliquez sur **« Envoi en masse »**
3. Téléversez le fichier
4. Vérifiez l'aperçu
5. Lancez l'envoi groupé

Exemple de CSV :
```
email,name,phone,montant,date
jean@example.com,Jean Dupont,+237699123456,1500000,2026-01-15
marie@example.com,Marie Nkomo,+237699234567,2500000,2026-01-16
```

### 7.4 Personnalisation de l'email d'invitation

Avant l'envoi, vous pouvez personnaliser :

- **Objet** de l'email
- **Message** d'invitation (prise en charge du HTML)
- **Variables** : `{signer_name}`, `{template_name}`, `{link}`, etc.

---

## 8. Signature par le destinataire

Cette section décrit l'expérience vécue par le signataire (externe ou interne).

### 8.1 Réception de l'invitation

Le signataire reçoit un email contenant :

- L'objet personnalisé (ex. « Contrat de prêt à signer »)
- Le message du demandeur
- Un bouton « Consulter le document »
- Éventuellement un aperçu du document en PJ

### 8.2 Accès au formulaire

1. Clic sur le lien → ouverture dans le navigateur
2. Si 2FA activée :
   - Saisie d'un code reçu par email ou SMS
   - Vérification d'identité
3. Page d'accueil affichant :
   - Le nom du document
   - L'émetteur
   - Un bouton « Commencer »

### 8.3 Remplissage du formulaire

1. Le document s'affiche en pleine largeur
2. Les champs à remplir sont mis en surbrillance
3. Navigation guidée : un bouton indique le champ suivant
4. Validation en temps réel (format email, téléphone, etc.)
5. Barre de progression indiquant le pourcentage complété

### 8.4 Apposition d'une signature

Selon le format configuré :

**Signature dessinée** :
- Tracer au doigt (mobile/tablette) ou à la souris
- Possibilité d'effacer et recommencer
- Validation par bouton **« Confirmer »**

**Signature tapée** :
- Saisie du nom complet
- Choix parmi plusieurs polices manuscrites
- Validation

**Signature téléversée** :
- Sélection d'une image (PNG, JPG)
- Recadrage automatique
- Validation

**Signature par QR code** (scénario mobile) :
- Afficher QR code sur écran desktop
- Scanner avec smartphone
- Signer sur téléphone
- Résultat synchronisé automatiquement

### 8.5 Soumission finale

1. Vérification récapitulative de tous les champs
2. Clic sur **« Signer et envoyer »**
3. Génération du PDF signé
4. Page de confirmation
5. Email avec copie du document signé

### 8.6 Refus de signature

Si le signataire souhaite refuser :

1. Clic sur **« Refuser de signer »**
2. Saisie optionnelle d'un motif
3. Confirmation
4. L'émetteur reçoit une notification de refus
5. La soumission est clôturée avec statut **« Refusée »**

---

## 9. Scénarios avancés

### 9.1 Signature séquentielle (ordre préservé)

**Contexte** : un contrat nécessite la signature du client puis celle du directeur d'agence.

**Déroulement** :

1. Soumission créée avec 2 signataires : [Client, Directeur]
2. Seul le **Client** reçoit l'email initial
3. Le Client signe → le Directeur reçoit automatiquement l'email
4. Le Directeur signe → soumission complétée
5. Tous reçoivent le document final

### 9.2 Signature parallèle (ordre aléatoire)

**Contexte** : une charte interne à signer par plusieurs collaborateurs.

**Déroulement** :

1. Soumission créée avec 5 signataires
2. Les 5 reçoivent l'email simultanément
3. Chacun signe à son rythme
4. Soumission complétée quand le dernier signe

### 9.3 Chaînage (chain link)

**Contexte** : un client veut faire cosigner par son conjoint dont l'email n'était pas connu au départ.

**Déroulement** :

1. Le signataire initial ouvre le formulaire
2. Un bouton **« Inviter un cosignataire »** est disponible
3. Saisie de l'email du cosignataire
4. Le cosignataire reçoit son lien personnel
5. Les deux signatures sont collectées
6. Événement `chain_link_resolve` enregistré dans la piste d'audit

### 9.4 Expiration automatique

- Date d'expiration définie à la création
- Avant expiration : l'email d'invitation fonctionne
- Après expiration : le lien est désactivé
- Webhook `submission.expired` déclenché
- L'émetteur peut relancer une nouvelle soumission

### 9.5 Rappels automatiques

**Prérequis** : configuration dans **Paramètres > Notifications**

- Configurez les intervalles : 1 jour, 3 jours, 7 jours après envoi
- Seuls les signataires n'ayant pas signé reçoivent le rappel
- Personnalisez le message de rappel

### 9.6 Prérempli depuis une API tierce

**Contexte** : intégration CRM qui pré-remplit le contrat avec les données client.

1. Le CRM appelle l'API `POST /api/submissions`
2. Envoie les données via `prefill_data`
3. La plateforme crée la soumission préremplie
4. Le client n'a plus qu'à signer

### 9.7 Documents dynamiques

Pour des documents générés à la volée selon les données (ex. contrat multilingue, clauses conditionnelles) :

- Utilisation des `DynamicDocument` et variables
- Le PDF est généré au moment de l'envoi selon les `variables` fournies

---

## 10. Suivi et tableau de bord

### 10.1 Tableau de bord principal

Accessible depuis l'URL `/submissions`, il affiche :

- **Statistiques** : soumissions en cours, complétées, refusées, expirées
- **Liste filtrable** par :
  - Statut
  - Plage de dates
  - Modèle utilisé
  - Email ou nom du signataire
- **Recherche** textuelle
- **Actions rapides** : téléchargement, relance, archivage

### 10.2 Statuts d'une soumission

| Statut | Signification |
|--------|--------------|
| **En attente** | Créée mais pas encore envoyée |
| **Envoyée** | Email d'invitation délivré |
| **Ouverte** | Signataire a ouvert le lien |
| **Complétée** | Tous les signataires ont signé |
| **Refusée** | Un signataire a refusé |
| **Expirée** | Date d'expiration dépassée |
| **Archivée** | Retirée de la liste active |

### 10.3 Détail d'une soumission

En cliquant sur une soumission, vous accédez à :

- **Aperçu du document** signé ou en cours
- **Liste des signataires** avec leur statut individuel
- **Horodatages** : envoi, ouverture, signature
- **Valeurs des champs** remplis
- **Historique** complet des événements
- **Actions** :
  - Télécharger le PDF
  - Télécharger la piste d'audit
  - Renvoyer l'invitation
  - Archiver
  - Annuler (si non complétée)

### 10.4 Export des données

Depuis un modèle, accédez à **« Exporter les soumissions »** :

- Format : CSV, Excel, PDF
- Filtrage par période
- Inclusion optionnelle des pistes d'audit (archive ZIP)

---

## 11. Piste d'audit et conformité

### 11.1 Qu'est-ce que la piste d'audit ?

Document PDF généré automatiquement qui recense chaque événement lié à une soumission :

- Envoi de l'email d'invitation
- Ouverture du lien
- Consultation du formulaire
- Saisie des champs
- Apposition de signature
- Vérification d'identité (2FA, SMS)
- Soumission finale

Pour chaque événement, la piste capture :

- **Date et heure** précises (UTC)
- **Adresse IP** du signataire
- **User-agent** (navigateur, système d'exploitation)
- **Actions** effectuées

### 11.2 Téléchargement de la piste

1. Ouvrir la soumission
2. Onglet **« Piste d'audit »**
3. Cliquer sur **« Télécharger »**
4. PDF téléchargé avec signature cryptographique

### 11.3 Vérification d'un document signé

La plateforme expose un service de vérification :

1. Naviguez vers **« Vérifier un document »**
2. Téléversez le PDF signé
3. Le système vérifie :
   - Intégrité de la signature
   - Identité du signataire
   - Horodatage
   - Validité du certificat

Résultat : **Valide** ou **Invalide** avec détails.

### 11.4 Événements enregistrés

| Type d'événement | Description |
|------------------|-------------|
| `send_email` | Email d'invitation envoyé |
| `send_reminder_email` | Rappel envoyé |
| `bounce_email` | Email rejeté |
| `start_form` | Formulaire ouvert |
| `view_form` | Page consultée |
| `complete_form` | Formulaire complété |
| `decline_form` | Refus signé |
| `send_2fa_sms` | Code SMS envoyé |
| `send_2fa_email` | Code email envoyé |
| `phone_verified` | Téléphone vérifié |
| `email_verified` | Email vérifié |
| `chain_link_resolve` | Cosignataire invité |
| `api_complete_form` | Signature via API |

---

## 12. Notifications et emails

### 12.1 Types d'emails envoyés

| Email | Destinataire | Déclenchement |
|-------|--------------|---------------|
| **Invitation** | Signataire | À l'envoi de la soumission |
| **Rappel** | Signataire | Selon intervalles configurés |
| **Complétion** | Émetteur | Quand tous ont signé |
| **Refus** | Émetteur | Quand un signataire refuse |
| **Copie du document** | Signataire | À la complétion |
| **Code 2FA** | Signataire | Lors de la vérification |

### 12.2 Personnalisation des emails

**Au niveau du modèle** :

- Objet et corps de l'invitation
- Objet et corps de la complétion
- Message de rappel
- Support HTML et variables

**Au niveau du compte** (administrateur) :

- Modèles d'emails globaux
- Pied de page / signature
- Adresse d'expédition personnalisée
- Domaine de tracking

### 12.3 Suivi de délivrabilité

Dans le détail de la soumission :

- Statut de l'email : envoyé, livré, rebondi
- Détection des plaintes (spam reports)
- Événements d'ouverture et clics (pixel tracking)

---

## 13. Administration

Cette section est réservée aux utilisateurs ayant le rôle **Administrateur**.

### 13.1 Gestion des utilisateurs

**Créer un utilisateur** :

1. **Paramètres > Utilisateurs > Nouveau**
2. Saisissez nom, email, rôle
3. L'utilisateur reçoit un email d'invitation
4. Définition du mot de passe lors de la première connexion

**Modifier un rôle** :

1. Sélectionnez l'utilisateur
2. Changez le rôle dans la liste déroulante
3. Confirmez
4. L'utilisateur reçoit une notification de changement
5. Historique conservé dans le journal des rôles

**Archiver un utilisateur** :

1. Ouvrez la fiche utilisateur
2. Cliquez sur **« Archiver »**
3. L'utilisateur ne peut plus se connecter
4. Ses soumissions restent accessibles

### 13.2 Paramètres du compte

- **Nom de l'entité** (ex. « Afriland First Bank »)
- **Fuseau horaire** par défaut
- **Langue** par défaut (français)
- **Logo** (affiché dans l'interface et les emails)
- **Pied de page** personnalisé

### 13.3 Configuration SMTP

1. **Paramètres > Email SMTP**
2. Renseignez :
   - Serveur (ex. `smtp.afrilandfirstbank.com`)
   - Port (587 pour TLS, 465 pour SSL)
   - Identifiants
   - Adresse d'expédition
3. Testez la connexion
4. Enregistrez

### 13.4 Stockage des fichiers

Choix entre :

- **Disque local** (par défaut pour déploiement on-premises)
- **Amazon S3**
- **Google Cloud Storage**
- **Azure Blob Storage**

Configuration dans **Paramètres > Stockage**.

### 13.5 Webhooks

**Créer un webhook** :

1. **Paramètres > Webhooks > Nouveau**
2. URL de destination
3. Secret HMAC (optionnel, recommandé)
4. Événements à écouter :
   - `submission.created`
   - `submission.completed`
   - `submission.expired`
   - `form.started`
   - `form.viewed`
   - `form.completed`
   - `form.declined`
5. Enregistrez

**Tester un webhook** : bouton **« Envoyer un test »** qui envoie un payload d'exemple.

**Rejouer un webhook échoué** : dans l'historique, bouton **« Rejouer »**.

### 13.6 Gestion des tokens API

1. **Paramètres > API**
2. **Générer un nouveau token**
3. Copiez le token (il ne sera plus affiché)
4. Utilisez-le dans l'en-tête `Authorization: Bearer <token>`
5. Révoquez en cas de compromission

### 13.7 Journal des changements de rôle

Accessible dans **Paramètres > Audit** :

- Ancien rôle
- Nouveau rôle
- Administrateur ayant opéré le changement
- Horodatage
- Motif (optionnel)

---

## 14. API et intégrations

### 14.1 Authentification

Toutes les requêtes API requièrent un token :

```
Authorization: Bearer <votre_token>
Content-Type: application/json
```

### 14.2 Principaux endpoints

| Méthode | Endpoint | Rôle |
|---------|----------|------|
| `GET` | `/api/templates` | Lister les modèles |
| `GET` | `/api/templates/:id` | Détails d'un modèle |
| `POST` | `/api/submissions` | Créer une soumission |
| `GET` | `/api/submissions` | Lister les soumissions |
| `GET` | `/api/submissions/:id` | Détails d'une soumission |
| `DELETE` | `/api/submissions/:id` | Supprimer une soumission |
| `GET` | `/api/submitters` | Lister les signataires |
| `PATCH` | `/api/submitters/:id` | Mettre à jour un signataire |
| `POST` | `/api/attachments` | Téléverser un fichier |
| `POST` | `/api/tools/merge` | Fusionner des PDFs |
| `POST` | `/api/tools/verify` | Vérifier une signature |

### 14.3 Exemple : créer une soumission

```bash
curl -X POST https://firstsign.afrilandfirstbank.com/api/submissions \
  -H "Authorization: Bearer VOTRE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "template_id": "abc123",
    "submitters": [
      {
        "email": "client@example.com",
        "name": "Jean Dupont",
        "role": "Client"
      }
    ],
    "send_email": true,
    "expire_at": "2026-05-21T23:59:59Z"
  }'
```

### 14.4 Documentation OpenAPI

Spécification complète disponible à l'URL `/docs/openapi.json` ou dans le fichier [docs/openapi.json](openapi.json).

### 14.5 Composants embarqués

Pour intégrer FirstSign dans une application tierce :

- **React** : package `@docuseal/docuseal-react`
- **Vue** : package `@docuseal/docuseal-vue`
- **Angular** : package `@docuseal/docuseal-angular`
- **JavaScript vanilla** : snippet intégrable

Consultez [docs/embedding/](embedding/) pour les guides complets.

### 14.6 Webhooks : structure d'un payload

```json
{
  "event_type": "form.completed",
  "event_timestamp": "2026-04-21T10:30:00Z",
  "data": {
    "submission_id": "uuid",
    "submitter": {
      "id": "uuid",
      "email": "client@example.com",
      "name": "Jean Dupont",
      "completed_at": "2026-04-21T10:30:00Z"
    },
    "values": {
      "field_uuid_1": "valeur1",
      "field_uuid_2": "valeur2"
    }
  }
}
```

En-tête de signature HMAC : `X-Docuseal-Signature: sha256=<hash>`

---

## 15. Sécurité et conformité

### 15.1 Chiffrement

- **En transit** : HTTPS/TLS obligatoire (via Caddy)
- **Au repos** : champs sensibles chiffrés en base
- **Stockage** : fichiers chiffrés dans ActiveStorage

### 15.2 Authentification

- Mots de passe hachés (bcrypt via Devise)
- 2FA TOTP (Google Authenticator, Microsoft Authenticator)
- Limitation des tentatives (protection brute force)
- Sessions sécurisées avec Redis

### 15.3 Signature électronique

- Standards : PDF Signature SMIME/CMS
- Certificat serveur (configurable)
- Horodatage cryptographique
- Support LTV (Long-Term Validation) en option Pro
- Vérification tierce possible (Adobe Reader, etc.)

### 15.4 Protection des données

- Conformité RGPD / loi sur la protection des données
- Données hébergées sur infrastructure interne AFB
- Droit à l'effacement : archivage et suppression possibles
- Logs de sécurité centralisés

### 15.5 Audit et traçabilité

- Tous les événements significatifs sont loggés
- Piste d'audit infalsifiable (PDF signé)
- Journal des actions administratives
- Historique des changements de rôle

---

## 16. Dépannage et FAQ

### 16.1 Je ne reçois pas l'email d'invitation

1. Vérifiez le dossier **Spam / Indésirables**
2. Demandez à l'émetteur de **« Renvoyer l'invitation »**
3. Vérifiez avec l'administrateur que votre email est bien orthographié
4. En cas de rebond, contactez votre administrateur SMTP

### 16.2 Le lien de signature ne fonctionne plus

Causes possibles :
- Le lien a **expiré** (date d'expiration dépassée)
- La soumission a été **archivée** par l'émetteur
- Un autre signataire a **refusé**, clôturant la soumission

**Solution** : contactez l'émetteur pour relancer.

### 16.3 J'ai signé par erreur

Une fois la signature apposée, **elle ne peut pas être retirée**. Contactez l'émetteur pour :
- Annuler la soumission
- Générer une nouvelle soumission corrective

### 16.4 Je n'arrive pas à dessiner ma signature

- Sur mobile/tablette : utilisez le doigt ou un stylet
- Sur desktop : utilisez la souris ou un pavé tactile
- Alternative : choisissez le format **« Signature tapée »** si disponible
- Alternative : téléversez une image de signature

### 16.5 J'ai oublié mon mot de passe

Utilisez le lien **« Mot de passe oublié »** sur la page de connexion (voir section 4.4).

### 16.6 Je n'ai plus accès à mon application 2FA

Contactez votre administrateur qui peut :
- Désactiver temporairement la 2FA sur votre compte
- Vous demander de la reconfigurer avec un nouveau dispositif

### 16.7 Comment supprimer définitivement une soumission ?

Seuls les administrateurs peuvent supprimer définitivement une soumission :

1. Ouvrir la soumission
2. **Actions > Supprimer définitivement**
3. Confirmation requise
4. Attention : action irréversible

### 16.8 Puis-je modifier un document après envoi ?

Non, un document envoyé pour signature est figé. Pour modifier :

1. Annulez la soumission en cours
2. Modifiez le modèle
3. Créez une nouvelle soumission

### 16.9 Combien de temps sont conservés les documents ?

- Par défaut : conservation indéfinie
- Politique configurable par l'administrateur
- Suppression manuelle possible à tout moment

### 16.10 Les documents signés sont-ils juridiquement valables ?

Oui, les signatures produites par FirstSign :
- Respectent les standards PDF (SMIME/CMS)
- Sont horodatées cryptographiquement
- Sont liées à une piste d'audit complète
- Valeur probante reconnue selon le cadre légal applicable

Pour les signatures qualifiées (eIDAS niveau 3), des modules complémentaires peuvent être activés.

---

## Ressources complémentaires

- **Guide des rôles** : [docs/GUIDE_ROLES_UTILISATEUR.md](GUIDE_ROLES_UTILISATEUR.md)
- **Architecture technique** : [docs/architecture.md](architecture.md)
- **Guides d'intégration** : [docs/embedding/](embedding/)
- **Spécification API** : [docs/openapi.json](openapi.json)
- **Webhooks** : [docs/webhooks/](webhooks/)

---

## Support

Pour toute question ou incident :

- **Administrateur FirstSign** : contactez votre administrateur système interne
- **Support technique** : via le canal interne AFB
- **Formation** : sessions disponibles auprès du département Formation

---

*Document version 1.0 - Dernière mise à jour : 2026-04-21*
*© Afriland First Bank - Tous droits réservés*
