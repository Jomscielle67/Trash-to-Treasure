# Model Analysis Report - Super User, Admin, and Student Systems

**Date**: October 18, 2025  
**Status**: ⚠️ Issues Found - Action Required

---

## 🚨 CRITICAL ISSUE FOUND

### Reports Page Bug: Missing Reward Attributes

**Location**: `app.py` Lines 1330-1338  
**Problem**: The reports route attempts to access attributes that don't exist in the Reward model:

```python
# Lines 1330-1338 in app.py
all_rewards = Reward.get_all_rewards()
category_distribution = {}
for reward in all_rewards:
    category = reward.category if reward.category else 'Others'  # ❌ 'category' doesn't exist
    if category in category_distribution:
        category_distribution[category] += reward.redeemed_count  # ❌ 'redeemed_count' doesn't exist
    else:
        category_distribution[category] = reward.redeemed_count  # ❌ 'redeemed_count' doesn't exist
```

**Current Reward Model Attributes**:
- ✅ id, name, cost, stock, department, image_url, created_by, status, created_at, updated_at
- ❌ category (missing)
- ❌ redeemed_count (missing)

**Impact**: This code will cause an `AttributeError` when accessing the reports page if any rewards exist.

**Solution Options**:

1. **Option A - Remove Category Distribution Chart** (Quick Fix)
   - Remove the category distribution calculation
   - Hide or remove the reward categories chart in the template
   - No database changes needed

2. **Option B - Add Missing Fields** (Complete Fix)
   - Add `category` field to Reward model (String: "Food", "Merchandise", etc.)
   - Add `redeemed_count` field to track redemptions (Integer, incremented on each redeem)
   - Update all three systems (Super User Python, Admin Flutter, User Flutter)
   - Update Firestore documents to include these fields

---

## 📊 Model Comparison Across Systems

### 1. **Student Model**

#### Super User (Python) - `models/student_model.py`
```python
class Student:
    - id: str
    - full_name: str
    - student_id: str (camelCase: studentID in Firestore)
    - email: str
    - department: str
    - course: str
    - year_level: str
    - section: str
    - points: int
    - bottles: int
    - total_bottles_lifetime: int
    - total_points_earned: int
    - total_points_spent: int
    - status: str (StudentStatus.ACTIVE)
    - profile_image_url: str
    - phone_number: str
    - date_of_birth: str
    - address: str
    - is_email_verified: bool
    - is_profile_complete: bool
    - current_streak: int
    - longest_streak: int
    - last_login_at: datetime
    - last_activity_at: datetime
    - total_sessions: int
    - achievements: List[str]
    - total_rewards_redeemed: int
    - favorite_reward_category: str
    - preferences: Dict
    - created_at: datetime
    - updated_at: datetime
    - last_modified_by: str
```

#### Admin Flutter - `t2t_admin/lib/models/student_model.dart`
```dart
class StudentModel {
    - id: String
    - fullName: String
    - studentID: String
    - email: String
    - department: String
    - points: int (default: 0)
    - bottles: int (default: 0)
    - role: String (always 'student')
    - createdAt: Timestamp
}
```

#### User Flutter - `t2t_user/lib/models/student_model.dart`
```dart
class StudentModel {
    - id: String
    - fullName: String
    - studentID: String
    - email: String
    - department: String
    - points: int (default: 0)
    - bottles: int (default: 0)
    - role: String (always 'student')
    - createdAt: Timestamp
    - profileImageUrl: String?  // ✅ Has this extra field
}
```

**Status**: ✅ **COMPATIBLE** - Core fields match across all systems
- Python model has many extended fields for analytics
- Flutter apps use minimal required fields
- All core transaction fields (points, bottles, studentID) are consistent

---

### 2. **Admin Model**

#### Super User (Python) - `models/admin_model.py`
```python
class Admin:
    - id: str
    - name: str
    - email: str
    - department: str
    - position: str
    - employee_id: str
    - image_url: str (camelCase: imageUrl in Firestore)
    - phone_number: str
    - office_location: str
    - office_hours: str
    - role: str (AdminRole.ADMIN)
    - permissions: List[str]
    - access_level: int (AccessLevel)
    - status: str (AdminStatus.ACTIVE)
    - last_login_at: datetime
    - total_logins: int
    - is_active: bool
    - students_managed: int
    - rewards_created: int
    - transactions_processed: int
    - created_at: datetime
    - created_by: str
    - updated_at: datetime
```

#### Admin Flutter - `t2t_admin/lib/models/admin_model.dart`
```dart
class AdminModel {
    - id: String
    - name: String
    - email: String
    - department: String
    - imageUrl: String?
    - role: String (default: 'admin')
    - permissions: List<String>?
    - createdAt: Timestamp
}
```

#### User Flutter - `t2t_user/lib/models/admin_model.dart`
```dart
class AdminModel {
    - id: String
    - name: String
    - email: String
    - department: String
    - imageUrl: String?
    - role: String (default: 'admin')
    - permissions: List<String>?
    - createdAt: Timestamp
}
```

**Status**: ✅ **COMPATIBLE** - Core fields match
- Python has extensive management fields
- Both Flutter apps have identical admin models (read-only display)
- Field names properly converted (camelCase ↔ snake_case)

---

### 3. **Reward Model**

#### Super User (Python) - `models/rewards.py`
```python
class Reward:
    - id: str
    - name: str
    - cost: int
    - stock: int
    - department: str
    - image_url: str (camelCase: imageUrl in Firestore)
    - created_by: str (camelCase: createdBy in Firestore)
    - status: str (RewardStatus)
    - created_at: datetime
    - updated_at: datetime
    
    ❌ MISSING:
    - category: str (needed for reports)
    - redeemed_count: int (needed for reports)
```

#### Admin Flutter - `t2t_admin/lib/models/reward_model.dart`
```dart
class RewardModel {
    - id: String
    - name: String
    - cost: int
    - stock: int
    - department: String
    - imageUrl: String?
    - createdBy: String
    - createdAt: Timestamp
}
```

#### User Flutter - `t2t_user/lib/models/reward_model.dart`
```dart
class RewardModel {
    - id: String
    - name: String
    - cost: int
    - stock: int
    - department: String
    - imageUrl: String?
    - createdBy: String
    - createdAt: Timestamp
}
```

**Status**: ⚠️ **ISSUE FOUND** - Missing attributes for reports functionality
- All three systems are currently consistent with each other
- **BUT** reports page expects `category` and `redeemed_count` fields
- Need to decide whether to add these fields or modify reports logic

---

### 4. **Department Model**

#### Super User (Python) - `models/department_model.py`
```python
class Department:
    - id: str
    - name: str
    - admin_id: str (camelCase: adminId in Firestore)
    - bottle_rate: int (camelCase: bottleRate in Firestore)
    - location: str
    - status: str ('active', 'inactive')
    - icon: str (emoji)
    - description: str
    - order: int
    - created_at: datetime
    - updated_at: datetime
    - created_by: str
```

#### Admin Flutter - `t2t_admin/lib/models/department_model.dart`
```dart
class DepartmentModel {
    - id: String
    - name: String
    - adminId: String?
    - bottleRate: int?
    - location: String?
}
```

#### User Flutter - `t2t_user/lib/models/department_model.dart`
```dart
class DepartmentModel {
    - id: String
    - name: String
    - adminId: String?
    - bottleRate: int?
    - location: String?
}
```

**Status**: ✅ **COMPATIBLE** - Core fields match perfectly
- Both Flutter apps have identical models
- Python has additional management fields (status, icon, description, order)
- All critical fields (name, adminId, bottleRate) are synchronized

---

### 5. **Transaction Model**

#### Super User (Python) - `models/transaction.py`
```python
class Transaction:
    - id: str
    - user_id: str (camelCase: userId in Firestore)
    - student_name: str (camelCase: studentName in Firestore)
    - reward_id: str (camelCase: rewardId in Firestore)
    - reward_name: str (camelCase: rewardName in Firestore)
    - points: int
    - type: str ('deposit', 'redeem')
    - department: str
    - status: str ('completed', 'pending', 'cancelled')
    - ticket_code: str (camelCase: ticketCode in Firestore)
    - timestamp: datetime
```

#### Admin Flutter - `t2t_admin/lib/models/transaction_model.dart`
```dart
class TransactionModel {
    - id: String
    - userId: String
    - studentName: String
    - rewardId: String?
    - rewardName: String?
    - points: int
    - type: String ('deposit', 'redeem')
    - department: String
    - status: String ('Pending', 'Completed')
    - ticketCode: String? (auto-generated for redemptions)
    - timestamp: Timestamp
    
    + static generateTicketCode(): String
}
```

#### User Flutter - `t2t_user/lib/models/transaction_model.dart`
```dart
class TransactionModel {
    - id: String
    - userId: String
    - studentName: String
    - rewardId: String?
    - rewardName: String?
    - points: int
    - type: String ('deposit', 'redeem')
    - department: String
    - status: String ('Pending', 'Completed')
    - ticketCode: String? (auto-generated for redemptions)
    - timestamp: Timestamp
    
    + static generateTicketCode(): String
}
```

**Status**: ✅ **PERFECTLY SYNCHRONIZED** - All fields match
- Identical structure across all three systems
- Field names properly converted between snake_case and camelCase
- Status values are compatible ('completed'/'Completed', 'pending'/'Pending')
- Both Flutter apps have identical models

---

### 6. **Machine Model** (Super User Only)

#### Super User (Python) - `models/machine_model.py`
```python
class Machine:
    - id: str
    - machine_id: str
    - location: str
    - status: str (MachineStatus: active, offline, full, maintenance, error)
    - last_maintenance: datetime
    - bottles_collected: int
    - updated_by: str
    - capacity: int
    - current_bottles: int
    - last_online: datetime
    - created_at: datetime
    - maintenance_schedule: int
    - notes: str
```

**Status**: ✅ **SUPER USER EXCLUSIVE** - Not needed in Flutter apps

---

### 7. **QR Code Model** (Super User Only)

#### Super User (Python) - `models/qr_code_model.py`
```python
class QRCode:
    - id: str
    - qr_code_id: str (auto-generated)
    - qr_code_type: str (QRCodeType enum)
    - machine_id: str
    - reward_id: str
    - student_id: str
    - generated_by: str
    - generated_for: str
    - data: Dict
    - is_active: bool
    - expires_at: datetime
    - usage_count: int
    - max_usage: int
    - last_used_at: datetime
    - last_used_by: str
    - department: str
    - location: str
    - status: str (QRCodeStatus)
    - created_at: datetime
    - notes: str
```

**Status**: ✅ **SUPER USER EXCLUSIVE** - Not needed in Flutter apps

---

### 8. **Notification Model** (Super User Only)

#### Super User (Python) - `models/notification_model.py`
```python
class Notification:
    - id: str
    - user_id: str
    - user_type: str (UserType: student, admin, all)
    - title: str
    - body: str
    - notification_type: str (NotificationType enum)
    - data: Dict
    - is_read: bool
    - sent_at: datetime
    - read_at: datetime
    - device_tokens: List[str]
    - priority: str (NotificationPriority)
    - image_url: str
    - action_url: str
    - expires_at: datetime
    - target_audience: str
    - department: str
    - created_by: str
    - created_at: datetime
```

**Status**: ✅ **SUPER USER EXCLUSIVE** - Push notification management

---

### 9. **Super User Model** (Super User Only)

#### Super User (Python) - `models/super_user_model.py`
```python
class SuperUser:
    - id: str
    - full_name: str
    - email: str
    - department: str
    - password_hash: str
    - salt: str
    - role: str (SuperUserRole enum)
    - status: str (SuperUserStatus enum)
    - phone_number: str
    - profile_image_url: str
    - last_login_at: datetime
    - last_login_ip: str
    - failed_login_attempts: int
    - account_locked_until: datetime
    - password_changed_at: datetime
    - email_verified: bool
    - email_verification_token: str
    - password_reset_token: str
    - password_reset_expires: datetime
    - two_factor_enabled: bool
    - two_factor_secret: str
    - session_tokens: List[str]
    - permissions: List[str]
    - created_at: datetime
    - updated_at: datetime
    - created_by: str
    - last_modified_by: str
```

**Status**: ✅ **SUPER USER EXCLUSIVE** - Web dashboard authentication

---

## 🔍 FIELD NAME MAPPING

### Python (snake_case) ↔ Firestore (camelCase)

| Python Field | Firestore Field | Status |
|-------------|-----------------|---------|
| `student_id` | `studentID` | ✅ Properly mapped |
| `full_name` | `fullName` | ✅ Properly mapped |
| `image_url` | `imageUrl` | ✅ Properly mapped |
| `created_by` | `createdBy` | ✅ Properly mapped |
| `user_id` | `userId` | ✅ Properly mapped |
| `student_name` | `studentName` | ✅ Properly mapped |
| `reward_id` | `rewardId` | ✅ Properly mapped |
| `reward_name` | `rewardName` | ✅ Properly mapped |
| `ticket_code` | `ticketCode` | ✅ Properly mapped |
| `admin_id` | `adminId` | ✅ Properly mapped |
| `bottle_rate` | `bottleRate` | ✅ Properly mapped |
| `created_at` | `createdAt` | ✅ Properly mapped |
| `updated_at` | `updatedAt` | ✅ Properly mapped |

---

## ✅ SUMMARY

### What's Working Well:
1. ✅ **Core Models Are Synchronized** - Student, Admin, Transaction, Department, Reward
2. ✅ **Field Name Conversion** - Python ↔ Firestore ↔ Flutter properly handled
3. ✅ **Data Types Match** - int, String, Timestamp, bool all consistent
4. ✅ **Transaction Flow** - All three systems can read/write transactions correctly
5. ✅ **Student Data** - Points and bottles tracked consistently
6. ✅ **Reward Management** - Stock and cost fields match perfectly

### Critical Issues:
1. ❌ **Reports Page Bug** - Accessing non-existent `reward.category` and `reward.redeemed_count`
2. ⚠️ **Incomplete Reward Tracking** - No way to track which rewards are most popular

### Recommendations:

#### **IMMEDIATE ACTION REQUIRED** (Fix Reports Page)

**Option 1 - Quick Fix** (Recommended for now):
```python
# In app.py, replace lines 1330-1343 with:
# Calculate reward statistics (simplified without category)
reward_categories = []  # Empty - remove chart or show "Coming Soon"
```

**Option 2 - Complete Fix** (Future enhancement):
1. Add `category` field to Reward model (all 3 systems)
2. Add `redeemed_count` field to Reward model (all 3 systems)
3. Increment `redeemed_count` whenever a reward is redeemed
4. Update existing Firestore documents with default values
5. Update reports logic to use these new fields

---

## 📝 ACTION ITEMS

### High Priority (Fix Now):
- [ ] Fix reports page to remove category distribution code OR
- [ ] Add category and redeemed_count fields to all Reward models

### Medium Priority (Future Enhancement):
- [ ] Add reward category tracking system
- [ ] Implement redemption counting mechanism
- [ ] Add analytics dashboard for reward popularity

### Low Priority (Optional):
- [ ] Standardize status field capitalization ('active' vs 'Active')
- [ ] Add more analytics fields to Flutter models
- [ ] Implement caching for frequently accessed data

---

**Report Generated**: October 18, 2025  
**Systems Analyzed**: Super User (Python/Flask), Admin (Flutter), Student (Flutter)  
**Total Models Checked**: 9 models across 3 systems  
**Issues Found**: 1 critical bug in reports page
