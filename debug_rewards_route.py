"""
Debug script to identify exactly what's failing in the rewards route
"""

import sys
import traceback
from datetime import datetime
from models.rewards import Reward
from models.transaction import Transaction

print("=" * 80)
print("🔍 DEBUGGING REWARDS ROUTE")
print("=" * 80)

# Step 1: Get rewards
print("\n📦 Step 1: Fetching rewards...")
try:
    all_rewards = Reward.get_all_rewards()
    print(f"✅ Success! Found {len(all_rewards)} rewards")
    for r in all_rewards:
        print(f"   - {r.name}: {r.cost} pts, Stock: {r.stock}, Dept: {r.department}")
except Exception as e:
    print(f"❌ Error getting rewards: {e}")
    traceback.print_exc()
    all_rewards = []

# Step 2: Get statistics
print("\n📊 Step 2: Getting reward statistics...")
try:
    reward_stats = Reward.get_reward_statistics()
    print(f"✅ Success! Stats: {reward_stats}")
except Exception as e:
    print(f"❌ Error getting stats: {e}")
    traceback.print_exc()
    reward_stats = {}

# Step 3: Format rewards
print("\n🔄 Step 3: Formatting rewards for template...")
try:
    rewards_data = []
    for reward in all_rewards:
        # Determine actual status based on stock
        if reward.stock == 0:
            actual_status = 'out_of_stock'
        elif reward.status == 'active' or reward.status == 'ACTIVE':
            actual_status = 'active'
        else:
            actual_status = 'inactive'
        
        # Simple emoji mapping based on reward name
        emoji_map = {
            'coffee': '☕', 'shirt': '👕', 'notebook': '📓', 'water': '🍼',
            'lunch': '🍽️', 'pen': '✒️', 'art': '🎨', 'coat': '🥼',
            'bag': '🎒', 'book': '📚', 'mug': '☕', 'tumbler': '🥤',
            'card': '🎫', 'voucher': '🎟️', 'meal': '🍱', 'snack': '🍿'
        }
        
        # Find appropriate emoji
        reward_emoji = '🎁'  # default
        for key, emoji in emoji_map.items():
            if key.lower() in reward.name.lower():
                reward_emoji = emoji
                break
        
        reward_dict = {
            'id': reward.id,
            'name': reward.name,
            'department': reward.department,
            'cost': reward.cost,
            'stock': reward.stock,
            'created_by': reward.created_by or 'Admin',
            'status': actual_status,
            'image': reward_emoji,
            'created_at': reward.created_at
        }
        rewards_data.append(reward_dict)
        print(f"   ✅ Formatted: {reward_dict['name']}")
    
    print(f"✅ Success! Formatted {len(rewards_data)} rewards")
except Exception as e:
    print(f"❌ Error formatting rewards: {e}")
    traceback.print_exc()
    rewards_data = []

# Step 4: Sort rewards
print("\n🔢 Step 4: Sorting rewards...")
try:
    rewards_data.sort(key=lambda x: x.get('created_at') or datetime.min, reverse=True)
    print(f"✅ Success! Sorted {len(rewards_data)} rewards")
except Exception as e:
    print(f"❌ Error sorting: {e}")
    traceback.print_exc()

# Step 5: Compile statistics
print("\n📈 Step 5: Compiling statistics...")
try:
    stats = {
        'total_rewards': reward_stats.get('total_rewards', 0),
        'active_rewards': len([r for r in rewards_data if r['status'] == 'active']),
        'out_of_stock': len([r for r in rewards_data if r['status'] == 'out_of_stock']),
        'redeemed_today': 0  # We'll test this separately
    }
    print(f"✅ Success! Stats: {stats}")
except Exception as e:
    print(f"❌ Error compiling stats: {e}")
    traceback.print_exc()
    stats = {}

# Step 6: Get transactions (this might be failing)
print("\n💳 Step 6: Getting transactions for 'redeemed_today'...")
try:
    redeemed_today = Transaction.get_transactions_by_type('redeem', limit=100)
    stats['redeemed_today'] = len(redeemed_today)
    print(f"✅ Success! Found {len(redeemed_today)} redemptions")
except Exception as e:
    print(f"❌ Error getting transactions: {e}")
    traceback.print_exc()
    stats['redeemed_today'] = 0

# Step 7: Get top redeemed
print("\n🏆 Step 7: Getting top redeemed rewards...")
try:
    transaction_stats = Transaction.get_transaction_statistics()
    popular_rewards = transaction_stats.get('popular_rewards', [])
    
    top_redeemed_data = []
    
    # Check if popular_rewards has data and handle both dict and tuple formats
    if popular_rewards:
        for i, reward_info in enumerate(popular_rewards[:3], 1):
            # Handle if it's a tuple or dict
            if isinstance(reward_info, dict):
                top_redeemed_data.append({
                    'name': reward_info.get('reward_name', 'Unknown'),
                    'count': reward_info.get('count', 0),
                    'points': reward_info.get('cost', 0),
                    'rank': i
                })
            elif isinstance(reward_info, (list, tuple)) and len(reward_info) >= 3:
                # If it's a tuple like (name, count, cost)
                top_redeemed_data.append({
                    'name': reward_info[0] if len(reward_info) > 0 else 'Unknown',
                    'count': reward_info[1] if len(reward_info) > 1 else 0,
                    'points': reward_info[2] if len(reward_info) > 2 else 0,
                    'rank': i
                })
    
    # Fallback if no popular rewards
    if not top_redeemed_data and len(rewards_data) > 0:
        print("   ℹ️ No transaction data, using fallback...")
        for i, reward in enumerate(rewards_data[:3], 1):
            top_redeemed_data.append({
                'name': reward['name'],
                'count': max(1, 100 - reward['cost']),
                'points': reward['cost'],
                'rank': i
            })
    
    print(f"✅ Success! Top redeemed: {len(top_redeemed_data)} items")
    for item in top_redeemed_data:
        print(f"   {item['rank']}. {item['name']} - {item['count']} redeemed")
except Exception as e:
    print(f"❌ Error getting top redeemed: {e}")
    traceback.print_exc()
    top_redeemed_data = []

# Step 8: Department names
print("\n🏫 Step 8: Setting up department names...")
try:
    department_names = sorted([
        'Accountancy, Business and Management',
        'College of Computer Studies',
        'College of Hospitality Management and Tourism',
        'College of Teacher Education',
        'College of Engineering',
        'Senior High School',
        'Food safety and security',
        'College of Fisheries',
        'College of Industrial Technology',
        'College of Agriculture',
        'College of Nursing',
        'Business Affairs Office',
    ])
    print(f"✅ Success! {len(department_names)} departments")
except Exception as e:
    print(f"❌ Error setting departments: {e}")
    traceback.print_exc()
    department_names = []

# Final summary
print("\n" + "=" * 80)
print("📋 FINAL SUMMARY")
print("=" * 80)
print(f"Rewards Data: {len(rewards_data)} items")
print(f"Statistics: {stats}")
print(f"Top Redeemed: {len(top_redeemed_data)} items")
print(f"Departments: {len(department_names)} items")

if len(rewards_data) > 0:
    print("\n✅ ALL DATA IS READY!")
    print("\nData that will be passed to template:")
    print(f"  rewards={len(rewards_data)} items")
    print(f"  stats={stats}")
    print(f"  top_redeemed={len(top_redeemed_data)} items")
    print(f"  departments={len(department_names)} items")
else:
    print("\n⚠️ NO REWARDS DATA!")
    print("This is why the page is empty.")

print("=" * 80)
