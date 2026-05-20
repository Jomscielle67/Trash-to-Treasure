#!/usr/bin/env python3
"""
Script to create the initial super user account for Trash to Treasure system.
"""

import sys
import os
import getpass

# Add the parent directory to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from models.super_user_model import SuperUser, SuperUserRole

def create_initial_super_user():
    """Create the initial super user account."""
    
    print("🚀 Trash to Treasure - Initial Super User Setup")
    print("=" * 60)
    
    # Check if any super users already exist
    existing_users = SuperUser.get_all_super_users()
    if existing_users:
        print(f"ℹ️  Found {len(existing_users)} existing super user(s):")
        for user in existing_users:
            print(f"   - {user.full_name} ({user.email}) - {user.role}")
        
        response = input("\nDo you want to create another super user? (y/N): ").strip().lower()
        if response != 'y':
            print("Setup cancelled.")
            return
    
    print("\nPlease provide the following information:")
    
    # Get user input
    full_name = input("Full Name: ").strip()
    while not full_name:
        print("❌ Full name is required.")
        full_name = input("Full Name: ").strip()
    
    email = input("Email Address: ").strip().lower()
    while not email or not SuperUser.validate_email(email):
        print("❌ Please provide a valid email address.")
        email = input("Email Address: ").strip().lower()
    
    # Check if email already exists
    if SuperUser.get_by_email(email):
        print(f"❌ An account with email '{email}' already exists.")
        return
    
    department = input("Department: ").strip()
    while not department:
        print("❌ Department is required.")
        department = input("Department: ").strip()
    
    print("\nAvailable roles:")
    print("1. Super Admin (Full access)")
    print("2. System Admin (Limited access)")
    print("3. Regional Admin (Regional access)")
    
    role_choice = input("Select role (1-3): ").strip()
    role_map = {
        '1': SuperUserRole.SUPER_ADMIN.value,
        '2': SuperUserRole.SYSTEM_ADMIN.value,
        '3': SuperUserRole.REGIONAL_ADMIN.value
    }
    
    role = role_map.get(role_choice, SuperUserRole.SUPER_ADMIN.value)
    if role_choice not in role_map:
        print("⚠️  Invalid selection, defaulting to Super Admin.")
    
    # Get password with validation
    while True:
        password = getpass.getpass("Password: ")
        if not password:
            print("❌ Password is required.")
            continue
        
        # Validate password strength
        validation = SuperUser.validate_password(password)
        if not validation['is_valid']:
            print("❌ Password does not meet requirements:")
            for error in validation['errors']:
                print(f"   - {error}")
            continue
        
        confirm_password = getpass.getpass("Confirm Password: ")
        if password != confirm_password:
            print("❌ Passwords do not match.")
            continue
        
        break
    
    # Create the super user
    print("\n🔄 Creating super user account...")
    
    try:
        super_user = SuperUser.create_super_user(
            full_name=full_name,
            email=email,
            password=password,
            department=department,
            role=role
        )
        
        if super_user:
            print("✅ Super user account created successfully!")
            print(f"   Name: {super_user.full_name}")
            print(f"   Email: {super_user.email}")
            print(f"   Department: {super_user.department}")
            print(f"   Role: {super_user.role}")
            print(f"   ID: {super_user.id}")
            
            # Show login instructions
            print("\n🔐 You can now log in to the system:")
            print("   1. Start the Flask app: python app.py")
            print("   2. Visit: http://127.0.0.1:5000/login")
            print(f"   3. Use email: {super_user.email}")
            print("   4. Use the password you just created")
            
        else:
            print("❌ Failed to create super user account.")
            print("   Please check your Firebase configuration and try again.")
    
    except Exception as e:
        print(f"❌ Error creating super user: {e}")
        print("   Please check your Firebase configuration and try again.")

def main():
    """Main function."""
    try:
        create_initial_super_user()
    except KeyboardInterrupt:
        print("\n\n❌ Setup cancelled by user.")
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")

if __name__ == "__main__":
    main()