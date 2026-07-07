// firebase-messaging-sw.js
//
// Service worker FCM pour Talky PWA. Affiche une notification quand un push
// data arrive alors que l'app est fermée ou en background.
// Les pushs `type=call|group_call` reçoivent des actions Accepter/Refuser
// directement depuis la notification.

importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

// Config Firebase Talky (projet talky-2026, app Web). Doit rester synchronisée
// avec lib/firebase_options.dart (DefaultFirebaseOptions.web).
firebase.initializeApp({
  apiKey: "AIzaSyCXkmcbAl8nY3T4PRaj2Am9AQNSO-jAjP4",
  authDomain: "talky-2026.firebaseapp.com",
  databaseURL: "https://talky-2026-default-rtdb.firebaseio.com",
  projectId: "talky-2026",
  storageBucket: "talky-2026.firebasestorage.app",
  messagingSenderId: "778851391746",
  appId: "1:778851391746:web:476fc08a445b652a014a1b",
  measurementId: "G-TGJXMRMJYZ" 
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const data = payload.data || {};
  const type = data.type;

  const baseTitle = data.title || 'Talky';
  const baseBody = data.body || '';

  if (type === 'call' || type === 'group_call') {
    self.registration.showNotification(baseTitle, {
      body: baseBody,
      icon: data.photo || '/icons/Icon-192.png',
      tag: 'incoming-call-' + (data.callId || data.roomId || 'unknown'),
      requireInteraction: true,
      renotify: true,
      vibrate: [400, 200, 400, 200, 400],
      actions: [
        { action: 'accept', title: 'Accepter' },
        { action: 'decline', title: 'Refuser' },
      ],
      data,
    });
    return;
  }

  // Message standard, statut, invitation meeting…
  const isMeeting = type === 'meeting_invite' || type === 'meeting_reminder';
  let tag;
  if (data.conversationId) {
    tag = 'conv-' + data.conversationId;
  } else if (isMeeting && data.meetingId) {
    tag = 'meeting-' + data.meetingId;
  }

  self.registration.showNotification(baseTitle, {
    body: baseBody,
    icon: '/icons/Icon-192.png',
    tag,
    data,
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const data = event.notification.data || {};
  const action = event.action || 'open';

  let target = '/';
  if (data.type === 'call' || data.type === 'group_call') {
    const callKey = data.callId || data.roomId || '';
    target = `/?incomingCall=${encodeURIComponent(callKey)}&action=${action}&callerId=${encodeURIComponent(data.callerId || '')}&isVideo=${data.isVideo || 'false'}&roomId=${encodeURIComponent(data.roomId || '')}`;
  } else if (data.conversationId) {
    target = `/?conversationId=${encodeURIComponent(data.conversationId)}`;
  }

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // Si une fenêtre Talky est déjà ouverte, lui passer l'action
      for (const client of clientList) {
        if ('focus' in client) {
          client.postMessage({ source: 'firebase-messaging-sw', target, data, action });
          return client.focus();
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow(target);
      }
    })
  );
});
