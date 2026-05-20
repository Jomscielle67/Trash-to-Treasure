"""
Sample Data Generator for Trash to Treasure System
Creates realistic student and transaction data for testing the dashboard
"""

from models.student_model import Student, StudentStatus, YearLevel
from models.transaction import Transaction, TransactionType, TransactionStatus
from models.department_model import Department
from datetime import datetime, timedelta
import random

def create_sample_departments():
    """Create sample departments."""
    departments = [
        {'name': 'Engineering', 'location': 'Building A'},
        {'name': 'Science', 'location': 'Building B'},
        {'name': 'Arts', 'location': 'Building C'},
        {'name': 'Business', 'location': 'Building D'},
        {'name': 'Education', 'location': 'Building E'}
    ]
    
    print("Creating departments...")
    for dept_data in departments:
        dept = Department(
            name=dept_data['name'],
            location=dept_data['location'],
            bottle_rate=1  # 1 bottle = 1 point
        )
        if dept.save():
            print(f"✓ Created department: {dept.name}")
        else:
            print(f"✗ Failed to create department: {dept.name}")

def create_sample_students():
    """Create sample students with realistic data."""
    first_names = ['James', 'Mary', 'John', 'Patricia', 'Robert', 'Jennifer', 'Michael', 'Linda', 
                   'William', 'Elizabeth', 'David', 'Barbara', 'Richard', 'Susan', 'Joseph', 'Jessica']
    last_names = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis',
                  'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Gonzalez', 'Wilson', 'Anderson', 'Thomas']
    
    departments = ['Engineering', 'Science', 'Arts', 'Business', 'Education']
    courses = {
        'Engineering': ['Computer Engineering', 'Electrical Engineering', 'Mechanical Engineering', 'Civil Engineering'],
        'Science': ['Biology', 'Chemistry', 'Physics', 'Mathematics'],
        'Arts': ['Fine Arts', 'Literature', 'Music', 'Theater'],
        'Business': ['Accounting', 'Marketing', 'Management', 'Finance'],
        'Education': ['Elementary Education', 'Secondary Education', 'Special Education', 'Physical Education']
    }
    year_levels = [YearLevel.FIRST.value, YearLevel.SECOND.value, YearLevel.THIRD.value, YearLevel.FOURTH.value]
    
    print("\nCreating students...")
    students_created = []
    
    for i in range(50):  # Create 50 students
        first_name = random.choice(first_names)
        last_name = random.choice(last_names)
        full_name = f"{first_name} {last_name}"
        
        dept = random.choice(departments)
        course = random.choice(courses[dept])
        year_level = random.choice(year_levels)
        
        # Generate realistic bottle and points data
        total_bottles = random.randint(20, 500)  # Lifetime bottles
        current_bottles = random.randint(0, 50)  # Current bottles in account
        
        points_earned = total_bottles  # 1 bottle = 1 point
        points_spent = random.randint(0, points_earned)  # Some students redeem rewards
        current_points = points_earned - points_spent
        
        student = Student(
            full_name=full_name,
            student_id=f"2024{i+1:04d}",  # e.g., 20240001
            email=f"{first_name.lower()}.{last_name.lower()}@university.edu",
            department=dept,
            course=course,
            year_level=year_level,
            section='A' if i % 2 == 0 else 'B',
            
            # Stats
            bottles=current_bottles,
            total_bottles_lifetime=total_bottles,
            points=current_points,
            total_points_earned=points_earned,
            total_points_spent=points_spent,
            total_rewards_redeemed=points_spent // 50,  # Assuming average reward costs 50 points
            
            # Status
            status=StudentStatus.ACTIVE.value,
            is_email_verified=True,
            is_profile_complete=True,
            
            # Activity
            current_streak=random.randint(0, 30),
            longest_streak=random.randint(0, 60),
            last_activity_at=datetime.now() - timedelta(days=random.randint(0, 7))
        )
        
        if student.save():
            students_created.append(student)
            print(f"✓ Created student: {student.full_name} ({student.department}) - {student.total_bottles_lifetime} bottles lifetime")
        else:
            print(f"✗ Failed to create student: {full_name}")
    
    return students_created

def create_sample_transactions(students):
    """Create sample transactions (deposits and redemptions)."""
    if not students:
        print("\n⚠ No students available. Create students first!")
        return
    
    rewards = [
        {'name': 'Coffee Voucher', 'points': 50},
        {'name': 'T-Shirt', 'points': 100},
        {'name': 'Notebook', 'points': 30},
        {'name': 'Water Bottle', 'points': 75},
        {'name': 'Eco Bag', 'points': 60},
        {'name': 'USB Drive', 'points': 120},
        {'name': 'Pen Set', 'points': 40},
        {'name': 'Plant Pot', 'points': 80}
    ]
    
    print("\nCreating deposit transactions...")
    deposit_count = 0
    
    # Create deposit transactions for each student
    for student in students:
        num_deposits = random.randint(5, 20)  # Each student has 5-20 deposit transactions
        
        for _ in range(num_deposits):
            bottles_deposited = random.randint(5, 30)
            points_earned = bottles_deposited  # 1 bottle = 1 point
            
            transaction = Transaction(
                user_id=student.id,
                student_name=student.full_name,
                points=points_earned,
                type=TransactionType.DEPOSIT.value,
                department=student.department,
                status=TransactionStatus.COMPLETED.value,  # All deposits are completed
                timestamp=datetime.now() - timedelta(days=random.randint(1, 90))
            )
            
            if transaction.save():
                deposit_count += 1
    
    print(f"✓ Created {deposit_count} deposit transactions")
    
    print("\nCreating redemption transactions...")
    redemption_count = 0
    
    # Create redemption transactions for students who have redeemed rewards
    for student in students:
        if student.total_rewards_redeemed > 0:
            num_redemptions = student.total_rewards_redeemed
            
            for _ in range(num_redemptions):
                reward = random.choice(rewards)
                
                # Random status - mostly completed, some pending
                status = 'Completed' if random.random() > 0.2 else 'Pending'
                
                transaction = Transaction(
                    user_id=student.id,
                    student_name=student.full_name,
                    reward_id=f"RWD{random.randint(1000, 9999)}",
                    reward_name=reward['name'],
                    points=reward['points'],
                    type=TransactionType.REDEEM.value,
                    department=student.department,
                    status=status,
                    ticket_code=Transaction.generate_ticket_code(),
                    timestamp=datetime.now() - timedelta(days=random.randint(1, 90))
                )
                
                if transaction.save():
                    redemption_count += 1
    
    print(f"✓ Created {redemption_count} redemption transactions")
    print(f"\n✅ Total transactions created: {deposit_count + redemption_count}")

def verify_data():
    """Verify the created data."""
    print("\n" + "="*60)
    print("DATA VERIFICATION")
    print("="*60)
    
    # Check students
    all_students = Student.get_all_students()
    print(f"\n📊 Total Students: {len(all_students)}")
    
    if all_students:
        student_stats = Student.get_student_statistics()
        print(f"   Active Students: {student_stats.get('active_students', 0)}")
        print(f"   Total Bottles (Lifetime): {student_stats.get('total_bottles', 0)}")
        print(f"   Current Points in Circulation: {student_stats.get('current_points', 0)}")
        
        print("\n   Department Breakdown:")
        dept_breakdown = student_stats.get('department_breakdown', {})
        for dept, data in dept_breakdown.items():
            print(f"      {dept}: {data['count']} students, {data['bottles']} bottles, {data['points']} points")
    
    # Check transactions
    all_transactions = Transaction.get_all_transactions()
    print(f"\n💳 Total Transactions: {len(all_transactions)}")
    
    if all_transactions:
        trans_stats = Transaction.get_transaction_statistics()
        print(f"   Deposits: {trans_stats.get('total_deposits', 0)}")
        print(f"   Redemptions: {trans_stats.get('total_redemptions', 0)}")
        print(f"   Completed Redemptions: {trans_stats.get('completed_redemptions', 0)}")
        print(f"   Pending Redemptions: {trans_stats.get('pending_redemptions', 0)}")
        
        print("\n   Popular Rewards:")
        popular_rewards = trans_stats.get('popular_rewards', [])
        for reward_name, count in popular_rewards:
            print(f"      {reward_name}: {count} redemptions")
    
    # Check departments
    all_departments = Department.get_all_departments()
    print(f"\n🏢 Total Departments: {len(all_departments)}")
    for dept in all_departments:
        print(f"   - {dept.name} ({dept.location})")
    
    print("\n" + "="*60)
    print("✅ VERIFICATION COMPLETE")
    print("="*60)
    print("\nYou can now:")
    print("1. Run your Flask app: python app.py")
    print("2. Visit http://localhost:5000/dashboard")
    print("3. Charts should now display data!")

def main():
    """Main function to create all sample data."""
    print("="*60)
    print("TRASH TO TREASURE - SAMPLE DATA GENERATOR")
    print("="*60)
    print("\nThis script will create:")
    print("- 5 departments")
    print("- 50 students with realistic data")
    print("- 500+ deposit transactions")
    print("- 100+ redemption transactions")
    print("\n⚠ WARNING: This will add data to your Firebase database!")
    
    response = input("\nDo you want to continue? (yes/no): ").strip().lower()
    
    if response != 'yes':
        print("\n❌ Operation cancelled.")
        return
    
    print("\n🚀 Starting data generation...\n")
    
    try:
        # Step 1: Create departments
        create_sample_departments()
        
        # Step 2: Create students
        students = create_sample_students()
        
        # Step 3: Create transactions
        create_sample_transactions(students)
        
        # Step 4: Verify data
        verify_data()
        
        print("\n✅ SAMPLE DATA CREATION COMPLETE!")
        
    except Exception as e:
        print(f"\n❌ Error creating sample data: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
