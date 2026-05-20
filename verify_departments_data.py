"""
Verify that departments.html will display data correctly.
"""
from models.department_model import Department
from models.student_model import Student

print("="*60)
print("DEPARTMENTS DATA VERIFICATION")
print("="*60)

# Get all departments
all_depts = Department.get_all_departments()
print(f"\n✓ Found {len(all_depts)} departments in Firebase\n")

# Get student statistics
student_stats = Student.get_student_statistics()
dept_breakdown = student_stats.get('department_breakdown', {})

print("Department Statistics:")
print("-" * 60)

for dept in sorted(all_depts, key=lambda x: x.name):
    dept_stats = dept_breakdown.get(dept.name, {})
    student_count = dept_stats.get('count', 0)
    bottles = dept_stats.get('bottles', 0)
    points = dept_stats.get('points', 0)
    
    print(f"\n📁 {dept.name}")
    print(f"   Students: {student_count}")
    print(f"   Total Bottles (Lifetime): {bottles}")
    print(f"   Total Points (Current): {points}")
    
    if student_count > 0:
        # Get students in this department
        dept_students = Student.get_students_by_department(dept.name)
        avg = bottles / student_count
        print(f"   Average per Student: {avg:.2f}")
        
        # Find top recycler
        if dept_students:
            top_student = max(dept_students, key=lambda x: x.total_bottles_lifetime)
            print(f"   Top Recycler: {top_student.full_name} ({top_student.total_bottles_lifetime} bottles)")

print("\n" + "="*60)
print("SUMMARY")
print("="*60)
print(f"Total Departments: {len(all_depts)}")
print(f"Total Students: {student_stats.get('total_students', 0)}")
print(f"Total Bottles (Lifetime): {student_stats.get('total_bottles', 0)}")
print(f"Total Points (Current): {student_stats.get('current_points', 0)}")

# Check which departments have students
depts_with_students = [name for name, stats in dept_breakdown.items() if stats['count'] > 0]
print(f"\nDepartments with students: {len(depts_with_students)}")
for dept_name in sorted(depts_with_students):
    stats = dept_breakdown[dept_name]
    print(f"  - {dept_name}: {stats['count']} students, {stats['bottles']} bottles")

print("\n✓ Verification complete!")
