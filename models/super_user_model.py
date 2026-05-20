from datetime import datetime
from typing import Dict, List, Optional, Any
from enum import Enum
from services.firebase_service import db
from firebase_admin import firestore
import hashlib
import secrets
import re

class SuperUserRole(Enum):
    SUPER_ADMIN = "super_admin"
    SYSTEM_ADMIN = "system_admin"
    REGIONAL_ADMIN = "regional_admin"

class SuperUserStatus(Enum):
    ACTIVE = "active"
    INACTIVE = "inactive"
    SUSPENDED = "suspended"
    PENDING_VERIFICATION = "pending_verification"

class SuperUser:
    """
    Super User model for Firebase Firestore integration.
    Manages super admin accounts with authentication and authorization capabilities.
    """
    
    def __init__(self, id: str = None, full_name: str = "", email: str = "", 
                 department: str = "", password_hash: str = "", salt: str = "",
                 role: str = SuperUserRole.SUPER_ADMIN.value, 
                 status: str = SuperUserStatus.ACTIVE.value,
                 phone_number: str = "", profile_image_url: str = "",
                 last_login_at: datetime = None, last_login_ip: str = "",
                 failed_login_attempts: int = 0, account_locked_until: datetime = None,
                 password_changed_at: datetime = None, 
                 email_verified: bool = False, email_verification_token: str = "",
                 password_reset_token: str = "", password_reset_expires: datetime = None,
                 two_factor_enabled: bool = False, two_factor_secret: str = "",
                 session_tokens: List[str] = None, permissions: List[str] = None,
                 created_at: datetime = None, updated_at: datetime = None,
                 created_by: str = "system", last_modified_by: str = "system"):
        
        self.id = id
        self.full_name = full_name
        self.email = email.lower() if email else ""
        self.department = department
        self.password_hash = password_hash
        self.salt = salt
        self.role = role
        self.status = status
        
        # Contact information
        self.phone_number = phone_number
        self.profile_image_url = profile_image_url
        
        # Authentication tracking
        self.last_login_at = last_login_at
        self.last_login_ip = last_login_ip
        self.failed_login_attempts = failed_login_attempts
        self.account_locked_until = account_locked_until
        self.password_changed_at = password_changed_at or datetime.now()
        
        # Email verification
        self.email_verified = email_verified
        self.email_verification_token = email_verification_token
        
        # Password reset
        self.password_reset_token = password_reset_token
        self.password_reset_expires = password_reset_expires
        
        # Two-factor authentication
        self.two_factor_enabled = two_factor_enabled
        self.two_factor_secret = two_factor_secret
        
        # Session management
        self.session_tokens = session_tokens or []
        self.permissions = permissions or self._get_default_permissions()
        
        # Metadata
        self.created_at = created_at or datetime.now()
        self.updated_at = updated_at or datetime.now()
        self.created_by = created_by
        self.last_modified_by = last_modified_by
    
    def _get_default_permissions(self) -> List[str]:
        """Get default permissions based on role."""
        permissions_map = {
            SuperUserRole.SUPER_ADMIN.value: [
                "read_all", "write_all", "delete_all", "manage_users", 
                "manage_admins", "manage_system", "view_analytics", 
                "export_data", "manage_permissions"
            ],
            SuperUserRole.SYSTEM_ADMIN.value: [
                "read_all", "write_all", "manage_users", "view_analytics", 
                "export_data"
            ],
            SuperUserRole.REGIONAL_ADMIN.value: [
                "read_regional", "write_regional", "manage_regional_users", 
                "view_regional_analytics"
            ]
        }
        return permissions_map.get(self.role, [])
    
    @staticmethod
    def hash_password(password: str, salt: str = None) -> tuple[str, str]:
        """Hash password with salt."""
        if not salt:
            salt = secrets.token_hex(32)
        
        # Combine password and salt
        password_bytes = (password + salt).encode('utf-8')
        
        # Hash with SHA-256
        password_hash = hashlib.sha256(password_bytes).hexdigest()
        
        return password_hash, salt
    
    @staticmethod
    def verify_password(password: str, stored_hash: str, salt: str) -> bool:
        """Verify password against stored hash."""
        password_hash, _ = SuperUser.hash_password(password, salt)
        return password_hash == stored_hash
    
    @staticmethod
    def validate_email(email: str) -> bool:
        """Validate email format."""
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        return re.match(pattern, email) is not None
    
    @staticmethod
    def validate_password(password: str) -> Dict[str, Any]:
        """Validate password strength."""
        errors = []
        
        if len(password) < 8:
            errors.append("Password must be at least 8 characters long")
        
        if not re.search(r'[A-Z]', password):
            errors.append("Password must contain at least one uppercase letter")
        
        if not re.search(r'[a-z]', password):
            errors.append("Password must contain at least one lowercase letter")
        
        if not re.search(r'[0-9]', password):
            errors.append("Password must contain at least one digit")
        
        if not re.search(r'[!@#$%^&*(),.?":{}|<>]', password):
            errors.append("Password must contain at least one special character")
        
        return {
            'is_valid': len(errors) == 0,
            'errors': errors,
            'strength': 'strong' if len(errors) == 0 else 'weak'
        }
    
    def generate_session_token(self) -> str:
        """Generate a new session token."""
        token = secrets.token_urlsafe(64)
        self.session_tokens.append(token)
        
        # Keep only the last 5 sessions
        if len(self.session_tokens) > 5:
            self.session_tokens = self.session_tokens[-5:]
        
        self.save()
        return token
    
    def invalidate_session_token(self, token: str) -> bool:
        """Invalidate a specific session token."""
        if token in self.session_tokens:
            self.session_tokens.remove(token)
            self.save()
            return True
        return False
    
    def invalidate_all_sessions(self) -> bool:
        """Invalidate all session tokens."""
        self.session_tokens = []
        self.save()
        return True
    
    def is_account_locked(self) -> bool:
        """Check if account is currently locked."""
        if not self.account_locked_until:
            return False
        return datetime.now() < self.account_locked_until
    
    def lock_account(self, duration_minutes: int = 30) -> None:
        """Lock account for specified duration."""
        from datetime import timedelta
        self.account_locked_until = datetime.now() + timedelta(minutes=duration_minutes)
        self.save()
    
    def unlock_account(self) -> None:
        """Unlock account and reset failed attempts."""
        self.account_locked_until = None
        self.failed_login_attempts = 0
        self.save()
    
    def record_login_attempt(self, success: bool, ip_address: str = "") -> None:
        """Record login attempt."""
        if success:
            self.last_login_at = datetime.now()
            self.last_login_ip = ip_address
            self.failed_login_attempts = 0
            self.account_locked_until = None
        else:
            self.failed_login_attempts += 1
            
            # Lock account after 5 failed attempts
            if self.failed_login_attempts >= 5:
                self.lock_account(30)  # Lock for 30 minutes
        
        self.save()
    
    def has_permission(self, permission: str) -> bool:
        """Check if user has specific permission."""
        return permission in self.permissions
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for Firebase storage."""
        return {
            'fullName': self.full_name,
            'email': self.email,
            'department': self.department,
            'passwordHash': self.password_hash,
            'salt': self.salt,
            'role': self.role,
            'status': self.status,
            'phoneNumber': self.phone_number,
            'profileImageUrl': self.profile_image_url,
            'lastLoginAt': self.last_login_at,
            'lastLoginIp': self.last_login_ip,
            'failedLoginAttempts': self.failed_login_attempts,
            'accountLockedUntil': self.account_locked_until,
            'passwordChangedAt': self.password_changed_at,
            'emailVerified': self.email_verified,
            'emailVerificationToken': self.email_verification_token,
            'passwordResetToken': self.password_reset_token,
            'passwordResetExpires': self.password_reset_expires,
            'twoFactorEnabled': self.two_factor_enabled,
            'twoFactorSecret': self.two_factor_secret,
            'sessionTokens': self.session_tokens,
            'permissions': self.permissions,
            'createdAt': self.created_at,
            'updatedAt': self.updated_at,
            'createdBy': self.created_by,
            'lastModifiedBy': self.last_modified_by
        }
    
    @classmethod
    def from_dict(cls, id: str, data: Dict[str, Any]) -> 'SuperUser':
        """Create SuperUser instance from dictionary."""
        return cls(
            id=id,
            full_name=data.get('fullName', ''),
            email=data.get('email', ''),
            department=data.get('department', ''),
            password_hash=data.get('passwordHash', ''),
            salt=data.get('salt', ''),
            role=data.get('role', SuperUserRole.SUPER_ADMIN.value),
            status=data.get('status', SuperUserStatus.ACTIVE.value),
            phone_number=data.get('phoneNumber', ''),
            profile_image_url=data.get('profileImageUrl', ''),
            last_login_at=data.get('lastLoginAt'),
            last_login_ip=data.get('lastLoginIp', ''),
            failed_login_attempts=data.get('failedLoginAttempts', 0),
            account_locked_until=data.get('accountLockedUntil'),
            password_changed_at=data.get('passwordChangedAt'),
            email_verified=data.get('emailVerified', False),
            email_verification_token=data.get('emailVerificationToken', ''),
            password_reset_token=data.get('passwordResetToken', ''),
            password_reset_expires=data.get('passwordResetExpires'),
            two_factor_enabled=data.get('twoFactorEnabled', False),
            two_factor_secret=data.get('twoFactorSecret', ''),
            session_tokens=data.get('sessionTokens', []),
            permissions=data.get('permissions', []),
            created_at=data.get('createdAt'),
            updated_at=data.get('updatedAt'),
            created_by=data.get('createdBy', 'system'),
            last_modified_by=data.get('lastModifiedBy', 'system')
        )
    
    def save(self) -> bool:
        """Save super user to Firebase."""
        try:
            self.updated_at = datetime.now()
            
            if self.id:
                # Update existing
                db.collection('super_users').document(self.id).update(self.to_dict())
            else:
                # Create new
                doc_ref = db.collection('super_users').add(self.to_dict())
                self.id = doc_ref[1].id
            
            return True
        except Exception as e:
            print(f"Error saving super user: {e}")
            return False
    
    @classmethod
    def get_by_id(cls, user_id: str) -> Optional['SuperUser']:
        """Get super user by ID."""
        try:
            doc = db.collection('super_users').document(user_id).get()
            if doc.exists:
                return cls.from_dict(doc.id, doc.to_dict())
        except Exception as e:
            print(f"Error fetching super user by ID: {e}")
        
        return None
    
    @classmethod
    def get_by_email(cls, email: str) -> Optional['SuperUser']:
        """Get super user by email."""
        try:
            users_ref = db.collection('super_users')
            query = users_ref.where('email', '==', email.lower()).limit(1)
            docs = query.stream()
            
            for doc in docs:
                return cls.from_dict(doc.id, doc.to_dict())
        except Exception as e:
            print(f"Error fetching super user by email: {e}")
        
        return None
    
    @classmethod
    def authenticate(cls, email: str, password: str, ip_address: str = "") -> Optional['SuperUser']:
        """Authenticate super user with email and password."""
        user = cls.get_by_email(email)
        
        if not user:
            return None
        
        # Check if account is locked
        if user.is_account_locked():
            return None
        
        # Check if account is active
        if user.status != SuperUserStatus.ACTIVE.value:
            return None
        
        # Verify password
        if cls.verify_password(password, user.password_hash, user.salt):
            user.record_login_attempt(True, ip_address)
            return user
        else:
            user.record_login_attempt(False, ip_address)
            return None
    
    @classmethod
    def create_super_user(cls, full_name: str, email: str, password: str, 
                         department: str = "", role: str = SuperUserRole.SUPER_ADMIN.value) -> Optional['SuperUser']:
        """Create a new super user."""
        # Validate email
        if not cls.validate_email(email):
            return None
        
        # Check if email already exists
        if cls.get_by_email(email):
            return None
        
        # Validate password
        password_validation = cls.validate_password(password)
        if not password_validation['is_valid']:
            return None
        
        # Hash password
        password_hash, salt = cls.hash_password(password)
        
        # Create super user
        super_user = cls(
            full_name=full_name,
            email=email,
            department=department,
            password_hash=password_hash,
            salt=salt,
            role=role,
            status=SuperUserStatus.ACTIVE.value,
            email_verification_token=secrets.token_urlsafe(32)
        )
        
        if super_user.save():
            return super_user
        
        return None
    
    @classmethod
    def get_all_super_users(cls) -> List['SuperUser']:
        """Get all super users."""
        super_users = []
        try:
            docs = db.collection('super_users').order_by('createdAt', direction=firestore.Query.DESCENDING).stream()
            
            for doc in docs:
                super_user = cls.from_dict(doc.id, doc.to_dict())
                super_users.append(super_user)
        except Exception as e:
            print(f"Error fetching super users: {e}")
        
        return super_users
    
    @classmethod
    def get_statistics(cls) -> Dict[str, Any]:
        """Get super user statistics."""
        try:
            all_users = cls.get_all_super_users()
            
            total_users = len(all_users)
            active_users = len([u for u in all_users if u.status == SuperUserStatus.ACTIVE.value])
            pending_users = len([u for u in all_users if u.status == SuperUserStatus.PENDING_VERIFICATION.value])
            suspended_users = len([u for u in all_users if u.status == SuperUserStatus.SUSPENDED.value])
            
            # Role distribution
            role_counts = {}
            for user in all_users:
                role_counts[user.role] = role_counts.get(user.role, 0) + 1
            
            return {
                'total_super_users': total_users,
                'active_super_users': active_users,
                'pending_super_users': pending_users,
                'suspended_super_users': suspended_users,
                'role_distribution': role_counts,
                'email_verified_count': len([u for u in all_users if u.email_verified]),
                'two_factor_enabled_count': len([u for u in all_users if u.two_factor_enabled])
            }
        except Exception as e:
            print(f"Error getting super user statistics: {e}")
            return {}
    
    def __str__(self) -> str:
        return f"SuperUser(id={self.id}, email={self.email}, role={self.role})"
    
    def __repr__(self) -> str:
        return self.__str__()