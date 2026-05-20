from datetime import datetime
from typing import Dict, List, Optional, Any
from enum import Enum
from services.firebase_service import db
from firebase_admin import firestore

class TransactionType(Enum):
    DEPOSIT = "deposit"
    REDEEM = "redeem"

class TransactionStatus(Enum):
    COMPLETED = "completed"
    PENDING = "pending"
    CANCELLED = "cancelled"

class Transaction:
    """
    Transaction model for Firebase Firestore integration.
    Matches Flutter TransactionModel structure for proper data synchronization.
    """
    
    def __init__(self, id: str = None, user_id: str = "", student_name: str = "",
                 reward_id: str = "", reward_name: str = "", points: int = 0, 
                 type: str = TransactionType.DEPOSIT.value, department: str = "",
                 status: str = TransactionStatus.PENDING.value, ticket_code: str = "",
                 timestamp: datetime = None):
        self.id = id
        self.user_id = user_id  # Match Flutter userId field
        self.student_name = student_name  # Match Flutter studentName field
        self.reward_id = reward_id  # Match Flutter rewardId field
        self.reward_name = reward_name  # Match Flutter rewardName field
        self.points = points
        self.type = type  # Match Flutter type field
        self.department = department
        self.status = status
        self.ticket_code = ticket_code  # Match Flutter ticketCode field
        self.timestamp = timestamp or datetime.now()
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert transaction object to dictionary for Firestore storage."""
        return {
            'userId': self.user_id,
            'studentName': self.student_name,
            'rewardId': self.reward_id,
            'rewardName': self.reward_name,
            'points': self.points,
            'type': self.type,
            'department': self.department,
            'status': self.status,
            'ticketCode': self.ticket_code,
            'timestamp': self.timestamp
        }
    
    @classmethod
    def from_dict(cls, doc_id: str, data: Dict[str, Any]) -> 'Transaction':
        """Create Transaction object from Firestore document."""
        return cls(
            id=doc_id,
            user_id=data.get('userId', ''),
            student_name=data.get('studentName', ''),
            reward_id=data.get('rewardId', ''),
            reward_name=data.get('rewardName', ''),
            points=int(data.get('points') or 0),
            type=data.get('type', TransactionType.DEPOSIT.value),
            department=data.get('department', ''),
            status=(data.get('status') or TransactionStatus.PENDING.value).lower(),
            ticket_code=data.get('ticketCode', ''),
            timestamp=data.get('timestamp')
        )
    
    @classmethod
    def get_all_transactions(cls, limit: Optional[int] = None) -> List['Transaction']:
        """Retrieve all transactions from Firestore."""
        transactions = []
        try:
            transactions_ref = db.collection('transactions')
            query = transactions_ref.order_by('timestamp', direction=firestore.Query.DESCENDING)
            
            if limit:
                query = query.limit(limit)
            
            docs = query.stream()
            
            for doc in docs:
                transaction = cls.from_dict(doc.id, doc.to_dict())
                transactions.append(transaction)
        except Exception as e:
            print(f"Error fetching transactions: {e}")
        
        return transactions
    
    @classmethod
    def get_transaction_by_id(cls, transaction_id: str) -> Optional['Transaction']:
        """Retrieve a specific transaction by ID."""
        try:
            doc_ref = db.collection('transactions').document(transaction_id)
            doc = doc_ref.get()
            
            if doc.exists:
                return cls.from_dict(doc.id, doc.to_dict())
        except Exception as e:
            print(f"Error fetching transaction {transaction_id}: {e}")
        
        return None
    
    @classmethod
    def get_transactions_by_user(cls, user_id: str, limit: Optional[int] = None) -> List['Transaction']:
        """Get all transactions for a specific user."""
        transactions = []
        try:
            transactions_ref = db.collection('transactions')
            query = transactions_ref.where('userId', '==', user_id).order_by('timestamp', direction=firestore.Query.DESCENDING)
            
            if limit:
                query = query.limit(limit)
            
            docs = query.stream()
            
            for doc in docs:
                transaction = cls.from_dict(doc.id, doc.to_dict())
                transactions.append(transaction)
        except Exception as e:
            print(f"Error fetching transactions for user {user_id}: {e}")
        
        return transactions
    
    @classmethod
    def get_transactions_by_type(cls, transaction_type: str, limit: Optional[int] = None) -> List['Transaction']:
        """Filter transactions by type (deposit/redeem)."""
        transactions = []
        try:
            transactions_ref = db.collection('transactions')
            query = transactions_ref.where('type', '==', transaction_type).order_by('timestamp', direction=firestore.Query.DESCENDING)
            
            if limit:
                query = query.limit(limit)
            
            docs = query.stream()
            
            for doc in docs:
                transaction = cls.from_dict(doc.id, doc.to_dict())
                transactions.append(transaction)
        except Exception as e:
            print(f"Error fetching transactions by type {transaction_type}: {e}")
        
        return transactions
    
    @classmethod
    def get_transactions_by_status(cls, status: str, limit: Optional[int] = None) -> List['Transaction']:
        """Filter transactions by status."""
        transactions = []
        try:
            transactions_ref = db.collection('transactions')
            query = transactions_ref.where('status', '==', status).order_by('timestamp', direction=firestore.Query.DESCENDING)
            
            if limit:
                query = query.limit(limit)
            
            docs = query.stream()
            
            for doc in docs:
                transaction = cls.from_dict(doc.id, doc.to_dict())
                transactions.append(transaction)
        except Exception as e:
            print(f"Error fetching transactions by status {status}: {e}")
        
        return transactions
    
    @classmethod
    def get_transactions_by_date_range(cls, start_date: datetime, end_date: datetime) -> List['Transaction']:
        """Get transactions within a specific date range."""
        transactions = []
        try:
            transactions_ref = db.collection('transactions')
            query = (transactions_ref
                    .where('timestamp', '>=', start_date)
                    .where('timestamp', '<=', end_date)
                    .order_by('timestamp', direction=firestore.Query.DESCENDING))
            
            docs = query.stream()
            
            for doc in docs:
                transaction = cls.from_dict(doc.id, doc.to_dict())
                transactions.append(transaction)
        except Exception as e:
            print(f"Error fetching transactions by date range: {e}")
        
        return transactions
    
    @classmethod
    def get_transactions_by_ticket_code(cls, ticket_code: str) -> Optional['Transaction']:
        """Find transaction by ticket code for verification."""
        try:
            transactions_ref = db.collection('transactions')
            query = transactions_ref.where('ticketCode', '==', ticket_code)
            docs = query.stream()
            
            for doc in docs:
                return cls.from_dict(doc.id, doc.to_dict())
        except Exception as e:
            print(f"Error fetching transaction by ticket code {ticket_code}: {e}")
        
        return None
    
    def save(self) -> bool:
        """Save or update transaction in Firestore."""
        try:
            transaction_data = self.to_dict()
            
            if self.id:
                # Update existing transaction
                db.collection('transactions').document(self.id).update(transaction_data)
            else:
                # Create new transaction
                doc_ref = db.collection('transactions').add(transaction_data)
                self.id = doc_ref[1].id
            
            return True
        except Exception as e:
            print(f"Error saving transaction: {e}")
            return False
    
    def delete(self) -> bool:
        """Delete transaction from Firestore."""
        try:
            if self.id:
                db.collection('transactions').document(self.id).delete()
                return True
        except Exception as e:
            print(f"Error deleting transaction: {e}")
        
        return False
    
    def update_status(self, new_status: str) -> bool:
        """Update transaction status."""
        try:
            if new_status in [status.value for status in TransactionStatus]:
                self.status = new_status
                return self.save()
        except Exception as e:
            print(f"Error updating transaction status: {e}")
        
        return False
    
    def complete_transaction(self) -> bool:
        """Mark transaction as completed."""
        return self.update_status(TransactionStatus.COMPLETED.value)
    
    def cancel_transaction(self) -> bool:
        """Cancel transaction."""
        return self.update_status(TransactionStatus.CANCELLED.value)
    
    @classmethod
    def create_deposit_transaction(cls, user_id: str, student_name: str, points_earned: int, department: str) -> 'Transaction':
        """Create a new bottle deposit transaction."""
        
        transaction = cls(
            user_id=user_id,
            student_name=student_name,
            points=points_earned,
            type=TransactionType.DEPOSIT.value,
            department=department,
            status=TransactionStatus.COMPLETED.value
        )
        
        return transaction
    
    @classmethod
    def create_redemption_transaction(cls, user_id: str, student_name: str, reward_id: str,
                                    reward_name: str, points_cost: int, department: str) -> 'Transaction':
        """Create a new reward redemption transaction."""
        # Generate unique ticket code
        ticket_code = cls.generate_ticket_code()
        
        transaction = cls(
            user_id=user_id,
            student_name=student_name,
            reward_id=reward_id,
            reward_name=reward_name,
            points=points_cost,
            type=TransactionType.REDEEM.value,
            department=department,
            status=TransactionStatus.PENDING.value,
            ticket_code=ticket_code
        )
        
        return transaction
    
    @staticmethod
    def generate_ticket_code() -> str:
        """Generate a random ticket code for redemption transactions (matches Flutter logic)."""
        import random
        import string
        
        chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
        code = ''.join(random.choice(chars) for _ in range(6))
        return f'T2T-{code}'
    
    @classmethod
    def get_transaction_statistics(cls) -> Dict[str, Any]:
        """Get overall transaction statistics for dashboard."""
        try:
            all_transactions = cls.get_all_transactions()
            
            total_transactions = len(all_transactions)
            deposit_transactions = [t for t in all_transactions if t.type == TransactionType.DEPOSIT.value]
            redeem_transactions = [t for t in all_transactions if t.type == TransactionType.REDEEM.value]
            
            total_points_earned = sum(t.points for t in deposit_transactions)
            total_points_redeemed = sum(t.points for t in redeem_transactions)
            
            # Accept both "completed" (Python) and "Completed" (Dart/Flutter)
            pending_redemptions = len([t for t in redeem_transactions if t.status.lower() == 'pending'])
            completed_redemptions = len([t for t in redeem_transactions if t.status.lower() == 'completed'])
            
            # Most popular rewards
            reward_counts = {}
            for transaction in redeem_transactions:
                reward = transaction.reward_name
                if reward:  # Only count if reward_name is not empty
                    if reward in reward_counts:
                        reward_counts[reward] += 1
                    else:
                        reward_counts[reward] = 1
            
            # Sort rewards by popularity
            popular_rewards = sorted(reward_counts.items(), key=lambda x: x[1], reverse=True)[:5]
            
            return {
                'total_transactions': total_transactions,
                'total_deposits': len(deposit_transactions),
                'total_redemptions': len(redeem_transactions),
                'total_points_earned': total_points_earned,
                'total_points_redeemed': total_points_redeemed,
                'pending_redemptions': pending_redemptions,
                'completed_redemptions': completed_redemptions,
                'popular_rewards': popular_rewards
            }
        except Exception as e:
            print(f"Error getting transaction statistics: {e}")
            return {}
    
    @classmethod
    def get_daily_statistics(cls, target_date: datetime = None) -> Dict[str, Any]:
        """Get transaction statistics for a specific day."""
        if not target_date:
            target_date = datetime.now()
        
        start_of_day = target_date.replace(hour=0, minute=0, second=0, microsecond=0)
        end_of_day = target_date.replace(hour=23, minute=59, second=59, microsecond=999999)
        
        daily_transactions = cls.get_transactions_by_date_range(start_of_day, end_of_day)
        
        deposits = [t for t in daily_transactions if t.type == TransactionType.DEPOSIT.value]
        redemptions = [t for t in daily_transactions if t.type == TransactionType.REDEEM.value]
        
        return {
            'date': target_date.strftime('%Y-%m-%d'),
            'total_transactions': len(daily_transactions),
            'deposits': len(deposits),
            'redemptions': len(redemptions),
            'points_earned': sum(t.points for t in deposits),
            'points_redeemed': sum(t.points for t in redemptions)
        }
    
    @classmethod
    def verify_ticket(cls, ticket_code: str) -> Dict[str, Any]:
        """Verify a redemption ticket and return transaction details."""
        transaction = cls.get_transactions_by_ticket_code(ticket_code)
        
        if not transaction:
            return {
                'valid': False,
                'message': 'Invalid ticket code'
            }
        
        if transaction.type != TransactionType.REDEEM.value:
            return {
                'valid': False,
                'message': 'Not a redemption transaction'
            }
        
        return {
            'valid': True,
            'transaction': transaction,
            'user_id': transaction.user_id,
            'student_name': transaction.student_name,
            'reward_name': transaction.reward_name,
            'status': transaction.status,
            'timestamp': transaction.timestamp
        }
    
    def __str__(self) -> str:
        return f"Transaction(id={self.id}, user={self.user_id}, type={self.type}, points={self.points})"
    
    def __repr__(self) -> str:
        return self.__str__()
