# Commit Alanya-Backend — Phase 6.3–7 (manuel)

L’agent n’a pas pu écrire dans `.git` d’Alanya-Backend (permissions FS).
Les fichiers de code/tests sont déjà sur le disque. Depuis un shell avec
droits normaux :

```bash
cd /home/chris/Alanya-Backend

git add package.json scripts/bench/ \
  src/notifications/apnsVoipProvider.js \
  src/notifications/apnsVoipProvider.test.js \
  src/notifications/notificationPrefs.test.js \
  src/notifications/notificationCallRouting.test.js \
  src/notifications/notificationIdempotence.test.js \
  src/notifications/notificationTokenStale.test.js \
  src/services/notificationService.js \
  src/socket/handlers/calls.js \
  src/socket/state/callState.js \
  src/socket/state/callState.test.js

git commit -m "$(cat <<'EOF'
feat(notifications): Phase 7 tests, bench push et fix glare appels

Complète la suite test:notifications:full, le bench mock P50/P95/P99
et le correctif anti-faux-busy (glare) côté socket.
EOF
)"

npm run test:notifications:full
```

Migrations staging (depuis un réseau qui atteint MySQL) :

```bash
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" \
  < migrations/020_user_push_devices.sql
# puis 021, 022 — détail dans docs/notifications_rollout.md (Talky)
```
