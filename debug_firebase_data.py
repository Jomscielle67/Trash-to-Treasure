"""
Debug script to check Firebase data and diagnose empty bottles issue
"""

from models.student_model import Student
from models.transaction import Transaction
from models.department_model import Department
from models.machine_model import Machine

print("="*60)
print("FIREBASE DATA DIAGNOSTIC")
print("="*60)

# Check Students
print("\n📊 STUDENTS:")
all_students = Student.get_all_students()
print(f"   Total students in Firebase: {len(all_students)}")

if all_students:
    print("\n   Sample student data:")
    for i, student in enumerate(all_students[:3]):  # Show first 3
        print(f"\n   Student {i+1}:")
        print(f"      Name: {student.full_name}")
        print(f"      Department: {student.department}")
        print(f"      Bottles (current): {student.bottles}")
        print(f"      Total Bottles Lifetime: {student.total_bottles_lifetime}")
        print(f"      Points (current): {student.points}")
        print(f"      Total Points Earned: {student.total_points_earned}")
        print(f"      Status: {student.status}")
    
    # Get statistics
    print("\n   📈 Student Statistics:")
    stats = Student.get_student_statistics()
    print(f"      Total Students: {stats.get('total_students', 0)}")
    print(f"      Active Students: {stats.get('active_students', 0)}")
    print(f"      Total Bottles (sum of totalBottlesLifetime): {stats.get('total_bottles', 0)}")
    print(f"      Current Points (sum of points): {stats.get('current_points', 0)}")
    print(f"      Total Points Earned: {stats.get('total_points_earned', 0)}")
    
    print("\n   🏢 Department Breakdown:")
    dept_breakdown = stats.get('department_breakdown', {})
    if dept_breakdown:
        for dept_name, dept_info in dept_breakdown.items():
            print(f"      {dept_name}:")
            print(f"         Students: {dept_info.get('count', 0)}")
            print(f"         Bottles: {dept_info.get('bottles', 0)}")
            print(f"         Points: {dept_info.get('points', 0)}")
    else:
        print("      ⚠️ No department breakdown available")
else:
    print("   ❌ NO STUDENTS FOUND IN FIREBASE!")
    print("   → Need to create students first")

# Check Transactions
print("\n\n💳 TRANSACTIONS:")
all_transactions = Transaction.get_all_transactions(limit=10)
print(f"   Total transactions (showing first 10): {len(all_transactions)}")

if all_transactions:
    print("\n   Sample transaction data:")
    for i, trans in enumerate(all_transactions[:3]):  # Show first 3
        print(f"\n   Transaction {i+1}:")
        print(f"      Student: {trans.student_name}")
        print(f"      Type: {trans.type}")
        print(f"      Points: {trans.points}")
        print(f"      Status: {trans.status}")
        if trans.type == 'redeem':
            print(f"      Reward: {trans.reward_name}")
        print(f"      Timestamp: {trans.timestamp}")
    
    # Get statistics
    print("\n   📈 Transaction Statistics:")
    trans_stats = Transaction.get_transaction_statistics()
    print(f"      Total Transactions: {trans_stats.get('total_transactions', 0)}")
    print(f"      Deposits: {trans_stats.get('total_deposits', 0)}")
    print(f"      Redemptions: {trans_stats.get('total_redemptions', 0)}")
    print(f"      Completed Redemptions: {trans_stats.get('completed_redemptions', 0)}")
    print(f"      Pending Redemptions: {trans_stats.get('pending_redemptions', 0)}")
    
    print("\n   🏆 Popular Rewards:")
    popular_rewards = trans_stats.get('popular_rewards', [])
    if popular_rewards:
        for reward_name, count in popular_rewards:
            print(f"      {reward_name}: {count} redemptions")
    else:
        print("      ⚠️ No popular rewards data")
else:
    print("   ❌ NO TRANSACTIONS FOUND IN FIREBASE!")
    print("   → Need to create transactions first")

# Check Departments
print("\n\n🏢 DEPARTMENTS:")
all_departments = Department.get_all_departments()
print(f"   Total departments in Firebase: {len(all_departments)}")

if all_departments:
    for dept in all_departments:
        print(f"   - {dept.name} ({dept.location})")
else:
    print("   ❌ NO DEPARTMENTS FOUND IN FIREBASE!")
    print("   → Need to create departments first")

# Check Machines
print("\n\n⚙️ MACHINES:")
all_machines = Machine.get_all_machines()
print(f"   Total machines in Firebase: {len(all_machines)}")

if all_machines:
    for machine in all_machines:
        print(f"   - {machine.machine_id} at {machine.location} ({machine.status})")
else:
    print("   ⚠️ No machines found (this is optional)")

print("\n" + "="*60)
print("DIAGNOSIS:")
print("="*60)

if not all_students:
    print("❌ ISSUE: No students in Firebase")
    print("   SOLUTION: Run 'python create_sample_data.py' to create test data")
elif stats.get('total_bottles', 0) == 0:
    print("❌ ISSUE: Students exist but totalBottlesLifetime = 0")
    print("   SOLUTION 1: Use Flutter app to deposit bottles via Arduino")
    print("   SOLUTION 2: Manually update student records in Firebase Console")
    print("   SOLUTION 3: Run 'python create_sample_data.py' to create realistic data")
else:
    print("✅ Data exists! Dashboard should display correctly.")
    print(f"   Expected Total Bottles: {stats.get('total_bottles', 0)}")

print("\n" + "="*60)
