from datetime import datetime
from typing import Dict, List, Optional, Any
from enum import Enum
from services.firebase_service import db
from firebase_admin import firestore

class AdminRole(Enum):
    ADMIN = "admin"
    SUPER_ADMIN = "super_admin"
    DEPARTMENT_ADMIN = "department_admin"

class AdminStatus(Enum):
    ACTIVE = "active"
    INACTIVE = "inactive"
    SUSPENDED = "suspended"

class AccessLevel(Enum):
    DEPARTMENT = 1  # Can manage own department only
    UNIVERSITY = 2  # Can manage multiple departments
    SYSTEM = 3      # Full system access

class Admin:
    """
    Enhanced Admin model for Firebase Firestore integration.
    Matches Flutter AdminModel structure with additional management features.
    Used by all three systems: Web (Super User), Admin Flutter, Student Flutter.
    """
    
    def __init__(self, id: str = None, name: str = "", email: str = "", 
                 department: str = "", position: str = "", employee_id: str = "",
                 image_url: str = "", phone_number: str = "", 
                 office_location: str = "", office_hours: str = "",
                 role: str = AdminRole.ADMIN.value, permissions: List[str] = None,
                 access_level: int = AccessLevel.DEPARTMENT.value, 
                 status: str = AdminStatus.ACTIVE.value,
                 last_login_at: datetime = None, total_logins: int = 0,
                 is_active: bool = True, students_managed: int = 0,
                 rewards_created: int = 0, transactions_processed: int = 0,
                 created_at: datetime = None, created_by: str = "",
                 updated_at: datetime = None):
        
        self.id = id
        self.name = name
        self.email = email
        self.department = department
        self.position = position
        self.employee_id = employee_id
        
        # Profile information
        self.image_url = image_url
        self.phone_number = phone_number
        self.office_location = office_location
        self.office_hours = office_hours
        
        # Access & permissions
        self.role = role
        self.permissions = permissions or self._get_default_permissions()
        self.access_level = access_level
        self.status = status
        
        # Activity tracking
        self.last_login_at = last_login_at
        self.total_logins = total_logins
        self.is_active = is_active
        
        # Management statistics
        self.students_managed = students_managed
        self.rewards_created = rewards_created
        self.transactions_processed = transactions_processed
        
        # Timestamps
        self.created_at = created_at or datetime.now()
        self.created_by = created_by
        self.updated_at = updated_at or datetime.now()
    
    def _get_default_permissions(self) -> List[str]:
        """Get default permissions based on role."""
        if self.role == AdminRole.SUPER_ADMIN.value:
            return [
                'manage_students', 'manage_admins', 'manage_rewards', 
                'manage_machines', 'view_analytics', 'manage_departments',
                'system_settings', 'generate_reports', 'manage_transactions'
            ]
        elif self.role == AdminRole.DEPARTMENT_ADMIN.value:
            return [
                'manage_students', 'manage_rewards', 'view_analytics',
                'generate_reports', 'manage_transactions'
            ]
        else:  # Regular admin
            return [
                'view_students', 'manage_rewards', 'view_analytics'
            ]
    
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert admin object to dictionary for Firestore storage."""
        return {
            # Basic info (Flutter compatible field names)
            'name': self.name,
            'email': self.email,
            'department': self.department,
            'position': self.position,
            'employeeId': self.employee_id,
            
            # Profile
            'imageUrl': self.image_url,
            'phoneNumber': self.phone_number,
            'officeLocation': self.office_location,
            'officeHours': self.office_hours,
            
            # Access & permissions
            'role': self.role,
            'permissions': self.permissions,
            'accessLevel': self.access_level,
            'status': self.status,
            
            # Activity tracking
            'lastLoginAt': self.last_login_at,
            'totalLogins': self.total_logins,
            'isActive': self.is_active,
            
            # Management statistics
            'studentsManaged': self.students_managed,
            'rewardsCreated': self.rewards_created,
            'transactionsProcessed': self.transactions_processed,
            
            # Timestamps
            'createdAt': self.created_at,
            'createdBy': self.created_by,
            'updatedAt': self.updated_at
        }
    
    @classmethod
    def from_dict(cls, doc_id: str, data: Dict[str, Any]) -> 'Admin':
        """Create Admin object from Firestore document."""
        return cls(
            id=doc_id,
            name=data.get('name', ''),
            email=data.get('email', ''),
            department=data.get('department', ''),
            position=data.get('position', ''),
            employee_id=data.get('employeeId', ''),
            
            # Profile
            image_url=data.get('imageUrl', ''),
            phone_number=data.get('phoneNumber', ''),
            office_location=data.get('officeLocation', ''),
            office_hours=data.get('officeHours', ''),
            
            # Access & permissions
            role=data.get('role', AdminRole.ADMIN.value),
            permissions=data.get('permissions', []),
            access_level=data.get('accessLevel', AccessLevel.DEPARTMENT.value),
            status=data.get('status', AdminStatus.ACTIVE.value),
            
            # Activity tracking
            last_login_at=data.get('lastLoginAt'),
            total_logins=data.get('totalLogins', 0),
            is_active=data.get('isActive', True),
            
            # Management statistics
            students_managed=data.get('studentsManaged', 0),
            rewards_created=data.get('rewardsCreated', 0),
            transactions_processed=data.get('transactionsProcessed', 0),
            
            # Timestamps
            created_at=data.get('createdAt'),
            created_by=data.get('createdBy', ''),
            updated_at=data.get('updatedAt')
        )
    
    
    @classmethod
    def get_all_admins(cls) -> List['Admin']:
        """Retrieve all admins from Firestore."""
        admins = []
        try:
            admins_ref = db.collection('admins')
            docs = admins_ref.stream()
            
            for doc in docs:
                admin = cls.from_dict(doc.id, doc.to_dict())
                admins.append(admin)
        except Exception as e:
            print(f"Error fetching admins: {e}")
        
        return admins
    
    @classmethod
    def get_admin_by_id(cls, admin_id: str) -> Optional['Admin']:
        """Retrieve a specific admin by ID."""
        try:
            doc_ref = db.collection('admins').document(admin_id)
            doc = doc_ref.get()
            
            if doc.exists:
                return cls.from_dict(doc.id, doc.to_dict())
        except Exception as e:
            print(f"Error fetching admin {admin_id}: {e}")
        
        return None
    
    @classmethod
    def get_admin_by_email(cls, email: str) -> Optional['Admin']:
        """Retrieve admin by email."""
        try:
            admins_ref = db.collection('admins')
            query = admins_ref.where('email', '==', email)
            docs = query.stream()
            
            for doc in docs:
                return cls.from_dict(doc.id, doc.to_dict())
        except Exception as e:
            print(f"Error fetching admin by email {email}: {e}")
        
        return None
    
    @classmethod
    def get_admins_by_department(cls, department: str) -> List['Admin']:
        """Filter admins by department."""
        admins = []
        try:
            admins_ref = db.collection('admins')
            query = admins_ref.where('department', '==', department)
            docs = query.stream()
            
            for doc in docs:
                admin = cls.from_dict(doc.id, doc.to_dict())
                admins.append(admin)
        except Exception as e:
            print(f"Error fetching admins by department {department}: {e}")
        
        return admins
    
    @classmethod
    def get_admins_by_role(cls, role: str) -> List['Admin']:
        """Filter admins by role."""
        admins = []
        try:
            admins_ref = db.collection('admins')
            query = admins_ref.where('role', '==', role)
            docs = query.stream()
            
            for doc in docs:
                admin = cls.from_dict(doc.id, doc.to_dict())
                admins.append(admin)
        except Exception as e:
            print(f"Error fetching admins by role {role}: {e}")
        
        return admins
    
    @classmethod
    def get_active_admins(cls) -> List['Admin']:
        """Get all active admins."""
        admins = []
        try:
            admins_ref = db.collection('admins')
            query = admins_ref.where('status', '==', AdminStatus.ACTIVE.value)
            docs = query.stream()
            
            for doc in docs:
                admin = cls.from_dict(doc.id, doc.to_dict())
                admins.append(admin)
        except Exception as e:
            print(f"Error fetching active admins: {e}")
        
        return admins
    
    def save(self) -> bool:
        """Save or update admin in Firestore."""
        try:
            self.updated_at = datetime.now()
            admin_data = self.to_dict()
            
            if self.id:
                # Update existing admin
                db.collection('admins').document(self.id).update(admin_data)
            else:
                # Create new admin
                doc_ref = db.collection('admins').add(admin_data)
                self.id = doc_ref[1].id
            
            return True
        except Exception as e:
            print(f"Error saving admin: {e}")
            return False
    
    def delete(self) -> bool:
        """Delete admin from Firestore."""
        try:
            if self.id:
                db.collection('admins').document(self.id).delete()
                return True
        except Exception as e:
            print(f"Error deleting admin: {e}")
        
        return False
    
    def has_permission(self, permission: str) -> bool:
        """Check if admin has specific permission."""
        return permission in self.permissions
    
    def can_manage_department(self, department: str) -> bool:
        """Check if admin can manage specific department."""
        if self.access_level >= AccessLevel.UNIVERSITY.value:
            return True
        return self.department == department
    
    def can_manage_student(self, student_department: str) -> bool:
        """Check if admin can manage student from specific department."""
        if not self.has_permission('manage_students'):
            return False
        return self.can_manage_department(student_department)
    
    def add_permission(self, permission: str) -> bool:
        """Add permission to admin."""
        try:
            if permission not in self.permissions:
                self.permissions.append(permission)
                return self.save()
            return True
        except Exception as e:
            print(f"Error adding permission: {e}")
            return False
    
    def remove_permission(self, permission: str) -> bool:
        """Remove permission from admin."""
        try:
            if permission in self.permissions:
                self.permissions.remove(permission)
                return self.save()
            return True
        except Exception as e:
            print(f"Error removing permission: {e}")
            return False
    
    def update_login_activity(self) -> bool:
        """Update login activity."""
        try:
            self.last_login_at = datetime.now()
            self.total_logins += 1
            return self.save()
        except Exception as e:
            print(f"Error updating login activity: {e}")
            return False
    
    def update_management_stats(self, students_count: int = None, rewards_count: int = None, 
                              transactions_count: int = None) -> bool:
        """Update management statistics."""
        try:
            if students_count is not None:
                self.students_managed = students_count
            if rewards_count is not None:
                self.rewards_created = rewards_count
            if transactions_count is not None:
                self.transactions_processed = transactions_count
            
            return self.save()
        except Exception as e:
            print(f"Error updating management stats: {e}")
            return False
    
    def update_status(self, new_status: str) -> bool:
        """Update admin status."""
        try:
            if new_status in [status.value for status in AdminStatus]:
                self.status = new_status
                self.is_active = (new_status == AdminStatus.ACTIVE.value)
                return self.save()
        except Exception as e:
            print(f"Error updating admin status: {e}")
        
        return False
    
    
    @classmethod
    def get_admin_statistics(cls) -> Dict[str, Any]:
        """Get overall admin statistics for dashboard."""
        try:
            all_admins = cls.get_all_admins()
            
            total_admins = len(all_admins)
            active_admins = len([a for a in all_admins if a.status == AdminStatus.ACTIVE.value])
            super_admins = len([a for a in all_admins if a.role == AdminRole.SUPER_ADMIN.value])
            department_admins = len([a for a in all_admins if a.role == AdminRole.DEPARTMENT_ADMIN.value])
            regular_admins = len([a for a in all_admins if a.role == AdminRole.ADMIN.value])
            
            # Department breakdown
            departments = {}
            for admin in all_admins:
                dept = admin.department
                if dept in departments:
                    departments[dept] += 1
                else:
                    departments[dept] = 1
            
            # Permission analysis
            all_permissions = []
            for admin in all_admins:
                all_permissions.extend(admin.permissions)
            
            permission_counts = {}
            for perm in all_permissions:
                if perm in permission_counts:
                    permission_counts[perm] += 1
                else:
                    permission_counts[perm] = 1
            
            # Activity stats
            active_this_week = len([a for a in all_admins if a.last_login_at and 
                                  (datetime.now() - a.last_login_at).days <= 7])
            
            total_students_managed = sum(admin.students_managed for admin in all_admins)
            total_rewards_created = sum(admin.rewards_created for admin in all_admins)
            total_transactions_processed = sum(admin.transactions_processed for admin in all_admins)
            
            return {
                'total_admins': total_admins,
                'active_admins': active_admins,
                'super_admins': super_admins,
                'department_admins': department_admins,
                'regular_admins': regular_admins,
                'active_this_week': active_this_week,
                'department_breakdown': departments,
                'permission_usage': permission_counts,
                'total_students_managed': total_students_managed,
                'total_rewards_created': total_rewards_created,
                'total_transactions_processed': total_transactions_processed
            }
        except Exception as e:
            print(f"Error getting admin statistics: {e}")
            return {}
    
    def __str__(self) -> str:
        return f"Admin(id={self.id}, name={self.name}, email={self.email}, department={self.department}, role={self.role})"
    
    def __repr__(self) -> str:
        return self.__str__()