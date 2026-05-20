from datetime import datetime
from typing import Dict, List, Optional, Any
from enum import Enum
from services.firebase_service import db
from firebase_admin import firestore

class RewardStatus(Enum):
    ACTIVE = "active"
    INACTIVE = "inactive"
    OUT_OF_STOCK = "out_of_stock"
    DISCONTINUED = "discontinued"

class Reward:
    """
    Reward model for Firebase Firestore integration.
    Matches Flutter RewardModel structure for proper data synchronization.
    """
    
    def __init__(self, id: str = None, name: str = "", cost: int = 0, 
                 stock: int = 0, department: str = "", image_url: str = "",
                 created_by: str = "", status: str = RewardStatus.ACTIVE.value,
                 created_at: datetime = None, updated_at: datetime = None):
        self.id = id
        self.name = name  # Match Flutter 'name' field
        self.cost = cost  # Match Flutter 'cost' field
        self.stock = stock
        self.department = department
        self.image_url = image_url  # Match Flutter 'imageUrl' field
        self.created_by = created_by  # Match Flutter 'createdBy' field
        self.status = status
        self.created_at = created_at or datetime.now()
        self.updated_at = updated_at or datetime.now()
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert reward object to dictionary for Firestore storage."""
        return {
            'name': self.name,
            'cost': self.cost,
            'stock': self.stock,
            'department': self.department,
            'imageUrl': self.image_url,
            'createdBy': self.created_by,
            'status': self.status,
            'createdAt': self.created_at,
            'updatedAt': self.updated_at
        }
    
    @classmethod
    def from_dict(cls, doc_id: str, data: Dict[str, Any]) -> 'Reward':
        """Create Reward object from Firestore document."""
        # Determine status based on stock if not explicitly set
        stock = data.get('stock', 0)
        status = data.get('status', '')
        
        if stock == 0:
            status = RewardStatus.OUT_OF_STOCK.value
        elif not status:
            status = RewardStatus.ACTIVE.value
        
        return cls(
            id=doc_id,
            name=data.get('name', ''),
            cost=data.get('cost', 0),
            stock=stock,
            department=data.get('department', ''),
            image_url=data.get('imageUrl', ''),
            created_by=data.get('createdBy', ''),
            status=status,
            created_at=data.get('createdAt'),
            updated_at=data.get('updatedAt')
        )
    
    @classmethod
    def get_all_rewards(cls) -> List['Reward']:
        """Retrieve all rewards from Firestore."""
        rewards = []
        try:
            rewards_ref = db.collection('rewards')
            docs = rewards_ref.stream()
            
            for doc in docs:
                reward = cls.from_dict(doc.id, doc.to_dict())
                rewards.append(reward)
        except Exception as e:
            print(f"Error fetching rewards: {e}")
        
        return rewards
    
    @classmethod
    def get_reward_by_id(cls, reward_id: str) -> Optional['Reward']:
        """Retrieve a specific reward by ID."""
        try:
            doc_ref = db.collection('rewards').document(reward_id)
            doc = doc_ref.get()
            
            if doc.exists:
                return cls.from_dict(doc.id, doc.to_dict())
        except Exception as e:
            print(f"Error fetching reward {reward_id}: {e}")
        
        return None
    
    @classmethod
    def get_rewards_by_department(cls, department: str) -> List['Reward']:
        """Filter rewards by department."""
        rewards = []
        try:
            rewards_ref = db.collection('rewards')
            query = rewards_ref.where('department', '==', department)
            docs = query.stream()
            
            for doc in docs:
                reward = cls.from_dict(doc.id, doc.to_dict())
                rewards.append(reward)
        except Exception as e:
            print(f"Error fetching rewards by department {department}: {e}")
        
        return rewards
    
    @classmethod
    def get_available_rewards(cls) -> List['Reward']:
        """Get all active rewards with stock > 0."""
        rewards = []
        try:
            all_rewards = cls.get_all_rewards()
            for reward in all_rewards:
                if reward.stock > 0:
                    rewards.append(reward)
        except Exception as e:
            print(f"Error fetching available rewards: {e}")
        
        return rewards
    
    @classmethod
    def get_rewards_by_cost_range(cls, min_cost: int, max_cost: int) -> List['Reward']:
        """Filter rewards by cost range."""
        rewards = []
        try:
            all_rewards = cls.get_all_rewards()
            
            for reward in all_rewards:
                if min_cost <= reward.cost <= max_cost:
                    rewards.append(reward)
        except Exception as e:
            print(f"Error fetching rewards by cost range: {e}")
        
        return rewards
    
    @classmethod
    def get_low_stock_rewards(cls, threshold: int = 5) -> List['Reward']:
        """Get rewards with low stock (below threshold)."""
        rewards = []
        try:
            all_rewards = cls.get_all_rewards()
            
            for reward in all_rewards:
                if 0 < reward.stock <= threshold:
                    rewards.append(reward)
        except Exception as e:
            print(f"Error fetching low stock rewards: {e}")
        
        return rewards
    
    def save(self) -> bool:
        """Save or update reward in Firestore."""
        try:
            self.updated_at = datetime.now()
            reward_data = self.to_dict()
            
            if self.id:
                # Update existing reward
                db.collection('rewards').document(self.id).update(reward_data)
            else:
                # Create new reward
                doc_ref = db.collection('rewards').add(reward_data)
                self.id = doc_ref[1].id
            
            return True
        except Exception as e:
            print(f"Error saving reward: {e}")
            return False
    
    def delete(self) -> bool:
        """Delete reward from Firestore."""
        try:
            if self.id:
                db.collection('rewards').document(self.id).delete()
                return True
        except Exception as e:
            print(f"Error deleting reward: {e}")
        
        return False
    
    def update_stock(self, new_stock: int) -> bool:
        """Update reward stock."""
        try:
            self.stock = new_stock
            
            # Auto-update status based on stock
            if new_stock == 0:
                self.status = RewardStatus.OUT_OF_STOCK.value
            elif new_stock > 0 and self.status == RewardStatus.OUT_OF_STOCK.value:
                self.status = RewardStatus.ACTIVE.value
            
            return self.save()
        except Exception as e:
            print(f"Error updating stock: {e}")
            return False
    
    def add_stock(self, quantity: int) -> bool:
        """Add stock to reward."""
        try:
            new_stock = self.stock + quantity
            return self.update_stock(new_stock)
        except Exception as e:
            print(f"Error adding stock: {e}")
            return False
    
    def reduce_stock(self, quantity: int = 1) -> bool:
        """Reduce stock when reward is redeemed."""
        try:
            if self.stock >= quantity:
                new_stock = self.stock - quantity
                return self.update_stock(new_stock)
            else:
                print("Insufficient stock")
                return False
        except Exception as e:
            print(f"Error reducing stock: {e}")
            return False
    
    def can_be_redeemed(self, user_points: int) -> bool:
        """Check if reward can be redeemed by user."""
        return (self.status == RewardStatus.ACTIVE.value and 
                self.stock > 0 and 
                user_points >= self.cost)
    
    @classmethod
    def search_rewards(cls, search_term: str) -> List['Reward']:
        """Search rewards by name."""
        rewards = []
        try:
            # Note: Firestore doesn't support case-insensitive search natively
            all_rewards = cls.get_all_rewards()
            search_term = search_term.lower()
            
            for reward in all_rewards:
                if search_term in reward.name.lower():
                    rewards.append(reward)
        except Exception as e:
            print(f"Error searching rewards: {e}")
        
        return rewards
    
    @classmethod
    def get_reward_statistics(cls) -> Dict[str, Any]:
        """Get overall reward statistics for dashboard."""
        try:
            all_rewards = cls.get_all_rewards()
            
            total_rewards = len(all_rewards)
            
            # Count statuses based on actual stock levels
            active_rewards = len([r for r in all_rewards if r.stock > 0])
            out_of_stock = len([r for r in all_rewards if r.stock == 0])
            inactive_rewards = total_rewards - active_rewards - out_of_stock
            
            total_stock = sum(reward.stock for reward in all_rewards)
            
            # Department breakdown
            departments = {}
            for reward in all_rewards:
                dept = reward.department
                if dept in departments:
                    departments[dept]['count'] += 1
                    departments[dept]['total_stock'] += reward.stock
                    departments[dept]['total_cost'] += reward.cost
                else:
                    departments[dept] = {
                        'count': 1,
                        'total_stock': reward.stock,
                        'total_cost': reward.cost
                    }
            
            # Cost range analysis
            if all_rewards:
                min_cost = min(reward.cost for reward in all_rewards)
                max_cost = max(reward.cost for reward in all_rewards)
                avg_cost = sum(reward.cost for reward in all_rewards) / len(all_rewards)
            else:
                min_cost = max_cost = avg_cost = 0
            
            return {
                'total_rewards': total_rewards,
                'active_rewards': active_rewards,
                'inactive_rewards': inactive_rewards,
                'out_of_stock': out_of_stock,
                'total_stock': total_stock,
                'department_breakdown': departments,
                'cost_range': {
                    'min': min_cost,
                    'max': max_cost,
                    'average': round(avg_cost, 2)
                }
            }
        except Exception as e:
            print(f"Error getting reward statistics: {e}")
            return {}
    
    def __str__(self) -> str:
        return f"Reward(id={self.id}, name={self.name}, department={self.department}, cost={self.cost})"
    
    def __repr__(self) -> str:
        return self.__str__()