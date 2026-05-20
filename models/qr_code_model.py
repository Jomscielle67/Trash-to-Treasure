from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from enum import Enum
import secrets
import string
from services.firebase_service import db
from firebase_admin import firestore

class QRCodeType(Enum):
    BOTTLE_DEPOSIT = "bottle_deposit"
    REWARD_CLAIM = "reward_claim"
    MACHINE_ACCESS = "machine_access"
    ADMIN_ACCESS = "admin_access"
    STUDENT_VERIFICATION = "student_verification"

class QRCodeStatus(Enum):
    ACTIVE = "active"
    EXPIRED = "expired"
    USED = "used"
    DISABLED = "disabled"

class QRCode:
    """
    QR Code model for Firebase Firestore integration.
    Manages QR codes for various system operations including bottle deposits,
    reward claims, machine access, and verification processes.
    """
    
    def __init__(self, id: str = None, qr_code_id: str = "", qr_code_type: str = QRCodeType.BOTTLE_DEPOSIT.value,
                 machine_id: str = "", reward_id: str = "", student_id: str = "",
                 generated_by: str = "", generated_for: str = "", 
                 data: Dict[str, Any] = None, is_active: bool = True,
                 expires_at: datetime = None, usage_count: int = 0,
                 max_usage: int = 1, last_used_at: datetime = None,
                 last_used_by: str = "", department: str = "",
                 location: str = "", status: str = QRCodeStatus.ACTIVE.value,
                 created_at: datetime = None, notes: str = ""):
        
        self.id = id
        self.qr_code_id = qr_code_id or self._generate_qr_code_id()
        self.qr_code_type = qr_code_type
        self.machine_id = machine_id
        self.reward_id = reward_id
        self.student_id = student_id
        self.generated_by = generated_by
        self.generated_for = generated_for
        self.data = data or {}
        self.is_active = is_active
        self.expires_at = expires_at
        self.usage_count = usage_count
        self.max_usage = max_usage
        self.last_used_at = last_used_at
        self.last_used_by = last_used_by
        self.department = department
        self.location = location
        self.status = status
        self.created_at = created_at or datetime.now()
        self.notes = notes
    
    def _generate_qr_code_id(self) -> str:
        """Generate a unique QR code ID."""
        # Generate a random string with letters and numbers
        chars = string.ascii_uppercase + string.digits
        random_part = ''.join(secrets.choice(chars) for _ in range(8))
        timestamp_part = datetime.now().strftime('%Y%m%d')
        return f"T2T-{timestamp_part}-{random_part}"
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert QR code object to dictionary for Firestore storage."""
        return {
            'qrCodeId': self.qr_code_id,
            'type': self.qr_code_type,
            'machineId': self.machine_id,
            'rewardId': self.reward_id,
            'studentId': self.student_id,
            'generatedBy': self.generated_by,
            'generatedFor': self.generated_for,
            'data': self.data,
            'isActive': self.is_active,
            'expiresAt': self.expires_at,
            'usageCount': self.usage_count,
            'maxUsage': self.max_usage,
            'lastUsedAt': self.last_used_at,
            'lastUsedBy': self.last_used_by,
            'department': self.department,
            'location': self.location,
            'status': self.status,
            'createdAt': self.created_at,
            'notes': self.notes
        }
    
    @classmethod
    def from_dict(cls, doc_id: str, data: Dict[str, Any]) -> 'QRCode':
        """Create QRCode object from Firestore document."""
        return cls(
            id=doc_id,
            qr_code_id=data.get('qrCodeId', ''),
            qr_code_type=data.get('type', QRCodeType.BOTTLE_DEPOSIT.value),
            machine_id=data.get('machineId', ''),
            reward_id=data.get('rewardId', ''),
            student_id=data.get('studentId', ''),
            generated_by=data.get('generatedBy', ''),
            generated_for=data.get('generatedFor', ''),
            data=data.get('data', {}),
            is_active=data.get('isActive', True),
            expires_at=data.get('expiresAt'),
            usage_count=data.get('usageCount', 0),
            max_usage=data.get('maxUsage', 1),
            last_used_at=data.get('lastUsedAt'),
            last_used_by=data.get('lastUsedBy', ''),
            department=data.get('department', ''),
            location=data.get('location', ''),
            status=data.get('status', QRCodeStatus.ACTIVE.value),
            created_at=data.get('createdAt'),
            notes=data.get('notes', '')
        )
    
    @classmethod
    def create_bottle_deposit_qr(cls, machine_id: str, generated_by: str, 
                               department: str = "", location: str = "",
                               expires_in_hours: int = 24) -> 'QRCode':
        """Create a QR code for bottle deposit."""
        expires_at = datetime.now() + timedelta(hours=expires_in_hours)
        
        return cls(
            qr_code_type=QRCodeType.BOTTLE_DEPOSIT.value,
            machine_id=machine_id,
            generated_by=generated_by,
            expires_at=expires_at,
            max_usage=-1,  # Unlimited usage for machine access
            department=department,
            location=location,
            data={
                'action': 'bottle_deposit',
                'machineId': machine_id,
                'location': location
            }
        )
    
    @classmethod
    def create_reward_claim_qr(cls, reward_id: str, student_id: str, 
                             generated_by: str, department: str = "",
                             expires_in_hours: int = 48) -> 'QRCode':
        """Create a QR code for reward claim."""
        expires_at = datetime.now() + timedelta(hours=expires_in_hours)
        
        return cls(
            qr_code_type=QRCodeType.REWARD_CLAIM.value,
            reward_id=reward_id,
            student_id=student_id,
            generated_by=generated_by,
            generated_for=student_id,
            expires_at=expires_at,
            max_usage=1,  # Single use for reward claims
            department=department,
            data={
                'action': 'claim_reward',
                'rewardId': reward_id,
                'studentId': student_id
            }
        )
    
    @classmethod
    def create_machine_access_qr(cls, machine_id: str, generated_by: str,
                               access_type: str = "maintenance", 
                               expires_in_hours: int = 8) -> 'QRCode':
        """Create a QR code for machine access (maintenance, etc.)."""
        expires_at = datetime.now() + timedelta(hours=expires_in_hours)
        
        return cls(
            qr_code_type=QRCodeType.MACHINE_ACCESS.value,
            machine_id=machine_id,
            generated_by=generated_by,
            expires_at=expires_at,
            max_usage=5,  # Limited usage for security
            data={
                'action': 'machine_access',
                'machineId': machine_id,
                'accessType': access_type
            }
        )
    
    @classmethod
    def create_student_verification_qr(cls, student_id: str, generated_by: str,
                                     department: str = "", 
                                     expires_in_minutes: int = 30) -> 'QRCode':
        """Create a QR code for student verification."""
        expires_at = datetime.now() + timedelta(minutes=expires_in_minutes)
        
        return cls(
            qr_code_type=QRCodeType.STUDENT_VERIFICATION.value,
            student_id=student_id,
            generated_by=generated_by,
            generated_for=student_id,
            expires_at=expires_at,
            max_usage=1,
            department=department,
            data={
                'action': 'verify_student',
                'studentId': student_id
            }
        )
    
    def save(self) -> bool:
        """Save QR code to Firestore."""
        try:
            qr_data = self.to_dict()
            
            if self.id:
                # Update existing QR code
                db.collection('qr_codes').document(self.id).update(qr_data)
            else:
                # Create new QR code
                doc_ref = db.collection('qr_codes').add(qr_data)
                self.id = doc_ref[1].id
            
            return True
        except Exception as e:
            print(f"Error saving QR code: {e}")
            return False
    
    def use(self, used_by: str) -> Dict[str, Any]:
        """Use the QR code and return result."""
        try:
            current_time = datetime.now()
            
            # Check if QR code is active
            if not self.is_active or self.status != QRCodeStatus.ACTIVE.value:
                return {
                    'success': False,
                    'message': 'QR code is not active',
                    'error_code': 'INACTIVE_QR'
                }
            
            # Check if expired
            if self.expires_at and current_time > self.expires_at:
                self.status = QRCodeStatus.EXPIRED.value
                self.save()
                return {
                    'success': False,
                    'message': 'QR code has expired',
                    'error_code': 'EXPIRED_QR'
                }
            
            # Check usage limit
            if self.max_usage > 0 and self.usage_count >= self.max_usage:
                self.status = QRCodeStatus.USED.value
                self.save()
                return {
                    'success': False,
                    'message': 'QR code usage limit exceeded',
                    'error_code': 'USAGE_LIMIT_EXCEEDED'
                }
            
            # Update usage
            self.usage_count += 1
            self.last_used_at = current_time
            self.last_used_by = used_by
            
            # Check if this was the last usage
            if self.max_usage > 0 and self.usage_count >= self.max_usage:
                self.status = QRCodeStatus.USED.value
            
            self.save()
            
            return {
                'success': True,
                'message': 'QR code used successfully',
                'data': self.data,
                'qr_type': self.qr_code_type,
                'usage_count': self.usage_count,
                'remaining_usage': max(0, self.max_usage - self.usage_count) if self.max_usage > 0 else -1
            }
            
        except Exception as e:
            print(f"Error using QR code: {e}")
            return {
                'success': False,
                'message': 'Error processing QR code',
                'error_code': 'PROCESSING_ERROR'
            }
    
    def disable(self, disabled_by: str, reason: str = "") -> bool:
        """Disable the QR code."""
        try:
            self.status = QRCodeStatus.DISABLED.value
            self.is_active = False
            self.notes = f"Disabled by {disabled_by}. Reason: {reason}"
            return self.save()
        except Exception as e:
            print(f"Error disabling QR code: {e}")
            return False
    
    def extend_expiry(self, hours: int) -> bool:
        """Extend QR code expiry time."""
        try:
            if self.expires_at:
                self.expires_at += timedelta(hours=hours)
            else:
                self.expires_at = datetime.now() + timedelta(hours=hours)
            
            # Reactivate if it was expired
            if self.status == QRCodeStatus.EXPIRED.value:
                self.status = QRCodeStatus.ACTIVE.value
                self.is_active = True
            
            return self.save()
        except Exception as e:
            print(f"Error extending QR code expiry: {e}")
            return False
    
    @classmethod
    def get_qr_by_code_id(cls, qr_code_id: str) -> Optional['QRCode']:
        """Get QR code by its ID."""
        try:
            qr_codes_ref = db.collection('qr_codes')
            query = qr_codes_ref.where('qrCodeId', '==', qr_code_id)
            docs = query.stream()
            
            for doc in docs:
                return cls.from_dict(doc.id, doc.to_dict())
        except Exception as e:
            print(f"Error fetching QR code by ID {qr_code_id}: {e}")
        
        return None
    
    @classmethod
    def get_qr_codes_by_type(cls, qr_type: str, active_only: bool = True) -> List['QRCode']:
        """Get QR codes by type."""
        qr_codes = []
        try:
            qr_codes_ref = db.collection('qr_codes')
            query = qr_codes_ref.where('type', '==', qr_type)
            
            if active_only:
                query = query.where('isActive', '==', True)
            
            docs = query.stream()
            
            for doc in docs:
                qr_code = cls.from_dict(doc.id, doc.to_dict())
                qr_codes.append(qr_code)
        except Exception as e:
            print(f"Error fetching QR codes by type {qr_type}: {e}")
        
        return qr_codes
    
    @classmethod
    def get_qr_codes_by_machine(cls, machine_id: str, active_only: bool = True) -> List['QRCode']:
        """Get QR codes for a specific machine."""
        qr_codes = []
        try:
            qr_codes_ref = db.collection('qr_codes')
            query = qr_codes_ref.where('machineId', '==', machine_id)
            
            if active_only:
                query = query.where('isActive', '==', True)
            
            docs = query.stream()
            
            for doc in docs:
                qr_code = cls.from_dict(doc.id, doc.to_dict())
                qr_codes.append(qr_code)
        except Exception as e:
            print(f"Error fetching QR codes for machine {machine_id}: {e}")
        
        return qr_codes
    
    @classmethod
    def get_qr_codes_by_student(cls, student_id: str, active_only: bool = True) -> List['QRCode']:
        """Get QR codes for a specific student."""
        qr_codes = []
        try:
            qr_codes_ref = db.collection('qr_codes')
            query = qr_codes_ref.where('studentId', '==', student_id)
            
            if active_only:
                query = query.where('isActive', '==', True)
            
            docs = query.stream()
            
            for doc in docs:
                qr_code = cls.from_dict(doc.id, doc.to_dict())
                qr_codes.append(qr_code)
        except Exception as e:
            print(f"Error fetching QR codes for student {student_id}: {e}")
        
        return qr_codes
    
    @classmethod
    def cleanup_expired_qr_codes(cls) -> int:
        """Clean up expired QR codes."""
        try:
            current_time = datetime.now()
            qr_codes_ref = db.collection('qr_codes')
            query = qr_codes_ref.where('expiresAt', '<=', current_time)
            
            docs = list(query.stream())
            batch = db.batch()
            
            for doc in docs:
                batch.update(doc.reference, {
                    'status': QRCodeStatus.EXPIRED.value,
                    'isActive': False
                })
            
            batch.commit()
            return len(docs)
        except Exception as e:
            print(f"Error cleaning up expired QR codes: {e}")
            return 0
    
    @classmethod
    def get_qr_statistics(cls) -> Dict[str, Any]:
        """Get QR code usage statistics."""
        try:
            all_qr_codes = []
            qr_codes_ref = db.collection('qr_codes')
            docs = qr_codes_ref.stream()
            
            for doc in docs:
                qr_code = cls.from_dict(doc.id, doc.to_dict())
                all_qr_codes.append(qr_code)
            
            total_qr_codes = len(all_qr_codes)
            active_qr_codes = len([qr for qr in all_qr_codes if qr.is_active])
            expired_qr_codes = len([qr for qr in all_qr_codes if qr.status == QRCodeStatus.EXPIRED.value])
            used_qr_codes = len([qr for qr in all_qr_codes if qr.status == QRCodeStatus.USED.value])
            
            # Type breakdown
            type_counts = {}
            for qr_code in all_qr_codes:
                qr_type = qr_code.qr_code_type
                type_counts[qr_type] = type_counts.get(qr_type, 0) + 1
            
            # Usage statistics
            total_usage = sum(qr.usage_count for qr in all_qr_codes)
            avg_usage = total_usage / total_qr_codes if total_qr_codes > 0 else 0
            
            # Most used QR codes
            most_used = sorted(all_qr_codes, key=lambda x: x.usage_count, reverse=True)[:5]
            most_used_data = [
                {
                    'qr_code_id': qr.qr_code_id,
                    'type': qr.qr_code_type,
                    'usage_count': qr.usage_count,
                    'created_at': qr.created_at
                }
                for qr in most_used
            ]
            
            return {
                'total_qr_codes': total_qr_codes,
                'active_qr_codes': active_qr_codes,
                'expired_qr_codes': expired_qr_codes,
                'used_qr_codes': used_qr_codes,
                'type_breakdown': type_counts,
                'total_usage': total_usage,
                'average_usage': round(avg_usage, 2),
                'most_used_qr_codes': most_used_data
            }
        except Exception as e:
            print(f"Error getting QR code statistics: {e}")
            return {}
    
    @classmethod
    def get_all_qr_codes(cls, limit: int = 50) -> List['QRCode']:
        """Get all QR codes (for testing purposes)."""
        qr_codes = []
        try:
            qr_codes_ref = db.collection('qr_codes')
            query = qr_codes_ref.order_by('createdAt', direction=firestore.Query.DESCENDING).limit(limit)
            docs = query.stream()
            
            for doc in docs:
                qr_code = cls.from_dict(doc.id, doc.to_dict())
                qr_codes.append(qr_code)
        except Exception as e:
            print(f"Error fetching all QR codes: {e}")
        
        return qr_codes
    
    def is_valid(self) -> bool:
        """Check if QR code is valid for use."""
        current_time = datetime.now()
        
        if not self.is_active or self.status != QRCodeStatus.ACTIVE.value:
            return False
        
        if self.expires_at and current_time > self.expires_at:
            return False
        
        if self.max_usage > 0 and self.usage_count >= self.max_usage:
            return False
        
        return True
    
    def get_remaining_time(self) -> Optional[timedelta]:
        """Get remaining time before expiry."""
        if not self.expires_at:
            return None
        
        current_time = datetime.now()
        if current_time >= self.expires_at:
            return timedelta(0)
        
        return self.expires_at - current_time
    
    def __str__(self) -> str:
        return f"QRCode(id={self.qr_code_id}, type={self.qr_code_type}, status={self.status})"
    
    def __repr__(self) -> str:
        return self.__str__()