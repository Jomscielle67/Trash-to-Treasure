from datetime import datetime
from typing import Dict, List, Optional, Any
from enum import Enum
from services.firebase_service import db
from firebase_admin import firestore

class StudentStatus(Enum):
    ACTIVE = "active"
    PENDING = "pending"
    SUSPENDED = "suspended"
    BANNED = "banned"

class YearLevel(Enum):
    FIRST = "1st Year"
    SECOND = "2nd Year"
    THIRD = "3rd Year"
    FOURTH = "4th Year"
    GRADUATE = "Graduate"

class Student:
    """
    Enhanced Student model for Firebase Firestore integration.
    Matches Flutter StudentModel structure with additional fields for comprehensive user management.
    Used by all three systems: Web (Super User), Admin Flutter, Student Flutter.
    """
    
    def __init__(self, id: str = None, full_name: str = "", student_id: str = "", 
                 email: str = "", department: str = "", course: str = "",
                 year_level: str = YearLevel.FIRST.value, section: str = "",
                 points: int = 0, bottles: int = 0, 
                 total_bottles_lifetime: int = 0, total_points_earned: int = 0, 
                 total_points_spent: int = 0, status: str = StudentStatus.ACTIVE.value,
                 profile_image_url: str = "", phone_number: str = "",
                 date_of_birth: str = "", address: str = "",
                 is_email_verified: bool = False, is_profile_complete: bool = False,
                 current_streak: int = 0, longest_streak: int = 0,
                 last_login_at: datetime = None, last_activity_at: datetime = None,
                 total_sessions: int = 0, achievements: List[str] = None,
                 total_rewards_redeemed: int = 0, favorite_reward_category: str = "",
                 preferences: Dict[str, Any] = None, created_at: datetime = None, 
                 updated_at: datetime = None, last_modified_by: str = "system"):
        
        self.id = id
        self.full_name = full_name
        self.student_id = student_id
        self.email = email
        self.department = department
        self.course = course
        self.year_level = year_level
        self.section = section
        
        # Core stats
        self.points = points
        self.bottles = bottles
        self.total_bottles_lifetime = total_bottles_lifetime
        self.total_points_earned = total_points_earned
        self.total_points_spent = total_points_spent
        
        # Status & verification
        self.status = status
        self.is_email_verified = is_email_verified
        self.is_profile_complete = is_profile_complete
        
        # Profile information
        self.profile_image_url = profile_image_url
        self.phone_number = phone_number
        self.date_of_birth = date_of_birth
        self.address = address
        
        # Activity tracking
        self.current_streak = current_streak
        self.longest_streak = longest_streak
        self.last_login_at = last_login_at
        self.last_activity_at = last_activity_at
        self.total_sessions = total_sessions
        
        # Achievements and preferences
        self.achievements = achievements or []
        self.total_rewards_redeemed = total_rewards_redeemed
        self.favorite_reward_category = favorite_reward_category
        self.preferences = preferences or self._default_preferences()
        
        # Timestamps
        self.created_at = created_at or datetime.now()
        self.updated_at = updated_at or datetime.now()
        self.last_modified_by = last_modified_by
    
    def _default_preferences(self) -> Dict[str, Any]:
        """Return default user preferences."""
        return {
            'notifications': {
                'push': True,
                'email': False,
                'newRewards': True,
                'transactionUpdates': True,
                'weeklyReport': False
            },
            'privacy': {
                'showInLeaderboard': True,
                'shareStats': True
            },
            'language': 'en',
            'theme': 'light'
        }
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert student object to dictionary for Firestore storage."""
        return {
            # Basic info (Flutter compatible field names)
            'fullName': self.full_name,
            'studentID': self.student_id,
            'email': self.email,
            'department': self.department,
            'course': self.course,
            'yearLevel': self.year_level,
            'section': self.section,
            
            # Core stats
            'points': self.points,
            'bottles': self.bottles,
            'totalBottlesLifetime': self.total_bottles_lifetime,
            'totalPointsEarned': self.total_points_earned,
            'totalPointsSpent': self.total_points_spent,
            
            # Status & verification
            'status': self.status,
            'role': 'student',  # Always student for this model
            'isEmailVerified': self.is_email_verified,
            'isProfileComplete': self.is_profile_complete,
            
            # Profile
            'profileImageUrl': self.profile_image_url,
            'phoneNumber': self.phone_number,
            'dateOfBirth': self.date_of_birth,
            'address': self.address,
            
            # Activity tracking
            'currentStreak': self.current_streak,
            'longestStreak': self.longest_streak,
            'lastLoginAt': self.last_login_at,
            'lastActivityAt': self.last_activity_at,
            'totalSessions': self.total_sessions,
            
            # Achievements and stats
            'achievements': self.achievements,
            'totalRewardsRedeemed': self.total_rewards_redeemed,
            'favoriteRewardCategory': self.favorite_reward_category,
            
            # Preferences
            'preferences': self.preferences,
            
            # Timestamps
            'createdAt': self.created_at,
            'updatedAt': self.updated_at,
            'lastModifiedBy': self.last_modified_by
        }
    
    @classmethod
    def from_dict(cls, doc_id: str, data: Dict[str, Any]) -> 'Student':
        """Create Student object from Firestore document."""
        return cls(
            id=doc_id,
            full_name=data.get('fullName', ''),
            student_id=data.get('studentID', ''),
            email=data.get('email', ''),
            department=data.get('department', ''),
            course=data.get('course', ''),
            year_level=data.get('yearLevel', YearLevel.FIRST.value),
            section=data.get('section', ''),
            
            # Core stats
            points=data.get('points', 0),
            bottles=data.get('bottles', 0),
            total_bottles_lifetime=data.get('totalBottlesLifetime', 0),
            total_points_earned=data.get('totalPointsEarned', 0),
            total_points_spent=data.get('totalPointsSpent', 0),
            
            # Status & verification
            status=data.get('status', StudentStatus.ACTIVE.value),
            is_email_verified=data.get('isEmailVerified', False),
            is_profile_complete=data.get('isProfileComplete', False),
            
            # Profile
            profile_image_url=data.get('profileImageUrl', ''),
            phone_number=data.get('phoneNumber', ''),
            date_of_birth=data.get('dateOfBirth', ''),
            address=data.get('address', ''),
            
            # Activity tracking
            current_streak=data.get('currentStreak', 0),
            longest_streak=data.get('longestStreak', 0),
            last_login_at=data.get('lastLoginAt'),
            last_activity_at=data.get('lastActivityAt'),
            total_sessions=data.get('totalSessions', 0),
            
            # Achievements and preferences
            achievements=data.get('achievements', []),
            total_rewards_redeemed=data.get('totalRewardsRedeemed', 0),
            favorite_reward_category=data.get('favoriteRewardCategory', ''),
            preferences=data.get('preferences', {}),
            
            # Timestamps
            created_at=data.get('createdAt'),
            updated_at=data.get('updatedAt'),
            last_modified_by=data.get('lastModifiedBy', 'system')
        )
    
    @classmethod
    def get_all_students(cls) -> List['Student']:
        """Retrieve all students from Firestore."""
        students = []
        try:
            students_ref = db.collection('students')
            docs = students_ref.stream()
            
            for doc in docs:
                student = cls.from_dict(doc.id, doc.to_dict())
                students.append(student)
        except Exception as e:
            print(f"Error fetching students: {e}")
        
        return students
    
    @classmethod
    def get_student_by_id(cls, student_id: str) -> Optional['Student']:
        """Retrieve a specific student by ID."""
        try:
            doc_ref = db.collection('students').document(student_id)
            doc = doc_ref.get()
            
            if doc.exists:
                return cls.from_dict(doc.id, doc.to_dict())
        except Exception as e:
            print(f"Error fetching student {student_id}: {e}")
        
        return None
    
    @classmethod
    def get_student_by_student_id(cls, student_id: str) -> Optional['Student']:
        """Retrieve student by student ID field."""
        try:
            students_ref = db.collection('students')
            query = students_ref.where('studentID', '==', student_id)
            docs = query.stream()
            
            for doc in docs:
                return cls.from_dict(doc.id, doc.to_dict())
        except Exception as e:
            print(f"Error fetching student by student ID {student_id}: {e}")
        
        return None
    
    @classmethod
    def get_student_by_email(cls, email: str) -> Optional['Student']:
        """Retrieve student by email."""
        try:
            students_ref = db.collection('students')
            query = students_ref.where('email', '==', email)
            docs = query.stream()
            
            for doc in docs:
                return cls.from_dict(doc.id, doc.to_dict())
        except Exception as e:
            print(f"Error fetching student by email {email}: {e}")
        
        return None
    
    @classmethod
    def get_students_by_department(cls, department: str) -> List['Student']:
        """Filter students by department."""
        students = []
        try:
            students_ref = db.collection('students')
            query = students_ref.where('department', '==', department)
            docs = query.stream()
            
            for doc in docs:
                student = cls.from_dict(doc.id, doc.to_dict())
                students.append(student)
        except Exception as e:
            print(f"Error fetching students by department {department}: {e}")
        
        return students
    
    @classmethod
    def get_students_by_status(cls, status: str) -> List['Student']:
        """Filter students by status."""
        students = []
        try:
            students_ref = db.collection('students')
            query = students_ref.where('status', '==', status)
            docs = query.stream()
            
            for doc in docs:
                student = cls.from_dict(doc.id, doc.to_dict())
                students.append(student)
        except Exception as e:
            print(f"Error fetching students by status {status}: {e}")
        
        return students
    
    @classmethod
    def get_top_students_by_points(cls, limit: int = 10, department: str = None) -> List['Student']:
        """Get top students by points."""
        students = []
        try:
            students_ref = db.collection('students')
            query = students_ref.where('status', '==', StudentStatus.ACTIVE.value)
            
            if department:
                query = query.where('department', '==', department)
            
            query = query.order_by('points', direction=firestore.Query.DESCENDING).limit(limit)
            docs = query.stream()
            
            for doc in docs:
                student = cls.from_dict(doc.id, doc.to_dict())
                students.append(student)
        except Exception as e:
            print(f"Error fetching top students: {e}")
        
        return students
    
    def save(self) -> bool:
        """Save or update student in Firestore."""
        try:
            self.updated_at = datetime.now()
            self.is_profile_complete = self._check_profile_completeness()
            student_data = self.to_dict()
            
            if self.id:
                # Update existing student
                db.collection('students').document(self.id).update(student_data)
            else:
                # Create new student
                doc_ref = db.collection('students').add(student_data)
                self.id = doc_ref[1].id
            
            return True
        except Exception as e:
            print(f"Error saving student: {e}")
            return False
    
    def _check_profile_completeness(self) -> bool:
        """Check if profile is complete."""
        required_fields = [
            self.full_name, self.student_id, self.email, 
            self.department, self.course, self.year_level
        ]
        return all(field for field in required_fields)
    
    def update_activity(self) -> bool:
        """Update last activity timestamp."""
        try:
            self.last_activity_at = datetime.now()
            return self.save()
        except Exception as e:
            print(f"Error updating activity: {e}")
            return False
    
    def add_bottles(self, bottle_count: int) -> bool:
        """Add bottles and calculate points."""
        try:
            self.bottles += bottle_count
            self.total_bottles_lifetime += bottle_count
            
            # Calculate points (1 bottle = 1 point by default)
            points_to_add = bottle_count
            self.points += points_to_add
            self.total_points_earned += points_to_add
            
            # Update streak
            self._update_streak()
            
            return self.save()
        except Exception as e:
            print(f"Error adding bottles: {e}")
            return False
    
    def deduct_points(self, point_amount: int) -> bool:
        """Deduct points for reward redemption."""
        try:
            if self.points >= point_amount:
                self.points -= point_amount
                self.total_points_spent += point_amount
                self.total_rewards_redeemed += 1
                return self.save()
            else:
                print("Insufficient points")
                return False
        except Exception as e:
            print(f"Error deducting points: {e}")
            return False
    
    def _update_streak(self):
        """Update current streak based on activity."""
        # Simplified streak logic - in production, you'd implement proper date checking
        self.current_streak += 1
        if self.current_streak > self.longest_streak:
            self.longest_streak = self.current_streak
    
    def add_achievement(self, achievement: str) -> bool:
        """Add achievement to student."""
        try:
            if achievement not in self.achievements:
                self.achievements.append(achievement)
                return self.save()
            return True
        except Exception as e:
            print(f"Error adding achievement: {e}")
            return False
    
    def update_status(self, new_status: str, modified_by: str = "system") -> bool:
        """Update student status."""
        try:
            if new_status in [status.value for status in StudentStatus]:
                self.status = new_status
                self.last_modified_by = modified_by
                return self.save()
        except Exception as e:
            print(f"Error updating status: {e}")
        
        return False
    
    @classmethod
    def get_student_statistics(cls) -> Dict[str, Any]:
        """Get overall student statistics for dashboard."""
        try:
            all_students = cls.get_all_students()
            
            total_students = len(all_students)
            active_students = len([s for s in all_students if s.status == StudentStatus.ACTIVE.value])
            pending_students = len([s for s in all_students if s.status == StudentStatus.PENDING.value])
            suspended_students = len([s for s in all_students if s.status == StudentStatus.SUSPENDED.value])
            banned_students = len([s for s in all_students if s.status == StudentStatus.BANNED.value])
            
            total_bottles = sum(student.total_bottles_lifetime for student in all_students)
            total_points_earned = sum(student.total_points_earned for student in all_students)
            total_points_spent = sum(student.total_points_spent for student in all_students)
            current_points = sum(student.points for student in all_students)
            
            # Department breakdown
            departments = {}
            for student in all_students:
                dept = student.department
                if dept in departments:
                    departments[dept]['count'] += 1
                    departments[dept]['bottles'] += student.total_bottles_lifetime
                    departments[dept]['points'] += student.points
                else:
                    departments[dept] = {
                        'count': 1,
                        'bottles': student.total_bottles_lifetime,
                        'points': student.points
                    }
            
            return {
                'total_students': total_students,
                'active_students': active_students,
                'pending_students': pending_students,
                'suspended_students': suspended_students,
                'banned_students': banned_students,
                'total_bottles': total_bottles,
                'total_points_earned': total_points_earned,
                'total_points_spent': total_points_spent,
                'current_points': current_points,
                'department_breakdown': departments
            }
        except Exception as e:
            print(f"Error getting student statistics: {e}")
            return {}
    
    def __str__(self) -> str:
        return f"Student(id={self.id}, name={self.full_name}, student_id={self.student_id}, department={self.department})"
    
    def __repr__(self) -> str:
        return self.__str__()