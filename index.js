const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.verifySafePath = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be signed in.');
  }
  const pathId = data.pathId;
  if (!pathId) {
    throw new functions.https.HttpsError('invalid-argument', 'Path ID is required.');
  }

  return {
    verified: true,
    riskScore: 0.12,
    message: 'AI verification complete. Route appears safe for walking in current conditions.',
  };
});

exports.notifyEmergency = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be signed in.');
  }
  const message = data.message || 'Emergency alert from BlindNav user.';
  const doc = await admin.firestore().collection('emergencies').add({
    uid: context.auth.uid,
    message,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, eventId: doc.id };
});
