from datetime import datetime
from typing import Dict, List, Optional, Any
from enum import Enum
from services.firebase_service import db
from firebase_admin import firestore

class UserRole(Enum):
    STUDENT = "student"
    ADMIN = "admin"
    SUPERUSER = "superuser"

class UserStatus(Enum):
    ACTIVE = "active"
    BANNED = "banned"
    PENDING = "pending"

class User:
    """
    User model for Firebase Firestore integration.
    Handles all user-related operations for the Super User dashboard.
    Matches Flutter StudentModel structure.
    """
    
    def __init__(self, id: str = None, full_name: str = "", student_id: str = "", email: str = "", 
                 department: str = "", bottles: int = 0, points: int = 0, 
                 role: str = UserRole.STUDENT.value, status: str = UserStatus.ACTIVE.value,
                 created_at: datetime = None, updated_at: datetime = None):
        self.id = id
        self.full_name = full_name
        self.student_id = student_id  # Match Flutter studentID field
        self.email = email
        self.department = department
        self.bottles = bottles
        self.points = points
        self.role = role
        self.status = status
        self.created_at = created_at or datetime.now()
        self.updated_at = updated_at or datetime.now()
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert user object to dictionary for Firestore storage."""
        return {
            'fullName': self.full_name,
            'studentID': self.student_id,  # Match Flutter field name
            'email': self.email,
            'department': self.department,
            'bottles': self.bottles,
            'points': self.points,
            'role': self.role,
            'status': self.status,
            'createdAt': self.created_at,
            'updatedAt': self.updated_at
        }
    
    @classmethod
    def from_dict(cls, doc_id: str, data: Dict[str, Any]) -> 'User':
        """Create User object from Firestore document."""
        return cls(
            id=doc_id,
            full_name=data.get('fullName', ''),
            student_id=data.get('studentID', ''),  # Match Flutter field name
            email=data.get('email', ''),
            department=data.get('department', ''),
            bottles=data.get('bottles', 0),
            points=data.get('points', 0),
            role=data.get('role', UserRole.STUDENT.value),
            status=data.get('status', UserStatus.ACTIVE.value),
            created_at=data.get('createdAt'),
            updated_at=data.get('updatedAt')
        )
    
    @classmethod
    def get_all_users(cls) -> List['User']:
        """Retrieve all users from Firestore."""
        users = []
        try:
            users_ref = db.collection('users')
            docs = users_ref.stream()
            
            for doc in docs:
                user = cls.from_dict(doc.id, doc.to_dict())
                users.append(user)
        except Exception as e:
            print(f"Error fetching users: {e}")
        
        return users
    
    @classmethod
    def get_user_by_id(cls, user_id: str) -> Optional['User']:
        """Retrieve a specific user by ID."""
        try:
            doc_ref = db.collection('users').document(user_id)
            doc = doc_ref.get()
            
            if doc.exists:
                return cls.from_dict(doc.id, doc.to_dict())
        except Exception as e:
            print(f"Error fetching user {user_id}: {e}")
        
        return None
    
    @classmethod
    def get_users_by_department(cls, department: str) -> List['User']:
        """Filter users by department."""
        users = []
        try:
            users_ref = db.collection('users')
            query = users_ref.where('department', '==', department)
            docs = query.stream()
            
            for doc in docs:
                user = cls.from_dict(doc.id, doc.to_dict())
                users.append(user)
        except Exception as e:
            print(f"Error fetching users by department {department}: {e}")
        
        return users
    
    @classmethod
    def get_users_by_status(cls, status: str) -> List['User']:
        """Filter users by status."""
        users = []
        try:
            users_ref = db.collection('users')
            query = users_ref.where('status', '==', status)
            docs = query.stream()
            
            for doc in docs:
                user = cls.from_dict(doc.id, doc.to_dict())
                users.append(user)
        except Exception as e:
            print(f"Error fetching users by status {status}: {e}")
        
        return users
    
    @classmethod
    def get_users_by_role(cls, role: str) -> List['User']:
        """Filter users by role."""
        users = []
        try:
            users_ref = db.collection('users')
            query = users_ref.where('role', '==', role)
            docs = query.stream()
            
            for doc in docs:
                user = cls.from_dict(doc.id, doc.to_dict())
                users.append(user)
        except Exception as e:
            print(f"Error fetching users by role {role}: {e}")
        
        return users
    
    def save(self) -> bool:
        """Save or update user in Firestore."""
        try:
            self.updated_at = datetime.now()
            user_data = self.to_dict()
            
            if self.id:
                # Update existing user
                db.collection('users').document(self.id).update(user_data)
            else:
                # Create new user
                doc_ref = db.collection('users').add(user_data)
                self.id = doc_ref[1].id
            
            return True
        except Exception as e:
            print(f"Error saving user: {e}")
            return False
    
    def delete(self) -> bool:
        """Delete user from Firestore."""
        try:
            if self.id:
                db.collection('users').document(self.id).delete()
                return True
        except Exception as e:
            print(f"Error deleting user: {e}")
        
        return False
    
    def update_status(self, new_status: str) -> bool:
        """Update user status (for admin actions like banning)."""
        try:
            if new_status in [status.value for status in UserStatus]:
                self.status = new_status
                return self.save()
        except Exception as e:
            print(f"Error updating user status: {e}")
        
        return False
    
    def ban_user(self) -> bool:
        """Ban a user (set status to banned)."""
        return self.update_status(UserStatus.BANNED.value)
    
    def activate_user(self) -> bool:
        """Activate a user (set status to active)."""
        return self.update_status(UserStatus.ACTIVE.value)
    
    def add_bottles(self, bottle_count: int) -> bool:
        """Add bottles to user's count."""
        try:
            self.bottles += bottle_count
            # Calculate points (assuming 1 bottle = 1 point, adjust as needed)
            self.points += bottle_count
            return self.save()
        except Exception as e:
            print(f"Error adding bottles: {e}")
            return False
    
    def deduct_points(self, point_amount: int) -> bool:
        """Deduct points from user (for rewards redemption)."""
        try:
            if self.points >= point_amount:
                self.points -= point_amount
                return self.save()
            else:
                print("Insufficient points")
                return False
        except Exception as e:
            print(f"Error deducting points: {e}")
            return False
    
    @classmethod
    def get_top_users_by_bottles(cls, limit: int = 10) -> List['User']:
        """Get top users by bottle count."""
        users = []
        try:
            users_ref = db.collection('users')
            query = users_ref.order_by('bottles', direction=firestore.Query.DESCENDING).limit(limit)
            docs = query.stream()
            
            for doc in docs:
                user = cls.from_dict(doc.id, doc.to_dict())
                users.append(user)
        except Exception as e:
            print(f"Error fetching top users: {e}")
        
        return users
    
    @classmethod
    def get_top_users_by_points(cls, limit: int = 10) -> List['User']:
        """Get top users by points."""
        users = []
        try:
            users_ref = db.collection('users')
            query = users_ref.order_by('points', direction=firestore.Query.DESCENDING).limit(limit)
            docs = query.stream()
            
            for doc in docs:
                user = cls.from_dict(doc.id, doc.to_dict())
                users.append(user)
        except Exception as e:
            print(f"Error fetching top users by points: {e}")
        
        return users
    
    @classmethod
    def search_users(cls, search_term: str) -> List['User']:
        """Search users by name or email."""
        users = []
        try:
            # Note: Firestore doesn't support case-insensitive search natively
            # You might want to implement this with additional fields or use Algolia
            all_users = cls.get_all_users()
            search_term = search_term.lower()
            
            for user in all_users:
                if (search_term in user.full_name.lower() or 
                    search_term in user.email.lower()):
                    users.append(user)
        except Exception as e:
            print(f"Error searching users: {e}")
        
        return users
    
    @classmethod
    def get_user_statistics(cls) -> Dict[str, Any]:
        """Get overall user statistics for dashboard."""
        try:
            all_users = cls.get_all_users()
            
            total_users = len(all_users)
            active_users = len([u for u in all_users if u.status == UserStatus.ACTIVE.value])
            banned_users = len([u for u in all_users if u.status == UserStatus.BANNED.value])
            pending_users = len([u for u in all_users if u.status == UserStatus.PENDING.value])
            
            total_bottles = sum(user.bottles for user in all_users)
            total_points = sum(user.points for user in all_users)
            
            # Department breakdown
            departments = {}
            for user in all_users:
                dept = user.department
                if dept in departments:
                    departments[dept] += 1
                else:
                    departments[dept] = 1
            
            return {
                'total_users': total_users,
                'active_users': active_users,
                'banned_users': banned_users,
                'pending_users': pending_users,
                'total_bottles': total_bottles,
                'total_points': total_points,
                'department_breakdown': departments
            }
        except Exception as e:
            print(f"Error getting user statistics: {e}")
            return {}
    
    def __str__(self) -> str:
        return f"User(id={self.id}, name={self.full_name}, email={self.email}, department={self.department})"
    
    def __repr__(self) -> str:
        return self.__str__()
