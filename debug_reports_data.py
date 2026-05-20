"""
Debug script to check what data the Reports page is receiving from Firebase.
Run this to see exactly what data is available before viewing the Reports page.
"""

from models.transaction import Transaction
from models.student_model import Student
from models.department_model import Department
from models.machine_model import Machine
from models.rewards import Reward
from datetime import datetime, timedelta

def check_data():
    print("\n" + "="*70)
    print("🔍 REPORTS DATA DEBUG - Checking Firebase Data")
    print("="*70 + "\n")
    
    # 1. Check Transactions
    print("📊 TRANSACTIONS:")
    print("-" * 70)
    all_transactions = Transaction.get_all_transactions()
    print(f"✓ Total transactions: {len(all_transactions)}")
    
    if len(all_transactions) > 0:
        deposits = [t for t in all_transactions if t.type == 'deposit']
        redemptions = [t for t in all_transactions if t.type == 'redeem']
        print(f"  - Deposits: {len(deposits)}")
        print(f"  - Redemptions: {len(redemptions)}")
        
        # Show sample transaction
        sample = all_transactions[0]
        print(f"\n  Sample transaction:")
        print(f"    ID: {sample.id}")
        print(f"    Type: {sample.type}")
        print(f"    Points: {sample.points}")
        print(f"    User: {sample.student_name}")
        print(f"    Timestamp: {sample.timestamp}")
        print(f"    Timestamp Type: {type(sample.timestamp)}")
    else:
        print("  ⚠️  NO TRANSACTIONS FOUND!")
        print("  → Reports page will show empty data")
        print("  → Add transactions via the Flutter app or admin panel")
    
    # 2. Check Students
    print("\n👥 STUDENTS:")
    print("-" * 70)
    all_students = Student.get_all_students()
    print(f"✓ Total students: {len(all_students)}")
    
    if len(all_students) > 0:
        active_students = [s for s in all_students if s.is_active]
        print(f"  - Active students: {len(active_students)}")
        total_points = sum(s.points for s in all_students)
        print(f"  - Total points: {total_points}")
        
        # Show sample student
        sample = all_students[0]
        print(f"\n  Sample student:")
        print(f"    Name: {sample.name}")
        print(f"    Points: {sample.points}")
        print(f"    Department: {sample.department}")
    else:
        print("  ⚠️  NO STUDENTS FOUND!")
    
    # 3. Check Departments
    print("\n🏢 DEPARTMENTS:")
    print("-" * 70)
    all_departments = Department.get_all_departments()
    print(f"✓ Total departments: {len(all_departments)}")
    
    if len(all_departments) > 0:
        for dept in all_departments[:5]:  # Show first 5
            dept_students = Student.get_students_by_department(dept.name)
            total_points = sum(s.points for s in dept_students)
            print(f"  - {dept.name}: {len(dept_students)} students, {total_points} points")
    else:
        print("  ⚠️  NO DEPARTMENTS FOUND!")
    
    # 4. Check Machines
    print("\n🤖 MACHINES:")
    print("-" * 70)
    machine_stats = Machine.get_machine_statistics()
    print(f"✓ Total machines: {machine_stats.get('total_machines', 0)}")
    print(f"  - Active: {machine_stats.get('active_machines', 0)}")
    print(f"  - Inactive: {machine_stats.get('inactive_machines', 0)}")
    uptime = (machine_stats.get('active_machines', 0) / machine_stats.get('total_machines', 1)) * 100
    print(f"  - Uptime: {uptime:.1f}%")
    
    # 5. Check Rewards
    print("\n🎁 REWARDS:")
    print("-" * 70)
    all_rewards = Reward.get_all_rewards()
    print(f"✓ Total rewards: {len(all_rewards)}")
    
    if len(all_rewards) > 0:
        total_redeemed = sum(r.redeemed_count for r in all_rewards)
        print(f"  - Total redeemed: {total_redeemed}")
        
        # Show categories
        categories = {}
        for r in all_rewards:
            cat = r.category if r.category else 'Others'
            categories[cat] = categories.get(cat, 0) + r.redeemed_count
        
        print(f"  - Categories:")
        for cat, count in sorted(categories.items(), key=lambda x: x[1], reverse=True)[:5]:
            print(f"    • {cat}: {count} redemptions")
    else:
        print("  ⚠️  NO REWARDS FOUND!")
    
    # 6. Date Range Check
    print("\n📅 DATE RANGES:")
    print("-" * 70)
    now = datetime.now()
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    week_start = today_start - timedelta(days=today_start.weekday())
    month_start = today_start.replace(day=1)
    
    print(f"  Today: {today_start.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"  Week start (Monday): {week_start.strftime('%Y-%m-%d')}")
    print(f"  Month start: {month_start.strftime('%Y-%m-%d')}")
    
    # Count transactions in each period
    if len(all_transactions) > 0:
        print(f"\n  Transactions by period:")
        
        today_count = 0
        week_count = 0
        month_count = 0
        
        for t in all_transactions:
            # Handle different timestamp types
            if hasattr(t.timestamp, 'timestamp'):
                t_time = datetime.fromtimestamp(t.timestamp.timestamp())
            elif isinstance(t.timestamp, datetime):
                t_time = t.timestamp
            else:
                continue
            
            if t_time >= today_start:
                today_count += 1
            if t_time >= week_start:
                week_count += 1
            if t_time >= month_start:
                month_count += 1
        
        print(f"    - Today: {today_count}")
        print(f"    - This week: {week_count}")
        print(f"    - This month: {month_count}")
    
    # 7. Summary
    print("\n" + "="*70)
    print("📋 SUMMARY:")
    print("="*70)
    
    has_data = len(all_transactions) > 0 and len(all_students) > 0
    
    if has_data:
        print("✅ You have data in Firebase!")
        print("✅ Reports page should show real statistics")
        print("\n💡 Next steps:")
        print("   1. Start your Flask app: python app.py")
        print("   2. Navigate to: http://localhost:5000/reports")
        print("   3. You should see real data from Firebase")
    else:
        print("⚠️  Your Firebase database is mostly empty!")
        print("⚠️  Reports page will show zeros or 'No data' messages")
        print("\n💡 To populate data:")
        print("   1. Add students via Users page")
        print("   2. Add departments via Departments page")
        print("   3. Add rewards via Rewards page")
        print("   4. Create transactions via Flutter user app")
        print("   5. Or add test data directly to Firebase Console")
    
    print("\n" + "="*70 + "\n")

if __name__ == "__main__":
    try:
        check_data()
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        import traceback
        traceback.print_exc()
        print("\n💡 Make sure Firebase is configured correctly!")
        print("   Check: serviceAccountKey.json file exists")
