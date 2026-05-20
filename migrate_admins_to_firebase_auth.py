"""
Migration Script: Add Firebase Authentication to Existing Admins
This script creates Firebase Auth users for admins who don't have them yet.
"""

from firebase_admin import auth as firebase_auth
from services.firebase_service import db
from models.admin_model import Admin

def check_admin_firebase_auth_status():
    """Check which admins have Firebase Auth accounts"""
    print("=" * 80)
    print("ADMIN FIREBASE AUTHENTICATION STATUS CHECK")
    print("=" * 80)
    
    # Get all admins from Firestore
    admins = Admin.get_all_admins()
    
    if not admins:
        print("\n❌ No admins found in Firestore!")
        return
    
    print(f"\nFound {len(admins)} admin(s) in Firestore\n")
    
    admins_with_auth = []
    admins_without_auth = []
    admins_with_mismatch = []
    
    for admin in admins:
        print(f"Checking: {admin.email}")
        print(f"  Firestore Doc ID: {admin.id}")
        
        try:
            # Try to get Firebase Auth user
            firebase_user = firebase_auth.get_user_by_email(admin.email)
            print(f"  Firebase Auth UID: {firebase_user.uid}")
            
            if admin.id == firebase_user.uid:
                print(f"  ✅ Status: PERFECT - IDs match!")
                admins_with_auth.append({
                    'email': admin.email,
                    'uid': firebase_user.uid,
                    'match': True
                })
            else:
                print(f"  ⚠️  Status: ID MISMATCH - Needs migration!")
                admins_with_mismatch.append({
                    'email': admin.email,
                    'firestore_id': admin.id,
                    'auth_uid': firebase_user.uid
                })
                
        except firebase_auth.UserNotFoundError:
            print(f"  ❌ Status: NO FIREBASE AUTH USER")
            
            # Check if password exists in Firestore
            admin_doc = db.collection('admins').document(admin.id).get()
            admin_data = admin_doc.to_dict()
            has_password = 'password' in admin_data
            
            print(f"  Password in Firestore: {'YES' if has_password else 'NO'}")
            
            admins_without_auth.append({
                'email': admin.email,
                'id': admin.id,
                'has_password': has_password,
                'password': admin_data.get('password', 'N/A') if has_password else 'N/A'
            })
        
        print()
    
    # Summary Report
    print("=" * 80)
    print("SUMMARY REPORT")
    print("=" * 80)
    print(f"\n✅ Admins with matching Firebase Auth: {len(admins_with_auth)}")
    print(f"⚠️  Admins with ID mismatch: {len(admins_with_mismatch)}")
    print(f"❌ Admins without Firebase Auth: {len(admins_without_auth)}")
    
    # Detailed reports
    if admins_without_auth:
        print("\n" + "=" * 80)
        print("ADMINS NEEDING FIREBASE AUTH CREATION")
        print("=" * 80)
        for admin in admins_without_auth:
            print(f"\nEmail: {admin['email']}")
            print(f"Firestore ID: {admin['id']}")
            print(f"Has Password: {'YES' if admin['has_password'] else 'NO'}")
            if admin['has_password']:
                print(f"Password: {admin['password']}")
            print(f"Action Needed: Create Firebase Auth user with this email")
    
    if admins_with_mismatch:
        print("\n" + "=" * 80)
        print("ADMINS WITH ID MISMATCH (NEED MIGRATION)")
        print("=" * 80)
        for admin in admins_with_mismatch:
            print(f"\nEmail: {admin['email']}")
            print(f"Firestore Doc ID: {admin['firestore_id']}")
            print(f"Firebase Auth UID: {admin['auth_uid']}")
            print(f"Action Needed: Update Firestore document to use UID as ID")
    
    if admins_with_auth:
        print("\n" + "=" * 80)
        print("ADMINS WITH CORRECT SETUP ✅")
        print("=" * 80)
        for admin in admins_with_auth:
            print(f"  {admin['email']} - UID: {admin['uid']}")
    
    print("\n" + "=" * 80)
    print("RECOMMENDATIONS")
    print("=" * 80)
    
    if admins_without_auth:
        print("\n⚠️  Action Required: Run create_missing_firebase_auth() to fix admins without Firebase Auth")
    
    if admins_with_mismatch:
        print("\n⚠️  Action Required: Run migrate_mismatched_ids() to fix ID mismatches")
    
    if not admins_without_auth and not admins_with_mismatch:
        print("\n✅ All admins are properly configured! No action needed.")

def create_missing_firebase_auth():
    """Create Firebase Auth users for admins that don't have them"""
    print("\n" + "=" * 80)
    print("CREATING FIREBASE AUTH FOR ADMINS")
    print("=" * 80)
    
    admins = Admin.get_all_admins()
    created_count = 0
    skipped_count = 0
    error_count = 0
    
    for admin in admins:
        try:
            # Check if Firebase Auth user already exists
            try:
                firebase_auth.get_user_by_email(admin.email)
                print(f"⏭️  Skipped {admin.email} - Already has Firebase Auth")
                skipped_count += 1
                continue
            except firebase_auth.UserNotFoundError:
                pass
            
            # Get password from Firestore
            admin_doc = db.collection('admins').document(admin.id).get()
            admin_data = admin_doc.to_dict()
            password = admin_data.get('password')
            
            if not password:
                print(f"❌ Error: {admin.email} - No password in Firestore")
                error_count += 1
                continue
            
            # Create Firebase Auth user
            firebase_user = firebase_auth.create_user(
                email=admin.email,
                password=password,
                display_name=admin.name,
                disabled=False,
                email_verified=False
            )
            
            print(f"✅ Created Firebase Auth for {admin.email}")
            print(f"   UID: {firebase_user.uid}")
            
            # Update Firestore document to use Firebase Auth UID
            new_ref = db.collection('admins').document(firebase_user.uid)
            new_ref.set(admin_data)
            
            # Delete old document if ID was different
            if admin.id != firebase_user.uid:
                db.collection('admins').document(admin.id).delete()
                print(f"   Migrated Firestore doc: {admin.id} → {firebase_user.uid}")
            
            created_count += 1
            
        except Exception as e:
            print(f"❌ Error processing {admin.email}: {e}")
            error_count += 1
    
    print("\n" + "=" * 80)
    print("MIGRATION SUMMARY")
    print("=" * 80)
    print(f"✅ Created: {created_count}")
    print(f"⏭️  Skipped: {skipped_count}")
    print(f"❌ Errors: {error_count}")

def migrate_mismatched_ids():
    """Fix admins where Firestore doc ID doesn't match Firebase Auth UID"""
    print("\n" + "=" * 80)
    print("FIXING ID MISMATCHES")
    print("=" * 80)
    
    admins = Admin.get_all_admins()
    migrated_count = 0
    error_count = 0
    
    for admin in admins:
        try:
            # Get Firebase Auth user
            firebase_user = firebase_auth.get_user_by_email(admin.email)
            
            # Check if IDs match
            if admin.id == firebase_user.uid:
                continue  # Already correct
            
            print(f"Migrating {admin.email}")
            print(f"  From: {admin.id}")
            print(f"  To: {firebase_user.uid}")
            
            # Get current admin data
            admin_doc = db.collection('admins').document(admin.id).get()
            admin_data = admin_doc.to_dict()
            
            # Create new document with correct UID
            new_ref = db.collection('admins').document(firebase_user.uid)
            new_ref.set(admin_data)
            
            # Delete old document
            db.collection('admins').document(admin.id).delete()
            
            print(f"  ✅ Migrated successfully")
            migrated_count += 1
            
        except firebase_auth.UserNotFoundError:
            continue  # Skip admins without Firebase Auth
        except Exception as e:
            print(f"  ❌ Error: {e}")
            error_count += 1
    
    print("\n" + "=" * 80)
    print("MIGRATION SUMMARY")
    print("=" * 80)
    print(f"✅ Migrated: {migrated_count}")
    print(f"❌ Errors: {error_count}")

if __name__ == '__main__':
    import sys
    
    print("\n")
    print("╔" + "=" * 78 + "╗")
    print("║" + " " * 20 + "ADMIN FIREBASE AUTH MIGRATION TOOL" + " " * 24 + "║")
    print("╚" + "=" * 78 + "╝")
    print("\n")
    
    print("Choose an option:")
    print("1. Check admin Firebase Auth status (read-only)")
    print("2. Create Firebase Auth for admins without it")
    print("3. Fix ID mismatches (migrate Firestore docs)")
    print("4. Run full migration (options 2 + 3)")
    print("0. Exit")
    print()
    
    choice = input("Enter your choice (0-4): ").strip()
    
    if choice == '1':
        check_admin_firebase_auth_status()
    elif choice == '2':
        print("\n⚠️  WARNING: This will create Firebase Auth users for admins.")
        confirm = input("Are you sure? (yes/no): ").strip().lower()
        if confirm == 'yes':
            create_missing_firebase_auth()
            print("\n✅ Done! Run option 1 to verify.")
        else:
            print("❌ Cancelled.")
    elif choice == '3':
        print("\n⚠️  WARNING: This will modify Firestore documents.")
        confirm = input("Are you sure? (yes/no): ").strip().lower()
        if confirm == 'yes':
            migrate_mismatched_ids()
            print("\n✅ Done! Run option 1 to verify.")
        else:
            print("❌ Cancelled.")
    elif choice == '4':
        print("\n⚠️  WARNING: This will create Firebase Auth users AND modify Firestore documents.")
        confirm = input("Are you sure? (yes/no): ").strip().lower()
        if confirm == 'yes':
            create_missing_firebase_auth()
            migrate_mismatched_ids()
            print("\n✅ Done! Run option 1 to verify.")
        else:
            print("❌ Cancelled.")
    elif choice == '0':
        print("Goodbye!")
    else:
        print("❌ Invalid choice.")
