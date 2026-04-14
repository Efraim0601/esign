# Projet : DocuSeal AFB — Système RBAC 

## Stack technique 
- Ruby on Rails (backend) 
- Vue.js + ERB (frontend)   
- Tailwind CSS (styles) 
- SQLite dev / PostgreSQL prod 

## Objectif Ajouter 5 rôles : admin, editor, member, agent, viewer La fonctionnalité "roles" est absente de la version open source. 

## Fichiers importants 
- app/models/user.rb → modèle utilisateur 
- app/controllers/application_controller.rb → base des controllers 
- db/schema.rb → structure de la base de données 
- config/routes.rb → les URLs de l'application

## Règle RBAC admin > editor > member > agent > viewer