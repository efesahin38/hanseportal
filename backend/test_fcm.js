const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const token = 'fLWUq5SstEC8jP2aP-FYP_:APA91bFQ1yLpLMOTFrj6FVR_OT570X3SGuDlP2cO0TbQ4uSC_8dfE7lLWFrB9nzAblc5S3haXyM0FyoBpoesjtVcIA9HEHQS2x53Iq0gIXhlybHD4gZlnzY';

const message = {
  notification: {
    title: 'Test Bildirimi',
    body: 'Bu bir test bildirimidir.'
  },
  token: token
};

admin.messaging().send(message)
  .then((response) => {
    console.log('Successfully sent message:', response);
    process.exit(0);
  })
  .catch((error) => {
    console.error('Error sending message:', error);
    process.exit(1);
  });
