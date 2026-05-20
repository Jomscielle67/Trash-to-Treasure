from datetime import datetime
from typing import Dict, List, Optional, Any
from enum import Enum
from services.firebase_service import db
from firebase_admin import firestore

class NotificationType(Enum):
    REWARD = "reward"
    TRANSACTION = "transaction"
    SYSTEM = "system"
    MAINTENANCE = "maintenance"
    ACHIEVEMENT = "achievement"
    ANNOUNCEMENT = "announcement"

class NotificationPriority(Enum):
    LOW = "low"
    NORMAL = "normal"
    HIGH = "high"
    CRITICAL = "critical"

class UserType(Enum):
    STUDENT = "student"
    ADMIN = "admin"
    ALL = "all"

class Notification:
    """
    Push Notification model for Firebase Firestore integration.
    Handles all notification-related operations for mobile apps.
    """
    
    def __init__(self, id: str = None, user_id: str = "", user_type: str = UserType.STUDENT.value,
                 title: str = "", body: str = "", notification_type: str = NotificationType.SYSTEM.value,
                 data: Dict[str, Any] = None, is_read: bool = False,
                 sent_at: datetime = None, read_at: datetime = None,
                 device_tokens: List[str] = None, priority: str = NotificationPriority.NORMAL.value,
                 image_url: str = "", action_url: str = "", expires_at: datetime = None,
                 target_audience: str = "", department: str = "",
                 created_by: str = "system", created_at: datetime = None):
        
        self.id = id
        self.user_id = user_id
        self.user_type = user_type
        self.title = title
        self.body = body
        self.notification_type = notification_type
        self.data = data or {}
        self.is_read = is_read
        self.sent_at = sent_at
        self.read_at = read_at
        self.device_tokens = device_tokens or []
        self.priority = priority
        self.image_url = image_url
        self.action_url = action_url
        self.expires_at = expires_at
        self.target_audience = target_audience
        self.department = department
        self.created_by = created_by
        self.created_at = created_at or datetime.now()
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert notification object to dictionary for Firestore storage."""
        return {
            'userId': self.user_id,
            'userType': self.user_type,
            'title': self.title,
            'body': self.body,
            'type': self.notification_type,
            'data': self.data,
            'isRead': self.is_read,
            'sentAt': self.sent_at,
            'readAt': self.read_at,
            'deviceTokens': self.device_tokens,
            'priority': self.priority,
            'imageUrl': self.image_url,
            'actionUrl': self.action_url,
            'expiresAt': self.expires_at,
            'targetAudience': self.target_audience,
            'department': self.department,
            'createdBy': self.created_by,
            'createdAt': self.created_at
        }
    
    @classmethod
    def from_dict(cls, doc_id: str, data: Dict[str, Any]) -> 'Notification':
        """Create Notification object from Firestore document."""
        return cls(
            id=doc_id,
            user_id=data.get('userId', ''),
            user_type=data.get('userType', UserType.STUDENT.value),
            title=data.get('title', ''),
            body=data.get('body', ''),
            notification_type=data.get('type', NotificationType.SYSTEM.value),
            data=data.get('data', {}),
            is_read=data.get('isRead', False),
            sent_at=data.get('sentAt'),
            read_at=data.get('readAt'),
            device_tokens=data.get('deviceTokens', []),
            priority=data.get('priority', NotificationPriority.NORMAL.value),
            image_url=data.get('imageUrl', ''),
            action_url=data.get('actionUrl', ''),
            expires_at=data.get('expiresAt'),
            target_audience=data.get('targetAudience', ''),
            department=data.get('department', ''),
            created_by=data.get('createdBy', 'system'),
            created_at=data.get('createdAt')
        )
    
    @classmethod
    def create_reward_notification(cls, user_id: str, reward_name: str, 
                                 reward_id: str, department: str = "") -> 'Notification':
        """Create a new reward notification."""
        return cls(
            user_id=user_id,
            user_type=UserType.STUDENT.value,
            title="New Reward Available! 🎁",
            body=f"Check out the new {reward_name} in the rewards section!",
            notification_type=NotificationType.REWARD.value,
            data={
                'rewardId': reward_id,
                'rewardName': reward_name,
                'action': 'open_rewards'
            },
            priority=NotificationPriority.NORMAL.value,
            department=department
        )
    
    @classmethod
    def create_transaction_notification(cls, user_id: str, transaction_type: str,
                                      points: int, reward_name: str = "") -> 'Notification':
        """Create a transaction notification."""
        if transaction_type == 'deposit':
            title = "Bottles Deposited Successfully! ♻️"
            body = f"You earned {points} points for your bottle deposit!"
        else:
            title = "Reward Redeemed! 🎉"
            body = f"You successfully redeemed {reward_name} for {points} points!"
        
        return cls(
            user_id=user_id,
            user_type=UserType.STUDENT.value,
            title=title,
            body=body,
            notification_type=NotificationType.TRANSACTION.value,
            data={
                'transactionType': transaction_type,
                'points': points,
                'rewardName': reward_name,
                'action': 'open_transactions'
            },
            priority=NotificationPriority.HIGH.value
        )
    
    @classmethod
    def create_achievement_notification(cls, user_id: str, achievement_name: str,
                                      achievement_description: str) -> 'Notification':
        """Create an achievement notification."""
        return cls(
            user_id=user_id,
            user_type=UserType.STUDENT.value,
            title="Achievement Unlocked! 🏆",
            body=f"Congratulations! You've earned the '{achievement_name}' achievement!",
            notification_type=NotificationType.ACHIEVEMENT.value,
            data={
                'achievementName': achievement_name,
                'achievementDescription': achievement_description,
                'action': 'open_profile'
            },
            priority=NotificationPriority.HIGH.value
        )
    
    @classmethod
    def create_system_announcement(cls, title: str, body: str, target_audience: str = UserType.ALL.value,
                                 department: str = "", priority: str = NotificationPriority.NORMAL.value,
                                 created_by: str = "system") -> 'Notification':
        """Create a system-wide announcement."""
        return cls(
            user_type=UserType.ALL.value,
            title=title,
            body=body,
            notification_type=NotificationType.ANNOUNCEMENT.value,
            target_audience=target_audience,
            department=department,
            priority=priority,
            created_by=created_by
        )
    
    @classmethod
    def create_maintenance_notification(cls, machine_id: str, maintenance_type: str,
                                      department: str = "") -> 'Notification':
        """Create a maintenance notification for admins."""
        return cls(
            user_type=UserType.ADMIN.value,
            title="Machine Maintenance Required 🔧",
            body=f"Machine {machine_id} requires {maintenance_type} maintenance.",
            notification_type=NotificationType.MAINTENANCE.value,
            data={
                'machineId': machine_id,
                'maintenanceType': maintenance_type,
                'action': 'open_machines'
            },
            priority=NotificationPriority.HIGH.value,
            department=department
        )
    
    def save(self) -> bool:
        """Save notification to Firestore."""
        try:
            notification_data = self.to_dict()
            
            if self.id:
                # Update existing notification
                db.collection('notifications').document(self.id).update(notification_data)
            else:
                # Create new notification
                doc_ref = db.collection('notifications').add(notification_data)
                self.id = doc_ref[1].id
            
            return True
        except Exception as e:
            print(f"Error saving notification: {e}")
            return False
    
    def mark_as_read(self) -> bool:
        """Mark notification as read."""
        try:
            self.is_read = True
            self.read_at = datetime.now()
            return self.save()
        except Exception as e:
            print(f"Error marking notification as read: {e}")
            return False
    
    def mark_as_sent(self) -> bool:
        """Mark notification as sent."""
        try:
            self.sent_at = datetime.now()
            return self.save()
        except Exception as e:
            print(f"Error marking notification as sent: {e}")
            return False
    
    @classmethod
    def get_user_notifications(cls, user_id: str, limit: int = 50, 
                             include_read: bool = True) -> List['Notification']:
        """Get all notifications for a specific user."""
        notifications = []
        try:
            notifications_ref = db.collection('notifications')
            query = notifications_ref.where('userId', '==', user_id)
            
            if not include_read:
                query = query.where('isRead', '==', False)
            
            query = query.order_by('createdAt', direction=firestore.Query.DESCENDING).limit(limit)
            docs = query.stream()
            
            for doc in docs:
                notification = cls.from_dict(doc.id, doc.to_dict())
                notifications.append(notification)
        except Exception as e:
            print(f"Error fetching user notifications: {e}")
        
        return notifications
    
    @classmethod
    def get_unread_count(cls, user_id: str) -> int:
        """Get count of unread notifications for a user."""
        try:
            notifications_ref = db.collection('notifications')
            query = (notifications_ref
                    .where('userId', '==', user_id)
                    .where('isRead', '==', False))
            
            docs = list(query.stream())
            return len(docs)
        except Exception as e:
            print(f"Error getting unread count: {e}")
            return 0
    
    @classmethod
    def mark_all_as_read(cls, user_id: str) -> bool:
        """Mark all notifications as read for a user."""
        try:
            notifications_ref = db.collection('notifications')
            query = (notifications_ref
                    .where('userId', '==', user_id)
                    .where('isRead', '==', False))
            
            batch = db.batch()
            docs = query.stream()
            
            for doc in docs:
                batch.update(doc.reference, {
                    'isRead': True,
                    'readAt': datetime.now()
                })
            
            batch.commit()
            return True
        except Exception as e:
            print(f"Error marking all notifications as read: {e}")
            return False
    
    @classmethod
    def cleanup_expired_notifications(cls) -> int:
        """Remove expired notifications."""
        try:
            current_time = datetime.now()
            notifications_ref = db.collection('notifications')
            query = notifications_ref.where('expiresAt', '<=', current_time)
            
            docs = list(query.stream())
            batch = db.batch()
            
            for doc in docs:
                batch.delete(doc.reference)
            
            batch.commit()
            return len(docs)
        except Exception as e:
            print(f"Error cleaning up expired notifications: {e}")
            return 0
    
    @classmethod
    def get_notification_statistics(cls) -> Dict[str, Any]:
        """Get notification statistics."""
        try:
            all_notifications = []
            notifications_ref = db.collection('notifications')
            docs = notifications_ref.stream()
            
            for doc in docs:
                notification = cls.from_dict(doc.id, doc.to_dict())
                all_notifications.append(notification)
            
            total_notifications = len(all_notifications)
            read_notifications = len([n for n in all_notifications if n.is_read])
            unread_notifications = total_notifications - read_notifications
            
            # Type breakdown
            type_counts = {}
            for notification in all_notifications:
                ntype = notification.notification_type
                type_counts[ntype] = type_counts.get(ntype, 0) + 1
            
            # Priority breakdown
            priority_counts = {}
            for notification in all_notifications:
                priority = notification.priority
                priority_counts[priority] = priority_counts.get(priority, 0) + 1
            
            return {
                'total_notifications': total_notifications,
                'read_notifications': read_notifications,
                'unread_notifications': unread_notifications,
                'type_breakdown': type_counts,
                'priority_breakdown': priority_counts
            }
        except Exception as e:
            print(f"Error getting notification statistics: {e}")
            return {}
    
    @classmethod
    def get_all_notifications(cls, limit: int = 50) -> List['Notification']:
        """Get all notifications (for testing purposes)."""
        notifications = []
        try:
            notifications_ref = db.collection('notifications')
            query = notifications_ref.order_by('createdAt', direction=firestore.Query.DESCENDING).limit(limit)
            docs = query.stream()
            
            for doc in docs:
                notification = cls.from_dict(doc.id, doc.to_dict())
                notifications.append(notification)
        except Exception as e:
            print(f"Error fetching all notifications: {e}")
        
        return notifications
    
    def __str__(self) -> str:
        return f"Notification(id={self.id}, title={self.title}, type={self.notification_type})"
    
    def __repr__(self) -> str:
        return self.__str__()


class UserDevice:
    """
    User Device model for managing FCM tokens and device information.
    """
    
    def __init__(self, id: str = None, user_id: str = "", user_type: str = UserType.STUDENT.value,
                 device_token: str = "", platform: str = "", app_version: str = "",
                 os_version: str = "", device_model: str = "", is_active: bool = True,
                 last_seen: datetime = None, registered_at: datetime = None):
        
        self.id = id
        self.user_id = user_id
        self.user_type = user_type
        self.device_token = device_token
        self.platform = platform  # 'android' or 'ios'
        self.app_version = app_version
        self.os_version = os_version
        self.device_model = device_model
        self.is_active = is_active
        self.last_seen = last_seen or datetime.now()
        self.registered_at = registered_at or datetime.now()
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert device object to dictionary for Firestore storage."""
        return {
            'userId': self.user_id,
            'userType': self.user_type,
            'deviceToken': self.device_token,
            'platform': self.platform,
            'appVersion': self.app_version,
            'osVersion': self.os_version,
            'deviceModel': self.device_model,
            'isActive': self.is_active,
            'lastSeen': self.last_seen,
            'registeredAt': self.registered_at
        }
    
    @classmethod
    def from_dict(cls, doc_id: str, data: Dict[str, Any]) -> 'UserDevice':
        """Create UserDevice object from Firestore document."""
        return cls(
            id=doc_id,
            user_id=data.get('userId', ''),
            user_type=data.get('userType', UserType.STUDENT.value),
            device_token=data.get('deviceToken', ''),
            platform=data.get('platform', ''),
            app_version=data.get('appVersion', ''),
            os_version=data.get('osVersion', ''),
            device_model=data.get('deviceModel', ''),
            is_active=data.get('isActive', True),
            last_seen=data.get('lastSeen'),
            registered_at=data.get('registeredAt')
        )
    
    def save(self) -> bool:
        """Save device to Firestore."""
        try:
            device_data = self.to_dict()
            
            if self.id:
                # Update existing device
                db.collection('user_devices').document(self.id).update(device_data)
            else:
                # Create new device
                doc_ref = db.collection('user_devices').add(device_data)
                self.id = doc_ref[1].id
            
            return True
        except Exception as e:
            print(f"Error saving device: {e}")
            return False
    
    @classmethod
    def register_device(cls, user_id: str, user_type: str, device_token: str,
                       platform: str, app_version: str = "", os_version: str = "",
                       device_model: str = "") -> 'UserDevice':
        """Register a new device or update existing one."""
        try:
            # Check if device already exists
            existing_device = cls.get_device_by_token(device_token)
            
            if existing_device:
                # Update existing device
                existing_device.user_id = user_id
                existing_device.user_type = user_type
                existing_device.app_version = app_version
                existing_device.os_version = os_version
                existing_device.device_model = device_model
                existing_device.is_active = True
                existing_device.last_seen = datetime.now()
                existing_device.save()
                return existing_device
            else:
                # Create new device
                device = cls(
                    user_id=user_id,
                    user_type=user_type,
                    device_token=device_token,
                    platform=platform,
                    app_version=app_version,
                    os_version=os_version,
                    device_model=device_model
                )
                device.save()
                return device
        except Exception as e:
            print(f"Error registering device: {e}")
            return None
    
    @classmethod
    def get_device_by_token(cls, device_token: str) -> Optional['UserDevice']:
        """Get device by FCM token."""
        try:
            devices_ref = db.collection('user_devices')
            query = devices_ref.where('deviceToken', '==', device_token)
            docs = query.stream()
            
            for doc in docs:
                return cls.from_dict(doc.id, doc.to_dict())
        except Exception as e:
            print(f"Error fetching device by token: {e}")
        
        return None
    
    @classmethod
    def get_user_devices(cls, user_id: str, active_only: bool = True) -> List['UserDevice']:
        """Get all devices for a user."""
        devices = []
        try:
            devices_ref = db.collection('user_devices')
            query = devices_ref.where('userId', '==', user_id)
            
            if active_only:
                query = query.where('isActive', '==', True)
            
            docs = query.stream()
            
            for doc in docs:
                device = cls.from_dict(doc.id, doc.to_dict())
                devices.append(device)
        except Exception as e:
            print(f"Error fetching user devices: {e}")
        
        return devices
    
    def update_last_seen(self) -> bool:
        """Update device last seen timestamp."""
        try:
            self.last_seen = datetime.now()
            return self.save()
        except Exception as e:
            print(f"Error updating last seen: {e}")
            return False
    
    def deactivate(self) -> bool:
        """Deactivate device."""
        try:
            self.is_active = False
            return self.save()
        except Exception as e:
            print(f"Error deactivating device: {e}")
            return False
    
    def __str__(self) -> str:
        return f"UserDevice(id={self.id}, user_id={self.user_id}, platform={self.platform})"
    
    def __repr__(self) -> str:
        return self.__str__()