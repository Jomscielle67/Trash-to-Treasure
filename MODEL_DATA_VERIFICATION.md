# Model Data Verification Guide

## Firebase Collections Structure

### 1. Students Collection (`students`)

**Fields (from student_model.py)**:
```python
{
    'fullName': str,
    'studentID': str,
    'email': str,
    'department': str,
    'course': str,
    'yearLevel': str,
    'section': str,
    'points': int,                    # Current available points
    'bottles': int,                   # Current bottle count
    'totalBottlesLifetime': int,      # All-time bottles deposited
    'totalPointsEarned': int,         # All-time points earned
    'totalPointsSpent': int,          # All-time points spent
    'status': str,                    # 'active', 'pending', 'suspended', 'banned'
    'totalRewardsRedeemed': int,      # Count of rewards redeemed
    # ... other fields
}
```

**Statistics Method** (`Student.get_student_statistics()`):
```python
Returns {
    'total_students': int,            # Total count
    'active_students': int,           # Status == 'active'
    'pending_students': int,
    'suspended_students': int,
    'banned_students': int,
    'total_bottles': int,             # Sum of all totalBottlesLifetime
    'total_points_earned': int,       # Sum of all totalPointsEarned
    'total_points_spent': int,        # Sum of all totalPointsSpent
    'current_points': int,            # Sum of all current points
    'department_breakdown': dict      # Per-department stats
}
```

### 2. Transactions Collection (`transactions`)

**Fields (from transaction.py)**:
```python
{
    'userId': str,                    # Reference to student ID
    'studentName': str,               # Cached student name
    'rewardId': str,                  # Reference to reward (if redeem)
    'rewardName': str,                # Cached reward name (if redeem)
    'points': int,                    # Points amount
    'type': str,                      # 'deposit' or 'redeem'
    'department': str,                # Student's department
    'status': str,                    # 'completed', 'pending', 'cancelled'
    'ticketCode': str,                # Redemption ticket (if redeem)
    'timestamp': datetime             # Transaction time
}
```

**Statistics Method** (`Transaction.get_transaction_statistics()`):
```python
Returns {
    'total_transactions': int,
    'total_deposits': int,            # Count of type='deposit'
    'total_redemptions': int,         # Count of type='redeem'
    'total_points_earned': int,       # Sum of deposit points
    'total_points_redeemed': int,     # Sum of redeem points
    'pending_redemptions': int,       # Status='pending' & type='redeem'
    'completed_redemptions': int,     # Status='completed' & type='redeem'
    'popular_rewards': list           # [(reward_name, count), ...]
}
```

### 3. Departments Collection (`departments`)

**Used for**:
- Department bottle counts (calculated from students)
- Department-wise statistics

### 4. Machines Collection (`machines`)

**Used for**:
- Machine status (online/offline/full)
- Fill percentage
- Location tracking

### 5. Rewards Collection (`rewards`)

**Used for**:
- Available rewards
- Point costs
- Stock levels

---

## Dashboard Data Mapping

### Top Metrics Cards

1. **Total Bottles**
   - Source: `student_stats.get('total_bottles', 0)`
   - Calculation: Sum of all `totalBottlesLifetime` from students collection
   - Shows: All-time bottles collected across all students

2. **Total Points**
   - Source: `student_stats.get('current_points', 0)`
   - Calculation: Sum of all `points` from students collection
   - Shows: Current points in circulation (not yet spent)

3. **Active Students**
   - Source: `student_stats.get('active_students', 0)`
   - Calculation: Count of students where `status == 'active'`
   - Shows: Number of currently active users

4. **Rewards Redeemed**
   - Source: `transaction_stats.get('completed_redemptions', 0)`
   - Calculation: Count of transactions where `type == 'redeem'` AND `status == 'completed'`
   - Shows: Total successful reward redemptions

5. **Machines Online**
   - Source: `machine_stats.get('active_machines', 0)` / `machine_stats.get('total_machines', 1)`
   - Shows: Number of online machines vs total

### Charts

1. **Bottles by Department**
   - Source: `dept_data` dictionary
   - Calculation: For each department, sum `total_bottles_lifetime` from all students in that department
   - Chart Type: Bar chart
   - Data: `{ 'Department Name': bottle_count, ... }`

2. **Popular Rewards**
   - Source: `popular_rewards` list
   - Calculation: Count redemption transactions grouped by `reward_name`, sorted descending
   - Chart Type: Doughnut chart
   - Data: `[('Reward Name', redemption_count), ...]`
   - Shows: Top 5 most redeemed rewards

### Recent Activity

- Source: `recent_transactions` list
- Query: Last 5 transactions ordered by `timestamp` DESC
- Shows:
  - Student name
  - Action (Deposited X bottles / Redeemed Y reward)
  - Points (+/- amount)
  - Time elapsed

### Machine Status

- Source: `machines` list from `Machine.get_all_machines()`
- Shows:
  - Machine ID
  - Location
  - Status (online/full/offline)
  - Fill percentage with progress bar

### Top Students This Week

- Source: `top_students` list
- Query: All students sorted by `bottles` DESC, limited to 5
- Shows:
  - Name, email, department
  - Current bottles count
  - Current points
  - Status

---

## Model Methods Used in Dashboard

### Student Model

```python
# Get all statistics
Student.get_student_statistics()

# Get all students (for top students)
Student.get_all_students()

# Get students by department (for dept chart)
Student.get_students_by_department(dept_name)

# Get specific student
Student.get_student_by_id(student_id)
```

### Transaction Model

```python
# Get all transactions
Transaction.get_all_transactions(limit=5)

# Get transaction statistics
Transaction.get_transaction_statistics()

# Get transactions by type
Transaction.get_transactions_by_type('redeem', limit=100)
```

### Department Model

```python
# Get all departments
Department.get_all_departments()

# Get department statistics
Department.get_department_statistics()
```

### Machine Model

```python
# Get all machines
Machine.get_all_machines()

# Get machine statistics
Machine.get_machine_statistics()
```

---

## Data Flow Example

### When a student deposits bottles:

1. **Arduino** detects bottles → sends to Firebase
2. **Transaction** created:
   ```python
   {
       'type': 'deposit',
       'points': 5,  # Example: 5 bottles = 5 points
       'userId': 'student123',
       'studentName': 'John Doe',
       'status': 'completed',
       'timestamp': now()
   }
   ```

3. **Student** record updated:
   ```python
   student.bottles += 5
   student.totalBottlesLifetime += 5
   student.points += 5
   student.totalPointsEarned += 5
   ```

4. **Dashboard** shows:
   - Total Bottles increases by 5
   - Total Points increases by 5
   - Recent Activity shows "John Doe deposited 5 bottles"
   - Department chart updates for John's department
   - Top Students ranks update

### When a student redeems a reward:

1. **Student** selects reward in Flutter app
2. **Transaction** created:
   ```python
   {
       'type': 'redeem',
       'points': 30,  # Cost of reward
       'rewardId': 'reward123',
       'rewardName': 'Coffee Voucher',
       'status': 'pending',
       'ticketCode': 'T2T-ABC123',
       'timestamp': now()
   }
   ```

3. **Student** record updated:
   ```python
   student.points -= 30
   student.totalPointsSpent += 30
   student.totalRewardsRedeemed += 1
   ```

4. **Dashboard** shows:
   - Rewards Redeemed count increases
   - Recent Activity shows "John Doe redeemed Coffee Voucher"
   - Popular Rewards chart updates
   - Top Points (current) for John decreases

---

## Verification Checklist

### To verify data is real:

- [ ] **Students exist**: Check Firebase Console → `students` collection
- [ ] **Transactions logged**: Check Firebase Console → `transactions` collection
- [ ] **Department data**: Students must have `department` field populated
- [ ] **Reward redemptions**: Transactions with `type='redeem'` must have `rewardName`
- [ ] **Machine registered**: Check Firebase Console → `machines` collection

### Common Issues:

1. **Charts show "No Data"**: 
   - Check if students exist with bottles deposited
   - Check if departments are properly assigned

2. **No recent activities**:
   - Check if transactions collection has entries
   - Check if timestamps are recent

3. **Zero rewards redeemed**:
   - Check if any transactions have `type='redeem'` AND `status='completed'`

4. **Top students empty**:
   - Check if students collection has entries
   - Check if students have `bottles` field populated

---

## Testing Tips

1. **Add Test Student**:
   ```python
   student = Student(
       full_name="Test Student",
       student_id="2024-0001",
       email="test@school.edu",
       department="Engineering",
       bottles=50,
       points=50,
       total_bottles_lifetime=50,
       total_points_earned=50
   )
   student.save()
   ```

2. **Add Test Transaction**:
   ```python
   transaction = Transaction.create_deposit_transaction(
       user_id="student_id_here",
       student_name="Test Student",
       points_earned=10,
       department="Engineering"
   )
   transaction.save()
   ```

3. **Check Data in Firebase Console**:
   - Navigate to Firestore Database
   - Check each collection manually
   - Verify field names match the model

---

**Date**: October 18, 2025
**Status**: ✅ Models Verified
**Collections**: students, transactions, departments, machines, rewards
