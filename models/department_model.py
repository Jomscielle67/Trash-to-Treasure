from datetime import datetime
from typing import Dict, List, Optional, Any
from services.firebase_service import db

class Department:
    """
    Department model for Firebase Firestore integration.
    Matches Flutter DepartmentModel structure for proper data synchronization.
    Enhanced with CRUD operations and validation.
    """
    
    def __init__(self, id: str = None, name: str = "", admin_id: str = "",
                 bottle_rate: int = 1, location: str = "", status: str = "active",
                 icon: str = "🏫", description: str = "", order: int = 0,
                 created_at: datetime = None, updated_at: datetime = None,
                 created_by: str = "system"):
        self.id = id
        self.name = name
        self.admin_id = admin_id  # Match Flutter adminId field
        self.bottle_rate = bottle_rate or 1  # Match Flutter bottleRate field (default: 1)
        self.location = location
        self.status = status  # active, inactive
        self.icon = icon
        self.description = description
        self.order = order
        self.created_at = created_at or datetime.now()
        self.updated_at = updated_at or datetime.now()
        self.created_by = created_by
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert department object to dictionary for Firestore storage."""
        return {
            'name': self.name,
            'adminId': self.admin_id,
            'bottleRate': self.bottle_rate,
            'location': self.location,
            'status': self.status,
            'icon': self.icon,
            'description': self.description,
            'order': self.order,
            'createdAt': self.created_at,
            'updatedAt': self.updated_at,
            'createdBy': self.created_by
        }
    
    @classmethod
    def from_dict(cls, doc_id: str, data: Dict[str, Any]) -> 'Department':
        """Create Department object from Firestore document."""
        return cls(
            id=doc_id,
            name=data.get('name', ''),
            admin_id=data.get('adminId', ''),
            bottle_rate=data.get('bottleRate', 1),
            location=data.get('location', ''),
            status=data.get('status', 'active'),
            icon=data.get('icon', '🏫'),
            description=data.get('description', ''),
            order=data.get('order', 0),
            created_at=data.get('createdAt'),
            updated_at=data.get('updatedAt'),
            created_by=data.get('createdBy', 'system')
        )
    
    @classmethod
    def get_all_departments(cls, include_inactive: bool = False) -> List['Department']:
        """Retrieve all departments from Firestore, optionally including inactive ones."""
        departments = []
        try:
            departments_ref = db.collection('departments')
            
            # Simple query without ordering to avoid index requirements
            # We'll sort in Python instead
            if not include_inactive:
                docs = departments_ref.where('status', '==', 'active').stream()
            else:
                docs = departments_ref.stream()
            
            for doc in docs:
                department = cls.from_dict(doc.id, doc.to_dict())
                departments.append(department)
            
            # Sort in Python - no Firestore index needed
            departments.sort(key=lambda x: (x.order, x.name.lower()))
            
        except Exception as e:
            print(f"Error fetching departments: {e}")
            # Ultimate fallback - get all without any filters
            try:
                docs = db.collection('departments').stream()
                for doc in docs:
                    department = cls.from_dict(doc.id, doc.to_dict())
                    if include_inactive or department.status == 'active':
                        departments.append(department)
                
                departments.sort(key=lambda x: (x.order, x.name.lower()))
            except Exception as e2:
                print(f"Error fetching departments (fallback): {e2}")
        
        return departments
    
    @classmethod
    def get_department_by_id(cls, department_id: str) -> Optional['Department']:
        """Retrieve a specific department by ID."""
        try:
            doc_ref = db.collection('departments').document(department_id)
            doc = doc_ref.get()
            
            if doc.exists:
                return cls.from_dict(doc.id, doc.to_dict())
        except Exception as e:
            print(f"Error fetching department {department_id}: {e}")
        
        return None
    
    @classmethod
    def get_department_by_name(cls, name: str) -> Optional['Department']:
        """Retrieve department by name."""
        try:
            departments_ref = db.collection('departments')
            query = departments_ref.where('name', '==', name)
            docs = query.stream()
            
            for doc in docs:
                return cls.from_dict(doc.id, doc.to_dict())
        except Exception as e:
            print(f"Error fetching department by name {name}: {e}")
        
        return None
    
    def save(self) -> str:
        """Save or update department in Firestore. Returns department ID."""
        try:
            self.updated_at = datetime.now()
            department_data = self.to_dict()
            
            if self.id:
                # Update existing department
                db.collection('departments').document(self.id).update(department_data)
                return self.id
            else:
                # Create new department
                _, doc_ref = db.collection('departments').add(department_data)
                self.id = doc_ref.id
                return self.id
        except Exception as e:
            print(f"Error saving department: {e}")
            import traceback
            traceback.print_exc()
            return None
    
    def delete(self) -> bool:
        """Delete department from Firestore."""
        try:
            if self.id:
                db.collection('departments').document(self.id).delete()
                return True
        except Exception as e:
            print(f"Error deleting department: {e}")
        
        return False
    
    def update_admin(self, new_admin_id: str) -> bool:
        """Update department admin."""
        try:
            self.admin_id = new_admin_id
            result = self.save()
            return result is not None
        except Exception as e:
            print(f"Error updating admin: {e}")
            return False
    
    def update_bottle_rate(self, new_rate: int) -> bool:
        """Update bottle rate for the department."""
        try:
            self.bottle_rate = new_rate
            result = self.save()
            return result is not None
        except Exception as e:
            print(f"Error updating bottle rate: {e}")
            return False
    
    def update_status(self, new_status: str) -> bool:
        """Update department status (active/inactive)."""
        try:
            if new_status in ['active', 'inactive']:
                self.status = new_status
                result = self.save()
                return result is not None
            return False
        except Exception as e:
            print(f"Error updating status: {e}")
            return False
    
    def validate_name_unique(self) -> tuple[bool, str]:
        """Check if department name is unique (excluding self if updating)."""
        try:
            existing = self.get_department_by_name(self.name)
            if existing:
                # If we're updating, it's okay if the existing dept is ourselves
                if existing.id == self.id:
                    return True, "Department name is valid"
                else:
                    return False, f"A department with name '{self.name}' already exists"
            return True, "Department name is valid"
        except Exception as e:
            print(f"Error validating name: {e}")
            return False, f"Error validating name: {str(e)}"
    
    def can_be_deleted(self) -> tuple[bool, str]:
        """Check if department can be safely deleted."""
        try:
            # Import here to avoid circular dependency
            from models.student_model import Student
            from models.transaction import Transaction
            
            # Check if any students belong to this department
            students = Student.get_students_by_department(self.name)
            if students:
                return False, f"Cannot delete department with {len(students)} active students"
            
            # Check if any transactions reference this department
            transactions_ref = db.collection('transactions')
            query = transactions_ref.where('department', '==', self.name).limit(1)
            transactions = list(query.stream())
            
            if transactions:
                return False, "Cannot delete department with transaction history"
            
            return True, "Department can be deleted"
        except Exception as e:
            print(f"Error checking if department can be deleted: {e}")
            return False, f"Error: {str(e)}"
    
    def get_student_count(self) -> int:
        """Get number of students in this department."""
        try:
            from models.student_model import Student
            students = Student.get_students_by_department(self.name)
            return len(students)
        except Exception as e:
            print(f"Error getting student count: {e}")
            return 0
    
    @classmethod
    def get_active_departments(cls) -> List['Department']:
        """Get only active departments."""
        return cls.get_all_departments(include_inactive=False)
    
    @classmethod
    def get_department_names(cls, include_inactive: bool = False) -> List[str]:
        """Get list of department names only."""
        departments = cls.get_all_departments(include_inactive=include_inactive)
        return [dept.name for dept in departments]
    
    @classmethod
    def get_department_statistics(cls) -> Dict[str, Any]:
        """Get overall department statistics for dashboard."""
        try:
            all_departments = cls.get_all_departments()
            
            total_departments = len(all_departments)
            departments_with_admin = len([d for d in all_departments if d.admin_id])
            departments_with_rate = len([d for d in all_departments if d.bottle_rate is not None])
            
            # Location breakdown
            locations = {}
            for dept in all_departments:
                loc = dept.location or 'Unknown'
                if loc in locations:
                    locations[loc] += 1
                else:
                    locations[loc] = 1
            
            # Average bottle rate
            rates = [d.bottle_rate for d in all_departments if d.bottle_rate is not None]
            avg_bottle_rate = sum(rates) / len(rates) if rates else 0
            
            return {
                'total_departments': total_departments,
                'departments_with_admin': departments_with_admin,
                'departments_with_rate': departments_with_rate,
                'location_breakdown': locations,
                'average_bottle_rate': round(avg_bottle_rate, 2)
            }
        except Exception as e:
            print(f"Error getting department statistics: {e}")
            return {}
    
    def __str__(self) -> str:
        return f"Department(id={self.id}, name={self.name}, admin_id={self.admin_id})"
    
    def __repr__(self) -> str:
        return self.__str__()