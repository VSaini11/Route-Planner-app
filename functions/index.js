// When the admin sends a route, push a notification to the worker's phone.
// Deploy:  cd functions && npm install && firebase deploy --only functions
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

exports.sendRouteNotification = onDocumentCreated("notifyQueue/{id}", async (event) => {
  const d = event.data.data();
  const user = await getFirestore().collection("users").doc(d.toUid).get();
  const token = user.exists ? user.data().fcmToken : null;
  if (!token) return;
  await getMessaging().send({
    token,
    notification: { title: d.title, body: d.body },
    android: { priority: "high", notification: { channelId: "plans" } },
  });
});
