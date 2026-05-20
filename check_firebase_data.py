"""
Quick Firebase Data Check Script
Run this to see what data actually exists in your Firebase collections
"""

from services.firebase_service import db
from models.rewards import Reward
from models.student_model import Student
from models.transaction import Transaction

def check_firebase_data():
    print("=" * 80)
    print("🔍 FIREBASE DATA CHECK")
    print("=" * 80)
    
    # Check Rewards Collection
    print("\n📦 REWARDS COLLECTION")
    print("-" * 80)
    try:
        all_rewards = Reward.get_all_rewards()
        print(f"Total Rewards Found: {len(all_rewards)}")
        
        if all_rewards:
            print("\nSample Rewards:")
            for i, reward in enumerate(all_rewards[:5], 1):  # Show first 5
                print(f"\n{i}. {reward.name}")
                print(f"   - ID: {reward.id}")
                print(f"   - Department: {reward.department}")
                print(f"   - Cost: {reward.cost} points")
                print(f"   - Stock: {reward.stock}")
                print(f"   - Status: {reward.status}")
        else:
            print("⚠️ No rewards found in Firebase!")
            print("   → Create rewards using the Flutter admin app")
    except Exception as e:
        print(f"❌ Error: {e}")
    
    # Check Students Collection
    print("\n\n👥 STUDENTS COLLECTION")
    print("-" * 80)
    try:
        all_students = Student.get_all_students()
        print(f"Total Students Found: {len(all_students)}")
        
        if all_students:
            print("\nSample Students:")
            for i, student in enumerate(all_students[:5], 1):
                print(f"\n{i}. {student.full_name}")
                print(f"   - ID: {student.student_id}")
                print(f"   - Department: {student.department}")
                print(f"   - Points: {student.points}")
                print(f"   - Bottles: {student.bottles}")
        else:
            print("⚠️ No students found in Firebase!")
            print("   → Register students using the Flutter user app")
    except Exception as e:
        print(f"❌ Error: {e}")
    
    # Check Transactions Collection
    print("\n\n💳 TRANSACTIONS COLLECTION")
    print("-" * 80)
    try:
        all_transactions = Transaction.get_all_transactions(limit=5)
        print(f"Recent Transactions Found: {len(all_transactions)}")
        
        if all_transactions:
            print("\nRecent Transactions:")
            for i, trans in enumerate(all_transactions, 1):
                print(f"\n{i}. Type: {trans.transaction_type}")
                print(f"   - Student ID: {trans.student_id}")
                print(f"   - Bottles: {trans.bottles_deposited}")
                print(f"   - Points: {trans.points_earned}")
                if trans.reward_id:
                    print(f"   - Reward ID: {trans.reward_id}")
        else:
            print("⚠️ No transactions found in Firebase!")
            print("   → Transactions will be created when students deposit bottles")
    except Exception as e:
        print(f"❌ Error: {e}")
    
    # Check Department Usage
    print("\n\n🏫 DEPARTMENT ANALYSIS")
    print("-" * 80)
    try:
        all_rewards = Reward.get_all_rewards()
        departments_used = set()
        
        for reward in all_rewards:
            if reward.department:
                departments_used.add(reward.department)
        
        print(f"Departments with Rewards: {len(departments_used)}")
        
        if departments_used:
            print("\nDepartments found in rewards:")
            for dept in sorted(departments_used):
                count = len([r for r in all_rewards if r.department == dept])
                print(f"  - {dept}: {count} reward(s)")
        
        # Compare with hardcoded list
        expected_departments = [
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
        
        print(f"\n\nExpected Departments (from Flutter apps): {len(expected_departments)}")
        print("Departments defined in code:")
        for dept in expected_departments:
            has_rewards = dept in departments_used
            status = "✅" if has_rewards else "⚪"
            print(f"  {status} {dept}")
        
        if not departments_used:
            print("\n⚠️ No rewards have department data yet!")
            
    except Exception as e:
        print(f"❌ Error: {e}")
    
    # Summary
    print("\n\n" + "=" * 80)
    print("📊 SUMMARY")
    print("=" * 80)
    
    try:
        reward_count = len(Reward.get_all_rewards())
        student_count = len(Student.get_all_students())
        transaction_count = len(Transaction.get_all_transactions(limit=100))
        
        print(f"✅ Rewards: {reward_count}")
        print(f"✅ Students: {student_count}")
        print(f"✅ Transactions: {transaction_count}")
        
        if reward_count == 0:
            print("\n⚠️ ACTION NEEDED:")
            print("   1. Open Flutter admin app")
            print("   2. Navigate to Rewards tab")
            print("   3. Click 'Add Reward' button")
            print("   4. Create some test rewards")
            print("   5. Refresh the web page")
        else:
            print("\n✅ Your rewards.html will display real data!")
            
    except Exception as e:
        print(f"❌ Error getting summary: {e}")
    
    print("\n" + "=" * 80)
    print("🎉 Check Complete!")
    print("=" * 80)

if __name__ == '__main__':
    check_firebase_data()
