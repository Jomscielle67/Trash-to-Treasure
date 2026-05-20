"""
Quick fix script to update existing students with totalBottlesLifetime
This will set totalBottlesLifetime = current bottles for all students
"""

from models.student_model import Student
from services.firebase_service import db

print("="*60)
print("FIXING EXISTING STUDENT DATA")
print("="*60)

all_students = Student.get_all_students()

if not all_students:
    print("\n❌ No students found!")
    exit()

print(f"\nFound {len(all_students)} students. Updating their totalBottlesLifetime field...\n")

updated_count = 0
for student in all_students:
    old_lifetime = student.total_bottles_lifetime
    current_bottles = student.bottles
    
    # If totalBottlesLifetime is 0 but bottles is not, fix it
    if old_lifetime == 0 and current_bottles > 0:
        # Set totalBottlesLifetime to at least equal current bottles
        # (In reality it should be higher, but this is a conservative fix)
        student.total_bottles_lifetime = current_bottles
        
        # Also set totalPointsEarned if it's 0
        if student.total_points_earned == 0 and student.points > 0:
            student.total_points_earned = student.points
        
        if student.save():
            print(f"✓ Updated {student.full_name}:")
            print(f"  Bottles (current): {current_bottles}")
            print(f"  Total Bottles Lifetime: {old_lifetime} → {student.total_bottles_lifetime}")
            print(f"  Total Points Earned: {student.total_points_earned}")
            updated_count += 1
        else:
            print(f"✗ Failed to update {student.full_name}")
    else:
        print(f"○ Skipped {student.full_name} (already has lifetime data or no bottles)")

print(f"\n{'='*60}")
print(f"✅ Updated {updated_count} students")
print(f"{'='*60}")

# Verify the fix
print("\nVerifying fix...")
stats = Student.get_student_statistics()
print(f"Total Bottles (after fix): {stats.get('total_bottles', 0)}")

if stats.get('total_bottles', 0) > 0:
    print("\n✅ SUCCESS! Dashboard should now show bottles correctly.")
else:
    print("\n⚠️ Total bottles still 0. Students may not have any bottles deposited yet.")
