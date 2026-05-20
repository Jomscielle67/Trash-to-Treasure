from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from enum import Enum
from services.firebase_service import db
from firebase_admin import firestore

class MachineStatus(Enum):
    ACTIVE = "active"
    OFFLINE = "offline"
    FULL = "full"
    MAINTENANCE = "maintenance"
    ERROR = "error"

class MaintenanceType(Enum):
    ROUTINE = "routine"
    REPAIR = "repair"
    CLEANING = "cleaning"
    BOTTLE_COLLECTION = "bottle_collection"
    EMERGENCY = "emergency"

class Machine:
    """
    Machine model for Firebase Firestore integration.
    Handles all vending machine-related operations for tracking status and maintenance.
    """
    
    def __init__(self, id: str = None, machine_id: str = "", name: str = "", location: str = "", 
                 status: str = MachineStatus.ACTIVE.value, last_maintenance: datetime = None,
                 bottles_collected: int = 0, updated_by: str = "", 
                 capacity: int = 100, current_bottles: int = 0,
                 last_online: datetime = None, created_at: datetime = None,
                 maintenance_schedule: int = 7, notes: str = "",
                 assigned_admin_id: str = "", assigned_admin_name: str = ""):
        self.id = id
        self.machine_id = machine_id
        self.name = name
        self.location = location
        self.status = status
        self.last_maintenance = last_maintenance
        self.bottles_collected = bottles_collected
        self.updated_by = updated_by
        self.capacity = capacity
        self.current_bottles = current_bottles
        self.last_online = last_online or datetime.now()
        self.created_at = created_at or datetime.now()
        self.maintenance_schedule = maintenance_schedule  # Days between maintenance
        self.notes = notes
        self.assigned_admin_id = assigned_admin_id
        self.assigned_admin_name = assigned_admin_name
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert machine object to dictionary for Firestore storage."""
        return {
            'machineId': self.machine_id,
            'name': self.name,
            'location': self.location,
            'status': self.status,
            'lastMaintenance': self.last_maintenance,
            'bottlesCollected': self.bottles_collected,
            'updatedBy': self.updated_by,
            'capacity': self.capacity,
            'currentBottles': self.current_bottles,
            'lastOnline': self.last_online,
            'createdAt': self.created_at,
            'maintenanceSchedule': self.maintenance_schedule,
            'notes': self.notes,
            'assignedAdminId': self.assigned_admin_id,
            'assignedAdminName': self.assigned_admin_name
        }
    
    @classmethod
    def from_dict(cls, doc_id: str, data: Dict[str, Any]) -> 'Machine':
        """Create Machine object from Firestore document."""
        return cls(
            id=doc_id,
            machine_id=data.get('machineId', ''),
            name=data.get('name', ''),
            location=data.get('location', ''),
            status=data.get('status', MachineStatus.ACTIVE.value),
            last_maintenance=data.get('lastMaintenance'),
            bottles_collected=data.get('bottlesCollected', 0),
            updated_by=data.get('updatedBy', ''),
            capacity=data.get('capacity', 100),
            current_bottles=data.get('currentBottles', 0),
            last_online=data.get('lastOnline'),
            created_at=data.get('createdAt'),
            maintenance_schedule=data.get('maintenanceSchedule', 7),
            notes=data.get('notes', ''),
            assigned_admin_id=data.get('assignedAdminId', ''),
            assigned_admin_name=data.get('assignedAdminName', '')
        )
    
    @classmethod
    def get_all_machines(cls) -> List['Machine']:
        """Retrieve all machines from Firestore."""
        machines = []
        try:
            machines_ref = db.collection('machines')
            docs = machines_ref.stream()
            
            for doc in docs:
                machine = cls.from_dict(doc.id, doc.to_dict())
                machines.append(machine)
        except Exception as e:
            print(f"Error fetching machines: {e}")
        
        return machines
    
    @classmethod
    def get_machine_by_id(cls, machine_id: str) -> Optional['Machine']:
        """Retrieve a specific machine by ID."""
        try:
            doc_ref = db.collection('machines').document(machine_id)
            doc = doc_ref.get()
            
            if doc.exists:
                return cls.from_dict(doc.id, doc.to_dict())
        except Exception as e:
            print(f"Error fetching machine {machine_id}: {e}")
        
        return None
    
    @classmethod
    def get_machine_by_machine_id(cls, machine_id: str) -> Optional['Machine']:
        """Retrieve machine by machine ID field."""
        try:
            machines_ref = db.collection('machines')
            query = machines_ref.where('machineId', '==', machine_id)
            docs = query.stream()
            
            for doc in docs:
                return cls.from_dict(doc.id, doc.to_dict())
        except Exception as e:
            print(f"Error fetching machine by machine ID {machine_id}: {e}")
        
        return None
    
    @classmethod
    def get_machines_by_status(cls, status: str) -> List['Machine']:
        """Filter machines by status."""
        machines = []
        try:
            machines_ref = db.collection('machines')
            query = machines_ref.where('status', '==', status)
            docs = query.stream()
            
            for doc in docs:
                machine = cls.from_dict(doc.id, doc.to_dict())
                machines.append(machine)
        except Exception as e:
            print(f"Error fetching machines by status {status}: {e}")
        
        return machines
    
    @classmethod
    def get_machines_by_location(cls, location: str) -> List['Machine']:
        """Filter machines by location."""
        machines = []
        try:
            machines_ref = db.collection('machines')
            query = machines_ref.where('location', '==', location)
            docs = query.stream()
            
            for doc in docs:
                machine = cls.from_dict(doc.id, doc.to_dict())
                machines.append(machine)
        except Exception as e:
            print(f"Error fetching machines by location {location}: {e}")
        
        return machines
    
    @classmethod
    def get_full_machines(cls) -> List['Machine']:
        """Get machines that are full or near capacity."""
        machines = []
        try:
            all_machines = cls.get_all_machines()
            for machine in all_machines:
                # Consider full if 90% or more of capacity, or status is FULL
                fill_percentage = (machine.current_bottles / machine.capacity) * 100 if machine.capacity > 0 else 0
                if machine.status == MachineStatus.FULL.value or fill_percentage >= 90:
                    machines.append(machine)
        except Exception as e:
            print(f"Error fetching full machines: {e}")
        
        return machines
    
    @classmethod
    def get_offline_machines(cls) -> List['Machine']:
        """Get machines that are offline."""
        return cls.get_machines_by_status(MachineStatus.OFFLINE.value)
    
    @classmethod
    def get_maintenance_due_machines(cls) -> List['Machine']:
        """Get machines that are due for maintenance."""
        machines = []
        try:
            all_machines = cls.get_all_machines()
            current_time = datetime.now()
            
            for machine in all_machines:
                if machine.last_maintenance:
                    days_since_maintenance = (current_time - machine.last_maintenance).days
                    if days_since_maintenance >= machine.maintenance_schedule:
                        machines.append(machine)
                else:
                    # If no maintenance record, consider it due
                    machines.append(machine)
        except Exception as e:
            print(f"Error fetching maintenance due machines: {e}")
        
        return machines
    
    @classmethod
    def get_machines_needing_attention(cls) -> List['Machine']:
        """Get all machines that need attention (full, offline, maintenance due, or error)."""
        machines = []
        try:
            all_machines = cls.get_all_machines()
            current_time = datetime.now()
            
            for machine in all_machines:
                needs_attention = False
                
                # Check if offline or error
                if machine.status in [MachineStatus.OFFLINE.value, MachineStatus.ERROR.value, MachineStatus.MAINTENANCE.value]:
                    needs_attention = True
                
                # Check if full
                fill_percentage = (machine.current_bottles / machine.capacity) * 100 if machine.capacity > 0 else 0
                if machine.status == MachineStatus.FULL.value or fill_percentage >= 90:
                    needs_attention = True
                
                # Check if maintenance due
                if machine.last_maintenance:
                    days_since_maintenance = (current_time - machine.last_maintenance).days
                    if days_since_maintenance >= machine.maintenance_schedule:
                        needs_attention = True
                else:
                    needs_attention = True
                
                if needs_attention:
                    machines.append(machine)
        except Exception as e:
            print(f"Error fetching machines needing attention: {e}")
        
        return machines
    
    def save(self) -> bool:
        """Save or update machine in Firestore."""
        try:
            machine_data = self.to_dict()
            
            if self.id:
                # Update existing machine
                db.collection('machines').document(self.id).update(machine_data)
            else:
                # Create new machine
                doc_ref = db.collection('machines').add(machine_data)
                self.id = doc_ref[1].id
            
            return True
        except Exception as e:
            print(f"Error saving machine: {e}")
            return False
    
    def delete(self) -> bool:
        """Delete machine from Firestore."""
        try:
            if self.id:
                db.collection('machines').document(self.id).delete()
                return True
        except Exception as e:
            print(f"Error deleting machine: {e}")
        
        return False
    
    def update_status(self, new_status: str, updated_by: str = "") -> bool:
        """Update machine status."""
        try:
            if new_status in [status.value for status in MachineStatus]:
                self.status = new_status
                self.updated_by = updated_by
                
                # Update last online if machine becomes active
                if new_status == MachineStatus.ACTIVE.value:
                    self.last_online = datetime.now()
                
                return self.save()
        except Exception as e:
            print(f"Error updating machine status: {e}")
        
        return False
    
    def set_offline(self, updated_by: str = "") -> bool:
        """Mark machine as offline."""
        return self.update_status(MachineStatus.OFFLINE.value, updated_by)
    
    def set_active(self, updated_by: str = "") -> bool:
        """Mark machine as active."""
        return self.update_status(MachineStatus.ACTIVE.value, updated_by)
    
    def set_full(self, updated_by: str = "") -> bool:
        """Mark machine as full."""
        return self.update_status(MachineStatus.FULL.value, updated_by)
    
    def set_maintenance(self, updated_by: str = "") -> bool:
        """Mark machine as under maintenance."""
        return self.update_status(MachineStatus.MAINTENANCE.value, updated_by)
    
    def collect_bottles(self, bottles_collected: int, updated_by: str = "") -> bool:
        """Record bottle collection from machine."""
        try:
            self.bottles_collected += bottles_collected
            self.current_bottles = max(0, self.current_bottles - bottles_collected)
            self.updated_by = updated_by
            
            # Update status if machine was full and now has space
            if self.status == MachineStatus.FULL.value:
                fill_percentage = (self.current_bottles / self.capacity) * 100 if self.capacity > 0 else 0
                if fill_percentage < 90:
                    self.status = MachineStatus.ACTIVE.value
            
            return self.save()
        except Exception as e:
            print(f"Error collecting bottles: {e}")
            return False
    
    def add_bottles(self, bottle_count: int) -> bool:
        """Add bottles to machine (when students deposit)."""
        try:
            self.current_bottles += bottle_count
            
            # Check if machine is full
            fill_percentage = (self.current_bottles / self.capacity) * 100 if self.capacity > 0 else 0
            if fill_percentage >= 90:
                self.status = MachineStatus.FULL.value
            
            return self.save()
        except Exception as e:
            print(f"Error adding bottles: {e}")
            return False
    
    def perform_maintenance(self, maintenance_type: str, updated_by: str = "", notes: str = "") -> bool:
        """Record maintenance performed on machine."""
        try:
            self.last_maintenance = datetime.now()
            self.updated_by = updated_by
            self.notes = notes
            
            # If it was under maintenance, set back to active
            if self.status == MachineStatus.MAINTENANCE.value:
                self.status = MachineStatus.ACTIVE.value
            
            # Create maintenance log entry
            maintenance_log = {
                'machineId': self.machine_id,
                'maintenanceType': maintenance_type,
                'performedBy': updated_by,
                'timestamp': datetime.now(),
                'notes': notes,
                'status': 'completed'
            }
            
            db.collection('maintenance_logs').add(maintenance_log)
            
            return self.save()
        except Exception as e:
            print(f"Error recording maintenance: {e}")
            return False
    
    def get_fill_percentage(self) -> float:
        """Calculate current fill percentage."""
        if self.capacity <= 0:
            return 0.0
        return round((self.current_bottles / self.capacity) * 100, 2)
    
    def get_days_since_maintenance(self) -> int:
        """Get number of days since last maintenance."""
        if not self.last_maintenance:
            return 999  # Large number if never maintained
        
        return (datetime.now() - self.last_maintenance).days
    
    def is_maintenance_due(self) -> bool:
        """Check if maintenance is due."""
        return self.get_days_since_maintenance() >= self.maintenance_schedule
    
    def get_next_maintenance_date(self) -> datetime:
        """Calculate next scheduled maintenance date."""
        if not self.last_maintenance:
            return datetime.now()
        
        return self.last_maintenance + timedelta(days=self.maintenance_schedule)
    
    @classmethod
    def get_machine_statistics(cls) -> Dict[str, Any]:
        """Get overall machine statistics for dashboard."""
        try:
            all_machines = cls.get_all_machines()
            
            total_machines = len(all_machines)
            active_machines = len([m for m in all_machines if m.status == MachineStatus.ACTIVE.value])
            offline_machines = len([m for m in all_machines if m.status == MachineStatus.OFFLINE.value])
            full_machines = len([m for m in all_machines if m.status == MachineStatus.FULL.value])
            maintenance_machines = len([m for m in all_machines if m.status == MachineStatus.MAINTENANCE.value])
            
            total_bottles_collected = sum(machine.bottles_collected for machine in all_machines)
            total_current_bottles = sum(machine.current_bottles for machine in all_machines)
            total_capacity = sum(machine.capacity for machine in all_machines)
            
            avg_fill_percentage = (total_current_bottles / total_capacity * 100) if total_capacity > 0 else 0
            
            # Location breakdown
            locations = {}
            for machine in all_machines:
                loc = machine.location
                if loc in locations:
                    locations[loc] += 1
                else:
                    locations[loc] = 1
            
            # Machines needing attention
            machines_needing_attention = len(cls.get_machines_needing_attention())
            maintenance_due = len(cls.get_maintenance_due_machines())
            
            return {
                'total_machines': total_machines,
                'active_machines': active_machines,
                'offline_machines': offline_machines,
                'full_machines': full_machines,
                'maintenance_machines': maintenance_machines,
                'machines_needing_attention': machines_needing_attention,
                'maintenance_due': maintenance_due,
                'total_bottles_collected': total_bottles_collected,
                'total_current_bottles': total_current_bottles,
                'total_capacity': total_capacity,
                'avg_fill_percentage': round(avg_fill_percentage, 2),
                'location_breakdown': locations
            }
        except Exception as e:
            print(f"Error getting machine statistics: {e}")
            return {}
    
    @classmethod
    def get_maintenance_logs(cls, machine_id: str = None, limit: int = 50) -> List[Dict[str, Any]]:
        """Get maintenance logs for a specific machine or all machines."""
        logs = []
        try:
            logs_ref = db.collection('maintenance_logs')
            
            if machine_id:
                query = logs_ref.where('machineId', '==', machine_id)
            else:
                query = logs_ref
            
            query = query.order_by('timestamp', direction=firestore.Query.DESCENDING).limit(limit)
            docs = query.stream()
            
            for doc in docs:
                log_data = doc.to_dict()
                log_data['id'] = doc.id
                logs.append(log_data)
        except Exception as e:
            print(f"Error fetching maintenance logs: {e}")
        
        return logs
    
    @classmethod
    def generate_maintenance_schedule(cls) -> List[Dict[str, Any]]:
        """Generate upcoming maintenance schedule for all machines."""
        schedule = []
        try:
            all_machines = cls.get_all_machines()
            
            for machine in all_machines:
                next_maintenance = machine.get_next_maintenance_date()
                days_until = (next_maintenance - datetime.now()).days
                
                schedule.append({
                    'machine_id': machine.machine_id,
                    'location': machine.location,
                    'next_maintenance': next_maintenance,
                    'days_until': days_until,
                    'is_overdue': days_until < 0,
                    'status': machine.status
                })
            
            # Sort by urgency (overdue first, then by days until)
            schedule.sort(key=lambda x: (not x['is_overdue'], x['days_until']))
        except Exception as e:
            print(f"Error generating maintenance schedule: {e}")
        
        return schedule
    
    def __str__(self) -> str:
        return f"Machine(id={self.machine_id}, location={self.location}, status={self.status})"
    
    def __repr__(self) -> str:
        return self.__str__()
