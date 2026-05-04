# Session Context - Backend Analysis & Flutter Integration

## Date: 2026-05-01

## Ce qui a été fait

### 1. Analyse du Backend
- Backend Node.js/Express avec Socket.IO pour le temps réel
- MySQL (mysql2) + Firebase Admin pour notifications push
- Architecture modulaire: routes, contrôleurs, middleware séparés
- Points forts: Modularité, JWT (access/refresh), bcrypt, rate limiting
- Points de vigilance: Requêtes SQL brutes, server.js monolithique, pas de tests

### 2. Fichiers créés pour Flutter

#### talky_api_client.dart
Client API complet avec:
- Auth (register, login, refresh token, reset password, getMe, updateMe)
- Users (getUsers, getUser, searchUsers)
- Contacts (getContacts, addContact, removeContact, checkIsContact)
- Conversations (getConversations, createConversation, getConversation)
- Messages (getMessages, sendMessage, deleteMessage)
- Calls (initiateCall, endCall)
- Meetings (createMeeting, getMeetings)
- Upload de fichiers
- Socket.IO intégré

#### talky_models.dart
Modèles de données:
- User, Message, Conversation, Call, Meeting
- SocketEvents (constantes pour tous les événements Socket.IO)

### 3. Configuration pour Flutter (pubspec.yaml)
```yaml
dependencies:
  http: ^1.1.0
  socket_io_client: ^2.0.3
  shared_preferences: ^2.2.0
```

### 4. Prochaines étapes (Frontend)
L'utilisateur veut implémenter:
1. **Appels** (1-1 et groupes) - WebRTC signaling via Socket.IO
2. **Meetings** - Gestion complète via Socket.IO

## Structure Backend pertinente pour le Frontend

### URLs
- API Base: `http://192.168.1.1:3000/api`
- Socket: `http://192.168.1.1:3000`
- Health: `/health`

### Événements Socket.IO importants
- Auth: `auth`, `authenticated`, `auth_error`
- Présence: `user_online`, `user_offline`
- Chat: `join_conversation`, `message:send`, `message:new`, `typing:start`, `typing:stop`
- Appels 1-1: `call:user`, `call:incoming`, `call:answer`, `call:reject`, `call:end`, `ice:candidate`, `offer`, `answer`
- Appels groupe: `group_call:create`, `group_call:join`, `group_call:leave`, `group_call:end`, `group:offer`, `group:answer`, `group:ice_candidate`
- Meetings: `meeting:create`, `meeting:join_room`, `meeting:join_request`, `meeting:join_accept`, `meeting:join_decline`, `meeting:start`, `meeting:end`, `meeting:chat`, `meeting:leave`, `meeting:offer`, `meeting:answer`, `meeting:ice_candidate`

## Notes importantes
- Le frontend n'a pas été trouvé au chemin `/home/chris-manuel/alanya/frontend/`
- À vérifier: le dossier frontend existe-t-il? Nom différent?
- Les fichiers Dart créés sont dans `/home/chris-manuel/alanya/backend/`
- À déplacer dans `lib/` du projet Flutter
