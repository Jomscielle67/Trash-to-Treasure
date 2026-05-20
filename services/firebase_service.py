import firebase_admin
from firebase_admin import credentials, firestore, storage, auth

cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred, {
    "storageBucket": "trash-to-treasure-76528.appspot.com"   # match your Firebase bucket name
})

db = firestore.client()
bucket = storage.bucket()