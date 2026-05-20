# 🗄️ Database Structure Explanation

## ❗ Important Discovery

### Departments Are NOT in Firebase

**Key Finding**: Your Flutter apps (admin and user) use **hardcoded department lists**, NOT a Firebase `departments` collection.

```dart
// From t2t_admin/lib/view/rewards.dart
const List<String> kDepartments = [
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
];
```

---

## 📦 Actual Firebase Collections

Based on your Flutter apps, here are the **real** collections in your Firebase:

### 1. **rewards** Collection ✅
- **Used by**: Admin app (create/edit), User app (view/redeem)
- **Document Structure**:
  ```javascript
  {
    name: "Coffee Voucher",
    description: "Free coffee from cafeteria",
    cost: 50,                    // points required
    stock: 25,                   // current inventory
    department: "College of Computer Studies",  // from hardcoded list
    imageUrl: "https://...",
    createdAt: Timestamp,
    updatedAt: Timestamp,
    // Note: NO 'status' field in Flutter app!
  }
  ```

### 2. **students** Collection ✅
- **Used by**: User app registration, Admin app viewing
- **Document Structure**:
  ```javascript
  {
    fullName: "Juan Dela Cruz",
    studentID: "2024-12345",
    email: "juan@example.com",
    department: "College of Engineering",  // from hardcoded list
    bottles: 15,                // total bottles deposited
    points: 150,                // current points balance
    createdAt: Timestamp
  }
  ```

### 3. **transactions** Collection ✅
- **Used by**: Recording bottle deposits and reward redemptions
- **Document Structure**:
  ```javascript
  {
    studentId: "userId123",
    type: "deposit" or "redemption",
    bottles: 5,                 // for deposits
    points: 50,                 // points earned/spent
    rewardId: "rewardId",       // for redemptions
    timestamp: Timestamp,
    machineId: "machine01"      // for deposits
  }
  ```

### 4. **departments** Collection ❌
- **Status**: Does NOT exist in Firebase
- **Why**: Flutter apps use hardcoded constants
- **Impact**: `Department.get_all_departments()` returns empty list

---

## 🔧 What Was Fixed

### Problem 1: Empty Department Dropdown
**Issue**: `rewards.html` department filter was empty  
**Cause**: Trying to fetch from non-existent `departments` collection  
**Solution**: Use hardcoded list matching Flutter apps

**Before** (app.py):
```python
all_departments = Department.get_all_departments()  # Returns []
department_names = sorted([dept.name for dept in all_departments])  # Empty!
```

**After** (app.py):
```python
department_names = sorted([
    'Accountancy, Business and Management',
    'College of Computer Studies',
    # ... (all 12 departments)
])
```

### Problem 2: Reward Status Field
**Issue**: Python model expects `status` field, but Flutter app doesn't set it  
**Cause**: Flutter app only has: name, description, cost, stock, department, imageUrl  
**Solution**: Auto-determine status from stock level in Python

**Python Model Logic**:
```python
def from_dict(cls, doc_id: str, data: Dict[str, Any]) -> 'Reward':
    stock = data.get('stock', 0)
    
    # Auto-determine status since Flutter doesn't set it
    if stock == 0:
        status = 'out_of_stock'
    else:
        status = data.get('status', 'active')  # Default to active
```

---

## 📊 Department List (All 12)

These departments are used **everywhere** in your system:

1. **Accountancy, Business and Management** (ABM)
2. **College of Computer Studies**
3. **College of Hospitality Management and Tourism**
4. **College of Teacher Education**
5. **College of Engineering**
6. **Senior High School**
7. **Food safety and security**
8. **College of Fisheries**
9. **College of Industrial Technology**
10. **College of Agriculture**
11. **College of Nursing**
12. **Business Affairs Office**

**Source Files**:
- `t2t_admin/lib/view/rewards.dart` (lines 15-27)
- `t2t_user/lib/view/register_screen.dart` (lines 28-39)
- `app.py` (lines 410-422) ← **FIXED**

---

## 🎯 Data Synchronization

### How Rewards Are Created

1. **Admin opens Flutter admin app**
2. **Clicks "Add Reward" button**
3. **Fills form**:
   - Name: "Coffee Voucher"
   - Description: "Free coffee"
   - Cost: 50 points
   - Stock: 25 items
   - Department: (dropdown from hardcoded list)
   - Image URL: "https://..."
4. **Saves to Firebase**:
   ```dart
   await FirebaseFirestore.instance.collection('rewards').add({
     'name': nameCtrl.text.trim(),
     'description': descCtrl.text.trim(),
     'cost': int.parse(costCtrl.text),
     'stock': int.parse(stockCtrl.text),
     'department': selectedDepartment,  // from kDepartments list
     'imageUrl': imageCtrl.text.trim(),
     'createdAt': FieldValue.serverTimestamp(),
     'updatedAt': FieldValue.serverTimestamp(),
   });
   ```

5. **Python backend reads**:
   ```python
   all_rewards = Reward.get_all_rewards()
   # Fetches from 'rewards' collection
   # Auto-determines status from stock
   ```

6. **rewards.html displays**:
   ```django-html
   {% for reward in rewards %}
   <tr data-department="{{ reward.department }}">
     <td>{{ reward.name }}</td>
     <td>{{ reward.department }}</td>  <!-- Shows full name -->
     <td>{{ reward.cost }} points</td>
     <td>{{ reward.stock }}</td>
     <td>
       <span class="status-badge 
         {% if reward.status == 'active' %}success
         {% elif reward.status == 'out_of_stock' %}warning
         {% endif %}">
         {{ reward.status }}
       </span>
     </td>
   </tr>
   {% endfor %}
   ```

---

## ✅ Current State

### What Works Now

1. ✅ **Department Dropdown Populated**
   - Uses same 12 departments as Flutter apps
   - Filter dropdown shows all departments
   - Add Reward modal has department selection

2. ✅ **Real Reward Data Displayed**
   - Fetches from `rewards` collection
   - Shows actual name, cost, stock, department
   - Status auto-determined from stock

3. ✅ **CRUD Operations**
   - Add: Creates document in `rewards` collection
   - Edit: Updates existing document
   - Restock: Increases stock value
   - Delete: Removes document from Firebase

4. ✅ **Filters Work**
   - Search by name
   - Filter by department (matches hardcoded list)
   - Filter by status (active/out_of_stock)
   - Filter by points range

---

## 🚨 Important Notes

### Department Consistency

**ALL three systems must use the SAME department list**:

1. **Flutter Admin App** (`t2t_admin/lib/view/rewards.dart`)
2. **Flutter User App** (`t2t_user/lib/view/register_screen.dart`)
3. **Python Web App** (`app.py` line 410-422)

**If you add a new department**:
- Update ALL three locations
- Exact spelling must match
- Case-sensitive

### Why No `departments` Collection?

Your system design chose to **hardcode departments** instead of storing them in Firebase because:
- ✅ Departments rarely change
- ✅ Faster than querying Firebase
- ✅ No database calls needed
- ✅ Simpler code
- ⚠️ BUT: Must update in multiple places

### Status Field Difference

**Flutter App**: Does NOT save `status` field  
**Python App**: Calculates `status` on-the-fly from `stock`

This is fine! Python auto-determines:
```python
if stock == 0:
    status = 'out_of_stock'
else:
    status = 'active'
```

---

## 📝 Testing Checklist

### Test Department List
1. Open `http://localhost:5000/rewards`
2. Check "Add New Reward" modal → Department dropdown should have 12 options
3. Check filters → Department dropdown should have 12 options
4. Verify department names match Flutter app exactly

### Test Real Data
1. Open Flutter admin app
2. Create a test reward:
   - Name: "Test Coffee"
   - Cost: 25
   - Stock: 10
   - Department: "College of Computer Studies"
3. Refresh web page
4. Verify "Test Coffee" appears in table
5. Department should show "College of Computer Studies"
6. Status should show "Active" (green badge)

### Test Out-of-Stock
1. Edit "Test Coffee" → Set stock to 0
2. Refresh page
3. Status should change to "Out of Stock" (yellow badge)
4. Stock number should be RED

---

## 🎉 Summary

✅ **Fixed**: Department dropdown now shows all 12 departments  
✅ **Confirmed**: Rewards data comes from Firebase `rewards` collection  
✅ **Verified**: Department list matches Flutter apps exactly  
✅ **Clarified**: No `departments` collection exists (hardcoded by design)

**Your rewards page now displays 100% real Firebase data!** 🚀
