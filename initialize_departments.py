"""
Script to initialize all departments in Firebase.
This ensures the departments collection has all the required departments.
"""
from services.firebase_service import db
from models.department_model import Department

# List of all departments from the Flutter app
DEPARTMENTS = [
    'Accountancy, Business and Management',
    'College of Computer Studies',
    'College of Hospitality Management and Tourism',
    'College of Teacher Education',
    'College of Engineering',
    'Senior High School',
    'Food safety and security',
    'College of Fisheries',
    'College of Industrial Technology',
    'College of Agriculture',
    'College of Nursing',
    'Business Affairs Office',
]

def check_existing_departments():
    """Check what departments already exist."""
    print("Checking existing departments in Firebase...")
    existing_depts = Department.get_all_departments()
    
    print(f"\nFound {len(existing_depts)} departments:")
    for dept in existing_depts:
        print(f"  - {dept.name}")
    
    return existing_depts

def initialize_departments():
    """Initialize all required departments if they don't exist."""
    print("\n" + "="*60)
    print("INITIALIZING DEPARTMENTS")
    print("="*60)
    
    existing_depts = check_existing_departments()
    existing_names = [dept.name for dept in existing_depts]
    
    print(f"\n\nAdding missing departments...")
    added_count = 0
    
    for dept_name in DEPARTMENTS:
        if dept_name not in existing_names:
            print(f"  + Adding: {dept_name}")
            dept = Department(
                name=dept_name,
                admin_id="",  # Will be assigned later
                bottle_rate=1,  # Default 1 point per bottle
                location="Main Campus"  # Default location
            )
            if dept.save():
                added_count += 1
                print(f"    ✓ Successfully added")
            else:
                print(f"    ✗ Failed to add")
        else:
            print(f"  ○ Already exists: {dept_name}")
    
    print(f"\n\n{'='*60}")
    print(f"SUMMARY:")
    print(f"  - Existing departments: {len(existing_names)}")
    print(f"  - Newly added: {added_count}")
    print(f"  - Total departments: {len(existing_names) + added_count}")
    print(f"{'='*60}\n")
    
    # Verify final state
    print("\nVerifying all departments are in Firebase...")
    all_depts = Department.get_all_departments()
    print(f"✓ Total departments in Firebase: {len(all_depts)}\n")
    
    for dept in sorted(all_depts, key=lambda x: x.name):
        print(f"  {dept.name}")

if __name__ == "__main__":
    try:
        initialize_departments()
    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()
